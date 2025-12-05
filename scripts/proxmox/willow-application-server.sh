#!/usr/bin/env bash
APP="Willow Application Server"
var_tags="${var_tags:-iot;voice}"
var_cpu="${var_cpu:-2}"
var_ram="${var_ram:-2048}"
var_disk="${var_disk:-8}"
var_os="${var_os:-debian}"
var_version="${var_version:-13}"
var_unprivileged="${var_unprivileged:-1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_INSTALL_BASE="file://${REPO_ROOT}/scripts/proxmox/install"
WAS_INSTALL_BRANCH="${WAS_INSTALL_BRANCH:-main}"
WAS_INSTALL_BASE="${WAS_INSTALL_BASE:-${DEFAULT_INSTALL_BASE}}"

source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)

patch_build_container() {
  local installer_url="${WAS_INSTALL_BASE}/\${var_install}.sh"
  local patched
  patched=$(declare -f build_container | sed "s#https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/install/\\\${var_install}.sh#${installer_url}#")
  eval "${patched}"
}
patch_build_container

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -f /etc/systemd/system/willow-application-server.service ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  msg_info "Updating ${APP} LXC"
  $STD apt-get update
  $STD apt-get -y upgrade

  local was_image=""
  if [[ -f /etc/default/willow-application-server ]]; then
    was_image=$(grep -E '^WAS_IMAGE=' /etc/default/willow-application-server | cut -d= -f2-)
  fi
  if [[ -n "$was_image" ]]; then
    msg_info "Refreshing Willow image"
    $STD podman pull --quiet "$was_image"
    $STD systemctl restart willow-application-server.service
    msg_ok "Refreshed Willow image"
  fi

  msg_ok "Updated successfully!"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:8502${CL}"

