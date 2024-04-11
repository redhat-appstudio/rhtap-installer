{{ define "rhtap.pipelines.test" }}
- name: test-pipelines
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
      
      check_rhtap_pipelines_health() {
        echo "[INFO] Checking OpenShift Pipelines health..."

        # wait until tekton pipelines operator is created
        echo "Waiting for OpenShift Pipelines Operator to be created..."
        timeout 2m bash <<-EOF
        until oc get deployment openshift-pipelines-operator -n openshift-operators; do
          echo -n "."
          sleep 5
        done
      EOF
        oc rollout status -n openshift-operators deployment/openshift-pipelines-operator --timeout 10m

        # wait until clustertasks tekton CRD is properly deployed
        timeout 10m bash <<-EOF
        until oc get crd tasks.tekton.dev; do
          sleep 5
        done
      EOF

        timeout 2m bash <<-EOF
        until oc get deployment tekton-pipelines-controller -n openshift-pipelines; do
          sleep 5
        done
      EOF
        rollout_status "openshift-pipelines" "tekton-pipelines-controller"
        rollout_status "openshift-pipelines" "tekton-pipelines-webhook"
      }

      check_rhtap_pipelines_health
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
{{ end }}