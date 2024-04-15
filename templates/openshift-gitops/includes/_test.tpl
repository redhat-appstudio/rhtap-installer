{{ define "rhtap.gitops.test" }}
- name: test-gitops
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
    
      ERRORS=()

      rollout_status() {
        local namespace="${1}"
        local deployment="${2}"

        if ! kubectl --namespace="${namespace}" --timeout="5m" \
          rollout status deployment "${deployment}"; then
          fail "'${namespace}/${deployment}' is not deployed as expected!"
        fi
      }

      check_gitops_operator_health() {
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
        oc delete ns test-argocd --ignore-not-found --wait
        oc create ns test-argocd

        cat << EOF | oc apply -f -
        apiVersion: argoproj.io/v1beta1
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

      check_rhtap_argocd_health() {
        echo "[INFO] Checking RHTAP ArgoCD instance health..."
        RHTAP_ARGOCD_INSTANCE="{{index .Values "trusted-application-pipeline" "name"}}-argocd"
        NAMESPACE="{{.Release.Namespace}}"
        PREFIX="$RHTAP_ARGOCD_INSTANCE-$NAMESPACE-argocd-"
        # Make sure the rhtap ArgoCD instance has permission on the cluster
        echo -n "* ArgoCD clusterroles: "
        if [ "$(oc get clusterroles -o name | grep -c "/$PREFIX")" = "3" ]; then
          echo "OK"
        else
          echo "FAIL"
          ERRORS+=("ClusterRoles for ArgoCD not found.")
        fi
        echo -n "* ArgoCD clusterrolebindings: "
        if [ "$(oc get clusterrolebindings -o name | grep -c "/$PREFIX")" = "3" ]; then
          echo "OK"
        else
          echo "FAIL"
          ERRORS+=("ClusterRoleBindings for ArgoCD not found.")
        fi
      }

      check_gitops_operator_health
      check_rhtap_argocd_health

      if [ "${#ERRORS[@]}" != "0" ]; then
        for MSG in "${ERRORS[@]}"; do
          echo "[ERROR]$MSG" >&2
        done
        exit 1
      fi
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 20m
      memory: 128Mi
{{ end }}