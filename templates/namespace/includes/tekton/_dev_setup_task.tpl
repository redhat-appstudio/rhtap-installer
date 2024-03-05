{{ define "rhtap.namespace.dev_setup_task" }}
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: {{.Chart.Name}}-dev-namespace-setup
  annotations:
    helm.sh/chart: "{{.Chart.Name}}-{{.Chart.Version}}"
spec:
  description: >-
    Create the required resources for {{.Chart.Name}} tasks to run in a namespace.
  params:
    - default: {{index .Values "acs" "central-endpoint"}}
      description: |
        Secret containing the address:port tuple for StackRox Central
        (example - rox.stackrox.io:443)
      name: acs_central_endpoint
      type: string
    - default: {{index .Values "acs" "api-token"}}
      description: |
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
        
        SECRET_NAME="rox-api-token"
        if [ -n "\$ROX_API_TOKEN" ] && [ -n "\$ROX_ENDPOINT" ]; then
          echo -n "* \$SECRET_NAME secret: "
          kubectl create secret generic "\$SECRET_NAME" \
            --from-literal=rox_central_endpoint=\$ROX_ENDPOINT \
            --from-literal=rox_api_token=\$ROX_API_TOKEN \
            --dry-run -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
          kubectl annotate secret "\$SECRET_NAME" "helm.sh/chart={{.Chart.Name}}-{{.Chart.Version}}" >/dev/null
          echo "OK"
        fi

        echo "Namespace is ready to execute {{ .Chart.Name }} pipelines"
      workingDir: /tmp
{{ end }}