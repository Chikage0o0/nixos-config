#!/usr/bin/env bash
# build-wsl.sh - 构建 NixOS-WSL 导入包

set -euo pipefail

usage() {
  cat <<'EOF'
用法:
  scripts/build-wsl.sh <hostname> [extra tarball builder args...]

示例:
  scripts/build-wsl.sh wsl-dev
  scripts/build-wsl.sh wsl-dev --extra-files ./extra-root --chown /home/your_username 1000:100

说明:
  - hostname 必须是 flake.nix 中启用了 machine.wsl.enable 的主机。
  - 脚本会构建 config.system.build.tarballBuilder，并运行生成当前目录下的 nixos.wsl。
  - tarball builder 内部执行 nixos-install，需要 sudo。
  - 如存在 hosts/<hostname>/age-key.txt.age，会使用管理员 age key 解密并注入 /var/lib/sops-nix/age/keys.txt。
  - 如存在 hosts/<hostname>/age-key.txt，也会直接注入；明文 key 不应提交到 git。
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
HOST="$1"
shift

[[ "$HOST" =~ ^[A-Za-z0-9_-]+$ ]] || {
  printf 'error: hostname 只能包含字母、数字、下划线和连字符: %s\n' "$HOST" >&2
  exit 1
}

printf '==> 检查 WSL tarball builder: %s\n' "$HOST"
nix eval --raw "path:${REPO_DIR}#nixosConfigurations.${HOST}.config.system.build.tarballBuilder.drvPath" >/dev/null

ENCRYPTED_KEY_PATH="${REPO_DIR}/hosts/${HOST}/age-key.txt.age"
HOST_KEY_PATH="${REPO_DIR}/hosts/${HOST}/age-key.txt"
ADMIN_KEY_PATH="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

probe_key() {
  local key="$1"
  if [[ -f "$key" && -r "$key" ]]; then
    return 0
  fi
  if [[ -f "$key" ]] && sudo test -r "$key"; then
    return 0
  fi
  return 1
}

extra_files_dir=""
cleanup_extra_files() {
  if [[ -n "$extra_files_dir" && -d "$extra_files_dir" ]]; then
    rm -rf "$extra_files_dir"
  fi
}
trap cleanup_extra_files EXIT

age_key_src=""
if [[ -f "$ENCRYPTED_KEY_PATH" ]]; then
  if ! probe_key "$ADMIN_KEY_PATH"; then
    printf 'error: 需要管理员 age key 解密 %s，但未找到: %s\n' "$ENCRYPTED_KEY_PATH" "$ADMIN_KEY_PATH" >&2
    exit 1
  fi
  if ! command -v age >/dev/null 2>&1; then
    printf 'error: 需要 age 工具解密 key，请先运行: nix shell nixpkgs#age\n' >&2
    exit 1
  fi

  printf '==> 解密并注入 %s 的 age key\n' "$HOST"
  extra_files_dir="$(mktemp -d)"
  install -d -m 0700 "$extra_files_dir/var/lib/sops-nix/age"
  age -d -i "$ADMIN_KEY_PATH" -o "$extra_files_dir/var/lib/sops-nix/age/keys.txt" "$ENCRYPTED_KEY_PATH"
elif probe_key "$HOST_KEY_PATH"; then
  age_key_src="$HOST_KEY_PATH"
fi

if [[ -n "$age_key_src" ]]; then
  printf '==> 使用明文 host age key: %s\n' "$age_key_src"
  extra_files_dir="$(mktemp -d)"
  install -d -m 0700 "$extra_files_dir/var/lib/sops-nix/age"
  sudo install -m 0600 "$age_key_src" "$extra_files_dir/var/lib/sops-nix/age/keys.txt"
elif [[ -z "$extra_files_dir" ]]; then
  printf '==> 未找到 host age key，构建继续；导入后需手动放置 /var/lib/sops-nix/age/keys.txt。\n'
fi

printf '==> 构建 %s 的 tarball builder\n' "$HOST"
nix build "path:${REPO_DIR}#nixosConfigurations.${HOST}.config.system.build.tarballBuilder"

printf '==> 运行 tarball builder\n'
extra_args=("$@")
if [[ -n "$extra_files_dir" ]]; then
  extra_args+=(--extra-files "$extra_files_dir")
fi
exec sudo ./result/bin/nixos-wsl-tarball-builder "${extra_args[@]}"
