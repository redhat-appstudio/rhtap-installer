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
    template
        Render the helm chart.

Optional arguments:
    -a, --app-name
        Name of the application.
        Default: $APP_NAME
    -n, --namespace
        Namespace where the application will be deployed.
        Default: $NAMESPACE
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.

Example:
    ${0##*/}
" >&2
}

set_defaults() {
  NAMESPACE=${NAMESPACE:-redhat-dance}
  APP_NAME=${APP_NAME:-installer}
  HELM_CHART="$(
    cd "$SCRIPT_DIR/.." >/dev/null
    pwd
  )"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    apply | delete | template)
      ACTION="$1"
      ;;
    -a | --app-name)
      APP_NAME="$2"
      shift
      ;;
    -n | --namespace)
      NAMESPACE="$2"
      shift
      ;;
    -d | --debug)
      set -x
      DEBUG="--debug"
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    --)
      # End of arguments
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

delete() {
  $helm uninstall "$APP_NAME"
  $helm list
}

apply() {
  $helm upgrade --install --create-namespace "$APP_NAME" "$HELM_CHART"
  $helm list
}

template() {
  $helm template "$APP_NAME" "$HELM_CHART"
}

main() {
  set_defaults
  parse_args "$@"
  $ACTION
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi
