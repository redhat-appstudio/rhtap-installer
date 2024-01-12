{{ define "rhtap.acs.configure" }}
- name: configure-acs
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      CRDS=( pipelines tasks )
      for CRD in "${CRDS[@]}"; do
        echo -n "* Waiting for '$CRD' CRD: "
        while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
          echo -n "."
          sleep 3
        done
        echo "OK"
      done

      echo -n "* Configuring Tasks: "
      cat << EOF | kubectl apply -f - >/dev/null
      {{ include "rhtap.acs.acs_deploy_check" . | indent 8 }}
      EOF
      echo -n "."
      cat << EOF | kubectl apply -f - >/dev/null
      {{ include "rhtap.acs.acs_image_check" . | indent 8 }}
      EOF
      echo -n "."
      cat << EOF | kubectl apply -f - >/dev/null
      {{ include "rhtap.acs.acs_image_scan" . | indent 8 }}
      EOF
      echo -n "."
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}