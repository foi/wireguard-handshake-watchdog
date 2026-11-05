#!/usr/bin/env bash
set -eu
WIREGUARD_INTERFACE_NAME="$1"

WIREGUARD_HANDSHAKE_WATCHDOG_MAX_AGE="${MAX_AGE:-180}"
# 0 - resets listener port - usable for clients for NAT or for highly unstable DPI internet connectivity; 1 - restart wireguard interface - usable for servers with static listener port;
WIREGUARD_HANDSHAKE_WATCHDOG_MODE="${WIREGUARD_HANDSHAKE_WATCHDOG_MODE:-0}"

now=$(date +%s)

latest=$(wg show "$WIREGUARD_INTERFACE_NAME" latest-handshakes | awk 'BEGIN{m=0} {if ($2>m) m=$2} END{print m}')

if (( now - latest > WIREGUARD_HANDSHAKE_WATCHDOG_MAX_AGE )); then
    if [[ "$WIREGUARD_HANDSHAKE_WATCHDOG_MODE" == "0" ]]; then
        wg set "$WIREGUARD_INTERFACE_NAME" listen-port 0
        echo "$WIREGUARD_INTERFACE_NAME: handshake stale ($(( now - latest ))s), new listen-port $(wg show "$WIREGUARD_INTERFACE_NAME" listen-port)"
    elif [[ "$WIREGUARD_HANDSHAKE_WATCHDOG_MODE" == "1" ]]; then
        systemctl restart wg-quick@$WIREGUARD_INTERFACE_NAME
        echo "$WIREGUARD_INTERFACE_NAME restarted"
    else
        echo "$WIREGUARD_HANDSHAKE_WATCHDOG_MODE is unknown WIREGUARD_HANDSHAKE_WATCHDOG_MODE!"
        exit 1
    fi
fi
