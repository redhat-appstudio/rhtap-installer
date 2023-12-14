{{ define "dance.pipelines.configure" }}
- name: configure-pipelines
  image: quay.io/redhat-appstudio/appstudio-utils:dbbdd82734232e6289e8fbae5b4c858481a7c057
  command:
    - /bin/bash
    - -c
    - |
      set -o errexit
      set -o nounset
      set -o pipefail

      CRD="tektonconfigs"
      echo -n "* Waiting for '$CRD' CRD: "
      while [ $(kubectl api-resources | grep -c "^$CRD ") = "0" ] ; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      #
      # All actions MUST be idempotent
      #
      TEKTON_NAMESPACE="openshift-pipelines"

      echo -n "* Waiting for pipelines operator deployment: "
      until kubectl get tektonconfig  -n "$TEKTON_NAMESPACE" config >/dev/null 2>&1; do
        echo -n "."
        sleep 3
      done
      echo "OK"

      echo -n "* Update the TektonConfig resource: "
      kubectl patch tektonconfig -n "$TEKTON_NAMESPACE" config --type 'merge' --patch '{{ include "dance.includes.tektonconfig" . | indent 8 }}' >/dev/null
      echo "OK"

      echo -n "* Configuring Chains secret: "
      SECRET="signing-secrets"
      if [ "$(kubectl get secret -n "$TEKTON_NAMESPACE" "$SECRET" -o jsonpath='{.data}' --ignore-not-found --allow-missing-template-keys)" == "" ]; then
        # Delete secret/signing-secrets if already exists since by default cosign creates immutable secrets
        echo -n "."
        kubectl delete secrets  -n "$TEKTON_NAMESPACE" "$SECRET" --ignore-not-found=true

        # To make this run conveniently without user input let's create a random password
        echo -n "."
        RANDOM_PASS=$( openssl rand -base64 30 )

        # Generate the key pair secret directly in the cluster.
        # The secret should be created as immutable.
        echo -n "."
        env COSIGN_PASSWORD=$RANDOM_PASS cosign generate-key-pair "k8s://$TEKTON_NAMESPACE/$SECRET"
      fi
      # If the secret is not marked as immutable, make it so.
      if [ "$(kubectl get secret -n "$TEKTON_NAMESPACE" "$SECRET" -o jsonpath='{.immutable}')" != "true" ]; then
        echo -n "."
        kubectl patch secret -n "$TEKTON_NAMESPACE" "$SECRET" --dry-run=client -o yaml \
          --patch='{"immutable": true}' \
        | kubectl apply -f -
      fi
      echo "OK"

      echo
      echo "Configuration successful"
{{ end }}