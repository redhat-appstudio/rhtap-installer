{{ define "rhtap.namespace.test" }}
- name: test-rhtap
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      pipeline_id="$(cat << EOF | kubectl create -f - | cut -d' ' -f 1
      {{ include "rhtap.namespace.test_pipeline" . | indent 8 }}
      EOF
      )"
      echo -n "* Pipeline $pipeline_id: "
      while ! kubectl get "$pipeline_id" | grep --extended-regex --quiet " False | True "; do
        echo -n "."
        sleep 2
      done
      if kubectl get "$pipeline_id" | grep --quiet " True "; then
        kubectl delete "$pipeline_id" > /dev/null
        echo "OK"
      else
        echo "Failed"
        exit 1
      fi
{{ end }}