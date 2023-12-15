{{ define "dance.namespace.dev_setup_pipelinerun" }}
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: {{ .Chart.Name }}-dev-namespace-setup-
spec:
  pipelineSpec:
    tasks:
      - name: configure-namespace
        taskRef:
          resolver: cluster
          params:
            - name: kind
              value: task
            - name: name
              value: {{ .Chart.Name }}-dev-namespace-setup
            - name: namespace
              value: {{ .Release.Namespace }}
        params:
          - name: acs_central_endpoint
            value: {{ (index .Values "acs" "central-endpoint") }}
          - name: acs_api_token
            value: {{ (index .Values "acs" "api-token") }}
{{ end }}