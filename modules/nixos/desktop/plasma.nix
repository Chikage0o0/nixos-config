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
    kdePackages.kio
    kdePackages.kio-extras
    kdePackages.kio-fuse
    kdePackages.kwallet
    kdePackages.kwalletmanager
    samba
    cifs-utils
    p7zip
    unrar
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
    thunderbird
    obsidian
    yt-dlp
    ffmpeg-full
    mediainfo
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

        environment.systemPackages = desktopPackages ++ [
          pkgs.papirus-icon-theme
          pkgs.bibata-cursors
        ];
        # Fira Code Nerd Font 仍属于桌面开发体验，而非中文字体基线。
        fonts.packages = [ pkgs.nerd-fonts.fira-code ];
      })
    ]
  );
}
