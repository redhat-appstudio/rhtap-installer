{{ define "rhtap.developer-hub.configure.configure_tls" }}
################################################################################
# Configure TLS
################################################################################
echo -n "* Waiting for deployment: "
until kubectl get deployment redhat-developer-hub -o name >/dev/null ; do
  echo -n "_"
  sleep 3
done
echo "OK"

ORIGNAL_POD=$(kubectl get pods -l app.kubernetes.io/name=developer-hub -o name)

DEPLOYMENT="/tmp/deployment.yaml"
DEPLOYMENT_PATCHED="/tmp/deployment.patched.yaml"
oc get deployment/redhat-developer-hub -o yaml >"$DEPLOYMENT"
cp "$DEPLOYMENT" "$DEPLOYMENT_PATCHED"

echo -n "* Configuring TLS:"
# Update env var.
if [ "$(yq '.spec.template.spec.containers[0].env[] | select(.name == "NODE_EXTRA_CA_CERTS") | length' "$DEPLOYMENT_PATCHED")" == "2" ]; then
    YQ_EXPRESSION='
(
    .spec.template.spec.containers[].env[] |
    select(.name == "NODE_EXTRA_CA_CERTS") | .value
) = "/ingress-cert/ca.crt"
'
else
    YQ_EXPRESSION='.spec.template.spec.containers[0].env += {"name": "NODE_EXTRA_CA_CERTS", "value": "/ingress-cert/ca.crt"}'
fi
yq --inplace "$YQ_EXPRESSION" "$DEPLOYMENT_PATCHED"
echo -n "."
# Update volume mount
if [ "$(yq '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "kube-root-ca") | length' "$DEPLOYMENT_PATCHED")" == "2" ]; then
    YQ_EXPRESSION='
(
    .spec.template.spec.containers[].volumeMounts[] |
    select(.name == "kube-root-ca") | .mountPath
) = "/ingress-cert"
'
else
    YQ_EXPRESSION='.spec.template.spec.containers[0].volumeMounts += {"name": "kube-root-ca", "mountPath": "/ingress-cert"}'
fi
yq --inplace "$YQ_EXPRESSION" "$DEPLOYMENT_PATCHED"
echo -n "."
# Update volume
if [ "$(yq '.spec.template.spec.volumes[] | select(.name == "kube-root-ca") | length' "$DEPLOYMENT_PATCHED")" == "2" ]; then
    YQ_EXPRESSION='
(
    .spec.template.spec.volumes[] |
    select(.name == "kube-root-ca") | .configMap
) = {"name": "kube-root-ca.crt", "defaultMode": 420}
'
else
    YQ_EXPRESSION='.spec.template.spec.volumes += {"name": "kube-root-ca", "configMap": {"name": "kube-root-ca.crt", "defaultMode": 420}}'
fi
yq --inplace "$YQ_EXPRESSION" "$DEPLOYMENT_PATCHED"
echo "OK"

echo -n "* Updating deployment: "
yq -i 'sort_keys(..)' "$DEPLOYMENT"
yq -i 'sort_keys(..)' "$DEPLOYMENT_PATCHED"
if ! diff --brief "$DEPLOYMENT" "$DEPLOYMENT_PATCHED" >/dev/null; then
    oc apply -f "$DEPLOYMENT_PATCHED" >/dev/null 2>&1

    # Wait for the configuration to be deployed
    while kubectl get "$ORIGNAL_POD" -o name >/dev/null 2>&1 ; do
        echo -n "_"
        sleep 2
    done
    echo -n "OK"
else
    echo "Configuration already up to date"
fi
{{ end }}