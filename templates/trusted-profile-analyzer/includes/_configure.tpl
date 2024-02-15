{{ define "rhtap.trusted-profile-analyzer.configure" }}
{{ if (index .Values "trusted-profile-analyzer") }}
- name: configure-trusted-profile-analyzer
  image: quay.io/codeready-toolchain/oc-client-base:latest
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail
  {{ if eq .Values.debug.script true }}
      set -x
  {{ end }}

      cd /tmp

      # Installing Helm...
      curl --fail --silent --show-error --location \
        https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 \
          | bash
      
      # Storing the attributes ".trusted-profile-analyzer" from "values.yaml" as a
      # standalone file, employed later on as input for the trustification Charts.
      declare -r TRUSTIFICATION_VALUES="/tmp/trustification-values.yaml"
  {{ if (index .Values "trusted-profile-analyzer") }}
      cat <<EOF >${TRUSTIFICATION_VALUES}
      ---
{{ index .Values "trusted-profile-analyzer" | toYaml | indent 6 }}
      EOF
  {{ end }}

      # Same namespace where the "rhtap" is being released
      declare -r NAMESPACE="{{ .Release.Namespace }}"
      # Primary openshift domain name, other apps will be exposed via wildcards
      declare -r INGRESS_DOMAIN=$(
          oc --namespace=openshift-ingress-operator \
            get ingresscontrollers.operator.openshift.io default \
              --output=jsonpath='{.status.domain}'
      )
      # suffix for applications with a fully qualified domain
      declare -r APP_DOMAIN="-${NAMESPACE}.${INGRESS_DOMAIN}"

      # Cloning the trustification repository, and resetting to a known commit
      # before rollout.
      git clone https://github.com/trustification/trustification.git
      pushd trustification &&
        # Desired commit for trustification charts.
        git reset --hard 8ae6b2c &&
          # Adding the bitnami repository for "trustification-infrastructure"
          # dependencies.
          helm repo add bitnami https://charts.bitnami.com/bitnami

          # Preparing Helm dependencies for both charts...
          pushd deploy/k8s/charts/trustification-infrastructure &&
            helm dependency build
          popd
          pushd deploy/k8s/charts/trustification &&
            helm dependency build
          popd

          pushd deploy/k8s &&
            # Installing the infrastructure needed for trustification first, and
            # only when infrastructure is ready the trustification rollout
            # starts...
            if ! helm upgrade \
              --install \
              --namespace=${NAMESPACE} \
              --values=${TRUSTIFICATION_VALUES} \
              --timeout=10m \
              --set-string=keycloak.ingress.hostname=sso${APP_DOMAIN} \
              --set-string=appDomain=${APP_DOMAIN} \
              --debug \
              tpa-infrastructure \
              charts/trustification-infrastructure; then
              echo "ERROR: Installing trustification-infrastructure chart!"
              exit 1
            fi
          
            if ! helm upgrade \
                --install \
                --namespace=${NAMESPACE} \
                --values=${TRUSTIFICATION_VALUES} \
                --timeout=10m \
                --set-string=keycloak.ingress.hostname=sso${APP_DOMAIN} \
                --set-string appDomain=${APP_DOMAIN} \
                --debug \
                tpa \
                charts/trustification; then
              echo "ERROR: Installing trustification chart!"
              exit 1
            fi
          popd
      popd
{{ end }}
{{ end }}
