#!/usr/bin/env bash
set -e -u -o pipefail

declare -r STRACE_DIR=/tmp/strace-hosts
declare -r STOP_STRACE_FILE=/tmp/stop-strace
declare -r MAX_FAILS=10
declare -a HOSTS=()

dig_hosts() {
  local out_dir=$1; shift
  mkdir -p "$out_dir"



  ### start tcpdump in background and stop it after all lookups
  tcpdump -i eth0 -w $out_dir/nw.pcap &
  local tcpdump_pid=$!

  # get the dig of all the hosts and only then check for NOERROR
  date -u +"%Y-%m-%dT%H:%M:%S%Z [%s]" > "$out_dir/timestamp"
  for h in ${HOSTS[@]}; do
    strace dig "$h" 2> "$out_dir/$h.debug" > "$out_dir/$h.dig.txt" || true
  done
  kill -TERM $tcpdump_pid || true

  ### ensure all hosts have NOERROR status
  ls "$out_dir"
  for h in ${HOSTS[@]}; do
    # NOTE: if the grep fails, it returns 1 / fail / false
    grep -q 'status: NOERROR' "$out_dir/$h.dig.txt"
  done
}

show_hosts() {
  echo "Hosts found"
  for h in ${HOSTS[@]}; do
    echo "  ... $h"
  done
  echo "    -------------"
}

read_hosts() {
  local hosts_file="$1"; shift
  echo "Reading Hosts from: $hosts_file"
  HOSTS=$(cat $hosts_file)
}

pause_strace() {
  echo "Last run failed"
  local failures=$(ls "$STRACE_DIR/out" | wc -l)
  [[ $failures -eq 0 ]] && {
    echo '==================================='
    echo "Failures: $failures - NONE found"
    echo "Sleeping for ever ..."
    echo '==================================='
    sleep infinity
  }

  (( failures-- ))  ### acutal failure dir

  echo '-----------------------------------'
  cat $STRACE_DIR/out/$failures/*.dig.txt
  echo '-----------------------------------'

  tar cfvz "$STRACE_DIR.tar.gz" "$STRACE_DIR"

  echo '==================================='
  echo "Failures: $failures"
  echo "Find all output at: $STRACE_DIR.tar.gz"
  echo "Sleeping for ever ..."
  echo '==================================='
  sleep infinity
}

dig_all_hosts() {
  local out_dirname=$1; shift

  date -u +"%Y-%m-%dT%H:%M:%S%Z [%s] [$out_dirname] starting dig"

  out_dir="$STRACE_DIR/out/$out_dirname"
  while dig_hosts "$out_dir" ; do
    date -u +"%Y-%m-%dT%H:%M:%S%Z [%s] ..."
    sleep 2
  done

  ### grab it again in case more start failing
  date -u +"%Y-%m-%dT%H:%M:%S%Z [%s] lookup failed"
  dig_hosts "$out_dir/again" || true
  date -u +"%Y-%m-%dT%H:%M:%S%Z [%s] done running dig"
}


main() {
  local hosts_file=${1:-hosts.txt}

  date -u +"%Y-%m-%dT%H:%M:%S%Z [%s] starting strace"
  mkdir -p $STRACE_DIR $STRACE_DIR/out

  read_hosts "$hosts_file"

  local failures=$(ls "$STRACE_DIR/out" | wc -l)
  echo "failed: $failures"

  cp -r /etc/resolv.conf $STRACE_DIR
  show_hosts

  while [[ $failures -lt $MAX_FAILS ]] && [[ ! -r $STOP_STRACE_FILE ]]; do
    dig_all_hosts $failures

    date -u +"%Y-%m-%dT%H:%M:%S%Z [%s] waiting 10s"
    sleep 10
    (( failures++ ))
  done

  pause_strace
  return $?
}

main "$@"
