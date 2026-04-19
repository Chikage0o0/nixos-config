{ ... }:
{
  virtualisation = {
    containers.enable = true;
    # 与 Docker 的短镜像名解析保持一致，未限定 registry 时默认走 docker.io。
    containers.registries.search = [ "docker.io" ];

    podman = {
      enable = true;

      # 同时兼容 `docker` 命令和依赖 Docker API 的现有工具。
      dockerCompat = true;
      dockerSocket.enable = true;

      # podman-compose 依赖容器网络内置 DNS 才能稳定解析服务名。
      defaultNetwork.settings.dns_enabled = true;
    };
  };
}
