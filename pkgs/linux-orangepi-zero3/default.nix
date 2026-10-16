{
  fetchurl,
  linux,
}:
(linux.override {
  argsOverride = {
    version = "7.2.11";
    modDirVersion = "7.2.11";
    src = fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v7.x/linux-7.2.11.tar.xz";
      hash = "sha256-/Q/EefmDqMBTE/E+nDYzD+ZlHPclOWdIxA1c2T+h5qQ=";
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
