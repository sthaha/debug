#!/usr/bin/env bash
set -e -u -o pipefail

### copied from image/dns-gather-tool.sh
declare -r STRACE_DIR=/tmp/strace-hosts


main() {
  local pods=$(oc get pods -n dns-gather-tool -l app=dns-gather-tool -o name)

  mkdir -p backup
  for pod in ${pods[@]}; do
    mkdir -p backup/$pod
    ## get the tar else get entire dir
    oc rsync $pod:$STRACE_DIR.tar.gz backup/$pod ||
      oc rsync $pod:$STRACE_DIR backup/$pod
  done

  return $?
}

main "$@"
