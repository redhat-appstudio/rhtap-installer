{{ define "dance.acs.configure" }}
- name: configure-acs
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      CRD=( pipelines tasks )
      echo -n "Waiting for '$CRD' CRD: "
      while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      cat << EOF | kubectl apply -f -
      {{ include "dance.acs.acs_image_check" . | indent 6 }}
      EOF
      cat << EOF | kubectl apply -f -
      {{ include "dance.acs.acs_image_scan" . | indent 6 }}
      EOF
{{ end }}