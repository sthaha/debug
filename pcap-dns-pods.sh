#!/usr/bin/env bash
set -u -e -o pipefail

declare -r SCRIPT_PATH=$(readlink -f "$0")
declare -r SCRIPT_DIR=$(cd $(dirname "$SCRIPT_PATH") && pwd)

trap cleanup EXIT
trap "exit 0" SIGINT

declare -r DNS_PCAP_NS=dns-pcap
declare  -r LOCAL_PCAP_DIR="dns-pcaps/$(date +%s)"

declare -a TCPDUMP_PIDS=()
declare -a DEBUG_PODS=()
declare -a NODE_NAMES=()

log() {
  echo $(date -u +"%Y-%m-%dT%H:%M:%S%Z [%s]") ": $@"
}

sub_header() {
  echo -e "\n*  $@"
  echo "-------------------------------------------------------"
}


CLEANUP_IN_PROGRESS=false
cleanup() {
  sub_header "Gathering all pcaps and cleaning up ..."
  $CLEANUP_IN_PROGRESS && return 0

  CLEANUP_IN_PROGRESS=true

  log "Shutting down tcpdump and copying pcaps"
  log "Please wait until all the pcaps are copied to $LOCAL_PCAP_DIR"

  ### DO NOT EXIT on ERRORS
  #set +e
  stop_listening
  sleep 10  ### requires time to flush

  cp_pcaps
  delete_debug_pods


  sub_header "All pcaps have been copied to $LOCAL_PCAP_DIR"
  echo -e "\n====================xxxXxxx=========================="
}

stop_listening() {
  sub_header  "Stopping tcpdump on all pods"

  for pod in ${DEBUG_PODS[@]}; do
    oc exec -t -n $DNS_PCAP_NS $pod  -- pkill tcpdump
  done

  for pid in ${TCPDUMP_PIDS[@]}; do
    log "sending kill to $pid"
    kill -TERM $pid || true
  done
  wait
}

cp_pcaps() {
  sub_header "Copying all pcaps to $LOCAL_PCAP_DIR"

  mkdir -p "$LOCAL_PCAP_DIR"

  local idx=0
  for pod in ${DEBUG_PODS[@]}; do
    local pcap_file="${NODE_NAMES[$idx]}.pcap"
    log "$pod -> $pcap_file"

    #set -x
    oc cp -n $DNS_PCAP_NS $pod:tmp/$pcap_file "$LOCAL_PCAP_DIR/$pcap_file"
    (( idx++ )) || true   ### something is wrong; why does this error ?
  done
}

delete_debug_pods() {
  sub_header "Deleting all debug pods "

  for pod in ${DEBUG_PODS[@]}; do
    log "Deleting pod $pod"
    oc delete -n $DNS_PCAP_NS pod $pod &
  done
  wait
}

start_debug_node() {
  local node=$1; shift
  local node_name=$(basename $node)

  log "Starting a debug pod for node: $node_name"


  local pod_manifest=$( oc debug $node --to-namespace="$DNS_PCAP_NS" -o json -- sleep infinity )
  local pod_name=$(echo $pod_manifest | jq -r '.metadata.name')

  log "Starting pod $pod_name for $node"
  DEBUG_PODS+=( $pod_name )
  NODE_NAMES+=( $node_name )   ### maintain same index

  echo $pod_manifest | oc apply -f-

  oc wait --for=condition=Ready -n $DNS_PCAP_NS "pod/$pod_name"

  return 0
}

tcpdump_node() {
  local node_name=$1; shift
  local pod_name=$1; shift

  local debug_script

  debug_script=$(cat <<-EOF
    pod_id=\$(chroot /host crictl ps -o json | jq -r '.containers[] | select(.labels["io.kubernetes.container.name"] == "dns") | .id')
    pod_pid=\$(chroot /host crictl inspect --output json \$pod_id | jq '.info.pid')
    nsenter -n -t \$pod_pid -- tcpdump -i any -nn -w /tmp/$node_name.pcap
EOF
)

  log "starting tcpdump on pod: $pod_name"

  oc exec -t -n $DNS_PCAP_NS $pod_name  -- bash -c "$debug_script" &
  TCPDUMP_PIDS+=( $! )
  return 0
}

start_tcpdump_all_nodes() {

  echo -e \n
  log "Starting tcpdump on all debug pods ... "
  echo "-----------------------------------------------------"

  local idx=0
  for pod in ${DEBUG_PODS[@]}; do
    local node=${NODE_NAMES[$idx]}

    tcpdump_node $node $pod
    (( idx++ )) || true   ### something is wrong; why does this error ?

  done
}

start_debug_pods() {
  sub_header "Starting Debug Pods on all nodes ... "

  local nodes=($(oc get nodes -o name))
  for n in ${nodes[@]}; do
    start_debug_node "$n"
  done

}


main() {

  ## todo: usage
  echo Starting packet capture of all dns pods
  echo All pcaps will be copied to $LOCAL_PCAP_DIR
  echo ==========================================================

  oc get ns $DNS_PCAP_NS -o name >/dev/null || oc create ns $DNS_PCAP_NS

  start_debug_pods
  start_tcpdump_all_nodes

  sleep 3
  echo ==========================================================
  log Capturing of all DNS pods have started. Press Ctrl+C to stop
  log All pcap files will be copied to $LOCAL_PCAP_DIR

  sleep infinity
  return $?
}

main "$@"
