{
  lib,
  stdenv,
  fetchurl,
}:

stdenv.mkDerivation rec {
  pname = "v2ray-rules-dat";
  # 使用最新的 release 版本号
  # 可以通过运行 ./pkgs/update-v2ray-rules-dat.sh 来更新版本和 hash
  version = "202602052221";

  # 从 GitHub Releases 下载 geoip.dat
  geoip = fetchurl {
    url = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geoip.dat";
    sha256 = "8cf3dac7d99e428a380bd3aa1330f57718a794d45fe4f9dd20077c010dc0bcdb";
  };

  # 从 GitHub Releases 下载 geosite.dat
  geosite = fetchurl {
    url = "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/download/${version}/geosite.dat";
    sha256 = "1cef268aba784cf84196b6576698c0308e6e8bde8bc27a3e7d5b7c4983e06bf8";
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
