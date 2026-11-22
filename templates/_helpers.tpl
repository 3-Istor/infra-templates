{{/*
Expand the name of the chart.
*/}}
{{- define "cnp-generic-app.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "cnp-generic-app.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
CNPG cluster name (see cnpg-cluster.yaml for why this doesn't just reuse
fullname): capped at 50 chars total, so truncate the release name to 47 and
append "-db" rather than the chart-name-bearing fullname.
*/}}
{{- define "cnp-generic-app.dbBaseName" -}}
{{- printf "%s-db" (include "cnp-generic-app.dbStem" (dict "ctx" . "max" 47)) }}
{{- end }}

{{/*
The release name cut to max characters, keeping the environment suffix.
Truncating "<app>-stg" as a whole could drop the suffix and give a staging
database the name, and the backup bucket, of the prod one.
*/}}
{{- define "cnp-generic-app.dbStem" -}}
{{- $ctx := .ctx }}
{{- if eq (include "cnp-generic-app.environment" $ctx) "prod" }}
{{- $ctx.Release.Name | trunc (int .max) | trimSuffix "-" }}
{{- else }}
{{- printf "%s-stg" ($ctx.Release.Name | trimSuffix "-stg" | trunc (sub (int .max) 4 | int) | trimSuffix "-") }}
{{- end }}
{{- end }}

{{/*
Validated environment. Staging is the only other value: it changes names, not
behaviour, except that it never runs a canary (see releaseStrategy).
*/}}
{{- define "cnp-generic-app.environment" -}}
{{- $env := .Values.environment | default "prod" }}
{{- if not (has $env (list "prod" "staging")) }}
{{- fail (printf "environment %q is not one of prod, staging" $env) }}
{{- end }}
{{- $env }}
{{- end }}

{{/*
A restore cannot happen in place: CNPG only recovers into a new cluster. Each
restore therefore bumps db.restore.generation, which names a new cluster the
app is switched to, while the backup bucket keeps the base name so every
generation's backups stay in one place.
*/}}
{{- define "cnp-generic-app.dbClusterName" -}}
{{- $generation := int (dig "restore" "generation" 0 .Values.db) }}
{{- if gt $generation 0 }}
{{- $suffix := printf "-db-r%d" $generation }}
{{- printf "%s%s" (include "cnp-generic-app.dbStem" (dict "ctx" . "max" (sub 50 (len $suffix)))) $suffix }}
{{- else }}
{{- include "cnp-generic-app.dbBaseName" . }}
{{- end }}
{{- end }}

