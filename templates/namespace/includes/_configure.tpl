{{ define "rhtap.namespace.configure" }}
- name: configure-namespace
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

      {{ include "rhtap.openshift-pipelines.wait" . | indent 6 }}

      CHART="{{.Chart.Name}}"
      NAMESPACE="{{.Release.Namespace}}"

      echo -n "* Configuring Tasks: "
      while ! kubectl get secrets -n openshift-pipelines signing-secrets >/dev/null 2>&1; do
        echo -n "_"
        sleep 2
      done
      echo -n "."
      COSIGN_SIGNING_PUBLIC_KEY=""
      while [ -z "${COSIGN_SIGNING_PUBLIC_KEY:-}" ]; do
        echo -n "_"
        sleep 2
        COSIGN_SIGNING_PUBLIC_KEY=$(kubectl get secrets -n openshift-pipelines signing-secrets -o jsonpath='{.data.cosign\.pub}' 2>/dev/null)
      done
      cat << EOF | kubectl apply -f - >/dev/null
      {{ include "rhtap.namespace.dev_setup_task" . | indent 8 }}
      EOF
      echo -n "."
      cat << EOF | kubectl apply -f - >/dev/null
      {{ include "rhtap.namespace.pe_info_task" . | indent 8 }}
      EOF
      echo -n "."
      echo "OK"

    {{if (unset .Values "" | dig "trusted-application-pipeline" "namespaces" false)}}
      {{include "rhtap.namespace.developer.configure" . | indent 6}}
    {{ end }}

      echo
      echo "Configuration successful"
{{ end }}