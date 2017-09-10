#!/bin/bash
#
## Wait until we can connect to all the VMs before moving onto the configuration stages.

usage_content() {
  echo "Wait until we can connect to all the VMs created before progressing. Errors here may point toward firewall/networking issues."
}

. $( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )/lib/common

failed=1

success "Checking VMs:"

for host in $VM_LIST; do
  info "Checking if $(generate_hostname $host) is in Satellite"

  if ! check_vm_exists "$host"; then
    error "$(generate_hostname $host) does not exist in Satellite."
    exit 2
  fi
done;

while [[ $failed -eq 1 ]]; do
  failed=0

  for host in $VM_LIST; do
    info "Testing $(generate_hostname $host) is up and running..."
    if running_vm $host; then
      success "$host $(resolve $host) is up"
    else
      warning "$host $(resolve $host) is down!"
      failed=1
      break
    fi
  done;

  debug "Wall clock is at $(wall_clock) seconds"

  if [[ $(wall_clock) -gt $WAIT_TIMEOUT ]]; then
    error "Time out waiting for hosts to come up. Timeout is ${WAIT_TIMEOUT}s."
    exit 1
  fi

if [[ $failed -eq 1 ]]; then
    info "Some of the hosts are not yet up. Checking again in 5s."
    sleep 5
  fi
done;

success "All hosts are up"

exit 0
