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
Env and envFrom shared by the app container and the migration Job, so both
see the same database and secrets.
*/}}
{{- define "cnp-generic-app.containerEnv" -}}
{{- if or .Values.db.enabled .Values.env }}
env:
  {{- if .Values.db.enabled }}
  - name: DB_TYPE
    value: postgres
  - name: DB_HOST
    value: {{ printf "%s-rw" (include "cnp-generic-app.dbClusterName" .) }}
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
  {{- with .Values.env }}
  {{- toYaml . | nindent 2 }}
  {{- end }}
{{- end }}
envFrom:
  {{- if .Values.secrets.enabled }}
  - secretRef:
      name: {{ include "cnp-generic-app.fullname" . }}-secrets
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
Container fields an imported workload may set. Renders nothing when
.Values.workload is empty, so template apps keep their manifests.
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
{{- with $probes.liveness }}
livenessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- if not (include "cnp-generic-app.isCanary" .) }}
{{- with $probes.readiness }}
readinessProbe:
  {{- toYaml . | nindent 2 }}
{{- end }}
{{- end }}
{{- with $probes.startup }}
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
