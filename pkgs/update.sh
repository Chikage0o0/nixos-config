#!/usr/bin/env bash
# 一键更新所有 pkgs 的版本和 hash 值
# 依赖: gh (GitHub CLI), nix, sha256sum, xxd, base64

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v gh &>/dev/null; then
    echo "错误: 需要 gh (GitHub CLI)，请先安装并运行 gh auth login"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "错误: gh 未登录，请先运行 gh auth login"
    exit 1
fi

gh_latest_tag() {
    local repo="$1"
    gh api "repos/${repo}/releases/latest" --jq '.tag_name' 2>/dev/null || true
}

# ============================================================
# v2ray-rules-dat
# ============================================================
update_v2ray_rules_dat() {
    local nix_file="$SCRIPT_DIR/v2ray-rules-dat/default.nix"
    if [ ! -f "$nix_file" ]; then
        echo "[v2ray-rules-dat] 跳过: 找不到 $nix_file"
        return 0
    fi

    echo "[v2ray-rules-dat] 正在获取最新版本信息..."
    local latest_version
    latest_version=$(gh_latest_tag "Loyalsoldier/v2ray-rules-dat")

    if [ -z "$latest_version" ]; then
        echo "[v2ray-rules-dat] 错误: 无法获取最新版本号"
        return 0
    fi

    local current_version
    current_version=$(grep -oP 'version = "\K[^"]+' "$nix_file" || true)

    if [ "$latest_version" = "$current_version" ]; then
        echo "[v2ray-rules-dat] 版本已是最新 ($current_version)，跳过"
        return 0
    fi

    echo "[v2ray-rules-dat] $current_version -> $latest_version"

    local tmpdir
    tmpdir=$(mktemp -d)

    echo "[v2ray-rules-dat] 正在下载 checksums ..."
    gh release download "$latest_version" \
        --repo Loyalsoldier/v2ray-rules-dat \
        --pattern 'geoip.dat.sha256sum' \
        --dir "$tmpdir" --clobber &>/dev/null || true
    gh release download "$latest_version" \
        --repo Loyalsoldier/v2ray-rules-dat \
        --pattern 'geosite.dat.sha256sum' \
        --dir "$tmpdir" --clobber &>/dev/null || true

    local geoip_hash geosite_hash
    geoip_hash=$(awk '{print $1}' "$tmpdir/geoip.dat.sha256sum" 2>/dev/null || true)
    geosite_hash=$(awk '{print $1}' "$tmpdir/geosite.dat.sha256sum" 2>/dev/null || true)

    rm -rf "$tmpdir"

    if [ -z "$geoip_hash" ] || [ -z "$geosite_hash" ]; then
        echo "[v2ray-rules-dat] 错误: 无法获取 hash"
        return 0
    fi

    sed -i "s|version = \"[^\"]*\";|version = \"$latest_version\";|" "$nix_file"
    sed -i "/geoip = fetchurl {/,/};/ s|sha256 = \"[^\"]*\";|sha256 = \"$geoip_hash\";|" "$nix_file"
    sed -i "/geosite = fetchurl {/,/};/ s|sha256 = \"[^\"]*\";|sha256 = \"$geosite_hash\";|" "$nix_file"

    echo "[v2ray-rules-dat] ✓ 已更新到 $latest_version"
}

# ============================================================
# opencode
# ============================================================
update_opencode() {
    local nix_file="$SCRIPT_DIR/opencode/default.nix"
    if [ ! -f "$nix_file" ]; then
        echo "[opencode] 跳过: 找不到 $nix_file"
        return 0
    fi

    echo "[opencode] 正在获取最新版本信息..."
    local latest_tag
    latest_tag=$(gh_latest_tag "anomalyco/opencode")

    if [ -z "$latest_tag" ]; then
        echo "[opencode] 错误: 无法获取最新版本号"
        return 0
    fi

    local latest_version="${latest_tag#v}"

    local current_version
    current_version=$(grep -oP 'version = "\K[^"]+' "$nix_file" | head -1 || true)

    if [ "$latest_version" = "$current_version" ]; then
        echo "[opencode] 版本已是最新 ($current_version)，跳过"
        return 0
    fi

    echo "[opencode] $current_version -> $latest_version"

    local tmpdir
    tmpdir=$(mktemp -d)

    local platforms=( "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" )
    local assets=( "opencode-linux-x64.tar.gz" "opencode-linux-arm64.tar.gz" "opencode-darwin-x64.zip" "opencode-darwin-arm64.zip" )

    for i in "${!platforms[@]}"; do
        local platform="${platforms[$i]}"
        local asset="${assets[$i]}"

        echo "[opencode] 正在下载 $asset ..."
        if ! gh release download "$latest_tag" \
            --repo anomalyco/opencode \
            --pattern "$asset" \
            --dir "$tmpdir" --clobber &>/dev/null; then
            echo "[opencode] 错误: 下载 $asset 失败"
            rm -rf "$tmpdir"
            return 0
        fi

        local sha256_hex hash
        sha256_hex=$(sha256sum "$tmpdir/$asset" | awk '{print $1}')
        hash="sha256-$(echo "$sha256_hex" | xxd -r -p | base64 -w0)"

        sed -i "/${platform}/,/}/ s|hash = \"[^\"]*\";|hash = \"${hash}\";|" "$nix_file"
    done

    rm -rf "$tmpdir"
    sed -i "s|version = \"[^\"]*\";|version = \"$latest_version\";|" "$nix_file"

    echo "[opencode] ✓ 已更新到 $latest_version"
}
# ============================================================
# 主流程
# ============================================================
echo "=========================================="
echo "  pkgs 一键更新工具"
echo "=========================================="
echo ""

update_v2ray_rules_dat
echo ""
update_opencode

echo ""
echo "=========================================="
echo "  所有包更新完成"
echo "=========================================="
