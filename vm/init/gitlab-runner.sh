#!/bin/bash

echo "========================"
echo "gitlab-runner.sh"
echo "========================"

# Basic system info for debugging
echo "System info:"
uname -a
lsb_release -a
ip a
echo "--------------------------------"

# Source .env
ENV_FILE=${ENV_FILE:-"./.env"}
if [ -f "$ENV_FILE" ]; then
    echo "Sourcing $ENV_FILE..."
    source "$ENV_FILE"
else
    echo "❌ No $ENV_FILE found."
    exit 1
fi

# Support both legacy registration tokens and new runner authentication tokens.
RUNNER_TOKEN="${RUNNER_AUTH_TOKEN:-$REGISTRATION_TOKEN}"

# Validate required env vars
if [[ -z "$RUNNER_TOKEN" || -z "$CI_SERVER_URL" ]]; then
    echo "❌ REGISTRATION_TOKEN or CI_SERVER_URL is not set in $ENV_FILE"
    exit 1
fi

# Verify GitLab Runner is installed
if ! command -v gitlab-runner &> /dev/null; then
    echo "❌ GitLab Runner is not installed!"
    exit 1
fi

# Print versions for context
echo "GitLab Runner version:"
gitlab-runner --version
echo "Docker version:"
docker --version
echo "--------------------------------"

# Ensure Docker is running and user is added
sudo usermod -aG docker ubuntu
sudo systemctl enable docker
sudo systemctl start docker

# Optional: verify Docker is working
docker ps &>/dev/null || {
    echo "❌ Docker is not running or permission denied."
    exit 1
}

# Register GitLab Runner (non-interactive)
echo "Registering GitLab Runner..."

sudo gitlab-runner unregister --name "$VM_NAME" &>/dev/null

REGISTER_TOKEN_FLAG="--registration-token"
if [[ "$RUNNER_TOKEN" == glrt-* ]]; then
  REGISTER_TOKEN_FLAG="--token"
  echo "Detected runner authentication token (new GitLab workflow)."
  echo "Skipping server-managed registration flags (tags/locked/run-untagged)."
fi

register_cmd=(
  sudo gitlab-runner register --non-interactive
  --url "$CI_SERVER_URL"
  "$REGISTER_TOKEN_FLAG" "$RUNNER_TOKEN"
  --executor "docker"
  --docker-image alpine:latest
  --description "$VM_NAME"
  --docker-privileged="true"
)

if [[ "$REGISTER_TOKEN_FLAG" == "--registration-token" ]]; then
  register_cmd+=(
    --tag-list "${RUNNER_TAGS:-multipass,ci}"
    --run-untagged="true"
    --locked="false"
  )
fi

"${register_cmd[@]}"

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ Runner registration failed ($EXIT_CODE)"
    exit 1
fi

# Set global concurrency (jobs run in parallel across all runners).
# Use RUNNER_CONCURRENT if set, otherwise autoscale from the VM's CPU/RAM.
CONFIG_TOML="/etc/gitlab-runner/config.toml"
JOB_MEM_MB="${RUNNER_JOB_MEM_MB:-1536}"

if [[ -n "$RUNNER_CONCURRENT" ]]; then
    CONCURRENT="$RUNNER_CONCURRENT"
    echo "Using explicit RUNNER_CONCURRENT=$CONCURRENT"
else
    CPUS=$(nproc)
    # Total RAM in MB; reserve ~20% for the OS/docker/runner itself.
    TOTAL_MEM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
    USABLE_MEM_MB=$(( TOTAL_MEM_MB * 80 / 100 ))
    MEM_LIMIT=$(( USABLE_MEM_MB / JOB_MEM_MB ))

    # Clamp to the smaller of the CPU and memory limits, floor of 1.
    CONCURRENT=$CPUS
    [[ "$MEM_LIMIT" -lt "$CONCURRENT" ]] && CONCURRENT=$MEM_LIMIT
    [[ "$CONCURRENT" -lt 1 ]] && CONCURRENT=1

    echo "Autoscaled concurrency: $CONCURRENT (cpus=$CPUS, usable_mem=${USABLE_MEM_MB}MB, job_mem=${JOB_MEM_MB}MB)"
fi

# Strip any existing global `concurrent` line(s), then prepend a single fresh
# one so it lands in the global section (not inside a [[runners]] block) and we
# never end up with duplicate keys. config.toml is root-only (0600), hence sudo.
sudo sed -i "/^concurrent[[:space:]]*=.*/d" "$CONFIG_TOML"
sudo sed -i "1i concurrent = $CONCURRENT" "$CONFIG_TOML"

# Start the runner service
echo "Starting GitLab Runner service..."
sudo systemctl enable gitlab-runner
sudo systemctl restart gitlab-runner

# Check runner status
echo "Runner status:"
sudo gitlab-runner status || {
    echo "❌ Runner failed to start properly."
    exit 1
}

echo "✅ GitLab Runner is registered and running."
