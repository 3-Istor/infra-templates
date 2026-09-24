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
{{- define "cnp-generic-app.dbClusterName" -}}
{{- printf "%s-db" (.Release.Name | trunc 47 | trimSuffix "-") }}
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