{{- define "cnp-generic-app.dbPoolerName" -}}
{{- printf "%s-pooler" (include "cnp-generic-app.dbClusterName" .) }}
{{- end }}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "cnp-generic-app.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels
*/}}
{{- define "cnp-generic-app.labels" -}}
helm.sh/chart: {{ include "cnp-generic-app.chart" . }}
{{ include "cnp-generic-app.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- /* Prod objects stay unlabelled so lighting up staging changes nothing in prod. */}}
{{- $env := include "cnp-generic-app.environment" . }}
{{- if ne $env "prod" }}
cnp.3istor.com/env: {{ $env }}
{{- end }}
{{- if .Values.commonLabels }}
{{- toYaml .Values.commonLabels }}
{{- end }}
{{- end }}

{{/*
Selector labels
*/}}
{{- define "cnp-generic-app.selectorLabels" -}}
app.kubernetes.io/name: {{ include "cnp-generic-app.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Pod labels the project's network policies select on (cnp-project-base):
backing marks a backing app's pods, set from cnp.type by the ApplicationSet;
egress-rgw lets the pod reach the RGW through the default egress filter.
*/}}
{{- define "cnp-generic-app.networkLabels" -}}
{{- if eq (dig "type" "" (.Values.cnp | default dict)) "backing" }}
cnp.3istor.com/role: backing
{{- end }}
{{- if or .Values.bucket.enabled .Values.network.rgwEgress }}
cnp.3istor.com/egress-rgw: "true"
{{- end }}
{{- end }}

{{/*
Name of the app's ObjectBucketClaim or bucket VaultSecret, and of the
ConfigMap and Secret Rook derives from the claim.
*/}}
{{- define "cnp-generic-app.bucketName" -}}
{{- printf "%s-bucket" (include "cnp-generic-app.fullname" .) }}
{{- end }}

{{/*
Env and envFrom shared by the app container and the migration Job, so both
see the same database, bucket and secrets. The migration Job passes directDB: DDL,
advisory locks and session settings do not survive transaction pooling, so it
always talks to the primary.
*/}}
{{- define "cnp-generic-app.containerEnv" -}}
{{- $tracing := .Values.tracing | default dict }}
{{- $rookBucket := and .Values.bucket.enabled (eq .Values.bucket.mode "rook") }}
{{- if or .Values.db.enabled .Values.env $tracing.enabled $rookBucket }}
env:
  {{- if .Values.db.enabled }}
  - name: DB_TYPE
    value: postgres
  - name: DB_HOST
    {{- if and .Values.db.pooler.enabled (not .directDB) }}
    value: {{ include "cnp-generic-app.dbPoolerName" . }}
    {{- else }}
    value: {{ printf "%s-rw" (include "cnp-generic-app.dbClusterName" .) }}
    {{- end }}
  - name: DB_PORT
    value: "5432"
  - name: DB_NAME
    value: {{ .Values.db.name | default .Values.app_name }}
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: {{ include "cnp-generic-app.fullname" . }}-secrets
        key: username
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: {{ include "cnp-generic-app.fullname" . }}-secrets
        key: password
  {{- end }}
  {{- if $rookBucket }}
  {{- $bucket := include "cnp-generic-app.bucketName" . }}
  {{- /* The RGW is outside the cluster: Rook's BUCKET_HOST is not used, same endpoint as the CNPG backups. */}}
  - name: S3_ENDPOINT
    value: {{ .Values.bucket.endpointURL | quote }}
  - name: S3_BUCKET
    valueFrom:
      configMapKeyRef:
        name: {{ $bucket }}
        key: BUCKET_NAME
  - name: S3_REGION
    valueFrom:
      configMapKeyRef:
        name: {{ $bucket }}
        key: BUCKET_REGION
  - name: AWS_ACCESS_KEY_ID
    valueFrom:
      secretKeyRef:
        name: {{ $bucket }}
        key: AWS_ACCESS_KEY_ID
  - name: AWS_SECRET_ACCESS_KEY
    valueFrom:
      secretKeyRef:
        name: {{ $bucket }}
        key: AWS_SECRET_ACCESS_KEY
  {{- end }}
  {{- if $tracing.enabled }}
  {{- include "cnp-generic-app.tracingEnv" . | trim | nindent 2 }}
  {{- end }}
  {{- with .Values.env }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
envFrom:
  {{- if .Values.secrets.enabled }}
  - secretRef:
      name: {{ include "cnp-generic-app.fullname" . }}-secrets
  {{- end }}
  {{- if and .Values.bucket.enabled (eq .Values.bucket.mode "vault") }}
  - secretRef:
      name: {{ include "cnp-generic-app.bucketName" . }}
  {{- end }}
  {{- with .Values.envFrom }}
    {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}

{{/*
Validated release strategy. Every template that changes shape with the
strategy goes through this, so a typo fails the render instead of silently
falling back to a rolling update.
*/}}
{{- define "cnp-generic-app.releaseStrategy" -}}
{{- $release := .Values.release | default dict }}
{{- $strategy := $release.strategy | default "rolling" }}
{{- /*
  The release block is shared by both environments, but a canary needs real
  traffic to measure: staging always rolls.
*/}}
{{- if ne (include "cnp-generic-app.environment" .) "prod" }}
{{- $strategy = "rolling" }}
{{- end }}
{{- $preset := $release.preset | default "safe" }}
{{- $stickiness := $release.stickiness | default "cookie" }}
{{- if not (has $strategy (list "rolling" "canary" "bluegreen")) }}
{{- fail (printf "release.strategy %q is not one of rolling, canary, bluegreen" $strategy) }}
{{- end }}
{{- if not (has $preset (list "safe" "fast" "demo" "manual")) }}
{{- fail (printf "release.preset %q is not one of safe, fast, demo, manual" $preset) }}
{{- end }}
{{- if not (has $stickiness (list "none" "cookie")) }}
{{- fail (printf "release.stickiness %q is not one of none, cookie" $stickiness) }}
{{- end }}
{{- if eq $strategy "bluegreen" }}
{{- fail "release.strategy \"bluegreen\" is not supported yet: use canary or rolling" }}
{{- end }}
{{- if and (eq $strategy "canary") (not .Values.ingress.enabled) }}
{{- fail "release.strategy \"canary\" shifts traffic through the app's HTTPRoute: it needs ingress.enabled" }}
{{- end }}
{{- if and (eq $strategy "canary") (not .Values.service.enabled) }}
{{- fail "release.strategy \"canary\" routes to the -stable and -canary Services: it needs service.enabled" }}
{{- end }}
{{- $strategy }}
{{- end }}

{{- define "cnp-generic-app.isCanary" -}}
{{- if eq (include "cnp-generic-app.releaseStrategy" .) "canary" }}true{{ end }}
{{- end }}

{{- define "cnp-generic-app.isSticky" -}}
{{- if and (include "cnp-generic-app.isCanary" .) (eq (dig "stickiness" "cookie" (.Values.release | default dict)) "cookie") }}true{{ end }}
{{- end }}

{{/*
Container fields an imported workload may set, and the top-level probes a
template app enables. Renders nothing when .Values.workload is empty and no
probe is enabled, so template apps keep their manifests.
*/}}
{{- define "cnp-generic-app.workloadContainer" -}}
{{- $w := .Values.workload | default dict }}
{{- with $w.command }}
command:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $w.args }}
args:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- $probes := $w.probes | default dict }}
{{- with $probes.liveness | default (include "cnp-generic-app.enabledProbe" .Values.livenessProbe | fromYaml) }}
livenessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if not (include "cnp-generic-app.isCanary" .) }}
{{- with $probes.readiness | default (include "cnp-generic-app.enabledProbe" .Values.readinessProbe | fromYaml) }}
readinessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- with $probes.startup | default (include "cnp-generic-app.enabledProbe" .Values.startupProbe | fromYaml) }}
startupProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $w.securityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if or $w.tmpDirs (eq ($w.kind | default "Deployment") "StatefulSet") }}
volumeMounts:
  {{- range $i, $dir := $w.tmpDirs }}
  - name: tmp-{{ $i }}
    mountPath: {{ $dir }}
  {{- end }}
  {{- if eq ($w.kind | default "Deployment") "StatefulSet" }}
  - name: data
    mountPath: {{ dig "persistence" "mountPath" "/data" $w }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
A top-level livenessProbe, readinessProbe or startupProbe value without its
enabled switch, or nothing when it is off.
*/}}
{{- define "cnp-generic-app.enabledProbe" -}}
{{- if and . .enabled }}
{{- omit . "enabled" | toYaml }}
{{- end }}
{{- end }}

