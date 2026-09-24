{
  fetchurl,
  linux,
}:
(linux.override {
  argsOverride = {
    version = "7.2.6";
    modDirVersion = "7.2.6";
    src = fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.6.tar.xz";
      hash = "sha256-A5rvhPKwmUrto/T8/D0C7J16m7uQIOomTEP0Rshg9gY=";
    };
    extraMeta.branch = "7.2";
  };
}).overrideAttrs
  (old: {
    # 通用内核安装所有 ARM64 板卡的 DTB；本镜像只服务 Zero 3。
    postInstall = (old.postInstall or "") + ''
      zero3Dtb="$out/dtbs/allwinner/sun50i-h618-orangepi-zero3.dtb"
      cp "$zero3Dtb" "$TMPDIR/sun50i-h618-orangepi-zero3.dtb"
      rm -rf "$out/dtbs"
      install -Dm0644 "$TMPDIR/sun50i-h618-orangepi-zero3.dtb" "$zero3Dtb"
    '';
  })
