{{ define "rhtap.developer-hub.configure" }}
- name: configure-developer-hub
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail
    {{ if eq .Values.debug.script true }}
      set -x
    {{ end }}


      # Installing Helm...
      curl --fail --silent --show-error --location \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
          | bash

      YQ_VERSION="v4.40.5"
      curl --fail --location --output "/usr/bin/yq" --silent --show-error "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
      chmod +x "/usr/bin/yq"

      CHART="{{ .Chart.Name }}"
      NAMESPACE="{{ .Release.Namespace }}"

      echo -n "* Generating values.yaml: "
      HELM_VALUES="/tmp/developer-hub-values.yaml"
    {{ if (index .Values "developer-hub") }}
      cat <<EOF >${HELM_VALUES}
{{ index .Values "developer-hub" "values" | toYaml | indent 6 }}
      EOF
    {{ else }}
      echo 'Expected "developer-hub" in the values.yaml' >&2
      exit 1
    {{ end }}
      echo "OK"

{{ include "rhtap.developer-hub.configure.plugin_kubernetes" . | indent 6 }}

      echo -n "* Installing Developer Hub: "
      helm repo add developer-hub https://raw.githubusercontent.com/rhdh-bot/openshift-helm-charts/rhdh-1.1-rhel-9/installation
      echo -n "."
      if ! helm upgrade \
        --install \
        --devel \
        --namespace=${NAMESPACE} \
        --values="$HELM_VALUES" \
        developer-hub \
        developer-hub/developer-hub; then
        echo "ERROR while installing chart!"
        exit 1
      fi
      echo "OK"

      echo -n "* Waiting for route: "
      until kubectl get route "developer-hub" -o name >/dev/null ; do
        echo -n "."
        sleep 3
      done
      HOSTNAME="$(kubectl get routes "developer-hub" -o jsonpath="{.spec.host}")"
      echo -n "."
      if [ "$(kubectl get secret "$CHART-developer-hub-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
        kubectl create secret generic "$CHART-developer-hub-secret" \
          --from-literal="hostname=$HOSTNAME" >/dev/null
      fi
      echo "OK"

      echo -n "* Updating app-config.yaml: "
      kubectl get configmap developer-hub-app-config -o yaml > developer-hub-app-config.current.yaml
      yq '.data.["app-config.yaml"]' developer-hub-app-config.current.yaml > app-config.yaml
      touch app-config-update.yaml
      echo -n "."

      # Set the base URL
      URL="https://$HOSTNAME"
      yq -i ".app.baseUrl = \"$URL\" | .backend.baseUrl = \"$URL\" |.backend.cors.origin = \"$URL\"" app-config.yaml
      echo -n "."

    {{ if and (index .Values "developer-hub") (index .Values "developer-hub" "app-config") }}
      cat << _EOF_ >> app-config-update.yaml
{{ index .Values "developer-hub" "app-config" | toYaml | indent 6 }}
      _EOF_
      echo -n "."
    {{ end }}

      # ArgoCD integration
      while [ "$(kubectl get secret "$CHART-argocd-secret" --ignore-not-found -o name | wc -l)" != "1" ]; do
        echo -ne "_"
        sleep 2
      done
      kubectl get secret "$CHART-argocd-secret" -o yaml > argocd_secret.yaml
      echo -n "."

      ARGOCD_API_TOKEN="$(yq '.data.api-token | @base64d' argocd_secret.yaml)"
      ARGOCD_HOSTNAME="$(yq '.data.hostname | @base64d' argocd_secret.yaml)"
      ARGOCD_PASSWORD="$(yq '.data.password | @base64d' argocd_secret.yaml)"
      ARGOCD_USER="$(yq '.data.user | @base64d' argocd_secret.yaml)"
      cat << _EOF_ >> app-config-update.yaml
      argocd:
        username: $ARGOCD_USER
        password: $ARGOCD_PASSWORD
        waitCycles: 25
        appLocatorMethods:
          - type: 'config'
            instances:
              - name: default
                url: https://$ARGOCD_HOSTNAME
                token: $ARGOCD_API_TOKEN
      _EOF_

      # Tekton integration
      while [ "$(kubectl get secret "$CHART-pipelines-secret" --ignore-not-found -o name | wc -l)" != "1" ]; do
        echo -ne "_"
        sleep 2
      done
      PIPELINES_PAC_URL="$(kubectl get secret "$CHART-pipelines-secret" -o yaml | yq '.data.webhook-url | @base64d')"
      yq -i ".integrations.github[0].apps[0].webhookUrl = \"$PIPELINES_PAC_URL\"" app-config-update.yaml
      echo -n "."

      # Process app-config update
      yq -i '. *= load("app-config-update.yaml")' app-config.yaml
      yq ".data.[\"app-config.yaml\"] = \"$(cat app-config.yaml | sed 's:":\\":g')\"" developer-hub-app-config.current.yaml > developer-hub-app-config.new.yaml
      if [ "$(md5sum developer-hub-app-config.current.yaml | cut -d' ' -f1)" != "$(md5sum developer-hub-app-config.new.yaml | cut -d' ' -f1)" ]; then
        echo
        kubectl apply -f developer-hub-app-config.new.yaml
        echo "OK"
        echo -n "* Restarting Developer Hub: "
        kubectl delete pods -l "app.kubernetes.io/component=backstage"
      fi
      echo "OK"

      echo -n "* Waiting for UI: "
      until curl --fail --insecure --location --output /dev/null --silent "$URL"; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}