{{/*
podAnnotations plus the scrape annotations of metrics. Renders nothing for an
app that sets neither, so its pod template, and its pods, stay as they are.
*/}}
{{- define "cnp-generic-app.podAnnotations" -}}
{{- $annotations := deepCopy (.Values.podAnnotations | default dict) }}
{{- $metrics := .Values.metrics | default dict }}
{{- if $metrics.enabled }}
{{- $port := $metrics.port }}
{{- if not $port }}
{{- if not (and .Values.service.enabled .Values.service.ports) }}
{{- fail "metrics.enabled needs metrics.port, or a service port to take it from" }}
{{- end }}
{{- $port = (first .Values.service.ports).targetPort }}
{{- end }}
{{- $_ := set $annotations "prometheus.io/scrape" "true" }}
{{- $_ := set $annotations "prometheus.io/port" (toString $port) }}
{{- $_ := set $annotations "prometheus.io/path" ($metrics.path | default "/metrics") }}
{{- end }}
{{- with $annotations }}
{{- toYaml . }}
{{- end }}
{{- end }}

{{/*
OTEL_* variables of tracing.enabled, in the form every OpenTelemetry SDK reads.
The resource is limited to the service identity: the collector sets k8s.*,
the project and the tenant from the connection, and a client must not be able
to claim them.
*/}}
{{- define "cnp-generic-app.tracingEnv" -}}
{{- $tracing := .Values.tracing }}
{{- range .Values.env }}
{{- if eq .name "OTEL_RESOURCE_ATTRIBUTES" }}
{{- fail "env sets OTEL_RESOURCE_ATTRIBUTES: with tracing.enabled the collector sets the resource attributes, the app only names its service" }}
{{- end }}
{{- end }}
{{- $cnp := .Values.cnp | default dict }}
{{- $serviceName := $tracing.serviceName | default $cnp.app | default .Values.app_name | default (include "cnp-generic-app.name" .) }}
- name: OTEL_SERVICE_NAME
  value: {{ $serviceName | quote }}
- name: APP_VERSION
  value: {{ .Values.image.digest | default .Values.image.tag | default .Chart.AppVersion | quote }}
