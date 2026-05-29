#!/usr/bin/env bash
# deploy.sh - 本机 NixOS 配置部署脚本
# 用法: ./deploy.sh [hostname]
# 如果不指定 hostname，则自动使用当前主机名。脚本会询问使用 switch 还是 boot。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOSTNAME="${1:-$(hostname)}"

echo "=== NixOS 配置部署 ==="
echo "目标主机: $HOSTNAME"
echo "配置目录: $SCRIPT_DIR"
echo ""

# 检查主机配置是否存在
if [[ ! -d "$SCRIPT_DIR/hosts/$HOSTNAME" ]]; then
    echo "错误: 未找到主机配置: hosts/$HOSTNAME"
    echo "可用主机:"
    ls -1 "$SCRIPT_DIR/hosts/" 2>/dev/null || echo "  (无)"
    exit 1
fi

# 检查 sops 密钥
SOPS_KEY_FILE="$HOME/.config/sops/age/keys.txt"
if [[ ! -f "$SOPS_KEY_FILE" ]]; then
    echo "警告: 未找到 sops age key: $SOPS_KEY_FILE"
    echo "如使用管理员本地密钥解密，可运行: age-keygen -o $SOPS_KEY_FILE"
    echo ""
fi

# 选择部署模式
echo "请选择部署模式:"
PS3="请输入选项 (1 或 2): "
select MODE in "switch (立即切换)" "boot (下次启动生效)"; do
    case "$MODE" in
        "switch (立即切换)") MODE="switch"; break ;;
        "boot (下次启动生效)") MODE="boot"; break ;;
        *) echo "无效选择，请重试" ;;
    esac
done

echo "执行: sudo nixos-rebuild $MODE --flake $SCRIPT_DIR#$HOSTNAME"
echo ""

cd "$SCRIPT_DIR"
sudo nixos-rebuild "$MODE" --flake "$SCRIPT_DIR#$HOSTNAME"

echo ""
echo "=== 部署完成 ==="
