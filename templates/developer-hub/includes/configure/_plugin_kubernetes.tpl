{{ define "rhtap.developer-hub.configure.plugin_kubernetes" }}
################################################################################
# Tekton plugin configuration
################################################################################
export K8S_SA_TOKEN=$(
  SECRET_NAME=$(kubectl get secrets --namespace "$NAMESPACE" -o name | grep rhdh-kubernetes-plugin-token- | cut -d/ -f2 | head -1)
  kubectl get secret --namespace "$NAMESPACE" "$SECRET_NAME" -o jsonpath={.data.token} | base64 -d
)
echo "K8S_SA_TOKEN=$K8S_SA_TOKEN"
yq -i '
  (
    (
      (.global.dynamic.plugins[] | select(.package == "./dynamic-plugins/dist/backstage-plugin-kubernetes-backend-dynamic")) |
      .pluginConfig.kubernetes.clusterLocatorMethods[].clusters[]
    ) |
    select(.name == "rhdh-kubernetes-plugin") |
    .serviceAccountToken
  ) = strenv(K8S_SA_TOKEN)
' "$HELM_VALUES"
{{ end }}