- name: OTEL_EXPORTER_OTLP_ENDPOINT
  value: {{ $tracing.endpoint | default "http://otelcol-gateway.observability.svc:4317" | quote }}
- name: OTEL_EXPORTER_OTLP_PROTOCOL
  value: grpc
- name: OTEL_TRACES_SAMPLER
  value: parentbased_traceidratio
- name: OTEL_TRACES_SAMPLER_ARG
  value: {{ ternary $tracing.sampleRatio "1.0" (hasKey $tracing "sampleRatio") | toString | quote }}
{{- end }}

{{/*
Pod-level fields of an imported workload.
*/}}
{{- define "cnp-generic-app.workloadPod" -}}
{{- $w := .Values.workload | default dict }}
{{- with $w.podSecurityContext }}
securityContext:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- with $w.tmpDirs }}
volumes:
  {{- range $i, $dir := . }}
  - name: tmp-{{ $i }}
    emptyDir: {}
  {{- end }}
{{- end }}
{{- end }}

{{- define "cnp-generic-app.isStatefulSet" -}}
{{- if eq (dig "kind" "Deployment" (.Values.workload | default dict)) "StatefulSet" }}true{{- end }}
{{- end }}

{{/*
A digest wins over the tag: the CMP pins imported images by digest, the image
updater keeps writing tags for template apps.
*/}}
{{- define "cnp-generic-app.image" -}}
{{- include "cnp-generic-app.checkImageOwner" . }}
{{- with .Values.image.digest }}
{{- printf "%s@%s" $.Values.image.repository . }}
{{- else }}
{{- printf "%v:%v" .Values.image.repository (.Values.image.tag | default .Chart.AppVersion) }}
{{- end }}
{{- end }}

{{/*
Who this release belongs to, as a dict: project, app, environment, namespace,
and the Vault role and base path of the app. Everything comes from cnp.*,
which the cnp-apps ApplicationSet sets as Helm parameters: parameters win over
every values file, so the app repository cannot change them. project_name and
secrets.vault* are written by the app (deploy values, CMP config) and are never
trusted for anything that crosses the namespace boundary.
Called with (list $ctx "<feature>"); use with fromJson.
*/}}
{{- define "cnp-generic-app.owner" -}}
{{- $ctx := index . 0 }}
{{- $feature := index . 1 }}
{{- $cnp := $ctx.Values.cnp | default dict }}
{{- if not (and $cnp.project $cnp.app $cnp.environment) }}
{{- fail (printf "%s needs cnp.project, cnp.app and cnp.environment, set by the ApplicationSet" $feature) }}
{{- end }}
{{- $env := $cnp.environment }}
{{- if not (has $env (list "prod" "staging")) }}
{{- fail (printf "%s: cnp.environment %q is not one of prod, staging" $feature $env) }}
{{- end }}
{{- $staging := eq $env "staging" }}
{{- $namespace := printf "%s-%s%s" $cnp.project $cnp.app (ternary "-stg" "" $staging) }}
{{- if ne $ctx.Release.Namespace $namespace }}
{{- fail (printf "%s: namespace %q is not %q, the namespace of %s/%s in %s" $feature $ctx.Release.Namespace $namespace $cnp.project $cnp.app $env) }}
{{- end }}
{{- if and $ctx.Values.project_name (ne $ctx.Values.project_name $cnp.project) }}
{{- fail (printf "%s: project_name %q is not this app's project %q" $feature $ctx.Values.project_name $cnp.project) }}
{{- end }}
{{- dict
  "project" $cnp.project
  "app" $cnp.app
  "environment" $env
  "namespace" $namespace
  "vaultRole" (printf "%s-%s%s-role" $cnp.project $cnp.app (ternary "-staging" "" $staging))
  "vaultPath" (printf "project-%s/%s%s" $cnp.project $cnp.app (ternary "/staging" "" $staging))
  | toJson }}
{{- end }}

