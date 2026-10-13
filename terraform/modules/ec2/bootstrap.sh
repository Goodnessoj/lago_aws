#!/bin/bash
set -euo pipefail

# Establish management only. Ansible owns Docker, mounts, and application configuration.
retry() {
  for attempt in {1..30}; do
    if "$@"; then
      return 0
    fi
    sleep 10
  done
  return 1
}

if ! snap list amazon-ssm-agent >/dev/null 2>&1; then
  retry snap install amazon-ssm-agent --classic
fi
snap start --enable amazon-ssm-agent
retry apt-get -o Acquire::Retries=3 update
retry env DEBIAN_FRONTEND=noninteractive apt-get install -y curl python3
