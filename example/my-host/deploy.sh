#!/usr/bin/env bash
# deploy.sh - NixOS 配置部署脚本
# 用法: ./deploy.sh [hostname]
# 如果不指定 hostname，则自动使用当前主机名

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME="${1:-$(hostname)}"

echo "=== NixOS Configuration Deploy ==="
echo "Target host: $HOSTNAME"
echo "Config dir: $SCRIPT_DIR"
echo ""

# 检查主机配置是否存在
if [[ ! -d "$SCRIPT_DIR/hosts/$HOSTNAME" ]]; then
    echo "Error: Host configuration not found: hosts/$HOSTNAME"
    echo "Available hosts:"
    ls -1 "$SCRIPT_DIR/hosts/" 2>/dev/null || echo "  (none)"
    exit 1
fi

# 检查 sops 密钥
SOPS_KEY_FILE="$HOME/.config/sops/age/keys.txt"
if [[ ! -f "$SOPS_KEY_FILE" ]]; then
    echo "Warning: sops age key not found at $SOPS_KEY_FILE"
    echo "Generate one with: age-keygen -o $SOPS_KEY_FILE"
    echo ""
fi

# 执行部署
echo "Running: sudo nixos-rebuild switch --flake .#$HOSTNAME"
echo ""

cd "$SCRIPT_DIR"
sudo nixos-rebuild switch --flake ".#$HOSTNAME"

echo ""
echo "=== Deploy complete ==="
