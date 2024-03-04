{{define "rhtap.namespace.dev_setup_pipelinerun"}}
apiVersion: tekton.dev/v1
kind: PipelineRun
metadata:
  generateName: {{.Chart.Name}}-dev-namespace-setup-
  annotations:
    helm.sh/chart: "{{.Chart.Name}}-{{.Chart.Version}}"
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
              value: {{.Chart.Name}}-dev-namespace-setup
            - name: namespace
              value: {{.Release.Namespace}}
{{end}}