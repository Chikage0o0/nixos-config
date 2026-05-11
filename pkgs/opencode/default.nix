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
  version = "1.14.48";
  release =
    {
      x86_64-linux = {
        asset = "opencode-linux-x64.tar.gz";
        hash = "sha256-0GEl3gdK+cF75kkTfivvWbd0x2aBMLAIb5vZm6Z7r4I=";
      };
      aarch64-linux = {
        asset = "opencode-linux-arm64.tar.gz";
        hash = "sha256-REF53lUE7T1oxVRJ4q+O0sks19X4TsHo8wbKwP5JvVA=";
      };
      x86_64-darwin = {
        asset = "opencode-darwin-x64.zip";
        hash = "sha256-kS/SeLqsqsk8cQ82uGePJ3u4lBWmCGIUql/4nXkX2X4=";
      };
      aarch64-darwin = {
        asset = "opencode-darwin-arm64.zip";
        hash = "sha256-UX09hz9iSmPaLU3h6mTPO9uK8mD5lCgU54eIpteWLSQ=";
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
