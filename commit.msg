📦 build(nix, opencode, v2ray-rules-dat): 升级 opencode 并补充交换空间配置

将 opencode 输入升级到 v1.2.21，并同步更新 flake 锁定版本。
同时更新 v2ray-rules-dat 规则数据，并为非 WSL 主机增加 16G
swapfile 与 zram 配置，提升本地构建和开发场景的内存缓冲能力。
