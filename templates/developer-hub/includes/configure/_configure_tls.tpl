{{ define "rhtap.developer-hub.configure.configure_tls" }}
################################################################################
# Configure TLS
################################################################################
# Add env var.
yq --inplace '
    .upstream.backstage.extraEnvVars += [
        {
            "name": "NODE_EXTRA_CA_CERTS",
            "value": "/ingress-cert/ca.crt"
        }
    ]
' "$HELM_VALUES"
echo -n "."

# Add volume
yq --inplace '
    .upstream.backstage.extraVolumes += [
        {
            "name": "kube-root-ca",
            "configMap": {
                "name": "kube-root-ca.crt",
                "defaultMode": 420
            }
        }
    ]
' "$HELM_VALUES"
echo -n "."

# Add volume mount
yq --inplace '
    .upstream.backstage.extraVolumeMounts += [
        {
            "name": "kube-root-ca",
            "mountPath": "/ingress-cert"
        }
    ] 
' "$HELM_VALUES"
echo -n "."
################################################################################
{{ end }}