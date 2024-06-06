{{define "rhtap.developer-hub.configure.helm_values"}}
upstream:
  backstage:
    extraAppConfig:
      - configMapRef: redhat-developer-hub-app-config-extra
        filename: app-config.extra.yaml
    extraEnvVarsSecrets:
      - redhat-developer-hub-{{index .Values "trusted-application-pipeline" "name"}}-config
global:
  dynamic:
    includes:
      - dynamic-plugins.default.yaml
    plugins:
      # Installed plugins can be listed at:
      # https://DH_HOSTNAME/api/dynamic-plugins-info/loaded-plugins
      - disabled: false
        package: ./dynamic-plugins/dist/janus-idp-backstage-plugin-argocd
      - disabled: false
        package: ./dynamic-plugins/dist/roadiehq-backstage-plugin-argo-cd-backend-dynamic
      - disabled: false
        package: ./dynamic-plugins/dist/roadiehq-scaffolder-backend-argocd-dynamic
      - disabled: false
        package: ./dynamic-plugins/dist/backstage-plugin-techdocs-backend-dynamic
      - disabled: false
        package: ./dynamic-plugins/dist/backstage-plugin-techdocs
      - disabled: false
        package: ./dynamic-plugins/dist/backstage-plugin-kubernetes
      - disabled: false
        package: ./dynamic-plugins/dist/backstage-plugin-kubernetes-backend-dynamic
        pluginConfig:
          kubernetes:
            clusterLocatorMethods:
              - clusters:
                  - authProvider: serviceAccount
                    name: rhdh-kubernetes-plugin
                    serviceAccountToken: <token>
                    skipTLSVerify: true
                    url: https://kubernetes.default.svc
                type: config
            customResources:
              - apiVersion: v1
                group: route.openshift.io
                plural: routes
              - apiVersion: v1
                group: tekton.dev
                plural: pipelineruns
              - apiVersion: v1
                group: tekton.dev
                plural: taskruns
            serviceLocatorMethod:
              type: multiTenant
      - disabled: false
        package: ./dynamic-plugins/dist/janus-idp-backstage-plugin-quay
      - disabled: false
        package: ./dynamic-plugins/dist/janus-idp-backstage-plugin-tekton
        pluginConfig:
          dynamicPlugins:
            frontend:
              janus-idp.backstage-plugin-tekton:
                mountPoints:
                  - config:
                      if:
                        allOf:
                          - isTektonCIAvailable
                      layout:
                        gridColumn: 1 / -1
                        gridRowStart: 1
                    importName: TektonCI
                    mountPoint: entity.page.ci/cards
      - disabled: false
        package: ./dynamic-plugins/dist/janus-idp-backstage-plugin-topology
{{end}}