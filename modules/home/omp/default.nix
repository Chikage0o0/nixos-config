{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform.home.omp;
  package =
    if cfg.package != null then
      cfg.package
    else
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.omp;
  standardFiles = {
    "AGENTS.md" = ./agent/AGENTS.md;
    "skills" = ./agent/skills;
    ".skill-lock.json" = ./agent/.skill-lock.json;
    "config.yml" = ./agent/config.yml;
  };
in
{
  config = lib.mkIf cfg.enable {
    home.packages = [ package ];

    home.file = lib.mapAttrs' (
      relativePath: source:
      lib.nameValuePair ".omp/agent/${relativePath}" {
        inherit source;
        force = true;
      }
    ) (standardFiles // cfg.files);
  };
}
