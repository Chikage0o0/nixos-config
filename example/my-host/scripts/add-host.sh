#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
用法:
  scripts/add-host.sh <hostname> [system] [kind]

参数:
  hostname  flake 中的主机名，例如 laptop、homelab、wsl-dev
  system    Nix system，默认 x86_64-linux；可选 x86_64-linux 或 aarch64-linux
  kind      主机类型，默认 linux；可选 linux 或 wsl

示例:
  scripts/add-host.sh laptop x86_64-linux linux
  scripts/add-host.sh wsl-work x86_64-linux wsl

说明:
  - 脚本只生成 hosts/<hostname>/ 脚手架，不会自动修改 flake.nix 或 .sops.yaml。
  - 生成后按脚本输出的 mkHost 片段手动加入 flake.nix。
EOF
}

die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

hostname="${1:-}"
system="${2:-x86_64-linux}"
kind="${3:-linux}"

if [[ -z "$hostname" || "$hostname" == "-h" || "$hostname" == "--help" ]]; then
  usage
  exit $([[ -z "$hostname" ]] && printf 1 || printf 0)
fi

[[ "$hostname" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || die "hostname 只能包含字母、数字、下划线和连字符，且不能以符号开头"
[[ "$system" == "x86_64-linux" || "$system" == "aarch64-linux" ]] || die "system 只能是 x86_64-linux 或 aarch64-linux"
[[ "$kind" == "linux" || "$kind" == "wsl" ]] || die "kind 只能是 linux 或 wsl"

host_dir="hosts/$hostname"
[[ ! -e "$host_dir" ]] || die "$host_dir 已存在"

mkdir -p "$host_dir"

if [[ "$kind" == "wsl" ]]; then
  cat >"$host_dir/default.nix" <<'EOF'
{ config, lib, ... }:
{
  wsl = {
    enable = true;
    defaultUser = config.platform.user.name;
    interop.register = true;
  };

  users.users.${config.platform.user.name}.hashedPasswordFile = lib.mkIf (
    config ? sops
  ) config.sops.secrets."user/hashedPassword".path;
}
EOF
else
  cat >"$host_dir/default.nix" <<'EOF'
{ config, lib, ... }:
{
  users.users.${config.platform.user.name}.hashedPasswordFile = lib.mkIf (
    config ? sops
  ) config.sops.secrets."user/hashedPassword".path;

  # 在这里添加只属于本机的服务、网络、磁盘挂载或硬件差异。
}
EOF

  cat >"$host_dir/hardware-configuration.nix" <<'EOF'
# 请用目标机器生成的硬件配置替换本文件：
# sudo nixos-generate-config --show-hardware-config > hosts/<hostname>/hardware-configuration.nix
{ ... }:
{
}
EOF
fi

cat >"$host_dir/secrets.yaml" <<'EOF'
user:
  # 使用 mkpasswd -m yescrypt 或 mkpasswd -m sha-512 生成。
  hashedPassword: "$y$j9T$replace-me"

# 如果该主机启用了 home.opencode.enable，并在 flake.nix 声明了 opencode/apiKey secret，取消注释：
# opencode:
#   apiKey: "sk-..."

# 如果该主机需要把 SSH 私钥注入 ssh-agent，并在 flake.nix 声明了 ssh_private_key secret，取消注释：
# ssh_private_key: |
#   -----BEGIN OPENSSH PRIVATE KEY-----
#   ...
#   -----END OPENSSH PRIVATE KEY-----
EOF

cat <<EOF
已创建 $host_dir

下一步：
1. 编辑 flake.nix，在 nixosConfigurations 中加入类似片段：
EOF

if [[ "$kind" == "wsl" ]]; then
  cat <<EOF

   $hostname = public.lib.mkHost {
     hostname = "$hostname";
     system = "$system";
     user = commonUser;
     profiles = [ "wsl-base" ];
     roles = [ "development" ];
     machine.wsl.enable = true;
     secrets.sops = {
       enable = true;
       defaultFile = ./hosts/$hostname/secrets.yaml;
       ageKeyFile = "/var/lib/sops-nix/age/keys.txt";
       secrets."user/hashedPassword".neededForUsers = true;
     };
     extraModules = [ ./hosts/$hostname ];
   };
EOF
else
  cat <<EOF

   $hostname = public.lib.mkHost {
     hostname = "$hostname";
     system = "$system";
     user = commonUser;
     profiles = [ "server-base" ];
     roles = [ "development" ];
     machine.boot.mode = "uefi";
     secrets.sops = {
       enable = true;
       defaultFile = ./hosts/$hostname/secrets.yaml;
       ageKeyFile = "/home/\${commonUser.name}/.config/sops/age/keys.txt";
       secrets."user/hashedPassword".neededForUsers = true;
     };
     hardwareModules = [ ./hosts/$hostname/hardware-configuration.nix ];
     extraModules = [ ./hosts/$hostname ];
   };
EOF
fi

cat <<EOF

2. 编辑 .sops.yaml，添加 $hostname 的 age recipient 和 hosts/$hostname/secrets.yaml 规则。
3. 编辑 hosts/$hostname/secrets.yaml，填入真实值后执行：sops -e -i hosts/$hostname/secrets.yaml
4. 运行：nix eval .#nixosConfigurations.$hostname.config.networking.hostName
EOF
