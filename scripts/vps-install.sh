#!/usr/bin/env bash
# vps-install.sh — one-time VPS setup for collab-services-hive (native systemd)
# Run via: cshive vps-setup (uploads to /tmp/ and executes with sudo)
#
# Installs: Caddy (apt), Continuwuity (.deb from Forgejo), wsproxy (static binary)
# Creates:  system users, config dirs, wsproxy systemd unit
# Enables:  services (but does NOT start them — use: cshive start vps)
#
# Config files are deployed separately by: cshive vps-setup (steps 3-5)
# Re-deploy without reinstalling: cshive vps-deploy-config

set -euo pipefail

WSPROXY_VERSION="${1:-1.0.0}"

# Detect architecture
ARCH="$(uname -m)"
case "${ARCH}" in
    x86_64)  DEB_ARCH="amd64" ;;
    aarch64) DEB_ARCH="arm64" ;;
    *) echo "ERROR: Unsupported arch: ${ARCH}"; exit 1 ;;
esac

echo "[1/5] Installing Caddy via apt..."
apt-get install -y debian-keyring debian-archive-keyring apt-transport-https curl
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
    | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
    | tee /etc/apt/sources.list.d/caddy-stable.list
apt-get update -q
apt-get install -y caddy
echo "[OK] Caddy installed: $(caddy version)"

echo "[2/5] Installing Continuwuity..."
# Download .deb from Forgejo releases.
# TODO: verify the exact asset name at:
#   https://forgejo.ellis.link/continuwuation/continuwuity/releases
# Update the URL below if the release asset name differs.
CONTINUWUITY_DEB_URL="https://forgejo.ellis.link/continuwuation/continuwuity/releases/download/main/conduwuit-linux-${DEB_ARCH}.deb"
curl -fsSL "${CONTINUWUITY_DEB_URL}" -o /tmp/continuwuity.deb
dpkg -i /tmp/continuwuity.deb
rm -f /tmp/continuwuity.deb
mkdir -p /etc/continuwuity
# Ensure the continuwuity user (created by dpkg) owns the config dir
chown root:continuwuity /etc/continuwuity 2>/dev/null || true
chmod 750 /etc/continuwuity
echo "[OK] Continuwuity installed"

echo "[3/5] Installing mautrix-wsproxy ${WSPROXY_VERSION}..."
WSPROXY_URL="https://github.com/mautrix/wsproxy/releases/download/v${WSPROXY_VERSION}/wsproxy-linux-${DEB_ARCH}"
curl -fsSL "${WSPROXY_URL}" -o /usr/local/bin/wsproxy
chmod +x /usr/local/bin/wsproxy
useradd --system --no-create-home --shell /usr/sbin/nologin wsproxy 2>/dev/null || true
mkdir -p /etc/wsproxy
chown wsproxy:wsproxy /etc/wsproxy
chmod 750 /etc/wsproxy
echo "[OK] wsproxy ${WSPROXY_VERSION} installed"

echo "[4/5] Writing wsproxy systemd unit..."
cat > /etc/systemd/system/wsproxy.service <<'UNIT'
[Unit]
Description=mautrix-wsproxy iMessage relay
Documentation=https://github.com/mautrix/wsproxy
After=network.target

[Service]
User=wsproxy
EnvironmentFile=/etc/wsproxy/wsproxy.env
ExecStart=/usr/local/bin/wsproxy
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
UNIT
echo "[OK] wsproxy.service written"

echo "[5/5] Enabling services (not starting — cshive start vps does that)..."
systemctl daemon-reload
systemctl enable continuwuity caddy wsproxy
echo "[OK] continuwuity, caddy, wsproxy enabled"

# Allow hive user to rsync Continuwuity data dir for cold backups (cshive backup).
echo "hive ALL=(ALL) NOPASSWD: /usr/bin/rsync" > /etc/sudoers.d/hive-rsync
chmod 440 /etc/sudoers.d/hive-rsync
echo "[OK] sudo rsync rule added for backup"

echo ""
echo "Installation complete. Next:"
echo "  cshive vps-setup  — deploys config files (runs this script, then deploys toml/Caddyfile/env)"
echo "  cshive vps-ufw    — configures UFW firewall rules"
echo "  cshive start vps  — starts all VPS services"
