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
  version = "1.14.31";
  release =
    {
      x86_64-linux = {
        asset = "opencode-linux-x64.tar.gz";
        hash = "sha256-XThT4pyB16E0kVaQYlAJ9XNsqEBwUp5peWz2LhIjLJ4=";
      };
      aarch64-linux = {
        asset = "opencode-linux-arm64.tar.gz";
        hash = "sha256-2IZ+d7kB3QTnB/RZ9Es+KPI6bwwtdA8buK9vS2SsGfc=";
      };
      x86_64-darwin = {
        asset = "opencode-darwin-x64.zip";
        hash = "sha256-aSHHcL5eA3/CTp90X9ojUBb3suUe15+0sATG4ZtayUI=";
      };
      aarch64-darwin = {
        asset = "opencode-darwin-arm64.zip";
        hash = "sha256-86I4ajzNsehzOvdmYAoOLDWgAa2qoNMUKf+BwNzTIYA=";
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
