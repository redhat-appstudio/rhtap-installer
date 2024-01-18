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

      {{ include "rhtap.openshift-pipelines.wait" . | indent 6 }}

      echo -n "* Configuring Tasks: "
      cat << EOF | kubectl apply -f - >/dev/null
      {{ include "rhtap.namespace.dev_setup_task" . | indent 8 }}
      EOF
      echo -n "."
      cat << EOF | kubectl apply -f - >/dev/null
      {{ include "rhtap.namespace.pe_info_task" . | indent 8 }}
      EOF
      echo -n "."
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}