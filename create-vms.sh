#!/bin/bash
#
# Provision VMs for jenkins according to settngs in config & environment variables

usage_content() {
	echo "Creates virtual machines according to variables set (see README.md)"
}

. $( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )/lib/common

count=${#longname[@]}

if [[ ! -e "$IPMAP" ]] && [[ ! -e "$HOSTDATA"]]; then
    error "IP map not found, try running prepare-ips (dynamic IPs) or writing an IP Map in '$IPMAP' first"
    error "Alternatively populate '$HOSTDATA' with role based configuration"
    exit 4
fi

success "Creating VMs"

check_create_vm() {
	local role=$1
	local hostname=$(generate_hostname "$role")
	local ip=$(get_hostdata_or_default "$role" "ETHO0_IP" $(get_ip_from_map "$role"))

	if [[ $ip == "" ]]; then
	    error "Missing IP for $role"
	    exit 3
	fi

	debug "Removing $role (as $ip) from known hosts"
	remove_from_knownhosts "$ip"

	sleep $((RANDOM % 10))

  info "Creating $hostname"

  if ! check_vm_exists "$role"; then
    #create it
    if create_vm "$role"; then
      success "$role created successfuly"
    else
      error "$role was not created - not good!"
    fi
  else
    error "$hostname already exists (before a build?)"
    exit 1
  fi
}

trap killscripts INT

if batch_limit_exec "check_create_vm" $ASYNC_LIMIT "$VM_LIST"; then
  success "VMs created"
else
  error "Some/all VMs failed to create"
fi

exit $failed
