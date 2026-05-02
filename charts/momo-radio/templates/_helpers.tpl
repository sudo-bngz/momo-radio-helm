{{/* Expand the name of the chart. */}}
{{- define "momo-radio.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/* Create a fully qualified app name. */}}
{{- define "momo-radio.fullname" -}}
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

{{/* Common labels */}}
{{- define "momo-radio.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
app.kubernetes.io/part-of: {{ template "momo-radio.name" . }}
{{- end }}

{{/* 
  Momo Radio Common Environment Variables 
  Mapping from values.yaml to Go App expectations
*/}}
{{- define "momo-radio.env.common" -}}
- name: RADIO_STORAGE_PROVIDER
  value: {{ .Values.config.storage.provider | quote }}
- name: RADIO_STORAGE_ENDPOINT
  value: {{ .Values.config.storage.endpoint | quote }}
- name: RADIO_STORAGE_REGION
  value: {{ .Values.config.storage.region | quote }}
- name: RADIO_STORAGE_KEY_ID
  value: {{ .Values.config.storage.keyId | quote }}
- name: RADIO_STORAGE_BUCKET_INGEST
  value: {{ .Values.config.storage.bucketIngest | quote }}
- name: RADIO_STORAGE_BUCKET_PROD
  value: {{ .Values.config.storage.bucketProd | quote }}
- name: RADIO_STORAGE_BUCKET_STREAM_LIVE
  value: {{ .Values.config.storage.bucketStreamLive | quote }}
- name: RADIO_STORAGE_BUCKET_MASTER
  value: {{ .Values.config.storage.bucketMaster | quote }}
- name: RADIO_TIMEZONE
  value: {{ .Values.config.server.timezone | quote }}
- name: RADIO_DATABASE_HOST
  value: {{ .Values.config.database.host | quote }}
- name: RADIO_DATABASE_PORT
  value: {{ .Values.config.database.port | quote }}
- name: RADIO_DATABASE_USER
  value: {{ .Values.config.database.user | quote }}
- name: RADIO_DATABASE_NAME
  value: {{ .Values.config.database.name | quote }}
- name: RADIO_REDIS_HOST
  value: {{ .Values.config.redis.host | quote }}
- name: RADIO_REDIS_PORT
  value: {{ .Values.config.redis.port | quote }}
- name: RADIO_SERVER_POLLING_INTERVAL_SECONDS
  value: {{ .Values.config.server.pollingInterval | quote }}
- name: RADIO_SERVER_TEMP_DIR
  value: {{ .Values.config.server.tempDir | quote }}
{{- end }}