{{ define "dance.namespace.pe_info_pipelinerun" }}
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: {{ .Chart.Name }}-pe-info-
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
              value: {{ .Chart.Name }}-pe-info
            - name: namespace
              value: {{ .Release.Namespace }}
{{ end }}