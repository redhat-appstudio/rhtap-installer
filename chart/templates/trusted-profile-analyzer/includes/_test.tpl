{{ define "rhtap.trusted-profile-analyzer.test" }}
{{ if (index .Values "trusted-profile-analyzer") }}
- name: test-trusted-profile-analyzer
  image: "registry.redhat.io/openshift4/ose-tools-rhel8:latest"
  workingDir: /tmp
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

      echo "Installing utils: "

      curl -Lso /usr/local/bin/cosign https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64 && chmod +x /usr/local/bin/cosign
      curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
      
      echo "Checking deployments..."
      deployments=(bombastic-api bombastic-collector bombastic-indexer guac-graphql spog-api spog-ui v11y-api v11y-indexer vexination-api vexination-collector vexination-indexer)
      for deploy in "${deployments[@]}"; do
        rollout_status "{{.Release.Namespace}}" "${deploy}"
      done

      echo "Upload SBOM to TPA..."
      cosign download sbom registry.access.redhat.com/rh-syft-tech-preview/syft-rhel9:1.0.1-1710487708 > sbom.json
      syft convert sbom.json -o cyclonedx-json@1.3=sbom-1-3.json
      keycloak_host=$(kubectl -n {{.Release.Namespace}} get route -l app.kubernetes.io/component=keycloak -o jsonpath='{.items[0].spec.host}')

      tpa_oidc_walker_client_secret='{{index .Values "trusted-profile-analyzer" "oidc" "clients" "walker" "clientSecret" "value" | replace "'" "'\\''"}}'
      tpa_token=$(curl -d 'client_id=walker' \
        -d "client_secret=${tpa_oidc_walker_client_secret}" \
        -d 'grant_type=client_credentials' \
        "https://${keycloak_host}/realms/chicken/protocol/openid-connect/token" | jq .access_token -r)

      bombastic_api_host=$(oc -n {{.Release.Namespace}} get route --selector app.kubernetes.io/name=bombastic-api -o jsonpath='{.items[].spec.host}')
      
      curl -H 'content-type: application/json' -H "authorization: Bearer ${tpa_token}" -H 'transfer-encoding: chunked' --data @sbom-1-3.json "https://${bombastic_api_host}/api/v1/sbom?id=rh-syft-0-105-0" | tee result.log
      # Check if the SBOM was uploaded successfully
      if ! grep -q "Successfully uploaded SBOM" result.log; then
          echo "SBOM was not uploaded successfully!"
          exit 1
      fi

      echo
      echo "Test successful"
  resources:
    limits:
      cpu: 100m
      memory: 256Mi
    requests:
      cpu: 20m
      memory: 128Mi
{{ end }}
{{ end }}