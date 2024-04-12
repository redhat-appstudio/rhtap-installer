{{ define "rhtap.trusted-artifact-signer.test" }}
{{ if (index .Values "trusted-artifact-signer") }}
- name: test-trusted-artifact-signer
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

      rollout_status() {
        local namespace="${1}"
        local deployment="${2}"

        if ! kubectl --namespace="${namespace}" --timeout="5m" \
          rollout status deployment "${deployment}"; then
          fail "'${namespace}/${deployment}' is not deployed as expected!"
        fi
      }

      deployments=(ctlog fulcio-server rekor-redis rekor-server trillian-db trillian-logserver trillian-logsigner tuf)
      for deploy in "${deployments[@]}"; do
        rollout_status "{{.Release.Namespace}}" "${deploy}"
      done
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 20m
      memory: 128Mi
{{ end }}
{{ end }}