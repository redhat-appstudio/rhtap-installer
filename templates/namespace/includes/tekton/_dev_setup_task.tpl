{{ define "rhtap.namespace.dev_setup_task" }}
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: {{ .Chart.Name }}-dev-namespace-setup
spec:
  description: >-
    Create the required resources for {{ .Chart.Name }} tasks to run in a namespace.
  params:
    - description: |
        Secret containing the address:port tuple for StackRox Central
        (example - rox.stackrox.io:443)
      name: acs_central_endpoint
      type: string
    - description: |
        Secret containing the StackRox API token with CI permissions
      name: acs_api_token
      type: string
  steps:
    - env:
      - name: ROX_API_TOKEN
        value: \$(params.acs_api_token)
      - name: ROX_ENDPOINT
        value: \$(params.acs_central_endpoint)
      image: "k8s.gcr.io/hyperkube:v1.12.1"
      name: setup
      script: |
        #!/usr/bin/env bash
        set -o errexit
        set -o nounset
        set -o pipefail
        
        echo "Generating secret: "
        kubectl create secret generic {{ .Chart.Name }}-secret \
          --from-literal=rox_central_endpoint=\$ROX_ENDPOINT \
          --from-literal=rox_api_token=\$ROX_API_TOKEN \
          --dry-run -o yaml | kubectl apply -f - >/dev/null
        echo "OK"

        echo "Namespace is ready to execute {{ .Chart.Name }} pipelines"
      workingDir: /tmp
{{ end }}