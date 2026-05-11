{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  nodejs_24,
}:

let
  version = "0.27.0";
  release =
    {
      x86_64-linux = "agent-browser-linux-x64";
      aarch64-linux = "agent-browser-linux-arm64";
    }
    .${stdenv.hostPlatform.system}
      or (throw "Unsupported system for agent-browser release binary: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "agent-browser";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/agent-browser/-/agent-browser-${version}.tgz";
    hash = "sha512-mmHzVsYFVA6nshNNGJzg83aVMgKpf4h98ytY3pvtJB1Cot0ZyA2bfnkbSngGD56Azkj+GlhVH6qx9DfKOVE0yg==";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/agent-browser/bin
    cp -R skill-data skills $out/lib/agent-browser/
    install -Dm755 bin/${release} $out/lib/agent-browser/bin/${release}
    install -Dm755 bin/agent-browser.js $out/lib/agent-browser/bin/agent-browser.js

    makeWrapper ${nodejs_24}/bin/node $out/bin/agent-browser \
      --add-flags $out/lib/agent-browser/bin/agent-browser.js

    runHook postInstall
  '';

  meta = with lib; {
    description = "Browser automation CLI for AI agents";
    homepage = "https://agent-browser.dev";
    license = licenses.asl20;
    mainProgram = "agent-browser";
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
