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
        StackRox Central address:port tuple
        (example - rox.stackrox.io:443)
      name: acs_central_endpoint
      type: string
    - default: {{index .Values "acs" "api-token"}}
      description: |
        StackRox API token with CI permissions
      name: acs_api_token
      type: string
    - default: {{index .Values "quay" "token"}}
      description: |
        Image registry token
      name: quay_token
      type: string
  steps:
    - env:
      - name: ROX_API_TOKEN
        value: \$(params.acs_api_token)
      - name: ROX_ENDPOINT
        value: \$(params.acs_central_endpoint)
      - name: QUAY_TOKEN
        value: \$(params.quay_token)
      image: "quay.io/codeready-toolchain/oc-client-base:latest"
      name: setup
      script: |
        #!/usr/bin/env bash
        set -o errexit
        set -o nounset
        set -o pipefail
      {{if eq .Values.debug.script true}}
        set -x
      {{end}}
        
        SECRET_NAME="rhtap-image-registry-token"
        if [ -n "\$QUAY_TOKEN" ]; then
          echo -n "* \$SECRET_NAME secret: "
          DATA=$(mktemp)
          echo -n "\$QUAY_TOKEN" | base64 -d >"\$DATA"
          kubectl create secret docker-registry "\$SECRET_NAME" \
            --from-file=.dockerconfigjson="\$DATA" --dry-run=client -o yaml | \
            kubectl apply --filename - --overwrite=true >/dev/null || sleep 600
          rm "\$DATA"
          echo -n "."
          kubectl annotate secret "\$SECRET_NAME" "helm.sh/chart={{.Chart.Name}}-{{.Chart.Version}}" >/dev/null
          echo -n "."
          while ! kubectl get serviceaccount pipeline >/dev/null &>2; do
            sleep 2
            echo -n "_"
          done
          kubectl patch serviceaccounts pipeline --patch "
        secrets:
          - name: \$SECRET_NAME
        imagePullSecrets:
          - name: \$SECRET_NAME
        " >/dev/null
          echo "OK"
          kubectl get serviceaccount pipeline -o yaml
        fi
        
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