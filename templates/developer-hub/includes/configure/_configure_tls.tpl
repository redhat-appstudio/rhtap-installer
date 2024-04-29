{{ define "rhtap.developer-hub.configure.configure_tls" }}
################################################################################
# Configure TLS
################################################################################
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
################################################################################
{{ end }}