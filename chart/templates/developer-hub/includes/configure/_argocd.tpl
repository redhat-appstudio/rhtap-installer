{{ define "rhtap.developer-hub.configure.argocd" }}
################################################################################
# ArgoCD integration
################################################################################
ARGOCD_SECRET="$CHART-argocd-secret"
export ARGOCD_SECRET

while [ "$(kubectl get secret "$ARGOCD_SECRET" --ignore-not-found -o name | wc -l)" != "1" ]; do
  echo -ne "_"
  sleep 2
done
echo -n "."

cat << EOF >> "$APPCONFIGEXTRA"
argocd:
  username: \${ARGOCD_USER}
  password: \${ARGOCD_PASSWORD}
  waitCycles: 25
  appLocatorMethods:
    - type: 'config'
      instances:
        - name: default
          url: https://\${ARGOCD_HOSTNAME}
          token: \${ARGOCD_API_TOKEN}
EOF

yq --inplace '.upstream.backstage.extraEnvVarsSecrets += strenv(ARGOCD_SECRET)' developer-hub-values.yaml
################################################################################
{{end}}