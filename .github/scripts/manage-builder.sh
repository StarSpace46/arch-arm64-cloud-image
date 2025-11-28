#!/bin/bash
# OpenStack Builder VM Orchestration Script
# Manages ephemeral ARM64 builder VM lifecycle for GitHub Actions
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-}"

# Configuration
BUILDER_NAME="arch-image-builder-$(date +%s)"
BUILDER_FLAVOR="ss46.arm64.medium"  # 4 vCPU, 8GB RAM, 80GB disk
BUILDER_IMAGE="arch-linux-arm64-builder"  # Must exist in OpenStack
BUILDER_NETWORK="provider-vlan151-1"  # Provider network VLAN 151
BUILDER_KEY="github-runner-key"  # SSH key name in OpenStack
STATE_FILE="/tmp/builder-state-${GITHUB_RUN_ID:-local}.json"

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"
}

error() {
    echo "[ERROR] $*" >&2
    exit 1
}

# Create ephemeral builder VM
create_builder() {
    log "Creating builder VM: ${BUILDER_NAME}"

    # Check if image exists
    if ! openstack image show "${BUILDER_IMAGE}" &>/dev/null; then
        error "Image '${BUILDER_IMAGE}' not found in OpenStack. Please create base image first."
    fi

    # Create VM with cloud-init (build tools already in builder image)
    local USER_DATA=$(cat <<'EOF'
#cloud-config
runcmd:
  - systemctl enable sshd
  - systemctl start sshd
EOF
)

    # Create server
    local SERVER_ID=$(openstack server create \
        --flavor "${BUILDER_FLAVOR}" \
        --image "${BUILDER_IMAGE}" \
        --network "${BUILDER_NETWORK}" \
        --key-name "${BUILDER_KEY}" \
        --user-data <(echo "$USER_DATA") \
        --format json \
        "${BUILDER_NAME}" | jq -r '.id')

    if [ -z "$SERVER_ID" ] || [ "$SERVER_ID" = "null" ]; then
        error "Failed to create builder VM"
    fi

    log "Builder VM created: ${SERVER_ID}"

    # Wait for VM to be ACTIVE
    log "Waiting for builder VM to become ACTIVE..."
    local RETRIES=60
    local COUNT=0
    while [ $COUNT -lt $RETRIES ]; do
        local STATUS=$(openstack server show "${SERVER_ID}" -f json | jq -r '.status')
        if [ "$STATUS" = "ACTIVE" ]; then
            log "Builder VM is ACTIVE"
            break
        elif [ "$STATUS" = "ERROR" ]; then
            error "Builder VM entered ERROR state"
        fi
        sleep 5
        COUNT=$((COUNT + 1))
    done

    if [ $COUNT -eq $RETRIES ]; then
        error "Timeout waiting for builder VM to become ACTIVE"
    fi

    # Get IP address
    local VM_IP=$(openstack server show "${SERVER_ID}" -f json | jq -r '.addresses' | grep -oP '\d+\.\d+\.\d+\.\d+' | head -1)

    if [ -z "$VM_IP" ]; then
        error "Failed to get IP address for builder VM"
    fi

    log "Builder VM IP: ${VM_IP}"

    # Save state
    jq -n \
        --arg id "$SERVER_ID" \
        --arg name "$BUILDER_NAME" \
        --arg ip "$VM_IP" \
        '{id: $id, name: $name, ip: $ip}' > "${STATE_FILE}"

    log "Builder state saved to ${STATE_FILE}"

    # Output for GitHub Actions
    echo "BUILDER_ID=${SERVER_ID}"
    echo "BUILDER_IP=${VM_IP}"
    echo "BUILDER_NAME=${BUILDER_NAME}"
}

# Wait for builder VM to be SSH-ready
wait_for_builder() {
    if [ ! -f "${STATE_FILE}" ]; then
        error "Builder state file not found: ${STATE_FILE}"
    fi

    local VM_IP=$(jq -r '.ip' "${STATE_FILE}")
    local SERVER_ID=$(jq -r '.id' "${STATE_FILE}")

    log "Waiting for SSH access to builder VM ${VM_IP}..."

    local RETRIES=60
    local COUNT=0
    while [ $COUNT -lt $RETRIES ]; do
        if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes \
               "alarm@${VM_IP}" "echo 'SSH ready'" &>/dev/null; then
            log "Builder VM is SSH-ready"

            # Wait a bit more for cloud-init to finish package installation
            log "Waiting for cloud-init to complete..."
            ssh "alarm@${VM_IP}" "cloud-init status --wait" || true

            log "Builder VM is fully ready"
            return 0
        fi
        sleep 5
        COUNT=$((COUNT + 1))
    done

    error "Timeout waiting for builder VM SSH access"
}

# Get builder info from state file
get_builder_info() {
    if [ ! -f "${STATE_FILE}" ]; then
        error "Builder state file not found: ${STATE_FILE}"
    fi

    jq -r '.ip' "${STATE_FILE}"
}

# Destroy builder VM
destroy_builder() {
    if [ ! -f "${STATE_FILE}" ]; then
        log "No builder state file found, nothing to destroy"
        return 0
    fi

    local SERVER_ID=$(jq -r '.id' "${STATE_FILE}")
    local BUILDER_NAME=$(jq -r '.name' "${STATE_FILE}")

    log "Destroying builder VM: ${BUILDER_NAME} (${SERVER_ID})"

    # Delete server
    if openstack server delete "${SERVER_ID}" --wait; then
        log "Builder VM destroyed successfully"
    else
        log "Warning: Failed to destroy builder VM (may already be deleted)"
    fi

    # Clean up state file
    rm -f "${STATE_FILE}"
}

# Main
case "$ACTION" in
    create)
        create_builder
        ;;
    wait)
        wait_for_builder
        ;;
    info)
        get_builder_info
        ;;
    destroy)
        destroy_builder
        ;;
    *)
        echo "Usage: $0 {create|wait|info|destroy}"
        echo ""
        echo "Commands:"
        echo "  create   - Create ephemeral builder VM"
        echo "  wait     - Wait for builder VM to be SSH-ready"
        echo "  info     - Get builder VM IP address"
        echo "  destroy  - Destroy builder VM"
        exit 1
        ;;
esac
