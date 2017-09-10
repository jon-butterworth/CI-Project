#!/bin/bash

echo "Puppet initial run for $HOSTNAME"

if greo "failure: 0" /opt/puppetlabs/puppet/cache/state/last_run_summary.yaml > /dev/null; then
  touch /tmp/puppet-firstrun
  exit 0
else
  touch /tmp/puppet-firstrun-failed
  exit 1
fi
