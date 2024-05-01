{{ define "rhtap.developer-hub.configure" }}
{{ if (index .Values "developer-hub") }}
- name: configure-developer-hub
  image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
  workingDir: /tmp
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

      CHART="{{ index .Values "trusted-application-pipeline" "name" }}"
      NAMESPACE="{{ .Release.Namespace }}"

      echo -n "* Generating 'app-config.extra.yaml': "
      APPCONFIGEXTRA="app-config.extra.yaml"
      touch "$APPCONFIGEXTRA"
      echo -n "."
      cat << EOF >> "$APPCONFIGEXTRA"
{{ include "rhtap.developer-hub.configure.app-config-extra" . | indent 6 }}
      EOF
      echo -n "."

      # Tekton integration
      while [ "$(kubectl get secret "$CHART-pipelines-secret" --ignore-not-found -o name | wc -l)" != "1" ]; do
        echo -ne "_"
        sleep 2
      done
      PIPELINES_PAC_URL="$(kubectl get secret "$CHART-pipelines-secret" -o yaml | yq '.data.webhook-url | @base64d')"
      echo "OK"

      echo -n "* Generating redhat-developer-hub-{{index .Values "trusted-application-pipeline" "name"}}-config secret: "
      cat <<EOF | kubectl apply -f - >/dev/null
{{ include "rhtap.developer-hub.configure.extra_env" . | indent 6 }}
      EOF
      echo "OK"

      echo -n "* Generating values.yaml: "
      helm repo add developer-hub https://raw.githubusercontent.com/rhdh-bot/openshift-helm-charts/rhdh-1.1-rhel-9/installation >/dev/null
      echo -n "."
      HELM_VALUES="/tmp/developer-hub-values.yaml"
      helm show values --devel developer-hub/redhat-developer-hub >"${HELM_VALUES}"

      cat <<EOF > rhtap-values.yaml
{{ include "rhtap.developer-hub.configure.helm_values" . | indent 6 }}
      EOF
      yq --inplace '. *= load("rhtap-values.yaml")' "${HELM_VALUES}"
      echo -n "."
      KUBERNETES_CLUSTER_FQDN="$(
        kubectl get routes -n openshift-pipelines pipelines-as-code-controller -o jsonpath='{.spec.host}' | \
        cut -d. -f 2-
      )"
      export KUBERNETES_CLUSTER_FQDN
      yq --inplace '.global.clusterRouterBase = strenv(KUBERNETES_CLUSTER_FQDN)' "$HELM_VALUES"
      echo -n "."

{{ include "rhtap.developer-hub.configure.configure_tls" . | indent 6 }}
{{ include "rhtap.developer-hub.configure.argocd" . | indent 6 }}
{{ include "rhtap.developer-hub.configure.plugin_kubernetes" . | indent 6 }}
      echo "OK"

      echo -n "* Installing Developer Hub: "
      kubectl create configmap redhat-developer-hub-app-config-extra \
        --from-file=app-config.extra.yaml="$APPCONFIGEXTRA" \
        -o yaml \
        --dry-run=client | kubectl apply -f - >/dev/null
      echo -n "."
      if ! helm upgrade \
        --install \
        --devel \
        --namespace=${NAMESPACE} \
        --values="$HELM_VALUES" \
        redhat-developer-hub \
        developer-hub/redhat-developer-hub >/dev/null; then
        echo "ERROR while installing chart!"
        exit 1
      fi
      echo "OK"

      echo -n "* Waiting for route: "
      until kubectl get route "redhat-developer-hub" -o name >/dev/null ; do
        echo -n "."
        sleep 3
      done
      HOSTNAME="$(kubectl get routes "redhat-developer-hub" -o jsonpath="{.spec.host}")"
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

      echo
      echo "Configuration successful"
{{ end }}
{{ end }}