{
  config,
  lib,
  ...
}:
let
  cfg = config.platform;
in
lib.mkIf (!cfg.machine.overseas) {
  home.sessionVariables = {
    PIP_INDEX_URL = "https://pypi.tuna.tsinghua.edu.cn/simple";
    UV_INDEX_URL = "https://pypi.tuna.tsinghua.edu.cn/simple";
    NPM_CONFIG_REGISTRY = "https://registry.npmmirror.com";
    GOPROXY = "https://goproxy.cn,direct";
    RUSTUP_DIST_SERVER = "https://rsproxy.cn";
    RUSTUP_UPDATE_ROOT = "https://rsproxy.cn/rustup";
  };

  xdg.configFile."bun/bunfig.toml".text = ''
    [install]
    registry = "https://registry.npmmirror.com"
  '';

  home.file.".cargo/config.toml".text = ''
    [source.crates-io]
    replace-with = "rsproxy"

    [source.rsproxy]
    registry = "sparse+https://rsproxy.cn/index/"
  '';
}
