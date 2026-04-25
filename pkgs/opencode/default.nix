{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  ripgrep,
  unzip,
  sysctl,
}:

let
  version = "1.14.24";
  release =
    {
      x86_64-linux = {
        asset = "opencode-linux-x64.tar.gz";
        hash = "sha256-Lt/Be60+y6VK4dl1PO+eymhv3YoLD0t4X5IJ7g/IptI=";
      };
      aarch64-linux = {
        asset = "opencode-linux-arm64.tar.gz";
        hash = "sha256-MEEI8FBjvRetbfYlQbSOGZgNjjbV1QeuLr+AkgmQyaI=";
      };
      x86_64-darwin = {
        asset = "opencode-darwin-x64.zip";
        hash = "sha256-fM+qvF0eNRutL17e9ohGUEjskCmz4h7MUvxUuOCK51A=";
      };
      aarch64-darwin = {
        asset = "opencode-darwin-arm64.zip";
        hash = "sha256-XmHLvWfW74Jo6ECqAx7fWjPxPUKBKjnN3h+0Yc55IKI=";
      };
    }
    .${stdenvNoCC.hostPlatform.system}
      or (throw "Unsupported system for opencode release binary: ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/${release.asset}";
    hash = release.hash;
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    makeWrapper
  ]
  ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [ unzip ];

  unpackPhase =
    if stdenvNoCC.hostPlatform.isLinux then
      ''
        tar -xzf "$src"
      ''
    else
      ''
        unzip -q "$src"
      '';

  installPhase = ''
    runHook preInstall

    install -Dm755 opencode $out/libexec/opencode

    makeWrapper $out/libexec/opencode $out/bin/opencode \
      --prefix PATH : "${
        lib.makeBinPath ([ ripgrep ] ++ lib.optionals stdenvNoCC.hostPlatform.isDarwin [ sysctl ])
      }"

    runHook postInstall
  '';

  meta = with lib; {
    description = "AI coding agent built for the terminal";
    homepage = "https://github.com/anomalyco/opencode";
    license = licenses.mit;
    mainProgram = "opencode";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
