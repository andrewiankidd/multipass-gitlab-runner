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

# Validate required env vars
if [[ -z "$REGISTRATION_TOKEN" || -z "$CI_SERVER_URL" ]]; then
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

sudo gitlab-runner register --non-interactive \
  --url "$CI_SERVER_URL" \
  --registration-token "$REGISTRATION_TOKEN" \
  --executor "docker" \
  --docker-image alpine:latest \
  --description "$VM_NAME" \
  --tag-list "${RUNNER_TAGS:-multipass,ci}" \
  --run-untagged="true" \
  --locked="false" \
  --docker-privileged="true"

EXIT_CODE=$?
if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ Runner registration failed ($EXIT_CODE)"
    exit 1
fi

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
