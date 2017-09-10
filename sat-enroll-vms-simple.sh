#!/bin/bash
#
## Enrol VMs into Satellite. The original slower (but possibly more stable) method.

. $( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )/lib/common

usage_content() {
  echo "Enroll the VMs into Satellite."
}

success "Enrolling hosts into Satellite"

export SSHPASS='password'

trap killscripts INT

# Investigating issues with Satellite.
# for role in $VM_LIST; do
#   info "Enrolling $role into Satellite"
#
#   install_katello_ca $role
#
#   register_host_satellite $role
#
#   sleep 20
#
#   rhsmcertd_cert_update $role
#
#   sleep 60
#
#   enable_sat_repos $role
#
#   install_katello_agent $role
# done;

# Split into separate loops to give Satellite more time between steps.

for role in $VM_LIST; do
  info "Installing Katello CA on $role"
  install_katello_ca $role
done

sleep 10

for role in $VM_LIST; do
  info "Registering $role into Satellite"
  register_host_satellite $role
done

sleep 30

for role in $VM_LIST; do
  info "Resetting RHSMCERTD in $role"
  rhsmcertd_cert_update $role

  sleep 10

  if [[ $? -ne 0 ]]; then
    error "Failed kicking RHSMCERTD for $role!"
  fi
done

sleep 10

for role in $VM_LIST; do
  info "Enabling repos for $role"
  enable_sat_repos $role
done

sleep 10

for role in $VM_LIST; do
  info "Installing Katello Agent to $role"
  install_katello_agent $role
done

success "Successfully enrolled all hosts into Satellite."
