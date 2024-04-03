{{ define "rhtap.quay.configure" }}
- name: configure-quay
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

      CRD=""
      echo -n "Waiting for '$CRD' CRD: "
      while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
        echo -n "."
        sleep 3
      done
      echo
      echo "OK"

      echo -n "Waiting for quay operator deployment: "
      # until kubectl get "$CRD" >/dev/null 2>&1; do
      #   echo -n "."
      #   sleep 3
      # done
      # echo
      echo "OK"

      # All actions must be idempotent
{{ end }}