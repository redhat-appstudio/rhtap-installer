#!/usr/bin/env bash
set -o errexit
set -o nounset
set -o pipefail

SCRIPT_DIR="$(
  cd "$(dirname "$0")" >/dev/null
  pwd
)"

usage() {
  echo "
Usage:
    ${0##*/} [options]

Manage the Helm chart in '$NAMESPACE' as '$APP_NAME'.

Commands:
    apply
        Apply (install/update) the helm chart.
    delete
        Delete the helm chart.
    release
        Package and release the helm chart.
    template
        Render the helm chart.
    test
        Run the helm chart tests.
    uninstall
        Uninstall as much of the chart as possible.
    values
        Generate a 'values-private.yaml' configuration based on environment
        variables defined in 'private.env'.
        User will be prompted for missing values.

Optional arguments:
    -a, --app-name APP_NAME
        Name of the application.
        Default: $APP_NAME
    -n, --namespace NAMESPACE
        Namespace where the application will be deployed.
        Default: $NAMESPACE
    --version VERSION
        Version of the helm chart to install.
        The version can end with 'x' to install the latest
        version (1.2.x to install the latest patch version,
        1.x to install the latest minor version).
        Default: current repository
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.

Example:
    ${0##*/}
" >&2
}

set_defaults() {
  NAMESPACE=${NAMESPACE:-rhtap}
  APP_NAME=${APP_NAME:-installer}
  HELM_CHART="$(
    cd "$SCRIPT_DIR/.." >/dev/null
    pwd
  )"
  VERSION="$HELM_CHART"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    apply | delete | release | template | test | uninstall | values)
      ACTION="$1"
      ;;
    -a | --app-name)
      shift
      APP_NAME="$1"
      ;;
    -n | --namespace)
      shift
      NAMESPACE="$1"
      ;;
    --version)
      shift
      VERSION="$(echo "$1" | cut -dx -f1)"
      VERSION=$(
        git ls-remote --tags https://github.com/redhat-appstudio/helm-repository.git "$VERSION*" |
          sed 's:.*refs/tags/::' |
          sort --version-sort |
          tail -1
      )
      VERSION="https://redhat-appstudio.github.io/helm-repository/rhtap-installer-$VERSION.tgz"
      ;;
    -d | --debug)
      set -x
      export DEBUG="--debug"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      # End of arguments
      shift
      PASSTHROUGH_ARGS=("$@")
      break
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
    esac
    shift
  done
  if [ -z "${ACTION:-}" ]; then
    echo "[ERROR] Command is missing" >&2
    exit 1
  fi
  helm="helm -n $NAMESPACE"
}

init() {
  PROJECT_DIR=$(
    cd "$(dirname "$SCRIPT_DIR")" >/dev/null
    pwd
  )
  cd "$PROJECT_DIR" >/dev/null
  helm repo add rhtap https://redhat-appstudio.github.io/helm-repository/ >/dev/null
  helm repo update rhtap >/dev/null
  helm dependencies update >/dev/null
}

delete() {
  $helm uninstall "$APP_NAME"
  $helm list
}

apply() {
  $helm upgrade --install --create-namespace --timeout=20m "$APP_NAME" "$VERSION" "${PASSTHROUGH_ARGS[@]}"
  $helm list
}

release() {
  # Check that the repository is in the right state
  if ! git diff --exit-code >/dev/null; then
    echo "Cannot release a version with uncommitted changes" >&2
    exit 1
  fi
  if ! git diff origin/main --exit-code >/dev/null; then
    echo "Cannot release a version that is not synced to origin/main" >&2
    exit 1
  fi

  # Check out repository
  HELM_REPOSITORY="$(mktemp -d)"
  git clone git@github.com:redhat-appstudio/helm-repository.git \
    --single-branch "$HELM_REPOSITORY"

  # Create package
  cd "$HELM_CHART"
  helm package --destination "$HELM_REPOSITORY" .
  _get_versions
  git tag --force "$version"
  git push --tags

  # Update version
  sed -i -e "s|^version: \+$version$|version: $next_version|" Chart.yaml
  "$SCRIPT_DIR/make.sh" template >"$HELM_CHART/test/data/helm-chart/template.yaml"
  git add .
  git commit -m "Init version: $next_version"
  git push

  # Release package
  cd "$HELM_REPOSITORY"
  helm repo index .
  git add .
  git commit -m "Release $version
  
Changes from $previous_version:
$(
    git -C "$HELM_CHART" log \
      --reverse --format="- %s" "$previous_version^..$version" \
      -- Chart.yaml values.yaml templates |
      tail -n +3
  )
  "
  git push
  git tag --force "$version"
  git push --tags
  cd -
  rm -rf "$HELM_REPOSITORY"
}

