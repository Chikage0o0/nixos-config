{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.platform.home.hermes;
  hermesPackage =
    if cfg.package != null then
      cfg.package
    else
      inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default;
  playwrightBrowsers = pkgs.playwright-driver.browsers;
  chromiumBinary = "${pkgs.chromium}/bin/chromium";
  defaultPackages = with pkgs; [
    hermesPackage
    agent-browser
    uv
    nodejs
    pnpm
    yarn
    ripgrep
    ffmpeg
    yt-dlp
    streamlink
    aria2
    mpv
    git
    python3
    python3Packages.pip
    gcc
    gnumake
    pkg-config
    cmake
    curl
    wget
    unzip
    zip
    gnutar
    gzip
    jq
    yq-go
    fd
    tree
    playwright
    playwright-mcp
    playwrightBrowsers
    chromium
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    source-han-sans
    sarasa-gothic
    wqy_zenhei
  ];
in
{
  config = lib.mkIf cfg.enable {
    home.packages = defaultPackages ++ cfg.extraPackages;

    fonts.fontconfig.enable = true;

    home.sessionVariables = {
      PLAYWRIGHT_BROWSERS_PATH = "${playwrightBrowsers}";
      PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD = "1";
      CHROME_PATH = chromiumBinary;
      BROWSER = chromiumBinary;
    };

    systemd.user.services.hermes-agent = lib.mkIf cfg.service.enable {
      Unit = {
        Description = "Hermes Agent gateway";
        After = [ "network-online.target" ];
        Wants = [ "network-online.target" ];
      };

      Service = {
        ExecStart = lib.escapeShellArgs (
          [
            "${hermesPackage}/bin/hermes"
            "gateway"
          ]
          ++ cfg.service.extraArgs
        );
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 210;
        WorkingDirectory = "%h";
        Environment = [
          "HOME=%h"
          "HERMES_HOME=%h/.hermes"
          "PLAYWRIGHT_BROWSERS_PATH=${playwrightBrowsers}"
          "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1"
          "CHROME_PATH=${chromiumBinary}"
          "BROWSER=${chromiumBinary}"
        ];
      };

      Install.WantedBy = [ "default.target" ];
    };
  };
}
