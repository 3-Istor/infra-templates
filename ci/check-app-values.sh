#!/usr/bin/env bash
# Renders an app repository's deploy/ values with this chart, the way Argo CD
# does, so the app's CI refuses what Argo CD would refuse: values outside
# values.schema.json, an image of another app, a release above the namespace
# quota. A fullstack app runs two releases in one namespace: their peaks are
# added here, which no single render can see.
#
# Usage: check-app-values.sh <app repository checkout> <app name>
# The app name is the repository name: template apps are named after it.
set -euo pipefail

app_dir=${1:?app repository checkout}
app=${2:?app name}
chart_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
deploy="$app_dir/deploy"

if [[ -f "$deploy/values.yaml" ]]; then
  type=static
  components=(app)
  base_file() { echo "$deploy/values.yaml"; }
elif [[ -f "$deploy/values-backend.yaml" && -f "$deploy/values-frontend.yaml" ]]; then
  type=fullstack
  components=(frontend backend)
  base_file() { echo "$deploy/values-$1.yaml"; }
else
  echo "::error::deploy/values.yaml, or deploy/values-frontend.yaml and deploy/values-backend.yaml, are missing"
  exit 1
fi

# The ApplicationSet takes the project from the registry and pins
# project_name to it; the template repository itself has none yet.
project=$(sed -nE 's/^project_name:[[:space:]]*"?([a-z0-9-]+)"?[[:space:]]*(#.*)?$/\1/p' "$(base_file "${components[0]}")" | head -n1)
project=${project:-template}

environments=(prod)
[[ -d "$deploy/env/staging" ]] && environments+=(staging)

status=0
for environment in "${environments[@]}"; do
  namespace="$project-$app"
  [[ "$environment" == staging ]] && namespace+="-stg"
  total_cpu=0 total_memory=0 total_pods=0
  for component in "${components[@]}"; do
    files=(-f "$(base_file "$component")")
    overlay="$deploy/env/$environment/$component.yaml"
    [[ -f "$overlay" ]] && files+=(-f "$overlay")
    echo "== $environment/$component"
    if ! report=$(helm template "$component" "$chart_dir" "${files[@]}" \
        --namespace "$namespace" \
        --set-string "cnp.project=$project,cnp.app=$app,cnp.environment=$environment,cnp.type=$type,project_name=$project" \
        --set cnp.quotaReport=true \
        --show-only templates/quota-report.yaml 2>&1); then
      echo "::error title=deploy/ values refused ($environment/$component)::${report//$'\n'/%0A}"
      status=1
      continue
    fi
    line=$(grep '^# cnp-quota ' <<<"$report")
    echo "$line"
    read -r cpu memory pods quota_cpu quota_memory quota_pods < <(
      sed -E 's/.*usage cpu=([0-9]+) memory=([0-9]+) pods=([0-9]+) quota cpu=([0-9]+) memory=([0-9]+) pods=([0-9]+).*/\1 \2 \3 \4 \5 \6/' <<<"$line")
    total_cpu=$((total_cpu + cpu))
    total_memory=$((total_memory + memory))
    total_pods=$((total_pods + pods))
  done
  if ((${#components[@]} > 1 && status == 0)); then
    echo "== $environment, namespace $namespace: cpu=${total_cpu}m memory=${total_memory}Mi pods=$total_pods of cpu=${quota_cpu}m memory=${quota_memory}Mi pods=$quota_pods"
    if ((total_cpu > quota_cpu || total_memory > quota_memory || total_pods > quota_pods)); then
      echo "::error title=namespace quota exceeded ($environment)::frontend and backend together need up to cpu=${total_cpu}m memory=${total_memory}Mi pods=$total_pods at their peak, more than the namespace quota cpu=${quota_cpu}m memory=${quota_memory}Mi pods=$quota_pods"
      status=1
    fi
  fi
done
exit "$status"
