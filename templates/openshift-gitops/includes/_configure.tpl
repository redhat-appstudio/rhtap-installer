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
      CHART="{{index .Values "trusted-application-pipeline" "name"}}"
      NAMESPACE="{{.Release.Namespace}}"
      RHTAP_ARGOCD_INSTANCE="$CHART-argocd"

      echo -n "* Waiting for gitops operator deployment: "
      until kubectl get argocds.argoproj.io -n openshift-gitops openshift-gitops -o jsonpath={.status.phase} | grep -q "^Available$"; do
        echo -n "_"
        sleep 2
      done
      echo "OK"

      echo -n "* Creating ArgoCD instance for RHTAP: "
      cat <<EOF | kubectl apply -n "$NAMESPACE" -f - >/dev/null
      {{ include "rhtap.include.argocd" . | indent 6 }}
      EOF
      until kubectl get argocds.argoproj.io -n "$NAMESPACE" "$RHTAP_ARGOCD_INSTANCE" --ignore-not-found -o jsonpath={.status.phase} | grep -q "^Available$"; do
        echo -n "_"
        sleep 2
      done
      echo -n "."
      until kubectl get route -n "$NAMESPACE" "$RHTAP_ARGOCD_INSTANCE-server" >/dev/null 2>&1; do
        echo -n "_"
        sleep 2
      done
      echo "OK"

      echo -n "* ArgoCD admin user: "
      if [ "$(kubectl get secret "$RHTAP_ARGOCD_INSTANCE-secret" -o name --ignore-not-found | wc -l)" = "0" ]; then
          ARGOCD_HOSTNAME="$(kubectl get route -n "$NAMESPACE" "$RHTAP_ARGOCD_INSTANCE-server" --ignore-not-found -o jsonpath={.spec.host})"
          echo -n "."
          ARGOCD_PASSWORD="$(kubectl get secret -n "$NAMESPACE" "$RHTAP_ARGOCD_INSTANCE-cluster" -o jsonpath="{.data.admin\.password}" | base64 --decode)"
          echo -n "."
          ./argocd login "$ARGOCD_HOSTNAME" --grpc-web --insecure --username admin --password "$ARGOCD_PASSWORD" >/dev/null
          echo -n "."
          ARGOCD_API_TOKEN="$(./argocd account generate-token --account "admin")"
          echo -n "."
          kubectl create secret generic "$RHTAP_ARGOCD_INSTANCE-secret" \
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
