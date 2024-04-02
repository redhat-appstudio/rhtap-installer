{{ define "rhtap.gitops.configure" }}
- name: configure-gitops
  image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
  command:
    - /bin/sh
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail
    {{ if eq .Values.debug.script true }}
      set -x
    {{ end }}

      echo -n "* Installing 'argocd' CLI: "
      curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
      chmod 555 argocd
      ./argocd version --client | head -1 | cut -d' ' -f2

      CRD="argocds"
      echo -n "* Waiting for '$CRD' CRD: "
      while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      #
      # All actions must be idempotent
      #
      CHART="{{ .Chart.Name }}"
      ARGOCD_NAMESPACE="openshift-gitops"

      echo -n "* Waiting for gitops operator deployment: "
      until kubectl get argocd -n "$ARGOCD_NAMESPACE" openshift-gitops --ignore-not-found >/dev/null; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      RHTAP_ARGOCD_NAMESPACE="{{.Release.Namespace}}"
      RHTAP_ARGOCD_INSTANCE="{{.Chart.Name}}"

      echo -n "* Creating ArgoCD instance for RHTAP: "
      cat <<EOF | kubectl apply -n "${RHTAP_ARGOCD_NAMESPACE}" -f -
      {{ include "rhtap.include.argocd" . | indent 6 }}
      EOF

      echo -n "* ArgoCD dashboard: "
      test_cmd="kubectl get route -n "${RHTAP_ARGOCD_NAMESPACE}" "${RHTAP_ARGOCD_INSTANCE}-server" --ignore-not-found -o jsonpath={.spec.host}"
      ARGOCD_HOSTNAME="$(${test_cmd})"
      until curl --fail --insecure --output /dev/null --silent "https://$ARGOCD_HOSTNAME"; do
        echo -n "."
        sleep 2
        ARGOCD_HOSTNAME="$(${test_cmd})"
      done
      echo "OK"

      echo -n " * ArgoCD admin user: "
      if [ "$(kubectl get secret "$CHART-argocd-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
          ARGOCD_PASSWORD="$(kubectl get secret -n "${RHTAP_ARGOCD_NAMESPACE}" "${RHTAP_ARGOCD_INSTANCE}-cluster" -o jsonpath="{.data.admin\.password}" | base64 --decode)"
          ./argocd login "$ARGOCD_HOSTNAME" --grpc-web --insecure --username admin --password "$ARGOCD_PASSWORD" >/dev/null
          echo -n "."
          ARGOCD_API_TOKEN="$(./argocd account generate-token --account "admin")"
          echo -n "."
          kubectl create secret generic "$CHART-argocd-secret" \
            --from-literal="api-token=$ARGOCD_API_TOKEN" \
            --from-literal="hostname=$ARGOCD_HOSTNAME" \
            --from-literal="password=$ARGOCD_PASSWORD" \
            --from-literal="user=admin" \
            > /dev/null
      fi
      echo "OK"

      {{ include "rhtap.openshift-pipelines.wait" . | indent 6 }}

      echo -n "* Configuring Tasks: "
      cat << EOF | kubectl apply -f - >/dev/null
      {{ include "rhtap.openshift-gitops.argocd-login-check" . | indent 6 }}
      EOF
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}
