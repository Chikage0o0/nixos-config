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
  config = lib.mkIf cfg.home.cliTools.enable {
    programs.eza = {
      enable = true;
      enableZshIntegration = true;
      icons = "auto";
      git = true;
    };

    programs.zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };

    programs.fzf = {
      enable = true;
      enableZshIntegration = true;
    };

    programs.bat = {
      enable = true;
      config.theme = "TwoDark";
    };

    programs.lazygit.enable = true;

    programs.yazi = {
      enable = true;
      enableZshIntegration = cfg.home.shell.enable;
      plugins = {
        git = pkgs.yaziPlugins.git;
        full-border = {
          package = pkgs.yaziPlugins.full-border;
          setup = true;
        };
        smart-enter = {
          package = pkgs.yaziPlugins.smart-enter;
          setup = true;
          # smart-enter 26.05+ 的 setup 直接读取 opts.open_multi；显式传入默认值，
          # 避免 Home Manager 生成 setup() 导致插件收到 nil。
          settings.open_multi = false;
        };
      }
      // lib.optionalAttrs config.programs.lazygit.enable {
        # lazygit 插件依赖外部 lazygit 命令；只在 lazygit program 启用时注册。
        lazygit = pkgs.yaziPlugins.lazygit;
      };
      settings = {
        opener.edit = [
          {
            run = ''hx "$@"'';
            block = true;
            for = "unix";
          }
        ];
        manager = {
          show_hidden = true;
          sort_dir_first = true;
        };
        plugin.prepend_fetchers = [
          {
            url = "*";
            run = "git";
            group = "git";
          }
          {
            url = "*/";
            run = "git";
            group = "git";
          }
        ];
      };
      keymap.mgr.prepend_keymap = [
        {
          on = "l";
          run = "plugin smart-enter";
          desc = "Enter child directory or open file";
        }
      ]
      ++ lib.optionals config.programs.lazygit.enable [
        {
          on = [
            "g"
            "i"
          ];
          run = "plugin lazygit";
          desc = "Open lazygit in current directory";
        }
      ];
    };

    programs.helix = {
      enable = true;
      defaultEditor = true;
      settings = {
        theme = "base16_transparent";
        editor = {
          line-number = "relative";
          cursorline = true;
          color-modes = true;
          bufferline = "multiple";
          true-color = true;
          indent-guides.render = true;
          soft-wrap.enable = true;
        };
      };
    };
  };
}
