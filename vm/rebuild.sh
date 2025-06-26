#!/bin/bash

echo "====================="
echo "rebuild.sh"
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

#############################
#         bootstrap         #
#############################

if ! command -v multipass &> /dev/null; then
    echo "Multipass is not installed. Exiting script."
    exit 1
fi

if [ -f "$PARENT_DIR/.env" ]; then
    echo "Sourcing $PARENT_DIR/.env..."
    source "$PARENT_DIR/.env"
else
    echo "No .env file found in $PARENT_DIR"
    exit 1
fi

VM_EXISTS=$(multipass list | grep -q "^$VM_NAME\s" && echo true || echo false)

if [ "$VM_EXISTS" = false ] || [ "$VM_REBUILD" = true ]; then
    if [ "$VM_EXISTS" = true ]; then
        echo "[VM_REBUILD] Deleting existing VM..."
        multipass delete "$VM_NAME" --purge || {
            echo "Failed to delete existing VM."
            exit 1
        }
    fi

    echo "Creating new VM '$VM_NAME' with:"
    echo "CPUs: $VM_CPUS, Memory: $VM_MEMORY, Disk: $VM_DISK"
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

# Windows-specific privileged mounts
if [[ "$OS" == "Windows_NT" ]]; then
    multipass set local.privileged-mounts=true
fi

# Mount project directory
MOUNT_PATH="//home/ubuntu/project"
if ! multipass info "$VM_NAME" | grep -q "$PARENT_DIR_NAME => $MOUNT_PATH"; then
    echo "Mounting '$PARENT_DIR' to '$MOUNT_PATH' in VM '$VM_NAME'..."
    multipass mount "$PARENT_DIR" "$VM_NAME:$MOUNT_PATH" || {
        echo "Failed to mount project directory."
        exit 1
    }
fi

# Check network access
echo "Checking network connectivity inside VM..."
multipass exec "$VM_NAME" -- ping -c 1 1.1.1.1 || {
    echo "No network connectivity inside VM."
    exit 1
}

# Execute GitLab Runner setup
echo "Running GitLab Runner setup..."
multipass exec "$VM_NAME" -- bash -c "chmod +x $MOUNT_PATH/vm/init/gitlab-runner.sh"
multipass exec "$VM_NAME" --working-directory "$MOUNT_PATH" -- bash "$MOUNT_PATH/vm/init/gitlab-runner.sh" || {
    echo "Failed to execute gitlab-runner.sh."
    exit 1
}

echo "✅ VM '$VM_NAME' ready. Opening shell..."
multipass shell "$VM_NAME"