template() {
  echo "# yamllint disable rule:line-length"
  echo "# yamllint disable rule:trailing-spaces"
  $helm template "$APP_NAME" "$VERSION" "${PASSTHROUGH_ARGS[@]}" |
    {
      sed 's|^  backend-secret:.*|  backend-secret: "#masked#"|' |
        sed 's|^  password:.*|  password: "#masked#"|' |
        sed 's|^  postgres-password:.*|  postgres-password: "#masked#"|'
    }
}

test() {
  $helm test "$APP_NAME"
}

uninstall() {
  # Remove install namespace
  kubectl get applications -n "$NAMESPACE" --ignore-not-found --output name | xargs --no-run-if-empty kubectl delete -n "$NAMESPACE" --wait
  kubectl delete namespace "$NAMESPACE" --ignore-not-found --wait &

  # Remove DH component deployment namespaces
  for namespace in $(
    kubectl get namespaces -o yaml |
      yq '
      .items[] |
      select(.metadata.annotations["argocd.argoproj.io/managed-by"] == "rhtap") |
      .metadata.name'
  ); do
    kubectl delete namespace "$namespace" --wait &
  done
  wait
}

values() {
  # The process is to
  # * Ask the user a bunch of questions about what they want to install.
  # * Generate a values file based of the default value file with only
  #   the relevant content.
  # * Use the generated file to only ask the user about relevant data.
  # * Use the generated file and the user's responses to generate the final
  #   values file.
  cd "$HELM_CHART"
  touch "private.env"
  # shellcheck source=/dev/null
  source "private.env"
  echo -n >"private.env"

  #
  # Enable/disable components in temporary value file
  #
  ENABLE_VARS=(
    "RHTAP_ENABLE_GITHUB"
    "RHTAP_ENABLE_GITLAB"
    "RHTAP_ENABLE_DEVELOPER_HUB"
    "RHTAP_ENABLE_TAS"
    "RHTAP_ENABLE_TAS_FULCIO_OIDC_DEFAULT_VALUES"
    "RHTAP_ENABLE_TPA"
  )
  for ENV_VAR in "${ENABLE_VARS[@]}"; do
    VALUE="${!ENV_VAR:-}"
    while [ -z "$VALUE" ]; do
      read -r -p "Enable ${ENV_VAR:13} (y/N): " VALUE
      case "${VALUE}" in
      y | Y)
        VALUE="true"
        ;;
      n | N | "")
        VALUE="false"
        ;;
      *)
        echo "Invalid value: $VALUE"
        VALUE=""
        ;;
      esac
    done
    echo "export $ENV_VAR='$VALUE'" >>"private.env"
  done
  # shellcheck source=/dev/null
  source private.env

  TMP_VALUES="private-values.yaml.tmp"
  echo "# Generated with bin/make.sh $(grep "^version: " Chart.yaml | grep --only-matching "[0-9.]*")-$(git rev-parse HEAD | cut -c1-7)" >"$TMP_VALUES"
  cat values.yaml >>"$TMP_VALUES"
  if [ "$RHTAP_ENABLE_GITHUB" == false ]; then
    yq -i ".developer-hub.app-config.auth.providers.github = null" "$TMP_VALUES"
    yq -i ".developer-hub.app-config.integrations.github = null" "$TMP_VALUES"
    yq -i ".openshift-gitops.git-token = null" "$TMP_VALUES"
    yq -i ".pipelines.pipelines-as-code.github = null" "$TMP_VALUES"
  fi
  if [ "$RHTAP_ENABLE_GITLAB" == false ]; then
    yq -i ".developer-hub.app-config.auth.providers.gitlab = null" "$TMP_VALUES"
    yq -i ".developer-hub.app-config.integrations.gitlab = null" "$TMP_VALUES"
  fi
  if [ "$RHTAP_ENABLE_DEVELOPER_HUB" == false ]; then
    yq -i ".developer-hub = null" "$TMP_VALUES"
  fi
  if [ "$RHTAP_ENABLE_TAS" == false ]; then
    yq -i ".trusted-artifact-signer = null" "$TMP_VALUES"
  else
    if [ "${RHTAP_ENABLE_TAS_FULCIO_OIDC_DEFAULT_VALUES}" == true ]; then
      yq -i ".trusted-artifact-signer.securesign.fulcio.config = null" "$TMP_VALUES"
    fi
  fi
  if [ "$RHTAP_ENABLE_TPA" == false ]; then
    yq -i ".trusted-profile-analyzer = null" "$TMP_VALUES"
  fi

  #
  # Get variable values based on the content of the temporary value file
  #
  mapfile -t ENV_VARS < <(grep --only-matching "\${[^}]*" "$TMP_VALUES" | cut -d'{' -f2 | sort -u)
  for ENV_VAR in "${ENV_VARS[@]}"; do
    if [ -z "${!ENV_VAR:-}" ]; then
      case $ENV_VAR in
      GITHUB__APP__PRIVATE_KEY | QUAY__DOCKERCONFIGJSON)
        echo "Enter value for $ENV_VAR (end with a blank line):"
        VALUE=$(sed '/^$/q')
        ;;
      *)
        read -r -p "Enter value for $ENV_VAR: " VALUE
        ;;
      esac
    else
      echo "$ENV_VAR: OK"
      VALUE=${!ENV_VAR}
    fi
    export VALUE
    case $ENV_VAR in
    GITHUB__APP__PRIVATE_KEY)
      yq -i "
      .developer-hub.app-config.integrations.github[0].apps[0].privateKey = strenv(VALUE),
      .pipelines.pipelines-as-code.github.private-key = strenv(VALUE)
      " "$TMP_VALUES"
      ;;
    QUAY__DOCKERCONFIGJSON)
      VALUE=$(echo "$VALUE" | tr -d '\n' | sed 's:  *: :g')
      yq -i ".quay.dockerconfigjson = strenv(VALUE)" "$TMP_VALUES"
      ;;
    esac
    # shellcheck disable=SC2001
    echo "export $ENV_VAR='$(echo "$VALUE" | sed 's:^ *::')'" >>"private.env"
  done
  # shellcheck source=/dev/null
  source "private.env"

  #
  # Generate the private value file
  #
  envsubst <"$TMP_VALUES" >"private-values.yaml"
  rm "$TMP_VALUES"
}

_get_versions() {
  version="$(
    git -C "$HELM_REPOSITORY" status | cut -c4- |
      grep --extended-regex --only-matching "([0-9]+\.){3}tgz$" |
      cut -d. -f 1-3
  )"

  for previous_version in $(
    git log --simplify-by-decoration --format=%D |
      sed -e 's|, tag: |\n|g' -e 's|^tag: ||' |
      grep --extended-regex "^([0-9]+\.){2}[0-9]+$" |
      sort --reverse --sort=version
  ); do
    if [ "$(echo -e "$previous_version\n$version" | sort --sort=version | head -1)" != "$version" ]; then
      break
    fi
    unset previous_version
  done

  major_minor="$(echo "$version" | cut -d. -f 1,2)"
  patch="$(($(echo "$version" | cut -d. -f 3) + 1))"
  next_version="$major_minor.$patch"
}

main() {
  set_defaults
  parse_args "$@"
  init
  $ACTION
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi
