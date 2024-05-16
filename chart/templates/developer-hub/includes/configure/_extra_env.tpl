{{define "rhtap.developer-hub.configure.extra_env"}}
apiVersion: v1
kind: Secret
metadata:
    name: redhat-developer-hub-{{index .Values "trusted-application-pipeline" "name"}}-config
    namespace: {{.Release.Namespace}}
type: Opaque
stringData:
    DEVELOPER_HUB__CATALOG__URL: "{{index .Values "developer-hub" "catalog" "url"}}"
{{if .Values.git.github}}
    GITHUB__APP__ID: "{{.Values.git.github.app.id}}"
    GITHUB__APP__CLIENT__ID: "{{.Values.git.github.app.client.id}}"
    GITHUB__APP__CLIENT__SECRET: "{{.Values.git.github.app.client.secret}}"
    GITHUB__APP__WEBHOOK__URL: "$PIPELINES_PAC_URL"
    GITHUB__APP__WEBHOOK__SECRET: "{{.Values.git.github.app.webhook.secret}}"
    GITHUB__APP__PRIVATE_KEY: |-
{{.Values.git.github.app.privateKey| indent 8}}
{{end}}
{{if .Values.git.gitlab}}
    GITLAB__APP__CLIENT__ID: "{{.Values.git.gitlab.app.id}}"
    GITLAB__APP__CLIENT__SECRET: "{{.Values.git.gitlab.app.secret}}"
    GITLAB__TOKEN: "{{.Values.git.gitlab.token}}"
{{end}}
{{if .Values.quay.token}}
    QUAY__API_TOKEN: "{{.Values.quay.token}}"
{{end}}
{{end}}