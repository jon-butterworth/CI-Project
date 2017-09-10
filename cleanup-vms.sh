#!/bin/bash
#
## Remove VMS, before or after a build.

usage_content() {
  echo " Deletes old VMs"
  echo -e "     --force\tIf in oneshot mode, delete the VMs anyway (probably a bad idea)"
}

. $(cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )/lib/common

if [[ "$BUILD_MODE" == "oneshot" ]] && ! $FORCE; then
  error "Not cleaning up VMs due to oneshot mode. User --force to override."
  exit 1
fi

success "Deleting VMs"

trap killscripts INT

cleanout_vm() {
  local role=$1

  if check_vm_exists "$role"; then
    delete_vm $role
    exit $?
  else
    warning "$hostname does not appear to exist"
  fi
}

if batch_limit_exec cleanout_vm $ASYNC_LIMIT "$VM_LIST"; then
  success "All hosts deleted"
  failed=0
else
  error "Some/all hosts failed to delete"
  failed=1
fi

for role in $VM_LIST; do
  host=$(resolve $role)

  debug "Removing $role (as $host) from known hosts"
  remove_from_knownhosts $host &
done

wait;

info "Revoking Puppet certs"

batch_limit_exec puppet_cert_revoke 5 "$VM_LIST"

exit $failed
