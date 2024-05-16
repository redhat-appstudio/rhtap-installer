{{define "rhtap.developer-hub.configure.app-config-extra"}}
auth:
  environment: production
  providers:
{{if .Values.git.github}}
    github:
      production:
        clientId: \${GITHUB__APP__CLIENT__ID}
        clientSecret: \${GITHUB__APP__CLIENT__SECRET}
{{end}}
{{if .Values.git.gitlab}}
    gitlab:
      production:
        clientId: \${GITLAB__APP__CLIENT__ID}
        clientSecret: \${GITLAB__APP__CLIENT__SECRET}
{{end}}
catalog:
  locations:
    - type: url
      target: \${DEVELOPER_HUB__CATALOG__URL}
  rules:
    - allow:
      - Component
      - System
      - Group
      - Resource
      - Location
      - Template
      - API
integrations:
{{if .Values.git.github}}
  github:
    - host: github.com
      apps:
        - appId: \${GITHUB__APP__ID}
          clientId: \${GITHUB__APP__CLIENT__ID}
          clientSecret: \${GITHUB__APP__CLIENT__SECRET}
          webhookUrl: \${GITHUB__APP__WEBHOOK__URL}
          webhookSecret: \${GITHUB__APP__WEBHOOK__SECRET}
          privateKey: \${GITHUB__APP__PRIVATE_KEY}
{{end}}
{{if .Values.git.gitlab}}
  gitlab:
    - host: gitlab.com
      token: \${GITLAB__TOKEN}
{{end}}
proxy:
  endpoints:
    '/quay/api':
      target: 'https://quay.io'
      headers:
        X-Requested-With: 'XMLHttpRequest'
      {{if .Values.quay.token}}
        Authorization: 'Bearer \${QUAY__API_TOKEN}'
      {{end}}
      changeOrigin: true
      # Change to "false" in case of using self hosted quay instance with a self-signed certificate
      secure: true
quay:
  # The UI url for Quay, used to generate the link to Quay
  uiUrl: 'https://quay.io'
techdocs:
  builder: 'local'
  generator:
    runIn: 'local'
  publisher:
    type: 'local'
{{end}}