{{ define "dance.developer-hub.configure" }}
- name: configure-developer-hub
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      YQ_VERSION="v4.40.5"
      curl --fail --location --output "/usr/bin/yq" --silent --show-error "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64"
      chmod +x "/usr/bin/yq"

      CHART="{{ .Chart.Name }}"

      echo -n "* Waiting for route: "
      until kubectl get route {{ .Release.Name }}-developer-hub -o name >/dev/null ; do
        echo -n "."
        sleep 3
      done
      HOSTNAME="$(kubectl get routes {{ .Release.Name }}-developer-hub -o jsonpath="{.spec.host}")"
      echo -n "."
      if [ "$(kubectl get secret "$CHART-developer-hub-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
        kubectl create secret generic "$CHART-developer-hub-secret" \
          --from-literal="hostname=$HOSTNAME" >/dev/null
      fi
      echo "OK"

      kubectl get configmap {{ .Release.Name }}-developer-hub-app-config -o yaml > developer-hub-app-config.yaml
      yq '.data.["app-config.yaml"]' developer-hub-app-config.yaml > app-config.yaml

      # Set the base URL
      URL="https://$HOSTNAME"
      yq -i ".app.baseUrl = \"$URL\" | .backend.baseUrl = \"$URL\" |.backend.cors.origin = \"$URL\"" app-config.yaml

      # Set the authentication
      {{ if and (index .Values "developer-hub") (index .Values "developer-hub" "app-config") }}
      cat << _EOF_ >> app-config.yaml
{{ index .Values "developer-hub" "app-config" | toYaml | indent 6 }}
      _EOF_
      {{ end }}
      yq -i ".data.[\"app-config.yaml\"] = \"$(cat app-config.yaml | sed 's:":\\":g')\"" developer-hub-app-config.yaml
      kubectl apply -f developer-hub-app-config.yaml

      kubectl delete pods -l "app.kubernetes.io/component=backstage"

      echo -n "* Waiting for UI: "
      until curl --fail --insecure --location --output /dev/null --silent "$URL"; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}