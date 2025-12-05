#!/usr/bin/env bash

# Willow Application Server installer for Proxmox helper scripts
# Uses podman to run the official container image inside the LXC.

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Podman and prerequisites"
$STD apt-get install -y podman uidmap slirp4netns fuse-overlayfs iptables
msg_ok "Installed Podman"

if ! grep -Rq "ghcr.io" /etc/containers/registries.conf /etc/containers/registries.conf.d 2>/dev/null; then
  cat <<'EOF' >/etc/containers/registries.conf.d/99-willow-registries.conf
[[registry]]
location = "ghcr.io"
prefix = "ghcr.io"
blocked = false
insecure = false
EOF
fi

WAS_DATA_DIR="${WAS_DATA_DIR:-/opt/willow-application-server}"
CONTAINER_NAME="${CONTAINER_NAME:-willow-application-server}"
WAS_IMAGE="${WAS_IMAGE:-ghcr.io/heywillow/willow-application-server:latest}"
WAS_LOG_LEVEL="${LOG_LEVEL:-info}"
WAS_TZ="${TZ:-Etc/UTC}"

msg_info "Creating Willow Application Server directories"
install -d -m 755 "${WAS_DATA_DIR}/storage"
msg_ok "Prepared ${WAS_DATA_DIR}"

cat <<EOF >/etc/default/willow-application-server
TZ=${WAS_TZ}
LOG_LEVEL=${WAS_LOG_LEVEL}
WAS_IMAGE=${WAS_IMAGE}
WAS_DATA_DIR=${WAS_DATA_DIR}
CONTAINER_NAME=${CONTAINER_NAME}
EOF

msg_info "Creating systemd service"
cat <<'EOF' >/etc/systemd/system/willow-application-server.service
[Unit]
Description=Willow Application Server (Podman)
Wants=network-online.target
After=network-online.target

[Service]
EnvironmentFile=/etc/default/willow-application-server
Restart=on-failure
RestartSec=5
TimeoutStartSec=900
ExecStartPre=/usr/bin/podman pull --quiet ${WAS_IMAGE}
ExecStart=/usr/bin/podman run \
  --name ${CONTAINER_NAME} \
  --replace \
  --network=host \
  --pull=never \
  --label "io.containers.autoupdate=image" \
  --volume ${WAS_DATA_DIR}/storage:/app/storage:Z \
  --env TZ=${TZ} \
  --env LOG_LEVEL=${LOG_LEVEL} \
  ${WAS_IMAGE}
ExecStop=/usr/bin/podman stop --time 10 ${CONTAINER_NAME}
ExecStopPost=/usr/bin/podman rm -f ${CONTAINER_NAME}

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now willow-application-server.service
msg_ok "Willow Application Server is running"

motd_ssh
customize
cleanup_lxc

