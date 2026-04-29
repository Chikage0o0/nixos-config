{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "v2ray-rules-dat";
  # 使用最新的 release 版本号
  # 可以通过运行 ./pkgs/update-v2ray-rules-dat.sh 来更新版本和 hash
  version = "202604282251";

  # 从 GitHub Releases 下载 geoip.dat
  geoip = fetchurl {
    url = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat";
    sha256 = "3a16eb14d7824209c30b50ec8a6fa2166b9718c9a7ce1c45ee9ccef2a2d9a9be";
  };

  # 从 GitHub Releases 下载 geosite.dat
  geosite = fetchurl {
    url = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat";
    sha256 = "4e56d3c371fc3bb747d96e7729ac5805f02eb9e0867ead97980e8fac34d0d57a";
  };

  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall

    # 创建输出目录
    mkdir -p $out/share/v2ray

    # 复制 geoip.dat 和 geosite.dat 到输出目录
    cp ${geoip} $out/share/v2ray/geoip.dat
    cp ${geosite} $out/share/v2ray/geosite.dat

    runHook postInstall
  '';

  meta = with lib; {
    description = "V2Ray 路由规则文件增强版,包含 geoip.dat 和 geosite.dat";
    longDescription = ''
      增强版 V2Ray 路由规则文件,由 Loyalsoldier 维护。
      包含 geoip.dat 和 geosite.dat 两个文件,用于代理软件的路由规则。
    '';
    homepage = "https://github.com/Loyalsoldier/v2ray-rules-dat";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
