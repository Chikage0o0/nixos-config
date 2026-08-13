{
  config,
  lib,
  ...
}:
let
  standardFiles = {
    "AGENTS.md" = ./agent/AGENTS.md;
    "skills" = ./agent/skills;
    ".skill-lock.json" = ./agent/.skill-lock.json;
    "config.yml" = ./agent/config.yml;
  };
in
{
  config = lib.mkIf config.programs.omp.enable {

    home.file = lib.mapAttrs' (
      relativePath: source:
      lib.nameValuePair ".omp/agent/${relativePath}" {
        source = lib.mkDefault source;
        force = lib.mkDefault true;
      }
    ) standardFiles;
  };
}
