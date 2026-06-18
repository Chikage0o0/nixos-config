{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform;
  enable = cfg.i18n.chinese.enable || (cfg.desktop.enable && cfg.desktop.apps.enable);

  chineseFonts = with pkgs; [
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    sarasa-gothic
    corefonts
    vista-fonts
    vista-fonts-chs
  ];
in
{
  config = lib.mkIf enable {
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

    fonts.packages = chineseFonts;
    fonts.fontconfig = {
      antialias = true;
      hinting = {
        enable = true;
        autohint = false;
        style = "slight";
      };
      subpixel = {
        rgba = "rgb";
        lcdfilter = "default";
      };
      defaultFonts.monospace = [ "Sarasa Mono SC" ];
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <!-- CJK: sans-serif 优先使用 Sarasa Gothic SC -->
          <match target="pattern">
            <test name="lang" compare="contains"><string>zh</string></test>
            <test name="family"><string>sans-serif</string></test>
            <edit name="family" mode="prepend"><string>Sarasa Gothic SC</string></edit>
          </match>
          <!-- CJK 字体使用 slight hinting，避免笔画扭曲 -->
          <match target="font">
            <test name="family" compare="contains"><string>Sarasa</string></test>
            <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
          </match>
          <match target="font">
            <test name="family" compare="contains"><string>Noto</string></test>
            <test name="family" compare="contains"><string>CJK</string></test>
            <edit name="hintstyle" mode="assign"><const>hintslight</const></edit>
          </match>
          <!-- emoji 回退 -->
          <match target="pattern">
            <test name="family"><string>sans-serif</string></test>
            <edit name="family" mode="append"><string>Noto Color Emoji</string></edit>
          </match>
        </fontconfig>
      '';
    };
  };
}