{{/*
The app's VaultSecret path and role. secrets.vaultPath may name a sub-path of
the app's own Vault path, nothing else; secrets.vaultRole may only repeat the
app's role. Both are kept in values for existing files, the role rendered is
always the derived one. Called with (list $ctx "<feature>"); use with fromJson.
*/}}
{{- define "cnp-generic-app.vault" -}}
{{- $ctx := index . 0 }}
{{- $owner := include "cnp-generic-app.owner" . | fromJson }}
{{- $path := $ctx.Values.secrets.vaultPath | default $owner.vaultPath | trimSuffix "/" }}
{{- if not (or (eq $path $owner.vaultPath) (hasPrefix (printf "%s/" $owner.vaultPath) $path)) }}
{{- fail (printf "secrets.vaultPath %q is outside this app's Vault path %q" $path $owner.vaultPath) }}
{{- end }}
{{- if or (contains "/../" (printf "%s/" $path)) (contains "//" $path) }}
{{- fail (printf "secrets.vaultPath %q is not a plain path" $path) }}
{{- end }}
{{- with $ctx.Values.secrets.vaultRole }}
{{- if ne . $owner.vaultRole }}
{{- fail (printf "secrets.vaultRole %q is not this app's role %q" . $owner.vaultRole) }}
{{- end }}
{{- end }}
{{- dict "path" $path "role" $owner.vaultRole | toJson }}
{{- end }}

{{/*
Same rule as the Kyverno policy restrict-tenant-images (K3s), checked at
render time so the app's CI refuses the values before Argo CD syncs them:
ghcr.io/3-istor holds every project's private images and every node can pull
them. Org images must be the app's own (ghcr.io/3-istor/<app>[/...], named
after the app's repository) or its project's imports. Without cnp.* (a bare
helm template) there is no owner to compare with.
*/}}
{{- define "cnp-generic-app.checkImageOwner" -}}
{{- $cnp := .Values.cnp | default dict }}
{{- if and $cnp.project $cnp.app }}
{{- $repository := regexReplaceAll "^([^/]+):[0-9]+/" (.Values.image.repository | toString | lower) "${1}/" }}
{{- $own := and (ne $cnp.app "imports") (or (eq $repository (printf "ghcr.io/3-istor/%s" $cnp.app)) (hasPrefix (printf "ghcr.io/3-istor/%s/" $cnp.app) $repository)) }}
{{- $imported := hasPrefix (printf "ghcr.io/3-istor/imports/%s/" $cnp.project) $repository }}
{{- if and (hasPrefix "ghcr.io/3-istor/" $repository) (not (or $own $imported)) }}
{{- fail (printf "image.repository %q belongs to another app: org images must be ghcr.io/3-istor/%s[/...] or ghcr.io/3-istor/imports/%s/..." .Values.image.repository $cnp.app $cnp.project) }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Kubernetes CPU quantity in millicores. values.schema.json keeps resources to
the forms parsed here (100m, 1, 0.5).
*/}}
{{- define "cnp-generic-app.milliCPU" -}}
{{- $q := toString . }}
{{- if hasSuffix "m" $q }}{{ trimSuffix "m" $q | float64 | ceil | int }}{{ else }}{{ mulf (float64 $q) 1000 | ceil | int }}{{ end }}
{{- end }}

{{/*
Kubernetes memory quantity in MiB, rounded up.
*/}}
{{- define "cnp-generic-app.memoryMi" -}}
{{- $q := toString . }}
{{- $units := dict "Ki" 0.0009765625 "Mi" 1.0 "Gi" 1024.0 "Ti" 1048576.0 "k" 0.00095367431640625 "M" 0.95367431640625 "G" 953.67431640625 "T" 953674.31640625 }}
{{- $unit := regexFind "[KMGTk]i?$" $q }}
{{- $number := trimSuffix $unit $q | float64 }}
{{- if $unit }}{{ mulf $number (get $units $unit) | ceil | int }}{{ else }}{{ divf $number 1048576 | ceil | int }}{{ end }}
{{- end }}

{{/*
Requests of one container, the LimitRange defaults (cnp-project-base
namespace.yaml) filling what it leaves out. Returns {cpu: millicores, memory: MiB}.
*/}}
{{- define "cnp-generic-app.podRequests" -}}
{{- $requests := (. | default dict).requests | default dict }}
{{- dict
  "cpu" (include "cnp-generic-app.milliCPU" ($requests.cpu | default "50m") | int)
  "memory" (include "cnp-generic-app.memoryMi" ($requests.memory | default "128Mi") | int)
  | toJson }}
{{- end }}

