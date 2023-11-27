{{ define "dance.configure.acs" }}
- name: configure-acs
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      echo -n "* OperatorGroup: "
      if [ "$(oc get operatorgroups -n rhacs-operator 2>/dev/null | wc -l)" = "0" ];then
        cat << EOF | oc create -f -
      {{ include "dance.includes.operatorgroup" . | indent 6}}
      EOF
      else
        echo "OK"
      fi

      CRDS=( centrals securedclusters )
      for CRD in "${CRDS[@]}"; do
        echo -n "* Waiting for '$CRD' CRD: "
        while [ $(kubectl api-resources 2>/dev/null | grep -c "^$CRD ") = "0" ] ; do
          echo -n "."
          sleep 3
        done
        echo "OK"
      done

      echo "TODO: Configure ACS"
{{ end }}