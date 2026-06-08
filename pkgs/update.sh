#!/usr/bin/env bash
# 一键更新所有 pkgs 的版本和 hash 值
# 依赖: gh (GitHub CLI), nix, jq, bun

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

require_command() {
    local command_name="$1"
    local hint="$2"
    if ! command -v "$command_name" &>/dev/null; then
        echo "错误: 需要 $command_name${hint:+，$hint}"
        exit 1
    fi
}

require_command gh "请先安装并运行 gh auth login"
require_command jq "请先安装 jq"
require_command nix "请先安装 nix"
require_command bun "请先安装 bun"

if ! gh auth status &>/dev/null; then
    echo "错误: gh 未登录，请先运行 gh auth login"
    exit 1
fi

gh_latest_tag() {
    local repo="$1"
    gh api "repos/${repo}/releases/latest" --jq '.tag_name' 2>/dev/null || true
}

bunx_opencode_version() {
    local requested_version="$1"
    local temp_dir
    temp_dir=$(mktemp -d)
    (
        cd "$temp_dir" \
            && bunx --bun "opencode-ai@${requested_version}" --version 2>/dev/null
    )
    local status=$?
    rm -rf "$temp_dir"
    return "$status"
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
        return 1
    fi

    local latest_version="${latest_tag#v}"

    local current_version
    current_version=$(grep -oP 'version = "\K[^"]+' "$nix_file" | head -1 || true)

    echo "[tabby] $current_version -> $latest_version"

    local platforms=( "x86_64-linux" "aarch64-linux" )
    local assets=( "tabby-${latest_version}-linux-x64.tar.gz" "tabby-${latest_version}-linux-arm64.tar.gz" )

    local needs_update=0
    for i in "${!platforms[@]}"; do
        local platform="${platforms[$i]}"
        local asset="${assets[$i]}"
        local url="https://github.com/Eugeny/tabby/releases/download/${latest_tag}/${asset}"

        echo "[tabby] 正在计算 $asset 的 hash ..."
        local hash
        hash=$(nix store prefetch-file --json "$url" 2>/dev/null | jq -r '.hash')

        if [ -z "$hash" ] || [ "$hash" = "null" ]; then
            echo "[tabby] 错误: 无法下载或计算 $asset 的 hash"
            return 1
        fi

        # 只更新变化的部分
        local current_hash
        current_hash=$(sed -n "/${platform}[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/ s|.*hash = \"\\([^\"]*\\)\";.*|\\1|p" "$nix_file")

        if [ "$hash" != "$current_hash" ]; then
            sed -i "/${platform}[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/ s|hash = \"[^\"]*\";|hash = \"${hash}\";|" "$nix_file"
            needs_update=1
        fi
    done

    if [ "$latest_version" != "$current_version" ]; then
        sed -i "s|version = \"[^\"]*\";|version = \"$latest_version\";|" "$nix_file"
        sed -i "s|tabby-[0-9.]*-linux|tabby-${latest_version}-linux|g" "$nix_file"
        needs_update=1
    fi

    if [ "$needs_update" -eq 1 ]; then
        echo "[tabby] ✓ 已更新"
    else
        echo "[tabby] 无变化，跳过"
    fi
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
    local latest_version
    latest_version=$(bunx_opencode_version "latest")

    if [ -z "$latest_version" ]; then
        echo "[opencode] 错误: 无法获取最新版本号"
        return 1
    fi

    if ! [[ "$latest_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.-]+)?$ ]]; then
        echo "[opencode] 错误: bunx 返回了无法识别的版本号: $latest_version"
        return 1
    fi

    local current_version
    current_version=$(grep -oP 'version = "\K[^"]+' "$nix_file" | head -1 || true)

    echo "[opencode] $current_version -> $latest_version"

    local cli_version
    cli_version=$(bunx_opencode_version "$latest_version")
    if [ "$cli_version" != "$latest_version" ]; then
        echo "[opencode] 错误: bunx opencode-ai@${latest_version} --version 输出 $cli_version"
        return 1
    fi

    local platforms=( "x86_64-linux" "aarch64-linux" )
    local packages=( "opencode-linux-x64-baseline" "opencode-linux-arm64" )

    local needs_update=0
    for i in "${!platforms[@]}"; do
        local platform="${platforms[$i]}"
        local package="${packages[$i]}"
        local url="https://registry.npmjs.org/${package}/-/${package}-${latest_version}.tgz"

        echo "[opencode] 正在计算 ${package}-${latest_version}.tgz 的 hash ..."
        local hash
        hash=$(nix store prefetch-file --json "$url" 2>/dev/null | jq -r '.hash')

        if [ -z "$hash" ] || [ "$hash" = "null" ]; then
            echo "[opencode] 错误: 无法下载或计算 ${package}-${latest_version}.tgz 的 hash"
            return 1
        fi

        local current_hash
        current_hash=$(sed -n "/${platform}[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/ s|.*hash = \"\([^\"]*\)\";.*|\1|p" "$nix_file")

        if [ "$hash" != "$current_hash" ]; then
            sed -i "/${platform}[[:space:]]*=[[:space:]]*{/,/^[[:space:]]*};/ s|hash = \"[^\"]*\";|hash = \"${hash}\";|" "$nix_file"
            needs_update=1
        fi
    done

    if [ "$latest_version" != "$current_version" ]; then
        sed -i "s|version = \"[^\"]*\";|version = \"$latest_version\";|" "$nix_file"
        needs_update=1
    fi

    if [ "$needs_update" -eq 1 ]; then
        echo "[opencode] ✓ 已更新"
    else
        echo "[opencode] 无变化，跳过"
    fi
}
# ============================================================
# 主流程
# ============================================================
echo "=========================================="
echo "  pkgs 一键更新工具"
echo "=========================================="
echo ""

update_tabby
update_opencode

echo ""
echo "=========================================="
echo "  所有包更新完成"
echo "=========================================="
