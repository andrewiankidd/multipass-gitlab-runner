#!/bin/bash

# Move into the vm directory and delegate to the real script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "$SCRIPT_DIR/vm/rebuild.sh"
