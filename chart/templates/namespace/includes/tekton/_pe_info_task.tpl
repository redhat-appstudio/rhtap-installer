{{ define "rhtap.namespace.pe_info_task" }}
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: {{ index .Values "trusted-application-pipeline" "name" }}-pe-info
  annotations:
    helm.sh/chart: "{{.Chart.Name}}-{{.Chart.Version}}"
spec:
  description: >-
    Display the configuration information needed by the Platform
    Engineer to configure the RHDH.
  steps:
    - env:
      - name: ARGOCD_HOSTNAME
        valueFrom:
          secretKeyRef:
            name: {{ index .Values "trusted-application-pipeline" "name" }}-argocd-secret
            key: ARGOCD_HOSTNAME
      - name: ARGOCD_TOKEN
        valueFrom:
          secretKeyRef:
            name: {{ index .Values "trusted-application-pipeline" "name" }}-argocd-secret
            key: ARGOCD_API_TOKEN
      - name: DEVELOPER_HUB_HOSTNAME
        valueFrom:
          secretKeyRef:
            name: {{ index .Values "trusted-application-pipeline" "name" }}-developer-hub-secret
            key: hostname
      - name: PIPELINES_PAC_GH_SECRET
        valueFrom:
          secretKeyRef:
            name: {{ index .Values "trusted-application-pipeline" "name" }}-pipelines-secret
            key: webhook-github-secret
      - name: PIPELINES_PAC_URL
        valueFrom:
          secretKeyRef:
            name: {{ index .Values "trusted-application-pipeline" "name" }}-pipelines-secret
            key: webhook-url
      image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
      name: setup
      script: |
        #!/usr/bin/env bash
        set -o errexit
        set -o nounset
        set -o pipefail

        # Output information in YAML so that it can easily be
        # post-processed if necessary.
        cat << _EOF_
        gitops:
          api-token: \$ARGOCD_TOKEN
          hostname: \$ARGOCD_HOSTNAME
        developer-hub:
          hostname: \$DEVELOPER_HUB_HOSTNAME
        pipelines:
          pipelines-as-code:
          {{if .Values.git.github}}
            github:
              # The docs URL explains how to setup the GitHub Application.
              # Set dummy values for the homepage URL and webhook URL, and
              # replace them with the final values after the chart is installed.
              docs-url: https://pipelinesascode.com/docs/install/github_apps/
              homepage-url: https://\$DEVELOPER_HUB_HOSTNAME
              callback-url: https://\$DEVELOPER_HUB_HOSTNAME/api/auth/github/handler/frame
              webhook-url: \$PIPELINES_PAC_URL
              secret: \$PIPELINES_PAC_GH_SECRET
          {{end}}
          {{if .Values.git.gitlab}}
            gitlab:
              redirect-uri: https://\$DEVELOPER_HUB_HOSTNAME/api/auth/gitlab/handler/frame
              webhook-url: \$PIPELINES_PAC_URL
              secret: \$PIPELINES_PAC_GH_SECRET
          {{end}}
        _EOF_
      workingDir: /tmp
{{ end }}