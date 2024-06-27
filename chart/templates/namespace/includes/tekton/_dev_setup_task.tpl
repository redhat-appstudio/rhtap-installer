{{ define "rhtap.namespace.dev_setup_task" }}
apiVersion: tekton.dev/v1
kind: Task
metadata:
  name: {{index .Values "trusted-application-pipeline" "name"}}-dev-namespace-setup
  annotations:
    helm.sh/chart: "{{.Chart.Name}}-{{.Chart.Version}}"
spec:
  description: >-
    Create the required resources for {{.Chart.Name}} tasks to run in a namespace.
  params:
    - default: |-
        {{mustRegexReplaceAll "[$`\\\\]" (index .Values "openshift-gitops" "git-token") "\\${0}"}}
      description: |
        Git token
      name: git_token
      type: string
    {{- $gitlab_token := "" }}
    {{- if .Values.git.gitlab }}
      {{- $gitlab_token = (mustRegexReplaceAll "[$`\\\\]" .Values.git.gitlab.token "\\${0}") }}
    {{- end }}
    - default: |-
        {{$gitlab_token}}
      description: |
        GitLab Personal Access Token
      name: gitlab_token
      type: string
    - default: |-
        {{mustRegexReplaceAll "[$`\\\\]" (index .Values "pipelines" "pipelines-as-code" "github" "webhook-secret") "\\${0}"}}
      description: |
        Pipelines as Code webhook secret
      name: pipelines_webhook_secret
      type: string
    - default: |-
        {{mustRegexReplaceAll "[$`\\\\]" (index .Values "quay" "dockerconfigjson") "\\${0}"}}
      description: |
        Image registry token
      name: quay_dockerconfigjson
      type: string
    - default: |-
        {{mustRegexReplaceAll "[$`\\\\]" (index .Values "acs" "central-endpoint") "\\${0}"}}
      description: |
        StackRox Central address:port tuple
        (example - rox.stackrox.io:443)
      name: acs_central_endpoint
      type: string
    - default: |-
        {{mustRegexReplaceAll "[$`\\\\]" (index .Values "acs" "api-token") "\\${0}"}}
      description: |
        StackRox API token with CI permissions
      name: acs_api_token
      type: string
  steps:
    - env:
      - name: GIT_TOKEN
        value: \$(params.git_token)
      - name: GITLAB_TOKEN
        value: \$(params.gitlab_token)
      - name: PIPELINES_WEBHOOK_SECRET
        value: \$(params.pipelines_webhook_secret)
      - name: QUAY_DOCKERCONFIGJSON
        value: \$(params.quay_dockerconfigjson)
      - name: ROX_API_TOKEN
        value: \$(params.acs_api_token)
      - name: ROX_ENDPOINT
        value: \$(params.acs_central_endpoint)
      image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
      name: setup
      script: |
        #!/usr/bin/env bash
        set -o errexit
        set -o nounset
        set -o pipefail
      {{- if eq .Values.debug.script true }}
        set -x
      {{- end }}

        SECRET_NAME="cosign-pub"
        if [ -n "$COSIGN_SIGNING_PUBLIC_KEY" ]; then
          echo -n "* \$SECRET_NAME secret: "
          cat <<EOF | kubectl apply -f - >/dev/null
        apiVersion: v1
        data:
          cosign.pub: $COSIGN_SIGNING_PUBLIC_KEY
        kind: Secret
        metadata:
          labels:
            app.kubernetes.io/instance: default
            app.kubernetes.io/part-of: tekton-chains
            helm.sh/chart: {{.Chart.Name}}-{{.Chart.Version}}
            operator.tekton.dev/operand-name: tektoncd-chains
          name: \$SECRET_NAME
        type: Opaque
        EOF
          echo "OK"
        fi

        SECRET_NAME="gitlab-auth-secret"
        if [ -n "\$GITLAB_TOKEN" ]; then
          echo -n "* \$SECRET_NAME secret: "
          kubectl create secret generic "\$SECRET_NAME" \
            --from-literal=password=\$GITLAB_TOKEN \
            --from-literal=username=oauth2 \
            --type=kubernetes.io/basic-auth \
            --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
          kubectl annotate secret "\$SECRET_NAME" "helm.sh/chart={{.Chart.Name}}-{{.Chart.Version}}" >/dev/null
          echo "OK"
        fi

        SECRET_NAME="gitops-auth-secret"
        if [ -n "\$GIT_TOKEN" ]; then
          echo -n "* \$SECRET_NAME secret: "
          kubectl create secret generic "\$SECRET_NAME" \
            --from-literal=password=\$GIT_TOKEN \
            --type=kubernetes.io/basic-auth \
            --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
          kubectl annotate secret "\$SECRET_NAME" "helm.sh/chart={{.Chart.Name}}-{{.Chart.Version}}" >/dev/null
          echo "OK"
        fi

        SECRET_NAME="pipelines-secret"
        if [ -n "\$PIPELINES_WEBHOOK_SECRET" ]; then
          echo -n "* \$SECRET_NAME secret: "
          kubectl create secret generic "\$SECRET_NAME" \
            --from-literal=webhook.secret=\$PIPELINES_WEBHOOK_SECRET \
            --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
          kubectl annotate secret "\$SECRET_NAME" "helm.sh/chart={{.Chart.Name}}-{{.Chart.Version}}" >/dev/null
          echo "OK"
        fi
        
        SECRET_NAME="rhtap-image-registry-token"
        if [ -n "\$QUAY_DOCKERCONFIGJSON" ]; then
          echo -n "* \$SECRET_NAME secret: "
          DATA=$(mktemp)
          echo -n "\$QUAY_DOCKERCONFIGJSON" >"\$DATA"
          kubectl create secret docker-registry "\$SECRET_NAME" \
            --from-file=.dockerconfigjson="\$DATA" --dry-run=client -o yaml | \
            kubectl apply --filename - --overwrite=true >/dev/null
          rm "\$DATA"
          echo -n "."
          kubectl annotate secret "\$SECRET_NAME" "helm.sh/chart={{.Chart.Name}}-{{.Chart.Version}}" >/dev/null
          echo -n "."
          while ! kubectl get serviceaccount pipeline >/dev/null &>2; do
            sleep 2
            echo -n "_"
          done
          for SA in default pipeline; do
            kubectl patch serviceaccounts "\$SA" --patch "
          secrets:
            - name: \$SECRET_NAME
          imagePullSecrets:
            - name: \$SECRET_NAME
          " >/dev/null
            echo -n "."
          done
          echo "OK"
        fi
        
        SECRET_NAME="rox-api-token"
        if [ -n "\$ROX_API_TOKEN" ] && [ -n "\$ROX_ENDPOINT" ]; then
          echo -n "* \$SECRET_NAME secret: "
          kubectl create secret generic "\$SECRET_NAME" \
            --from-literal=rox-api-endpoint=\$ROX_ENDPOINT \
            --from-literal=rox-api-token=\$ROX_API_TOKEN \
            --dry-run=client -o yaml | kubectl apply --filename - --overwrite=true >/dev/null
          kubectl annotate secret "\$SECRET_NAME" "helm.sh/chart={{.Chart.Name}}-{{.Chart.Version}}" >/dev/null
          echo "OK"
        fi

        echo
        echo "Namespace is ready to execute {{ .Chart.Name }} pipelines"
      workingDir: /tmp
{{- end }}
