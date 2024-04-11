{{ define "rhtap.namespace.test" }}
- name: test-namespace
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
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
{{ end }}