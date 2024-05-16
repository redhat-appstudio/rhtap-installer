{{ define "rhtap.trusted-artifact-signer.securesign" }}
apiVersion: rhtas.redhat.com/v1alpha1
kind: Securesign
metadata:
  name: {{index .Values "trusted-application-pipeline" "name"}}-securesign
  labels:
    app.kubernetes.io/instance: securesign-sample
    app.kubernetes.io/name: securesign-sample
    app.kubernetes.io/part-of: trusted-artifact-signer
  namespace: {{ .Release.Namespace }}
spec:
  fulcio:
    certificate:
      commonName: fulcio.hostname
      organizationEmail: ${FULCIO__ORG_EMAIL}
      organizationName: ${FULCIO__ORG_NAME}
    config:
      OIDCIssuers:
        - Issuer: "${FULCIO__OIDC__URL}"
          ClientID: ${FULCIO__OIDC__CLIENT_ID}
          IssuerURL: "${FULCIO__OIDC__URL}"
          Type: ${FULCIO__OIDC__TYPE}
    externalAccess:
      enabled: true
    monitoring:
      enabled: false
  rekor:
    externalAccess:
      enabled: true
    signer:
      kms: secret
    monitoring:
      enabled: false
  trillian:
    database:
      create: true
  tuf:
    externalAccess:
      enabled: true
    keys:
      - name: rekor.pub
      - name: ctfe.pub
      - name: fulcio_v1.crt.pem
    port: 80
{{ end }}