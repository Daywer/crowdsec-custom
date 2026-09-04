#!/bin/bash
set -e

PARSER_DIR="/etc/crowdsec/parsers/s01-parse"
SCENARIO_DIR="/etc/crowdsec/scenarios"

echo "[1/4] Installing parser..."
install -Dm644 parsers/sshd-session-local.yaml \
    "$PARSER_DIR/sshd-session-local.yaml"

echo "[2/4] Installing scenarios..."
install -Dm644 scenarios/ssh-invalid-user-local.yaml \
    "$SCENARIO_DIR/ssh-invalid-user-local.yaml"

install -Dm644 scenarios/ssh-root-auth-local.yaml \
    "$SCENARIO_DIR/ssh-root-auth-local.yaml"

echo "[3/4] Checking CrowdSec configuration..."
crowdsec -c /etc/crowdsec/config.yaml -t

echo "[4/4] Restarting CrowdSec..."
systemctl restart crowdsec

echo "CrowdSec custom configuration installed successfully."
