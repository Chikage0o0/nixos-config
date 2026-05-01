{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
in
{
  config = lib.mkIf (cfg.desktop.enable && cfg.desktop.apps.enable) {
    home.activation.setKsmserverLoginMode = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file ksmserverrc --group General --key loginMode emptySession
    '';

    home.activation.setPlasmaTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kcminputrc --group Mouse --key cursorTheme Bibata-Modern-Ice
      run ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 --file kcminputrc --group Mouse --key cursorSize 24
    '';

    gtk = {
      enable = true;
      theme = {
        name = "Breeze-Dark";
        package = pkgs.kdePackages.breeze-gtk;
      };
      iconTheme = {
        name = "Papirus-Dark";
        package = pkgs.papirus-icon-theme;
      };
    };

    home.pointerCursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Ice";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
    };

    programs.kitty = {
      enable = true;
      themeFile = "Catppuccin-Mocha";
      font = {
        name = "FiraCode Nerd Font";
        package = pkgs.nerd-fonts.fira-code;
        size = 12;
      };
      settings = {
        font_family = "FiraCode Nerd Font,Sarasa Mono SC";
        confirm_os_window_close = 0;
        enable_audio_bell = false;
        scrollback_lines = 10000;
        background_opacity = 0.85;
        background_blur = 10;
        mouse_map = "ctrl+left click ungrabbed mouse_handle_click selection link prompt";
      };
    };

    programs.mpv = {
      enable = true;
      scripts = with pkgs.mpvScripts; [
        uosc
        thumbfast
        mpris
      ];
      config = {
        hwdec = "auto-safe";
        save-position-on-quit = true;
        osd-bar = false;
        osc = false;
        sub-auto = "fuzzy";
        slang = "chi,chs,sc,zh-Hans,zh-CN,zh,eng,en";
        alang = "jpn,ja,eng,en,chi,zh";
        screenshot-format = "png";
        screenshot-png-compression = 3;
        ytdl-format = "bestvideo[height<=?2160]+bestaudio/best";
      };
      scriptOpts = {
        uosc = {
          timeline_style = "bar";
          timeline_size = 40;
          controls = "menu,gap,subtitles,audio,space,fullscreen";
          top_bar = "yes";
        };
        thumbfast = {
          network = true;
          spawn_first = true;
        };
      };
      bindings = {
        RIGHT = "seek 5";
        LEFT = "seek -5";
        UP = "seek 60";
        DOWN = "seek -60";
        "]" = "add speed 0.1";
        "[" = "add speed -0.1";
        "\\" = "set speed 1.0";
        a = "cycle audio";
        s = "cycle sub";
        v = "cycle sub-visibility";
        i = "script-binding stats/display-stats-toggle";
        q = "quit-watch-later";
        S = "screenshot";
        "." = "frame-step";
        "," = "frame-back-step";
        PGUP = "add chapter 1";
        PGDWN = "add chapter -1";
        SPACE = "cycle pause";
        m = "cycle mute";
      };
    };
  };
}
