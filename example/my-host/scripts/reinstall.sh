#!/usr/bin/env bash
# reinstall.sh - 使用 nixos-anywhere 重装远端 NixOS 主机

set -euo pipefail

usage() {
  cat <<'EOF'
用法:
  scripts/reinstall.sh <flake-host> <target-host> [disk-device] [extra nixos-anywhere args...]

示例:
  scripts/reinstall.sh server root@1.2.3.4
  scripts/reinstall.sh server root@1.2.3.4 /dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_drive-scsi0
  scripts/reinstall.sh server root@1.2.3.4 /dev/vda -i ~/.ssh/install_key -p 2222

说明:
  - 这是破坏性脚本：nixos-anywhere 可能会重新分区/格式化目标磁盘。
  - flake-host 必须存在于当前 flake 的 nixosConfigurations。
  - 主机配置通常需要包含 disko；未提供 disk-device 时使用配置内的 disko 磁盘路径。
  - 提供 disk-device 时，脚本会生成临时 flake 覆盖 disko.devices.disk.main.device。
  - 目标机 SSH host key recipient 应提前写入 .sops.yaml，并重新加密对应 secrets.yaml。
  - 额外参数会原样传给 nixos-anywhere；-i、-p/--ssh-port、--ssh-option 也会用于远端磁盘预检查。
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 2 ]]; then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
FLAKE_HOST="$1"
TARGET_HOST="$2"
REINSTALL_CONFIG="${FLAKE_HOST}-reinstall"
TARGET_DISK=""
shift 2

if [[ "${1:-}" == /dev/* ]]; then
  TARGET_DISK="$1"
  shift
fi

SSH_ARGS=()
NIXOS_ANYWHERE_ARGS=()
HAS_NO_SUBSTITUTE_ON_DESTINATION="n"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -i)
      [[ $# -ge 2 ]] || { printf 'error: -i 缺少 SSH 私钥路径\n' >&2; exit 1; }
      SSH_ARGS+=("-i" "$2")
      NIXOS_ANYWHERE_ARGS+=("$1" "$2")
      shift 2 ;;
    -p|--ssh-port)
      [[ $# -ge 2 ]] || { printf 'error: %s 缺少端口号\n' "$1" >&2; exit 1; }
      SSH_ARGS+=("-p" "$2")
      NIXOS_ANYWHERE_ARGS+=("$1" "$2")
      shift 2 ;;
    --ssh-option)
      [[ $# -ge 2 ]] || { printf 'error: --ssh-option 缺少参数\n' >&2; exit 1; }
      SSH_ARGS+=("-o" "$2")
      NIXOS_ANYWHERE_ARGS+=("$1" "$2")
      shift 2 ;;
    --no-substitute-on-destination)
      HAS_NO_SUBSTITUTE_ON_DESTINATION="y"
      NIXOS_ANYWHERE_ARGS+=("$1")
      shift ;;
    *)
      NIXOS_ANYWHERE_ARGS+=("$1")
      shift ;;
  esac
done

[[ "$FLAKE_HOST" =~ ^[A-Za-z0-9_-]+$ ]] || {
  printf 'error: flake host 只能包含字母、数字、下划线和连字符: %s\n' "$FLAKE_HOST" >&2
  exit 1
}

printf '即将对 %s 执行 nixos-anywhere 重装。请输入 flake host 名称确认: ' "$TARGET_HOST"
read -r CONFIRM_HOST || CONFIRM_HOST=""
if [[ "$CONFIRM_HOST" != "$FLAKE_HOST" ]]; then
  printf '已取消。\n' >&2
  exit 1
fi

TMPDIR_ROOT="$(mktemp -d)"
TMP_FLAKE_DIR="${TMPDIR_ROOT}/flake"

cleanup() {
  rm -rf "$TMPDIR_ROOT"
}
trap cleanup EXIT

printf '==> 预检查 flake: path:%s#%s\n' "$REPO_DIR" "$FLAKE_HOST"
nix eval --raw "path:${REPO_DIR}#nixosConfigurations.${FLAKE_HOST}.config.system.build.toplevel.drvPath" >/dev/null

FLAKE_REF="path:${REPO_DIR}#${FLAKE_HOST}"

if [[ -n "$TARGET_DISK" ]]; then
  printf '==> 在远端校验目标整盘: %s (%s)\n' "$TARGET_HOST" "$TARGET_DISK"
  TARGET_DISK_REAL="$(
    ssh "${SSH_ARGS[@]}" "$TARGET_HOST" sh -s -- "$TARGET_DISK" <<'EOF'
set -eu
target_disk="$1"
target_disk_real="$(readlink -f "$target_disk")"

if [ ! -b "$target_disk_real" ]; then
  printf 'error: 目标磁盘不是块设备: %s\n' "$target_disk_real" >&2
  exit 1
fi

target_disk_type="$(lsblk -dnro TYPE "$target_disk_real")"
if [ "$target_disk_type" != "disk" ]; then
  printf 'error: 目标设备必须是整盘而不是分区/映射设备: %s (type=%s)\n' "$target_disk_real" "$target_disk_type" >&2
  exit 1
fi

printf '%s\n' "$target_disk_real"
EOF
  )"

  printf '==> 远端目标整盘确认: %s\n' "$TARGET_DISK_REAL"
  ssh "${SSH_ARGS[@]}" "$TARGET_HOST" lsblk -dnro PATH,TYPE,SIZE,MODEL,SERIAL "$TARGET_DISK_REAL"

  printf '==> 生成临时 flake 覆盖目标磁盘\n'
  install -d -m 0700 "$TMP_FLAKE_DIR"
  cat >"$TMP_FLAKE_DIR/flake.nix" <<EOF
{
  description = "Temporary ${FLAKE_HOST} reinstall flake";

  inputs.src.url = "path:${REPO_DIR}";

  outputs = { src, ... }: {
    nixosConfigurations.${REINSTALL_CONFIG} = src.nixosConfigurations.${FLAKE_HOST}.extendModules {
      modules = [
        {
          disko.devices.disk.main.device = "${TARGET_DISK_REAL}";
        }
      ];
    };
  };
}
EOF
  FLAKE_REF="${TMP_FLAKE_DIR}#${REINSTALL_CONFIG}"
else
  printf '==> 未提供目标磁盘，直接使用主机配置中的 disko 磁盘路径\n'
fi

while true; do
  printf '==> 是否由本地构建上传 system closure？[Y/n] '
  read -r USE_LOCAL_UPLOAD || USE_LOCAL_UPLOAD=""
  case "$USE_LOCAL_UPLOAD" in
    ""|y|Y|yes|YES)
      printf '==> 使用本地构建并上传 system closure\n'
      if [[ "$HAS_NO_SUBSTITUTE_ON_DESTINATION" == "n" ]]; then
        NIXOS_ANYWHERE_ARGS+=(--no-substitute-on-destination)
      fi
      break ;;
    n|N|no|NO)
      printf '==> 允许目标机自行替代下载 system closure\n'
      break ;;
    *)
      printf 'error: 请输入 y 或 n\n' >&2 ;;
  esac
done

printf '==> 启动 nixos-anywhere: %s\n' "$TARGET_HOST"
exec nix run github:nix-community/nixos-anywhere -- \
  --flake "$FLAKE_REF" \
  --target-host "$TARGET_HOST" \
  --copy-host-keys \
  "${NIXOS_ANYWHERE_ARGS[@]}"
