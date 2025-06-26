#!/bin/bash

echo "====================="
echo "start.sh"
echo "====================="
uname -a

#############################
#        script vars        #
#############################

VM_OS=${VM_OS:-"22.04"}
VM_NAME=${VM_NAME:-"ubuntu-vm"}
VM_CPUS=${VM_CPUS:-"4"}
VM_MEMORY=${VM_MEMORY:-"4G"}
VM_DISK=${VM_DISK:-"30G"}
VM_REBUILD=${VM_REBUILD:-false}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PARENT_DIR="$(dirname "$SCRIPT_DIR")"
PARENT_DIR_NAME="$(basename "$PARENT_DIR")"

##############################
#         startup            #
##############################

# Ensure Multipass is installed
if ! command -v multipass &> /dev/null; then
    echo "Multipass is not installed. Exiting."
    exit 1
fi

# Load .env config
if [ -f "$PARENT_DIR/.env" ]; then
    echo "Sourcing $PARENT_DIR/.env..."
    source "$PARENT_DIR/.env"
else
    echo "No .env file found in $PARENT_DIR"
    exit 1
fi

# Check if VM exists
echo "Checking for existing VM '$VM_NAME'..."
VM_EXISTS=$(multipass list | grep -q "^$VM_NAME\s" && echo true || echo false)

# Create or rebuild VM
if [ "$VM_EXISTS" = false ] || [ "$VM_REBUILD" = true ]; then
    if [ "$VM_EXISTS" = true ]; then
        echo "[VM_REBUILD] Deleting existing VM..."
        multipass delete "$VM_NAME" --purge || {
            echo "Failed to delete VM."
            exit 1
        }
    fi

    echo "Launching VM '$VM_NAME' (CPUs: $VM_CPUS, Memory: $VM_MEMORY, Disk: $VM_DISK)"
    multipass launch "$VM_OS" \
        --name "$VM_NAME" \
        --cpus "$VM_CPUS" \
        --memory "$VM_MEMORY" \
        --disk "$VM_DISK" \
        --cloud-init "$SCRIPT_DIR/cloud-config.yaml" || {
            echo "Failed to create VM."
            exit 1
        }
fi

# Windows-specific fix for file sharing
if [[ "$OS" == "Windows_NT" ]]; then
    multipass set local.privileged-mounts=true
fi

# Mount project directory
MOUNT_PATH="//home/ubuntu/project"
if ! multipass info "$VM_NAME" | grep -q "$PARENT_DIR_NAME => $MOUNT_PATH"; then
    echo "Mounting '$PARENT_DIR' to '$MOUNT_PATH'..."
    multipass mount "$PARENT_DIR" "$VM_NAME:$MOUNT_PATH" || {
        echo "Failed to mount project folder."
        exit 1
    }
else
    echo "Project folder is already mounted."
fi

# Verify network access inside VM
echo "Checking network inside VM..."
multipass exec "$VM_NAME" -- ping -c 1 1.1.1.1 || {
    echo "VM has no network access."
    exit 1
}

# Execute GitLab runner setup script
echo "Running GitLab Runner setup inside VM..."
multipass exec "$VM_NAME" -- bash -c "chmod +x $MOUNT_PATH/vm/init/gitlab-runner.sh"
multipass exec "$VM_NAME" --working-directory "$MOUNT_PATH" -- bash "$MOUNT_PATH/vm/init/gitlab-runner.sh" || {
    echo "❌ Failed to execute gitlab-runner.sh inside the VM."
    exit 1
}

echo "✅ GitLab Runner is now installed and configured."
multipass shell "$VM_NAME"
