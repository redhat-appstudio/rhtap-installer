{{ define "dance.namespace.pe_info_task" }}
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: {{ .Chart.Name }}-pe-info
spec:
  description: >-
    Display the configuration information needed by the Platform
    Engineer to configure the RHDH.
  steps:
    - env:
      - name: ARGOCD_HOSTNAME
        valueFrom:
          secretKeyRef:
            name: {{ .Chart.Name }}-argocd-secret
            key: hostname
      - name: ARGOCD_TOKEN
        valueFrom:
          secretKeyRef:
            name: {{ .Chart.Name }}-argocd-secret
            key: api-token
      image: "k8s.gcr.io/hyperkube:v1.12.1"
      name: setup
      script: |
        #!/usr/bin/env bash
        set -o errexit
        set -o nounset
        set -o pipefail

        # Output information in YAML so that it can easily be
        # post-processed if necessary.
        cat << EOF
        gitops:
          api-token: \$ARGOCD_TOKEN
          hostname: \$ARGOCD_HOSTNAME
        EOF
      workingDir: /tmp
{{ end }}