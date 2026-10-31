#!/bin/bash
set -euo pipefail

PARSER_DIR="/etc/crowdsec/parsers/s01-parse"
SCENARIO_DIR="/etc/crowdsec/scenarios"
ACQUIS_DIR="/etc/crowdsec/acquis.d"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: sudo $0 {ssh|3x-ui|all}"
    exit 1
}

if [[ $EUID -ne 0 ]]; then
    echo "Error: run this script as root (sudo)."
    exit 1
fi

[[ $# -eq 1 ]] || usage

install_ssh() {
    echo "Installing SSH configuration..."

    install -Dm644 "$SCRIPT_DIR/parsers/sshd-session-local.yaml" \
        "$PARSER_DIR/sshd-session-local.yaml"

    install -Dm644 "$SCRIPT_DIR/scenarios/ssh-invalid-user-local.yaml" \
        "$SCENARIO_DIR/ssh-invalid-user-local.yaml"

    install -Dm644 "$SCRIPT_DIR/scenarios/ssh-root-auth-local.yaml" \
        "$SCENARIO_DIR/ssh-root-auth-local.yaml"
}

install_3x_ui() {
    echo "Installing 3x-ui configuration..."

    install -Dm644 "$SCRIPT_DIR/parsers/3x-ui-logs.yaml" \
        "$PARSER_DIR/3x-ui-logs.yaml"

    install -Dm644 "$SCRIPT_DIR/scenarios/3x-ui-bf.yaml" \
        "$SCENARIO_DIR/3x-ui-bf.yaml"

    install -Dm644 "$SCRIPT_DIR/acquisition/3x-ui.yaml" \
        "$ACQUIS_DIR/3x-ui.yaml"
}

case "$1" in
    ssh)
        install_ssh
        ;;
    3x-ui)
        install_3x_ui
        ;;
    all)
        install_ssh
        install_3x_ui
        ;;
    *)
        usage
        ;;
esac

echo "Checking CrowdSec configuration..."
crowdsec -c /etc/crowdsec/config.yaml -t

echo "Restarting CrowdSec..."
systemctl restart crowdsec

echo "Installation completed successfully."
