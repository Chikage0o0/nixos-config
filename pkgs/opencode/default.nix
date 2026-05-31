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
  version = "1.15.13";
  release =
    {
      x86_64-linux = {
        asset = "opencode-linux-x64.tar.gz";
        hash = "sha256-UXhaB8AJ8nxRJaUjXFoP94Qz2s4H9z+8ROtnLq1LPXk=";
      };
      aarch64-linux = {
        asset = "opencode-linux-arm64.tar.gz";
        hash = "sha256-eg5dokJ8eAQxT+D4e3S0QIRn+U47ixphuiWh1x/gtNI=";
      };
      x86_64-darwin = {
        asset = "opencode-darwin-x64.zip";
        hash = "sha256-4NofDAEdqocXR5AUlo1+yM5nKAGoukcQ9JRx3J+7LHs=";
      };
      aarch64-darwin = {
        asset = "opencode-darwin-arm64.zip";
        hash = "sha256-vjaaONFaIug/rTSHTRvH3erYCE4H3ykrKNB5KH1Uqww=";
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
