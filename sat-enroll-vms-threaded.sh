#!/bin/bash
#
## Enroll the VMs into Satellite - Threaded version in an attempt to speed up the build.

. $( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )/lib/common

usage_content() {
  echo "Enroll the VMs into Satellite - Threaded version in an attempt to speed up the build."
}

success "Enrolling provisioned VMs into Satellite"

export SSHPASS='password'

trap killscripts INT

info "Installing Katello CA"
if ! batch_limit_exec install_katello_ca 4 "$VM_LIST"; then
  error "Failed to install Katello CA"
  exit 1
done

info "Registering hosts into Satellite"
if ! batch_limit_exec register_host_satellite 2 "$VM_LIST"; then
  error "Failed to register some hosts into Satellite"
  exit 2
fi

info "Waiting a moment for Satellite to recover from key generation."
sleep 60

info "Kicking RHSMCERTD to get certificates"
if ! batch_limit_exec rhsmcertd_cert_update 2 "$VM_LIST"; then
  error "Failed to update RHSMCERTD on some hosts"
  exit 3
fi

info "Waiting a moment before we enable respositories"
sleep 20

info "Enabling repos for packages"
if ! batch_limit_exec enable_sat_repos 4 "$VM_LIST"; then
  error "Failed to enable repos on some hosts"
  exit 4
fi

info "Giving Satellite a few moments before we install Katello Agents"
sleep 20

info "Install Katello Agent"
if ! batch_limit_exec install_katello_agent 6 "$VM_LIST"; then
  error "Failed to install Katello Agent on some hosts"
  exit 5
fi

success "Successfully enrolled all hosts into Satellite"
