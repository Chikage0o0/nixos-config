{
  lib,
  stdenv,
  fetchurl,
  makeWrapper,
  autoPatchelfHook,
  copyDesktopItems,
  makeDesktopItem,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cups,
  dbus,
  fontconfig,
  gtk3,
  libdrm,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  systemd,
  wayland,
  libglvnd,
  xorg,
  libappindicator-gtk3,
  libsecret,
}:

let
  version = "1.0.230";
  release =
    {
      x86_64-linux = {
        asset = "tabby-${version}-linux-x64.tar.gz";
        hash = "sha256-dH33qLrHpMwEr8BK7oUS3Mi+1RXhdAQbKCxXPD26cwI=";
      };
      aarch64-linux = {
        asset = "tabby-${version}-linux-arm64.tar.gz";
        hash = "sha256-aCtQqqjCozviRVwR8D8gYXRpXBJ2L1FQOaFYlFnwrI8=";
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "Unsupported system for tabby release binary: ${stdenv.hostPlatform.system}");
  icon = fetchurl {
    url = "https://raw.githubusercontent.com/Eugeny/tabby/v${version}/build/icons/256x256.png";
    hash = "sha256-1+heO61qXP658BQW1dvcSJ0rre0Kj6ohpWgloxZnlJE=";
  };
in
stdenv.mkDerivation {
  pname = "tabby";
  inherit version;

  src = fetchurl {
    url = "https://github.com/Eugeny/tabby/releases/download/v${version}/${release.asset}";
    hash = release.hash;
  };

  dontConfigure = true;
  dontBuild = true;

  nativeBuildInputs = [
    makeWrapper
    autoPatchelfHook
    copyDesktopItems
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    cups
    dbus
    fontconfig
    gtk3
    libdrm
    libxkbcommon
    mesa
    nspr
    nss
    pango
    systemd
    wayland
    libglvnd
    xorg.libX11
    xorg.libXcomposite
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXrandr
    xorg.libxcb
    libappindicator-gtk3
    libsecret
  ];

  unpackPhase = ''
    tar -xzf "$src" --strip-components=1
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/tabby $out/bin $out/share/icons/hicolor/256x256/apps
    cp -r ./* $out/lib/tabby/
    # The upstream prebuilt Electron bundle does not ship a usable Chromium sandbox on NixOS.
    makeWrapper $out/lib/tabby/tabby $out/bin/tabby \
      --add-flags "--no-sandbox"
    cp ${icon} $out/share/icons/hicolor/256x256/apps/tabby.png

    runHook postInstall
  '';

  preFixup = ''
    # Remove musl prebuilds that can't be patched on glibc systems
    find $out -name '*.node' -path '*/prebuilds/*/node.napi.musl.node' -delete
  '';

  postFixup = ''
    patchelf \
      --add-needed ${libglvnd}/lib/libGLESv2.so.2 \
      --add-needed ${libglvnd}/lib/libEGL.so.1 \
      $out/lib/tabby/tabby
  '';

  desktopItems = lib.optionals stdenv.hostPlatform.isLinux [
    (makeDesktopItem {
      name = "tabby";
      desktopName = "Tabby";
      comment = "A terminal for a more modern age";
      exec = "tabby";
      icon = "tabby";
      categories = [
        "System"
        "TerminalEmulator"
      ];
      startupWMClass = "tabby";
    })
  ];

  meta = with lib; {
    description = "A terminal for a more modern age";
    homepage = "https://github.com/Eugeny/tabby";
    license = licenses.mit;
    mainProgram = "tabby";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
