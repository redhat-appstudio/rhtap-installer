{{ define "rhtap.developer-hub.configure.configure_tls" }}
################################################################################
# Configure TLS
################################################################################
echo -n "* Waiting for deployment: "
until kubectl get deployment developer-hub -o name >/dev/null ; do
  echo -n "."
  sleep 3
done
echo "OK"

echo -n "* Configure TLS:"
PATCH="/tmp/configure_tls.patch.json"
cat << EOF >"$PATCH"
[
    {
        "op": "add",
        "path": "/spec/template/spec/containers/0/env/-",
        "value": {
            "name": "NODE_EXTRA_CA_CERTS",
            "value": "/ingress-cert/ca.crt"
        }
    },
    {
        "op": "add",
        "path": "/spec/template/spec/containers/0/volumeMounts/-",
        "value": {
            "name": "kube-root-ca",
            "mountPath": "/ingress-cert"
        }
    },
    {
        "op": "add",
        "path": "/spec/template/spec/volumes/-",
        "value": {
            "name": "kube-root-ca",
            "configMap": {
                "name": "kube-root-ca.crt",
                "defaultMode": 420
            }
        }
    }
]
EOF
echo -n "."
oc patch deployment/developer-hub --namespace "$NAMESPACE" --type=json --patch-file="$PATCH" >/dev/null
echo "OK"
{{ end }}