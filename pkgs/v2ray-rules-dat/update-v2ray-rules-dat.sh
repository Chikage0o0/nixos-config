#!/usr/bin/env bash
# 用于更新 v2ray-rules-dat 版本和 hash 值的脚本

set -euo pipefail

# 获取最新的 release 版本号
echo "正在获取最新版本信息..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/Loyalsoldier/v2ray-rules-dat/releases/latest | grep '"tag_name"' | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo "错误: 无法获取最新版本号"
    exit 1
fi

echo "最新版本: $LATEST_VERSION"

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIX_FILE="$SCRIPT_DIR/v2ray-rules-dat.nix"

# 检查文件是否存在
if [ ! -f "$NIX_FILE" ]; then
    echo "错误: 找不到文件 $NIX_FILE"
    exit 1
fi

# 读取当前版本号
CURRENT_VERSION=$(grep -oP 'version = "\K[^"]+' "$NIX_FILE" || echo "")

if [ -z "$CURRENT_VERSION" ]; then
    echo "错误: 无法从 $NIX_FILE 读取当前版本号"
    exit 1
fi

echo "当前版本: $CURRENT_VERSION"

# 比较版本号，如果一致则退出
if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
    echo "版本已是最新，无需更新"
    exit 0
fi

# 直接读取 sha256sum 文件获取 hash
echo "正在获取 geoip.dat.sha256sum..."
GEOIP_SHA256SUM_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${LATEST_VERSION}/geoip.dat.sha256sum"
GEOIP_HASH=$(curl -sL "$GEOIP_SHA256SUM_URL" | awk '{print $1}')

echo "正在获取 geosite.dat.sha256sum..."
GEOSITE_SHA256SUM_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${LATEST_VERSION}/geosite.dat.sha256sum"
GEOSITE_HASH=$(curl -sL "$GEOSITE_SHA256SUM_URL" | awk '{print $1}')

echo ""
echo "=========================================="
echo "更新信息:"
echo "=========================================="
echo "版本号: $LATEST_VERSION"
echo "geoip.dat SHA256: $GEOIP_HASH"
echo "geosite.dat SHA256: $GEOSITE_HASH"
echo ""

# 自动更新 .nix 文件
echo "正在更新 $NIX_FILE ..."

# 使用 sed 进行替换
sed -i "s/version = \"[^\"]*\";/version = \"$LATEST_VERSION\";/" "$NIX_FILE"
sed -i "/geoip = fetchurl {/,/};/ s/sha256 = \"[^\"]*\";/sha256 = \"$GEOIP_HASH\";/" "$NIX_FILE"
sed -i "/geosite = fetchurl {/,/};/ s/sha256 = \"[^\"]*\";/sha256 = \"$GEOSITE_HASH\";/" "$NIX_FILE"

echo "✓ 文件已更新!"
echo "=========================================="
echo ""
echo "更新内容:"
echo "  version = \"$LATEST_VERSION\";"
echo "  geoip.sha256 = \"$GEOIP_HASH\";"
echo "  geosite.sha256 = \"$GEOSITE_HASH\";"
echo "=========================================="