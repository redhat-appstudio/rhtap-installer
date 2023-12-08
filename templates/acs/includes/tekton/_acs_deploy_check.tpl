{{ define "dance.acs.acs_deploy_check" }}
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: acs-deploy-check
spec:
  description: >-
    Policy check a deployment with StackRox/RHACS This tasks allows you to check
    a deployment against build-time policies and apply enforcement to fail
    builds. It's a companion to the stackrox-image-scan task, which returns full
    vulnerability scan results for an image.
  params:
    - default:  "{{ (index .Values "acs" "central-endpoint") }}"
      description: |
        Secret containing the address:port tuple for StackRox Central
        (example - rox.stackrox.io:443)
      name: rox_central_endpoint
      type: string
    - default: "{{ (index .Values "acs" "api-token") }}"
      description: |
        Secret containing the StackRox API token with CI permissions
      name: rox_api_token
      type: string
    - description: |
        URL to the deployment
        (example - https://raw.gitlab.mycompany.com/myorg/myapp/mybranch/argocd/mycomponent/myenv/deployment.yaml)
      name: deployment_url
      type: string
    - default: 'false'
      description: |
        When set to \`"true"\`, skip verifying the TLS certs of the Central
        endpoint.  Defaults to \`"false"\`.
      name: insecure-skip-tls-verify
      type: string
  results:
    - description: Output of \`roxctl deployment check\`
      name: check_output
  steps:
    - env:
      - name: ROX_API_TOKEN
        value: \$(params.rox_api_token)
      - name: ROX_ENDPOINT
        value: \$(params.rox_central_endpoint)
      image: registry.access.redhat.com/ubi8/ubi-minimal
      name: rox-deploy-scan
      script: |
        #!/usr/bin/env bash
        set -o errexit
        set -o nounset
        set -o pipefail

        curl -s -k -L -H "Authorization: Bearer \$ROX_API_TOKEN" \
          "https://\$ROX_ENDPOINT/api/cli/download/roxctl-linux" \
          --output ./roxctl  \
          > /dev/null
        chmod +x ./roxctl  > /dev/null

        curl --fail --insecure --location --output deployment.yaml --silent "\$(params.deployment_url)"

        ./roxctl deployment check \
          \$(
            [ "\$(params.insecure-skip-tls-verify)" = "true" ] && \
            echo -n "--insecure-skip-tls-verify"
          ) \
          --file "deployment.yaml" \
          --output json > check.log
          cat check.log
      workingDir: /tmp
{{ end }}