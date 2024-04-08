{{ define "rhtap.trusted-profile-analyzer.test" }}
{{ if (index .Values "trusted-profile-analyzer") }}
- name: test-trusted-profile-analyzer
  image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
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
    
      rollout_status() {
        local namespace="${1}"
        local deployment="${2}"

        if ! kubectl --namespace="${namespace}" --timeout="5m" \
          rollout status deployment "${deployment}"; then
          fail "'${namespace}/${deployment}' is not deployed as expected!"
        fi
      }

      echo "Checking deployments..."
      deployments=(bombastic-api bombastic-collector bombastic-indexer documentation guac-graphql spog-api spog-ui v11y-api v11y-indexer vexination-api vexination-collector vexination-indexer)
      for deploy in "${deployments[@]}"; do
        rollout_status "{{.Release.Namespace}}" "${deploy}"
      done

      echo "Upload SBOM to TPA..."
      cosign download sbom registry.redhat.io/rh-syft-tech-preview/syft-rhel9:0.105.0 > sbom.json
      syft convert sbom.json -o cyclonedx-json@1.3=sbom-1-3.json
      keycloak_host=$(kubectl -n {{.Release.Namespace}} get route -l app.kubernetes.io/component=keycloak -o jsonpath='{.items[0].spec.host}')

      tpa_oidc_walker_client_secret={{index .Values "trusted-profile-analyzer" "oidc" "clients" "walker" "clientSecret" "value"}}
      tpa_token=$(curl \
        -d 'client_id=walker' \         
        -d "client_secret=${tpa_oidc_walker_client_secret}" \
        -d 'grant_type=client_credentials' \
        "https://${keycloak_host}/realms/chicken/protocol/openid-connect/token" | jq .access_token -r)

      bombastic_api_host=$(oc -n {{.Release.Namespace}} get route --selector app.kubernetes.io/name=bombastic-api -o jsonpath='{.items[].spec.host}')
      curl \
        -H "authorization: Bearer ${tpa_token}" \
        -H 'transfer-encoding: chunked' \
        --json @sbom-1-3.json \
        'https://${bombastic_api_host}/api/v1/sbom?id=rh-syft-0-105-0'
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
{{ end }}
{{ end }}