{{/*
What this release asks of its namespace at its peak, as {cpu, memory, pods}:
the app's replicas plus the larger of a rollout's extra pods (25% surge, or a
full second set while a canary reaches 100%) and the migration Job, which
runs before the rollout while the old pods are up; then the database
instances, the pooler and the per-release tunnel. Each app namespace has the
same ResourceQuota (cnp-project-base namespace.yaml), mirrored in
cnp-generic-app.quota: a release that cannot fit in it alone is refused at
render time, before Argo CD syncs anything. A fullstack app has two releases
in one namespace; its CI adds both reports (templates/quota-report.yaml).
*/}}
{{- define "cnp-generic-app.quotaUsage" -}}
{{- $app := include "cnp-generic-app.podRequests" .Values.resources | fromJson }}
{{- $replicas := int (.Values.replicaCount | default 1) }}
{{- if and .Values.autoscaling .Values.autoscaling.enabled }}
{{- $replicas = int (.Values.autoscaling.maxReplicas | default 1) }}
{{- end }}
{{- $extra := 0 }}
{{- if include "cnp-generic-app.isStatefulSet" . }}
{{- $replicas = 1 }}
{{- else if include "cnp-generic-app.isCanary" . }}
{{- $extra = $replicas }}
{{- else }}
{{- $extra = div (add $replicas 3) 4 | int }}
{{- end }}
{{- $cpu := mul $replicas $app.cpu }}
{{- $memory := mul $replicas $app.memory }}
{{- $pods := $replicas }}
{{- $extraCPU := mul $extra $app.cpu }}
{{- $extraMemory := mul $extra $app.memory }}
{{- $extraPods := $extra }}
{{- if .Values.migrations.enabled }}
{{- $job := include "cnp-generic-app.podRequests" (.Values.migrations.resources | default .Values.resources) | fromJson }}
{{- $extraCPU = max $extraCPU $job.cpu }}
{{- $extraMemory = max $extraMemory $job.memory }}
{{- $extraPods = max $extraPods 1 }}
{{- end }}
{{- $cpu = add $cpu $extraCPU }}
{{- $memory = add $memory $extraMemory }}
{{- $pods = add $pods $extraPods }}
{{- if .Values.db.enabled }}
{{- $instances := int (.Values.db.instances | default 1) }}
{{- $instance := include "cnp-generic-app.podRequests" dict | fromJson }}
{{- $cpu = add $cpu (mul $instances $instance.cpu) }}
{{- $memory = add $memory (mul $instances $instance.memory) }}
{{- $pods = add $pods $instances }}
{{- if (.Values.db.pooler | default dict).enabled }}
{{- $poolers := int (.Values.db.pooler.instances | default 1) }}
{{- $pooler := include "cnp-generic-app.podRequests" .Values.db.pooler.resources | fromJson }}
{{- $cpu = add $cpu (mul $poolers $pooler.cpu) }}
{{- $memory = add $memory (mul $poolers $pooler.memory) }}
{{- $pods = add $pods $poolers }}
{{- end }}
{{- end }}
{{- if and .Values.ingress.enabled .Values.ingress.tunnel.perRelease }}
{{- $cpu = add $cpu 10 }}
{{- $memory = add $memory 16 }}
{{- $pods = add $pods 1 }}
{{- end }}
{{- dict "cpu" $cpu "memory" $memory "pods" $pods | toJson }}
{{- end }}

{{/*
The ResourceQuota of every app namespace, from cnp-project-base
templates/namespace.yaml: requests.cpu 1, requests.memory 2Gi, pods 10.
Constants on purpose: a value would let the app raise its own ceiling.
*/}}
{{- define "cnp-generic-app.quota" -}}
{{- dict "cpu" 1000 "memory" 2048 "pods" 10 | toJson }}
{{- end }}

{{/*
The app's route may only carry its own hostname: <app>-<project>.3istor.com,
or <app>-<project>-staging.3istor.com in staging, as the CMP derives them
(registry_names, environments/layout). An exact name rather than a
*-<project> suffix: project names contain dashes, so iot could otherwise
claim shop-b-iot.3istor.com of project b-iot, and its own auth-, status- and
offhours- hostnames. Without cnp.* (a bare helm template) there is no owner
to compare with.
*/}}
{{- define "cnp-generic-app.checkHostname" -}}
{{- $cnp := .Values.cnp | default dict }}
{{- if and $cnp.project $cnp.app $cnp.environment .Values.ingress.hostname }}
{{- $expected := printf "%s-%s%s.3istor.com" $cnp.app $cnp.project (ternary "-staging" "" (eq $cnp.environment "staging")) }}
{{- if ne (lower (toString .Values.ingress.hostname)) $expected }}
{{- fail (printf "ingress.hostname %q is not this app's hostname: %s/%s in %s is served at %q only" .Values.ingress.hostname $cnp.project $cnp.app $cnp.environment $expected) }}
{{- end }}
{{- end }}
{{- end }}
