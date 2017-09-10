#!/bin/bash
#
## Enroll all nodes to puppet and carry out first puppet agent run.

. $(cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )/lib/common

success "Enrolling hosts into puppet"

export SSHPASS="password"

for role in $VM_LIST; do
  host=$(resolve $host)
  hostname=$(generate_hostname $role)
  info "Installing puppet agent on $hostname with env $BRANCH_NAME"

  sshpass -e ssh -o "StrictHostkeyChecking=no" root@$host "mkdir -p /etc/puppetlabs/facter/facts.d/ && echo '{\"env\": \"$BRANCH_NAME\"}' > /etc/puppetlabs/facter/facts.d/facts.json"
  sshpass -e ssh -o "StrictHostkeyChecking=no" root@$host "yum install puppet-agent -y"
  sshpass -e ssh -o "StrictHostkeyChecking=no" root@$host "puppet config set server '$PUPPETSERVER'"
  sshpass -e ssh -o "StrictHostkeyChecking=no" root@$host "puppet config set certname '$hostname'"
  sshpass -e ssh -o "StrictHostkeyChecking=no" root@$host "puppet-agent -t"
done

wait;

sleep 20

for role in $VM_LIST; do
  host=$(resolve $host)
  hostname=$(generate_hostname $role)

  info "Signing CSR for $role"

  puppet_cert_sign $role
done

wait;

sleep 10

for role in $VM_LIST; do
  host=$(resolve $host)
  hostname=$(generate_hostname $role)

  info "Performing initial puppet run for $role"

  sshpass -e scp -o "StrictHostkeyChecking=no" "$DIR/puppet-initial.sh" root@$host:/root/puppet-initial.sh
  sshpass -e ssh -o "StrictHostkeyChecking=no" root@$host 'chmod +x /root/puppet-initial.sh'
  timeout -k 60 30 sshpass -e ssh -o "StrictHostkeyChecking=no" root@$host '/usr/bin/nohup bash -c "/root/puppet-initial.sh > puppet-initial.log 2>&1"'
  info "puppet-initial being killed, expected and can ignore"
done

wait;

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
