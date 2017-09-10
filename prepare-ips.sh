#!/bin/bash
#
# Generates a list of IP addresses for VM creation

usage_conten() {
	echo "Dynamically allocates IPs for use creating VMs. Uses probing via ping (subnet scanned is configured via variable, see README.md"
}

. $( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )/lib/common

if [[ "$BUILD_MODE" != auto ]] && ! $FORCE; then
    error "Not generating an IP Map as we're not in auto mode, and we rish overwriting a real IPMAP, override with --force"
    exit 1
fi

success "Probing for $VM_COUNT free IPs"

free=$(free_ips_available)
remaining=$(($free - $VM_COUNT))

if [[ $VM_COUNT -gt $free ]]; then
    error "Insufficient free IPs to begin build ($free)"
    exit 2
fi

if [[ $remaining -lt $VM_COUNT ]]; then
    warning "Out of free IPs for concurrent build. $remaining left."
fi

ip_list=$(printf "%s\n" $(generate_free_ips $VM_COUNT))

if [[ ip_list == "" ]]; then
    error "No IP Addresses available, check probing? ('$free alledgedly free)"
    exit 3
fi

clear_ip_map

## Tell Hammer to create VMs from $list with correct role/purpose.
for role in $VM_LIST; do
    ip=$(head -n1<<<"$IP_LIST")
    ip_list=$(tail -n+2<<<"$ip_list")

    debug "Adding $role with $ip"
    add_to_ip_map $role $ip
done

for line in $(cat $IPMAP); do
    info "$line"
done

success "Finished probing, map written"
