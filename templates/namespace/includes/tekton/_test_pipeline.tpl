{{ define "rhtap.namespace.test_pipeline" }}
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: rhtap-test-config-
  annotations:
    helm.sh/chart: "{{.Chart.Name}}-{{.Chart.Version}}"
spec:
  pipelineSpec:
    tasks:
    - name: argocd-login-check
      taskRef:
        resolver: cluster
        params:
          - name: kind
            value: task
          - name: name
            value: argocd-login-check
          - name: namespace
            value: {{ .Release.Namespace }}
{{ end }}