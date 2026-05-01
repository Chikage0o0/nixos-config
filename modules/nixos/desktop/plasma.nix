{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;

  desktopPackages = with pkgs; [
    microsoft-edge
    wpsoffice-cn
    kdePackages.gwenview
    kdePackages.spectacle
    gimp
    kdePackages.dolphin
    kdePackages.kate
    kdePackages.ark
    kdePackages.kcalc
    p7zip
    unrar
    bitwarden-desktop
    remmina
    kdePackages.plasma-systemmonitor
    kdePackages.partitionmanager
    kdePackages.filelight
    kdePackages.print-manager
    kdePackages.bluedevil
    kdePackages.plasma-nm
    kdePackages.discover
    # appimage-run 缺少 pname，覆盖仅补齐元数据以便验证匹配，不改变安装的 derivation
    (appimage-run // { pname = "appimage-run"; })
    obsidian
    thunderbird
    yt-dlp
    ffmpeg-full
    mediainfo
  ];

  desktopFonts = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    sarasa-gothic
    nerd-fonts.fira-code
    corefonts
    vista-fonts
    vista-fonts-chs
  ];
in
{
  config = lib.mkIf cfg.desktop.enable (
    lib.mkMerge [
      {
        services.xserver.enable = true;
        services.desktopManager.plasma6.enable = true;
        services.displayManager.sddm = {
          enable = true;
          wayland.enable = true;
        };
        services.libinput.enable = true;
        xdg.portal.enable = true;

        services.pipewire = {
          enable = true;
          alsa = {
            enable = true;
            support32Bit = true;
          };
          pulse.enable = true;
          jack.enable = true;
          wireplumber.enable = true;
        };
        security.rtkit.enable = true;

        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
        };

        services.printing.enable = true;

        i18n.defaultLocale = cfg.locale;
        i18n.extraLocales = [ "en_US.UTF-8/UTF-8" ];
        i18n.extraLocaleSettings = {
          LC_ADDRESS = cfg.locale;
          LC_IDENTIFICATION = cfg.locale;
          LC_MEASUREMENT = cfg.locale;
          LC_MONETARY = cfg.locale;
          LC_NAME = cfg.locale;
          LC_NUMERIC = cfg.locale;
          LC_PAPER = cfg.locale;
          LC_TELEPHONE = cfg.locale;
          LC_TIME = cfg.locale;
        };

        i18n.inputMethod = {
          enable = true;
          type = "fcitx5";
          fcitx5.waylandFrontend = true;
          fcitx5.addons = with pkgs; [
            fcitx5-gtk
            kdePackages.fcitx5-qt
            kdePackages.fcitx5-chinese-addons
            kdePackages.fcitx5-configtool
            catppuccin-fcitx5
          ];
          fcitx5.settings = {
            addons = {
              classicui.globalSection = {
                Theme = "catppuccin-latte-sky";
                DarkTheme = "catppuccin-mocha-sky";
                UseDarkTheme = "True";
                UseAccentColor = "True";
                PerScreenDPI = "True";
                VerticalCandidateList = "False";
                WheelForPaging = "True";
                Font = "Sarasa UI SC 12";
                MenuFont = "Sarasa UI SC 10";
              };
            };
          };
        };

        environment.plasma6.excludePackages = with pkgs; [
          kdePackages.konsole
          kdePackages.okular
          kdePackages.elisa
          kdePackages.dragon
        ];
      }

      (lib.mkIf cfg.desktop.apps.enable {
        services.flatpak.enable = true;
        programs.kdeconnect.enable = true;

        environment.systemPackages = desktopPackages;
        fonts.packages = desktopFonts;
        fonts.fontconfig.defaultFonts.monospace = [ "Sarasa Mono SC" ];
      })
    ]
  );
}
