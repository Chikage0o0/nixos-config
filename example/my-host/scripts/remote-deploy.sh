#!/usr/bin/env bash
# remote-deploy.sh - 通过 SSH 远程部署单台 NixOS 主机
# 用法: scripts/remote-deploy.sh [选项] <ssh-target>

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

usage() {
  cat <<'EOF'
用法:
  scripts/remote-deploy.sh [选项] <ssh-target>

参数:
  ssh-target  SSH 目标地址，例如 root@1.2.3.4、user@server 或 192.168.1.100

选项:
  -u, --user USER            SSH 用户名；当 ssh-target 不含 @ 时使用
  -p, --ssh-port PORT        SSH 端口
  -i, --ssh-key FILE         SSH 私钥文件
  -o, --ssh-option OPT       额外 SSH 选项，可重复
  --dry-run                  只验证/构建，不切换远端系统
  --build-local              本地构建后推送到远端；默认在远端构建
  -h, --help                 显示帮助

示例:
  scripts/remote-deploy.sh root@1.2.3.4
  scripts/remote-deploy.sh -u admin -p 2222 1.2.3.4
  scripts/remote-deploy.sh --dry-run root@server.example.com

说明:
  - 脚本会先 SSH 到目标机运行 hostname，并要求该 hostname 存在于 flake.nix 的 nixosConfigurations。
  - 默认执行 nixos-rebuild boot，下次重启生效；确认无误后可在远端手动 reboot。
  - 远端需要可用 sudo；nixos-rebuild 通过 --use-remote-sudo 调用。
EOF
}

error() {
  printf "${RED}错误: %s${NC}\n" "$1" >&2
  exit 1
}

info() {
  printf "${GREEN}%s${NC}\n" "$1" >&2
}

warn() {
  printf "${YELLOW}%s${NC}\n" "$1" >&2
}

get_hosts() {
  nix eval --raw "path:$REPO_DIR#nixosConfigurations" \
    --apply 'hosts: builtins.concatStringsSep "\n" (builtins.attrNames hosts)' 2>/dev/null || \
    error "无法从 flake.nix 提取主机列表，请确认 nix flakes 可用。"
}

validate_host() {
  local host="$1"
  local hosts
  hosts="$(get_hosts)"

  while IFS= read -r candidate; do
    [[ "$candidate" == "$host" ]] && return 0
  done <<<"$hosts"

  error "主机 '$host' 不存在于 flake.nix。可用主机: $(tr '\n' ' ' <<<"$hosts")"
}

validate_local_config() {
  local host="$1"
  info "正在验证本地配置: $host"
  nix build --dry-run "path:$REPO_DIR#nixosConfigurations.${host}.config.system.build.toplevel" >/dev/null || \
    error "本地配置验证失败，请先修复 flake 或主机配置。"
}

detect_remote_hostname() {
  local ssh_target="$1"
  shift
  local extra_ssh_args=("$@")

  info "正在通过 SSH 探测远端 hostname: $ssh_target"
  local remote_hostname
  remote_hostname="$(ssh "${extra_ssh_args[@]}" "$ssh_target" hostname 2>/dev/null)" || \
    error "无法连接到 $ssh_target，请检查网络、SSH 密钥和目标地址。"
  remote_hostname="${remote_hostname//$'\n'/}"
  remote_hostname="${remote_hostname//$'\r'/}"
  [[ -n "$remote_hostname" ]] || error "远端返回的 hostname 为空"
  printf '%s\n' "$remote_hostname"
}

deploy_host() {
  local host="$1"
  local target="$2"
  shift 2
  local extra_ssh_args=("$@")

  local nix_args=(boot --flake "path:$REPO_DIR#$host" --target-host "$target" --use-remote-sudo)
  if [[ "$DRY_RUN" == true ]]; then
    nix_args=(dry-build --flake "path:$REPO_DIR#$host")
  elif [[ "$BUILD_LOCAL" != true ]]; then
    nix_args+=(--build-host "$target" --option builders-use-substitutes true)
  fi

  if [[ ${#extra_ssh_args[@]} -gt 0 ]]; then
    export NIX_SSHOPTS="${extra_ssh_args[*]}"
  else
    unset NIX_SSHOPTS
  fi

  info "执行: nixos-rebuild ${nix_args[*]}"
  if nixos-rebuild "${nix_args[@]}"; then
    info "✓ $host 远程部署成功"
  else
    warn "✗ $host 远程部署失败"
    return 1
  fi
}

SSH_ARGS=()
DRY_RUN=false
BUILD_LOCAL=false
SSH_USER=""

main() {
  local ssh_target=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h|--help) usage; exit 0 ;;
      --dry-run) DRY_RUN=true; shift ;;
      --build-local) BUILD_LOCAL=true; shift ;;
      -u|--user)
        [[ $# -ge 2 ]] || error "选项 $1 需要参数"
        SSH_USER="$2"; shift 2 ;;
      -p|--ssh-port)
        [[ $# -ge 2 ]] || error "选项 $1 需要参数"
        SSH_ARGS+=(-p "$2"); shift 2 ;;
      -i|--ssh-key)
        [[ $# -ge 2 ]] || error "选项 $1 需要参数"
        SSH_ARGS+=(-i "$2"); shift 2 ;;
      -o|--ssh-option)
        [[ $# -ge 2 ]] || error "选项 $1 需要参数"
        SSH_ARGS+=(-o "$2"); shift 2 ;;
      -*) error "未知选项: $1" ;;
      *)
        [[ -z "$ssh_target" ]] || error "只能指定一个 SSH 目标，多余参数: $1"
        ssh_target="$1"; shift ;;
    esac
  done

  [[ -n "$ssh_target" ]] || error "请指定 SSH 目标，例如: scripts/remote-deploy.sh root@1.2.3.4"
  if [[ -n "$SSH_USER" && "$ssh_target" != *@* ]]; then
    ssh_target="$SSH_USER@$ssh_target"
  fi

  local host
  host="$(detect_remote_hostname "$ssh_target" "${SSH_ARGS[@]}")"
  info "远端 hostname: $host"
  validate_host "$host"
  validate_local_config "$host"
  deploy_host "$host" "$ssh_target" "${SSH_ARGS[@]}"
}

main "$@"
