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
# tabby
# ============================================================
update_tabby() {
    local nix_file="$SCRIPT_DIR/tabby/default.nix"
    if [ ! -f "$nix_file" ]; then
        echo "[tabby] 跳过: 找不到 $nix_file"
        return 0
    fi

    echo "[tabby] 正在获取最新版本信息..."
    local latest_tag
    latest_tag=$(gh_latest_tag "Eugeny/tabby")

    if [ -z "$latest_tag" ]; then
        echo "[tabby] 错误: 无法获取最新版本号"
        return 0
    fi

    local latest_version="${latest_tag#v}"

    local current_version
    current_version=$(grep -oP 'version = "\K[^"]+' "$nix_file" | head -1 || true)

    if [ "$latest_version" = "$current_version" ]; then
        echo "[tabby] 版本已是最新 ($current_version)，跳过"
        return 0
    fi

    echo "[tabby] $current_version -> $latest_version"

    local tmpdir
    tmpdir=$(mktemp -d)

    local platforms=( "x86_64-linux" "aarch64-linux" )
    local assets=( "tabby-${latest_version}-linux-x64.tar.gz" "tabby-${latest_version}-linux-arm64.tar.gz" )

    for i in "${!platforms[@]}"; do
        local platform="${platforms[$i]}"
        local asset="${assets[$i]}"

        echo "[tabby] 正在下载 $asset ..."
        if ! gh release download "$latest_tag" \
            --repo Eugeny/tabby \
            --pattern "$asset" \
            --dir "$tmpdir" --clobber &>/dev/null; then
            echo "[tabby] 错误: 下载 $asset 失败"
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
    # 同时更新 asset 字段中的版本号
    sed -i "s|tabby-[0-9.]*-linux|tabby-${latest_version}-linux|g" "$nix_file"

    echo "[tabby] ✓ 已更新到 $latest_version"
}
# ============================================================
# 主流程
# ============================================================
echo "=========================================="
echo "  pkgs 一键更新工具"
echo "=========================================="
echo ""

update_opencode

echo ""

update_tabby

echo ""
echo "=========================================="
echo "  所有包更新完成"
echo "=========================================="
