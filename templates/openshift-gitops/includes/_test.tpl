{{ define "rhtap.openshift-gitops.test" }}
- name: test-openshift-gitops
  image: "quay.io/codeready-toolchain/oc-client-base:latest"
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      rollout_status() {
        local namespace="${1}"
        local deployment="${2}"

        if ! kubectl --namespace="${namespace}" --timeout="5m" \
          rollout status deployment "${deployment}"; then
          fail "'${namespace}/${deployment}' is not deployed as expected!"
        fi
      }

      check_rhtap_gitops_health() {
        echo "[INFO] Checking OpenShift GitOps health..."

        # wait until tekton pipelines operator is created
        echo "Waiting for OpenShift Pipelines Operator to be created..."
        timeout 2m bash <<-EOF
        until oc get deployment openshift-gitops-operator-controller-manager -n openshift-operators; do
          echo -n "."
          sleep 5
        done
      EOF
        oc rollout status -n openshift-operators deployment/openshift-gitops-operator-controller-manager --timeout 10m

        # wait until all the deployments in the openshift-gitops namespace are ready:
        rollout_status "openshift-gitops" "cluster"
        rollout_status "openshift-gitops" "kam"
        rollout_status "openshift-gitops" "openshift-gitops-applicationset-controller"
        rollout_status "openshift-gitops" "openshift-gitops-dex-server"
        rollout_status "openshift-gitops" "openshift-gitops-redis"
        rollout_status "openshift-gitops" "openshift-gitops-repo-server"
        rollout_status "openshift-gitops" "openshift-gitops-server"


        # Check argocd instance creation
        oc create ns test-argocd

        cat << EOF | oc apply -f -
        apiVersion: argoproj.io/v1alpha1
        kind: ArgoCD
        metadata:
            name: argocd
            namespace: test-argocd
      EOF

        while [ "$(oc -n test-argocd get pod | grep -c argocd-)" -ne 4 ]; do
          sleep 5
        done
        oc wait --for=condition=Ready -n test-argocd pod --timeout=15m  -l 'app.kubernetes.io/name in (argocd-application-controller,argocd-redis,argocd-repo-server,argocd-server)'


        oc delete ns test-argocd
      }
      
      check_rhtap_gitops_health
{{ end }}