{{- define "rhtap.developer-hub.configure.extra_env" }}
apiVersion: v1
kind: Secret
metadata:
    name: redhat-developer-hub-{{index .Values "trusted-application-pipeline" "name"}}-config
    namespace: {{.Release.Namespace}}
type: Opaque
stringData:
    DEVELOPER_HUB__CATALOG__URL: |-
        {{mustRegexReplaceAll "[$`\\\\]" (index .Values "developer-hub" "catalog" "url") "\\${0}"}}
{{- if .Values.git.github }}
    GITHUB__APP__ID: |-
        {{mustRegexReplaceAll "[$`\\\\]" .Values.git.github.app.id "\\${0}"}}
    GITHUB__APP__CLIENT__ID: |-
        {{mustRegexReplaceAll "[$`\\\\]" .Values.git.github.app.client.id "\\${0}"}}
    GITHUB__APP__CLIENT__SECRET: |-
        {{mustRegexReplaceAll "[$`\\\\]" .Values.git.github.app.client.secret "\\${0}"}}
    GITHUB__APP__WEBHOOK__URL: |-
        $PIPELINES_PAC_URL
    GITHUB__APP__WEBHOOK__SECRET: |-
        {{mustRegexReplaceAll "[$`\\\\]" .Values.git.github.app.webhook.secret "\\${0}"}}
    GITHUB__APP__PRIVATE_KEY: |-
{{.Values.git.github.app.privateKey| indent 8}}
{{- end }}
{{- if .Values.git.gitlab }}
    GITLAB__APP__CLIENT__ID: |-
        {{mustRegexReplaceAll "[$`\\\\]" .Values.git.gitlab.app.id "\\${0}"}}
    GITLAB__APP__CLIENT__SECRET: |-
        {{mustRegexReplaceAll "[$`\\\\]" .Values.git.gitlab.app.secret "\\${0}"}}
    GITLAB__TOKEN: |-
        {{mustRegexReplaceAll "[$`\\\\]" .Values.git.gitlab.token "\\${0}"}}
{{- end }}
{{- if .Values.quay.token }}
    QUAY__API_TOKEN: |-
        {{mustRegexReplaceAll "[$`\\\\]" .Values.quay.token "\\${0}"}}
{{- end }}
{{- end }}