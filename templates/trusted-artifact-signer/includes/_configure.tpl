{{ define "rhtap.trusted-artifact-signer.configure" }}
{{ if (index .Values "trusted-artifact-signer") }}
- name: configure-trusted-artifact-signer
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

      CHART="{{index .Values "trusted-application-pipeline" "name"}}"

      echo -n "* Configure OIDC: "
    {{ if (unset .Values "" | dig "trusted-artifact-signer" "securesign" "fulcio" "OIDCIssuer" false) }}
      export FULCIO__OIDC__CLIENT_ID="{{ unset .Values "" | dig "trusted-artifact-signer" "securesign" "fulcio" "OIDCIssuer" "ClientID" "trusted-artifact-signer" }}
      export FULCIO__OIDC__TYPE="{{ unset .Values "" | dig "trusted-artifact-signer" "securesign" "fulcio" "OIDCIssuer" "Type" "email" }}
      export FULCIO__OIDC__URL="{{ unset .Values "" | dig "trusted-artifact-signer" "securesign" "fulcio" "OIDCIssuer" "IssuerURL" "https://oidc.cluster.com" }}"
    {{ else }}
      git clone https://github.com/securesign/sigstore-ocp.git >/dev/null
      echo -n "."
      oc apply --kustomize sigstore-ocp/keycloak/operator/base
      echo -n "."
      for CR in keycloaks keycloakclients keycloakrealms keycloakusers; do
        while [ $(kubectl api-resources | grep -c "^$CR ") = "0" ] ; do
          echo -n "_"
          sleep 2
        done
        echo -n "."
      done
      oc apply --kustomize sigstore-ocp/keycloak/resources/base --dry-run=client -o yaml
      oc apply --kustomize sigstore-ocp/keycloak/resources/base
      echo -n "."
      export FULCIO__OIDC__CLIENT_ID="trusted-artifact-signer"
      export FULCIO__OIDC__TYPE="email"
      FULCIO__OIDC__URL=""
      while [ -z "$FULCIO__OIDC__URL" ]; do
        FULCIO__OIDC__URL="$(kubectl get routes -n keycloak-system keycloak -o jsonpath="{.spec.host}" --ignore-not-found)"
        sleep 2
      done
      export FULCIO__OIDC__URL="https://$FULCIO__OIDC__URL/auth/realms/trusted-artifact-signer"
    {{ end }}
      export FULCIO__ORG_EMAIL="{{ unset .Values "" | dig "trusted-artifact-signer" "securesign" "fulcio" "certificate" "organizationEmail" "email@company.com" }}"
      export FULCIO__ORG_NAME="{{ unset .Values "" | dig "trusted-artifact-signer" "securesign" "fulcio" "certificate" "organizationName" "Company" }}"
      echo "OK"

      CRDS=( securesigns )
      for CRD in "${CRDS[@]}"; do
        echo -n "* Waiting for '$CRD' CRD: "
        while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
          echo -n "_"
          sleep 2
        done
        echo "OK"
      done

      echo -n "* Configure SecureSign instance: "
      cat <<EOF | kubectl apply -f - >/dev/null
{{ include "rhtap.trusted-artifact-signer.securesign" . | indent 6 }}
      EOF
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}
{{ end }}
