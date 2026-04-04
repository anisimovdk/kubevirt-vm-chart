{{/*
Expand the name of the chart.
*/}}
{{- define "kubevirt-vm.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a default fully qualified app name.
*/}}
{{- define "kubevirt-vm.fullname" -}}
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
Create chart name and version as used by the chart label.
*/}}
{{- define "kubevirt-vm.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "kubevirt-vm.labels" -}}
helm.sh/chart: {{ include "kubevirt-vm.chart" . }}
{{ include "kubevirt-vm.selectorLabels" . }}
{{- if .Chart.AppVersion }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
{{- end }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{/*
Selector labels.
*/}}
{{- define "kubevirt-vm.selectorLabels" -}}
app.kubernetes.io/name: {{ include "kubevirt-vm.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
DataVolume name used by the VM.
*/}}
{{- define "kubevirt-vm.rootDataVolumeName" -}}
{{- include "kubevirt-vm.fullname" . -}}
{{- end }}

{{/*
Chart-managed bridge NetworkAttachmentDefinition name.
*/}}
{{- define "kubevirt-vm.bridgeNetworkAttachmentDefinitionName" -}}
{{- printf "%s-%s" (include "kubevirt-vm.fullname" .) .Values.interfaces.bridge.config.name | trunc 63 | trimSuffix "-" -}}
{{- end }}

{{/*
User data mode precedence.
*/}}
{{- define "kubevirt-vm.cloudInitUserDataMode" -}}
{{- if .Values.cloudInit.userDataSecretRef -}}
secretRef
{{- else if .Values.cloudInit.userDataBase64 -}}
userDataBase64
{{- else if .Values.cloudInit.userData -}}
userData
{{- else -}}
generated
{{- end -}}
{{- end }}

{{/*
Network data mode precedence.
*/}}
{{- define "kubevirt-vm.cloudInitNetworkDataMode" -}}
{{- if .Values.cloudInit.networkDataSecretRef -}}
secretRef
{{- else if .Values.cloudInit.networkDataBase64 -}}
networkDataBase64
{{- else if .Values.cloudInit.networkData -}}
networkData
{{- else -}}
none
{{- end -}}
{{- end }}

{{/*
Generate cloud-init userData when raw userData was not supplied.
*/}}
{{- define "kubevirt-vm.generatedUserData" -}}
#cloud-config
{{- if .Values.cloudInit.config.username }}
user: {{ .Values.cloudInit.config.username | quote }}
{{- end }}
ssh_pwauth: {{ .Values.cloudInit.config.sshPasswordAuth }}
{{- if .Values.cloudInit.config.password }}
password: {{ .Values.cloudInit.config.password | quote }}
chpasswd:
  expire: {{ .Values.cloudInit.config.passwordExpire }}
{{- end }}
{{- if .Values.cloudInit.firstBoot.commands }}
runcmd:
{{- range .Values.cloudInit.firstBoot.commands }}
  - {{ toJson . }}
{{- end }}
{{- end }}
{{- end }}
