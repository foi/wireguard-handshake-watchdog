#!/usr/bin/env bash
set -eu
WIREGUARD_INTERFACE_NAME="$1"
# Restart related wireguard proxy service; by default it will not be restarted
# Service should have the same name as wireguard interface name
WIREGUARD_RESTART_PROXY_SERVICE=${WIREGUARD_RESTART_PROXY_SERVICE:-0}
WIREGUARD_RESTART_PROXY_SERVICE_NAME="$WIREGUARD_INTERFACE_NAME.service"
WIREGUARD_HANDSHAKE_WATCHDOG_MAX_AGE="${WIREGUARD_HANDSHAKE_WATCHDOG_MAX_AGE:-180}"
# 0 - resets listener port - usable for clients for NAT or for highly unstable DPI internet connectivity; 1 - restart wireguard interface - usable for servers with static listener port;
WIREGUARD_HANDSHAKE_WATCHDOG_MODE="${WIREGUARD_HANDSHAKE_WATCHDOG_MODE:-0}"

WIREGUARD_HANDSHAKE_WATCHDOG_KEEPALIVE_VALUE=$(wg show "$WIREGUARD_INTERFACE_NAME" persistent-keepalive | awk '$2!="off" && ($2<m || m==0) {m=$2} END{print m+0}')

if (( WIREGUARD_HANDSHAKE_WATCHDOG_KEEPALIVE_VALUE == 0 )); then
    echo "keepalive for $WIREGUARD_INTERFACE_NAME is not enabled; exiting." >&2
    exit 1
fi

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

    if [[ "$WIREGUARD_RESTART_PROXY_SERVICE" == "1" ]]; then
        if ! systemctl cat "$WIREGUARD_RESTART_PROXY_SERVICE_NAME" &>/dev/null; then
            echo "$WIREGUARD_RESTART_PROXY_SERVICE_NAME doesn't exist!" >&2
            exit 1
        fi
        systemctl restart "$WIREGUARD_RESTART_PROXY_SERVICE_NAME"
        echo "$WIREGUARD_RESTART_PROXY_SERVICE_NAME restarted"
    fi
fi
