#!/bin/bash
#
## A threaded version of the puppet enroll script in an attempt to make builds faster.

. $(cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )/lib/common

export SSHPASS="password"

if ! batch_limit_exec install_puppet_agent 4 "$VM_LIST"; then
  error "Install/config of Puppet Agent or CSR generation failed"
  exit 1
fi

sleep 20

if ! batch_limit_exec puppet_cert_sign 2 "$VM_LIST"; then
  error "Puppet certificate signing failed"
  exit 2
fi

sleep 10

if ! batch_limit_exec puppet_initial_run 4 "$VM_LIST"; then
  error "Puppet initial run failed"
  exit 3
fi

echo "Waiting a little before we check for agent completion"
sleep 300

echo "Checking for agent completion"
failed=1

while [[ $failed -eq 1 ]]; do
  failed=0

  for host in $VM_LIST; do
    host=$(resolve $role)

    status=$(timeout -k 60 30 sshpass -e ssh -o "StrictHostkeyChecking=no" root@$host "if [[ -e /tmp/puppet-firstrun ]]; then echo 'Success'; elif [[ -e /tmp/puppet-firstrun-failed ]]; then echo 'Failed'; else echo 'Running'; fi")

    debug "Status is $status"

    if [[ $status == "Success" ]]; then
      success "Puppet agent run on $role is complete"
    elif [[ $status == "Running" ]]; then
      failed=1
      info "Puppet agent run on $role is still running"
    elif [[ $status == "Failed" ]]; then
      error "Puppet agent run on $role failed - Check log in /root on the node (if retained)"
      exit 1
    else
      warning "Got an unknown state from puppet run: $status"
    fi

    debug "Wall clock is at $(wall_clock) seconds"

    if [[ $failed -eq 1 ]]; then
      info "Some puppet agent runs not finished"
      sleep 30
    fi
done

success "All hosts enrolled"
 
