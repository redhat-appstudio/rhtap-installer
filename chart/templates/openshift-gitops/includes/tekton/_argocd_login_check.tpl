{{ define "rhtap.openshift-gitops.argocd-login-check" }}
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: argocd-login-check
spec:
  description: >-
    Check the argocd login credentials.
  steps:
    - env:
      - name: ARGOCD_HOSTNAME
        valueFrom:
          secretKeyRef:
            name: {{index .Values "trusted-application-pipeline" "name"}}-argocd-secret
            key: ARGOCD_HOSTNAME
      - name: ARGOCD_PASSWORD
        valueFrom:
          secretKeyRef:
            name: {{index .Values "trusted-application-pipeline" "name"}}-argocd-secret
            key: ARGOCD_PASSWORD
      - name: ARGOCD_USER
        valueFrom:
          secretKeyRef:
            name: {{index .Values "trusted-application-pipeline" "name"}}-argocd-secret
            key: ARGOCD_USER
      image: registry.access.redhat.com/ubi9/ubi-minimal
      name: check-argocd-login
      script: |
        #!/usr/bin/env bash
        set -o errexit
        set -o nounset
        set -o pipefail

        echo -n "* Installing 'argocd' CLI: "
        curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
        chmod 555 argocd
        ./argocd version --client | head -1 | cut -d' ' -f2

        ./argocd login "\$ARGOCD_HOSTNAME" --grpc-web --insecure --username "\$ARGOCD_USER" --password "\$ARGOCD_PASSWORD"
      workingDir: /tmp
{{ end }}