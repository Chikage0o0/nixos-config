{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  version = "1.16.2";

  release =
    {
      x86_64-linux = {
        npmPackage = "opencode-linux-x64-baseline";
        hash = "sha256-rFiIbdCpZ1LHaI4HyP8IkWVd9FIH6qlP3rhnO++4K2k=";
      };
      aarch64-linux = {
        npmPackage = "opencode-linux-arm64";
        hash = "sha256-03Czj0TkePx/LugO3qoZoigS9Zh73YLo3wnZQRu7q34=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "opencode npm binary is not available for ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/${release.npmPackage}/-/${release.npmPackage}-${version}.tgz";
    inherit (release) hash;
  };

  # opencode 的 npm 平台包是 Bun standalone binary；patchelf 会破坏其嵌入 payload。
  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/opencode "$out/bin/opencode"

    runHook postInstall
  '';

  meta = {
    description = "AI coding agent built for the terminal";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
