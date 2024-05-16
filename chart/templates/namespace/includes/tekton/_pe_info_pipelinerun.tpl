{{ define "rhtap.namespace.pe_info_pipelinerun" }}
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: {{ index .Values "trusted-application-pipeline" "name" }}-pe-info-
  namespace: {{ .Release.Namespace }}
spec:
  pipelineSpec:
    tasks:
      - name: configuration-info
        taskRef:
          resolver: cluster
          params:
            - name: kind
              value: task
            - name: name
              value: {{ index .Values "trusted-application-pipeline" "name" }}-pe-info
            - name: namespace
              value: {{ .Release.Namespace }}
{{ end }}