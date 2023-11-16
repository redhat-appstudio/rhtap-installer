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

Test the Helm chart.

Optional arguments:
    -t, --test TEST_NAME
        Name of the test(s) to run. Must be one of:
          apply, template
        By default all tests are run.
    -d, --debug
        Activate tracing/debug mode.
    -h, --help
        Display this message.

Example:
    ${0##*/}
" >&2
}

set_defaults() {
  ACTIONS=()
  DEFAULT_ACTIONS=(template apply)
  HELM_CHART="$(
    cd "$SCRIPT_DIR/.." >/dev/null
    pwd
  )"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
    -t | --test)
      ACTIONS+=("$2")
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
  ACTIONS=${ACTION:-$ACTIONS}
}

apply() {
  # Because the chart is idempotent there is no
  # need to track if the chart as already been
  # applied.
  $HELM_CHART/bin/make.sh apply
}

template() {
  echo -n "Template: "
  cat "$SCRIPT_DIR/data/helm-chart/template.yaml" | diff - <($HELM_CHART/bin/make.sh template) &&
    echo "OK" ||
    {
      echo "FAIL"
      exit 1
    }
}

main() {
  set_defaults
  parse_args "$@"
  for ACTION in "${ACTIONS[@]}"; do
    echo "# Test: $ACTION"
    $ACTION
    echo
  done
}

if [ "${BASH_SOURCE[0]}" == "$0" ]; then
  main "$@"
fi
