{{ define "dance.acs.acs_image_check" }}
apiVersion: tekton.dev/v1beta1
kind: Task
metadata:
  name: acs-image-check
spec:
  description: |
    Policy check an image with StackRox/RHACS This tasks allows you to
    check an image against build-time policies and apply enforcement to fail builds.
    It's a companion to the acs-image-scan task, which returns full vulnerability
    scan results for an image.
  params:
  - default: "{{ (index .Values "acs" "central-endpoint") }}"
    description: |
      Secret containing the address:port tuple for StackRox Central)
      (example - rox.stackrox.io:443)
    name: rox_central_endpoint
    type: string
  - default: "{{ (index .Values "acs" "api-token") }}"
    description: |
      Secret containing the StackRox API token with CI permissions
    name: rox_api_token
    type: string
  - description: |
      Full name of image to scan (example -- gcr.io/rox/sample:5.0-rc1)
    name: image
    type: string
  - default: "false"
    description: |
      When set to \`"true"\`, skip verifying the TLS certs of the Central
      endpoint.  Defaults to \`"false"\`.
    name: insecure-skip-tls-verify
    type: string
  - description: |
      Digest of the image
    name: image_digest
    type: string
  results:
  - description: Output of \`roxctl image check\`
    name: check_output
  steps:
  - env:
    - name: ROX_API_TOKEN
      value: \$(params.rox_api_token)
    - name: ROX_ENDPOINT
      value: \$(params.rox_central_endpoint)
    image: registry.access.redhat.com/ubi8/ubi-minimal
    name: rox-image-check
    workingDir: /tmp
    script: |
      #!/usr/bin/env bash
      set -o errexit
      set -o nounset
      set -o pipefail
      set -x

      # Install roxctl
      curl --fail --insecure --location --silent \
        --header "Authorization: Bearer \$ROX_API_TOKEN" \
        --output ./roxctl  \
        "https://\$ROX_ENDPOINT/api/cli/download/roxctl-linux" \
        > /dev/null
      chmod +x ./roxctl  > /dev/null

      # Check image
      IMAGE=\$(params.image)@\$(params.image_digest)
      ./roxctl image scan --force \
        \$(
          [ "\$(params.insecure-skip-tls-verify)" = "true" ] && \
          echo -n "--insecure-skip-tls-verify"
        ) \
        --image "\$IMAGE" \
        --output json > check.log

      cat check.log
{{ end }}