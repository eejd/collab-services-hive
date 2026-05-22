#!/usr/bin/env bash
# Shared helpers for collab-services-hive scripts. Source, do not execute.
set -euo pipefail

HIVE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log_info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()  { echo -e "${BLUE}[STEP]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }

load_env() {
    local env_file="${HIVE_ROOT}/.env"
    if [[ ! -f "$env_file" ]]; then
        log_error ".env not found at ${env_file}"
        log_info  "Copy .env.example to .env and fill in your values."
        exit 1
    fi
    # set -a exports all variables so child processes (envsubst, etc.) see them
    set -a
    set +u
    # shellcheck disable=SC1090
    source "$env_file"
    set -u
    set +a
}

require_env() {
    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            log_error "Required variable \$${var} is not set in .env"
            exit 1
        fi
    done
}

require_command() {
    command -v "$1" &>/dev/null || {
        log_error "Required command not found: $1"
        [[ -n "${2:-}" ]] && log_info "$2"
        exit 1
    }
}

colima_socket() {
    local profile="${1:-default}"
    echo "${HOME}/.colima/${profile}/docker.sock"
}

export_docker_host() {
    local profile="${COLIMA_PROFILE:-default}"
    local sock; sock="$(colima_socket "$profile")"
    if [[ -S "$sock" ]]; then
        export DOCKER_HOST="unix://${sock}"
    else
        log_warn "Colima socket not found at ${sock} — is Colima running?"
    fi
}

require_docker() {
    export_docker_host
    docker info &>/dev/null 2>&1 || {
        log_error "Docker not reachable for Colima profile '${COLIMA_PROFILE:-default}'"
        log_info  "Start Colima: colima start --profile ${COLIMA_PROFILE:-default}"
        exit 1
    }
}

# Connect to the VPS Docker daemon over SSH.
# Requires COLLAB_VPS_SSH_HOST and COLLAB_VPS_SSH_KEY to be set in .env.
require_docker_vps() {
    require_env COLLAB_VPS_SSH_HOST
    local key_arg=""
    if [[ -n "${COLLAB_VPS_SSH_KEY:-}" ]]; then
        local key_path="${COLLAB_VPS_SSH_KEY/#\~/${HOME}}"
        key_arg="-o IdentityFile=${key_path}"
    fi
    DOCKER_HOST="ssh://${COLLAB_VPS_SSH_HOST}" \
    DOCKER_SSH_OPTS="${key_arg}" \
    docker info &>/dev/null 2>&1 || {
        log_error "VPS Docker not reachable at ssh://${COLLAB_VPS_SSH_HOST}"
        log_info  "Check: is Docker running on the VPS? Is SSH accessible?"
        log_info  "Test: ssh ${COLLAB_VPS_SSH_HOST} 'docker info'"
        exit 1
    }
}

launchd_loaded() {
    local label="$1"
    launchctl list 2>/dev/null | grep -q "	${label}$"
}
