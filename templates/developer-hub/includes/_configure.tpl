{{ define "rhtap.developer-hub.configure" }}
{{ if (index .Values "developer-hub") }}
- name: configure-developer-hub
  image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
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

      echo -n "Installing utils: "
      dnf install -y diffutils > /dev/null 2>/dev/null
      echo -n "."

      # Installing Helm...
      curl --fail --silent --show-error --location \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
          | bash >/dev/null
      echo "OK"

      YQ_VERSION="v4.40.5"
      curl --fail --location --output "/usr/bin/yq" --silent --show-error "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
      chmod +x "/usr/bin/yq"

      CHART="{{ .Chart.Name }}"
      NAMESPACE="{{ .Release.Namespace }}"

      echo -n "* Generating 'app-config.extra.yaml': "
      APPCONFIGEXTRA="app-config.extra.yaml"
      touch "$APPCONFIGEXTRA"
      echo -n "."
    {{ if and (index .Values "developer-hub") (index .Values "developer-hub" "app-config") }}
      cat << _EOF_ >> "$APPCONFIGEXTRA"
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
      cat << _EOF_ >> "$APPCONFIGEXTRA"
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
      yq -i ".integrations.github[0].apps[0].webhookUrl = \"$PIPELINES_PAC_URL\"" "$APPCONFIGEXTRA"
      echo "OK"

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
      echo -n "."
      KUBERNETES_CLUSTER_FQDN="$(
        kubectl get routes -n openshift-pipelines pipelines-as-code-controller -o jsonpath='{.spec.host}' | \
        cut -d. -f 2-
      )"
      export KUBERNETES_CLUSTER_FQDN
      yq --inplace '.global.clusterRouterBase = strenv(KUBERNETES_CLUSTER_FQDN)' "$HELM_VALUES"
      echo "OK"

{{ include "rhtap.developer-hub.configure.plugin_kubernetes" . | indent 6 }}

      echo -n "* Installing Developer Hub: "
      kubectl create configmap developer-hub-app-config-extra \
        --from-file=app-config.extra.yaml="$APPCONFIGEXTRA" \
        -o yaml \
        --dry-run=client | kubectl apply -f - >/dev/null
      echo -n "."
      helm repo add developer-hub https://raw.githubusercontent.com/rhdh-bot/openshift-helm-charts/rhdh-1.1-rhel-9/installation >/dev/null
      echo -n "."
      if ! helm upgrade \
        --install \
        --devel \
        --namespace=${NAMESPACE} \
        --values="$HELM_VALUES" \
        developer-hub \
        developer-hub/developer-hub >/dev/null; then
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

      # Wait for the UI to fully boot once before modifying the configuration.
      # This should avoid issues with DB migrations being interrupted and generating locks.
      # Once RHIDP-1691 is solved that safeguard could be removed.
      echo -n "* Waiting for UI: "
      until curl --fail --insecure --location --output /dev/null --silent "https://$HOSTNAME"; do
        echo -n "_"
        sleep 3
      done
      echo "OK"

{{ include "rhtap.developer-hub.configure.configure_tls" . | indent 6 }}

      echo -n "* Waiting for UI: "
      until curl --fail --insecure --location --output /dev/null --silent "https://$HOSTNAME"; do
        echo -n "_"
        sleep 3
      done
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}
{{ end }}