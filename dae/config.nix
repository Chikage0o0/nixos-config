{
  nodes ? { },
  subscriptions ? [ ],
}:
''
  global {
      ##### 软件基础选项

      # tproxy 监听端口。
      # 注意：这不是 HTTP/SOCKS 代理端口，而是用于 eBPF 程序捕获流量的端口。
      # 一般情况下，你不需要手动去连接这个端口。
      tproxy_port: 12345

      # 设置为 true 以保护 tproxy 端口不被未经授权的流量访问。
      # 如果你想手动配置 iptables tproxy 规则，请将其设置为 false。
      tproxy_port_protect: true

      # 设置非零值以启用 pprof (用于性能分析和调试)。
      pprof_port: 0

      # 如果非零，dae 发出的流量将被打上 SO_MARK 标记。
      # 这主要用于防止在使用 iptables tproxy 规则时出现流量死循环。
      so_mark_from_dae: 0

      # 日志级别: error (错误), warn (警告), info (信息), debug (调试), trace (追踪)。
      log_level: info

      # 禁止在拉取订阅前等待网络连接。设置为 false 则会等待网络就绪。
      disable_waiting_network: false

      # 启用本地 TCP 连接的快速重定向。
      # 这是一个实验性选项，可能会导致某些客户端（如 nadoo/glider）出现问题，开启需自行承担风险。
      enable_local_tcp_fast_redirect: false

      ##### 接口和内核选项

      # 绑定的 LAN (局域网) 接口。
      # 如果你想让 dae 代理局域网内其他设备的流量（充当网关），请填写此项。
      # 多个接口用 "," 分隔。
      #lan_interface: docker0,ens2,eth0

      # 绑定的 WAN (外网) 接口。如果你想代理本机的流量，此项必填。
      # 多个接口用 "," 分隔。使用 "auto" 可以自动检测出口网卡。
      wan_interface: auto

      # 自动配置 Linux 内核参数（如 ip_forward 和 send_redirects）。
      # 详情参考文档：https://github.com/daeuniverse/dae/blob/main/docs/en/user-guide/kernel-parameters.md
      auto_config_kernel_parameter: true

      ##### 节点连通性检查 (测速)
      # 如果 group 中没有定义特定的检查参数，默认使用这里的配置。

      # TCP 检查链接。建议使用带有 Anycast IP 且响应包较小的站点。
      # 格式：'URL,IP1,IP2'。如果本地是双栈网络，建议同时包含 IPv4 和 IPv6 地址。
      #tcp_check_url: 'http://cp.cloudflare.com'
      tcp_check_url: 'http://cp.cloudflare.com,1.1.1.1,2606:4700:4700::1111'

      # 对 `tcp_check_url` 使用的 HTTP 请求方法。默认使用 'HEAD'，以此减少流量消耗。
      tcp_check_http_method: HEAD

      # UDP 连通性检查使用的 DNS。
      # 如果下方的 dns_upstream 包含 tcp 协议，此地址也会用于检查 TCP DNS 的连通性。
      # 格式：'host:port,IP1,IP2'。
      #udp_check_dns: 'dns.google:53'
      udp_check_dns: 'dns.google:53,8.8.8.8,2001:4860:4860::8888'

      # 检查间隔时间。
      check_interval: 30s

      # 只有当 新节点的延迟 <= 旧节点延迟 - 容差值 时，才会切换节点。
      # 用于防止节点频繁跳动。
      check_tolerance: 50ms


      ##### 连接选项 (核心配置)

      # dial_mode (连接模式) 可选值：
      # 1. "ip": 直接使用本地 DNS 解析出的 IP 连接代理。
      #    这允许 IPv4/IPv6 根据本地解析结果分别选择最佳路径。
      #    例如：curl -4 ip.sb 走 IPv4 代理，curl -6 ip.sb 走 IPv6。
      #    此模式下，嗅探 (sniffing) 功能将被禁用。
      #
      # 2. "domain": (推荐) 使用嗅探出的域名进行代理连接。
      #    即使本地 DNS 被污染，代理服务器会在远程重新解析域名，从而获取正确的 IP。
      #    这通常能获得更快的响应速度。注意：此设置仅影响连接方式，不影响路由分流。
      #
      # 3. "domain+": 基于 domain 模式，但不检查嗅探到的域名是否真实有效。
      #    适用于 DNS 请求不经过 dae 但仍希望获得较快代理响应的用户。
      #    注意：如果 DNS 不经过 dae，dae 将无法根据域名进行分流。
      #
      # 4. "domain++": 基于 domain+，但在路由决策时强制使用嗅探到的域名重新进行路由匹配。
      #    这可以部分恢复基于域名的分流能力，但不支持直连流量，且消耗更多 CPU。
      dial_mode: domain

      # 是否允许不安全的 TLS 证书。除非必要，否则建议保持 false。
      allow_insecure: false

      # 嗅探流量等待首个数据包发送的超时时间。
      # 如果 dial_mode 为 ip，此值为 0。在高延迟的局域网环境中，调大此值可能有帮助。
      sniffing_timeout: 100ms

      # TLS 实现方式。
      # "tls": 使用 Go 语言原生 crypto/tls。
      # "utls": 使用 uTLS，可以模拟浏览器的 Client Hello 特征，防止被识别。
      tls_implementation: utls

      # uTLS 模拟的 Client Hello ID。仅当 tls_implementation 为 utls 时生效。
      utls_imitate: chrome_auto

   
      # 多路径 TCP (MPTCP) 支持。
      # 开启后，如果节点支持，dae 将尝试使用 MPTCP 连接。可用于多网口/多 IP 的负载均衡和故障转移。
      mptcp: false

      # 最大带宽限制。主要用于 Hysteria2 等协议的拥塞控制建议。
      # 单位支持 b, kb, mb, gb, tb 或 bps。
      bandwidth_max_tx: '200 mbps' # 上行带宽
      bandwidth_max_rx: '1 gbps'   # 下行带宽

      # 后备 DNS 解析器。
      # dae 默认使用系统 DNS (resolv.conf) 解析 DoH/DoT 域名和订阅链接。
      # 当系统 DNS 不可靠时，使用此后备 DNS 确保 dae 自身能正常解析域名。
      # 默认值是 Google DNS (8.8.8.8:53)。
      # fallback_resolver: '8.8.8.8:53'
  }

  # 订阅配置
  # 在此处定义的订阅将被解析为节点，并合并到全局节点池中。
  subscription {
      ${builtins.concatStringsSep "\n    " (map (url: "'${url}'") subscriptions)}
  }

  # 节点配置
  # 单独定义的节点也会合并到全局节点池。
  node {
      # 支持 socks5, http, https, ss, ssr, vmess, vless, trojan, tuic, juicity, hysteria2 等。
      ${builtins.concatStringsSep "\n    " (
        map (name: "${name}: '${builtins.getAttr name nodes}'") (builtins.attrNames nodes)
      )}
  }

  # DNS 配置 (dae 自带 DNS 服务器)
  dns {
      # IP 版本偏好。例如设为 4，当域名同时有 A (IPv4) 和 AAAA (IPv6) 记录时，只响应 A 记录。
      ipversion_prefer: 4

      # 固定域名的 TTL (生存时间)。0 表示不缓存，每次都向上游查询。
      #fixed_domain_ttl {
      #    ddns.example.org: 10
      #    test.example.org: 3600
      #}

      # 监听地址。用于接收 DNS 查询。
      # bind: '127.0.0.1:5353'
      # bind: 'udp://127.0.0.1:5353'

      upstream {
          # 定义上游 DNS 服务器。
          # scheme 支持: tcp/udp/tcp+udp/h3/http3/quic/https/tls。
          # 建议：如果 dial_mode 为 "ip"，且在没有 routing 规则的情况下，国内 DNS 不建议设为直连，以免污染。

          alidns: 'udp://dns.alidns.com:53'
          googledns: 'tcp+udp://dns.google:53'

          # 更多示例：
          # ali_doh: 'https://dns.alidns.com:443'
          # ali_dot: 'tls://dns.alidns.com:853'
      }
      
      routing {
          # DNS 请求路由：根据请求内容决定使用哪个上游 DNS。
          # 规则从上到下匹配。
          request {
              # 国内域名 -> 使用阿里 DNS
              qname(geosite:cn) -> alidns
              # 默认回退 -> 使用 Google DNS
              fallback: googledns
          }
      }
      
      # 响应路由示例（通常不需要配置，除非有高级需求）：
  #    routing {
  #        response {
  #            # 信任 Google DNS 的结果
  #            upstream(googledns) -> accept
  #            # 如果结果是私有 IP 但域名不是 CN 的，可能被污染了，强制用 Google DNS 再查一次
  #            ip(geoip:private) && !qname(geosite:cn) -> googledns
  #            fallback: accept
  #        }
  #    }
  }

  # 节点组 (出站分组)
  group {
      my_group {
          # 没有过滤器，使用所有节点。

          # 策略：随机选择
          #policy: random

          # 策略：固定选择第一个节点
          #policy: fixed(0)

          # 策略：选择延迟最低的节点
          #policy: min

          # 策略：选择移动平均延迟最低的节点 (推荐，更平滑)
          policy: min_moving_avg
      }

      group2 {
          # 过滤器：只选择 subtag 为 my_sub 且名字不含 'ExpireAt:' 的节点
          #filter: subtag(my_sub) && !name(keyword: 'ExpireAt:')
          
          # 多行 filter 是 "或" (OR) 的关系
          #filter: subtag(regex: '^my_', another_sub) && !name(keyword: 'ExpireAt:')

          # 根据节点名称筛选
          #filter: name(node1, node2)

          # 带有延迟偏移的筛选 (用于故障转移偏好)。
          # 示例：即使 US 节点延迟较高，但减去 500ms 后可能比 HK 节点更“快”，从而被选中。
          filter: name(HK_node)
          filter: name(US_node) [add_latency: -500ms]

          # 策略：最近 10 次延迟的平均值最小
          policy: min_avg10
      }

      steam {
          filter: subtag(my_sub) && !name(keyword: 'ExpireAt:')
          policy: min_moving_avg

          # 覆盖全局的连通性检查设置，针对 Steam 进行优化
          tcp_check_url: 'http://test.steampowered.com'
      }
  }

  # 流量路由规则 (Routing)
  # 详情：https://github.com/daeuniverse/dae/blob/main/docs/en/configuration/routing.md
  routing {
      ### 预设规则

      # 本机网络管理器直连，避免绑定 WAN 接口时出现连通性误报。
      pname(NetworkManager, systemd-resolved, dnsmasq, netbird) -> direct

      # 放在最前面，防止广播、组播等局域网流量被代理转发。
      # dip = destination IP (目标 IP)
      dip(224.0.0.0/3, 'ff00::/8', 100.64.0.0/16) -> direct

      # 私有地址 (局域网 IP) 直连。
      # 如果你想代理局域网内的某个网段，请修改此行。
      dip(geoip:private) -> direct

      ### 自定义规则

      # 屏蔽 UDP 443 端口 (通常是 HTTP/3 QUIC)。
      # 因为 QUIC 经常导致 Youtube 等流媒体分流困难或消耗过多资源，屏蔽后浏览器会回退到 TCP (HTTP/2)。
      l4proto(udp) && dport(443) -> block
      
      # 目标 IP 为中国大陆 -> 直连
      dip(geoip:cn) -> direct
      # 域名包含在中国大陆列表 -> 直连
      domain(geosite:cn) -> direct
      
      domain(suffix:qoder.com) -> direct 
      # 默认规则：走 my_group 代理组
      fallback: my_group
  }
''
