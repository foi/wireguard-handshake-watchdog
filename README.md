# wireguard-handshake-watchdog

If there are no handshakes in 180 sec (`WIREGUARD_HANDSHAKE_WATCHDOG_MAX_AGE`) it resets listener port to trigger wireguard connection to awake; or restarts wireguard interface. It also able to restart related proxy wireguard service if `WIREGUARD_RESTART_PROXY_SERVICE=1` by default it will not try to restart.

## Example usage

systemd timer `/etc/systemd/system/wireguard-handshake-watchdog@.timer`

```
[Unit]
Description=Run WireGuard watchdog for %i every minute

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
```

systemd service `/etc/systemd/system/wireguard-handshake-watchdog@.service`
```
[Unit]
Description=WireGuard handshake watchdog for %i
After=wg-quick@%i.service
ConditionPathExists=/sys/class/net/%i

[Service]
Type=oneshot
ExecStart=/usr/local/bin/wireguard-handshake-watchdog.sh %i
```

enable timer
```
systemctl enable --now wireguard-handshake-watchdog@wg-int-name.timer
```
