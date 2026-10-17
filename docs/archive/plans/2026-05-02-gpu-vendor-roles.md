# GPU 厂商 role 与 AI 加速分层 实施计划

> **给代理执行者：** REQUIRED SUB-SKILL: 使用 `subagent-driven-development`（推荐）或 `executing-plans` 逐任务执行本计划。步骤使用复选框 `- [ ]` 语法追踪。

**目标：** 为 `workstation-base` 补齐通用图形基线，新增 `gpu-intel` / `gpu-amd` / `gpu-nvidia` 三个厂商 role，把 GPU 能力入口统一迁移到 `platform.machine.gpu.<vendor>.enable`，并将 `ai-accelerated` 重构为按厂商叠加 `CUDA` / `ROCm` / `OpenVINO` 运行时的能力层。

**架构：** `profiles/workstation-base.nix` 继续只表达工作站形态，通用图形栈由 `modules/nixos/hardware/workstation.nix` 落地。GPU 厂商 role 只打开 `platform.machine.gpu.<vendor>.enable` 开关，真正的图形/视频/驱动能力由 `modules/nixos/hardware/{intel,amd,nvidia}.nix` 承担；`roles/ai-accelerated.nix` 不再表达厂商身份，而是基于这些开关条件叠加计算运行时。

**技术栈：** NixOS Flakes, nixpkgs module system, Home Manager bridge, Mesa, NVIDIA proprietary driver, ROCm/OpenCL, OpenVINO, Nix eval checks

---

## 文件结构与职责

| 路径 | 职责 |
| --- | --- |
| `lib/platform/checks.nix` | 增加 GPU 图形基线、厂商 role、AI 叠加层的 eval 级回归检查，并提供最小示例 host。 |
| `modules/shared/options.nix` | 定义新的 `platform.machine.gpu.{intel,amd,nvidia}.enable` 选项，并删除旧的 `platform.machine.nvidia.enable`。 |
| `modules/nixos/core/assertions.nix` | 迁移 WSL/NVIDIA 断言到新命名空间，并新增 `ai-accelerated` 必须搭配至少一个 GPU 厂商 role 的断言。 |
| `modules/nixos/default.nix` | 导入新的 `./hardware/intel.nix` 和 `./hardware/amd.nix`。 |
| `modules/nixos/hardware/workstation.nix` | 为所有 `workstation-base` 主机提供通用图形基线、Mesa 与 32 位兼容。 |
| `modules/nixos/hardware/intel.nix` | 落地 Intel 基础视频加速包：`intel-media-driver`、`intel-vaapi-driver`、`vpl-gpu-rt`。 |
| `modules/nixos/hardware/amd.nix` | 落地 AMD 基础驱动侧配置：启用 `hardware.amdgpu.initrd.enable`。 |
| `modules/nixos/hardware/nvidia.nix` | 迁移到 `platform.machine.gpu.nvidia.enable`，仅保留 NVIDIA 基础图形驱动，不再默认启用 CUDA/toolkit。 |
| `roles/default.nix` | 导出新增的 `gpu-intel`、`gpu-amd`、`gpu-nvidia` role。 |
| `roles/gpu-intel.nix` | 仅把 `platform.machine.gpu.intel.enable` 设为 `mkDefault true`。 |
| `roles/gpu-amd.nix` | 仅把 `platform.machine.gpu.amd.enable` 设为 `mkDefault true`。 |
| `roles/gpu-nvidia.nix` | 仅把 `platform.machine.gpu.nvidia.enable` 设为 `mkDefault true`。 |
| `roles/ai-accelerated.nix` | 基于 GPU 厂商开关条件叠加 `cudatoolkit`、`hardware.nvidia-container-toolkit.enable`、`hardware.amdgpu.opencl.enable`、`rocmPackages.rocminfo`、`openvino`、`intel-compute-runtime`。 |
| `example/my-host/flake.nix` | 把工作站示例迁移到 `gpu-nvidia + ai-accelerated` 的新分层，不再使用旧的 `machine.nvidia.enable`。 |

## 全局执行规则

- 每个任务开始前先运行 `git status --short`，只确认当前工作树状态，不回滚或覆盖其他代理/用户改动。
- 所有 Nix 代码改动后统一运行 `nix fmt`；格式化结果也必须纳入验证范围。
- 按 RED -> GREEN -> REFACTOR 推进：先写失败检查并确认失败，再做最小实现，最后重新验证通过。
- 不在本计划执行过程中自动提交；只有用户明确要求提交时，才通过 `git-commit` skill 单独处理。
- 任何“已完成”“已修好”“可以交付”的表述之前，都必须有新鲜的命令输出作为证据。

---

### 任务 1：先补 GPU 图形基线与分层回归检查

**文件：**
- 修改：`lib/platform/checks.nix`

- [ ] **步骤 1：在 `lib/platform/checks.nix` 中新增 GPU 检查辅助函数**

在 `mkSshAgentSessionCheck` 后插入以下代码：

```nix
  packageNames = packages: map lib.getName packages;

  mkWorkstationGraphicsBaseCheck =
    system: name: host:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
      cfg = config.config;
      passes =
        cfg.hardware.enableRedistributableFirmware
        && cfg.hardware.graphics.enable
        && cfg.hardware.graphics.enable32Bit;
    in
    pkgs.runCommand "${name}-workstation-graphics-base"
      {
        pass = if passes then "1" else "0";
        firmware = if cfg.hardware.enableRedistributableFirmware then "1" else "0";
        graphics = if cfg.hardware.graphics.enable then "1" else "0";
        graphics32 = if cfg.hardware.graphics.enable32Bit then "1" else "0";
      }
      ''
        if [[ "$pass" != 1 ]]; then
          echo "Expected workstation graphics base for ${name}." >&2
          echo "firmware=$firmware" >&2
          echo "graphics=$graphics" >&2
          echo "graphics32=$graphics32" >&2
          exit 1
        fi
        touch $out
      '';

  mkGpuLayeringCheck =
    system: name: host: expected:
    let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      config = self.lib.mkHost (host // { inherit system; });
      cfg = config.config;
      gpuCfg = cfg.platform.machine.gpu;
      graphicsPkgNames = packageNames (cfg.hardware.graphics.extraPackages or [ ]);
      systemPkgNames = packageNames (cfg.environment.systemPackages or [ ]);
      videoDrivers = cfg.services.xserver.videoDrivers or [ ];
      passes =
        gpuCfg.intel.enable == expected.intel
        && gpuCfg.amd.enable == expected.amd
        && gpuCfg.nvidia.enable == expected.nvidia
        && cfg.hardware.graphics.enable == expected.graphics
        && cfg.hardware.graphics.enable32Bit == expected.graphics32
        && (cfg.hardware.amdgpu.initrd.enable or false) == expected.amdgpuInitrd
        && (cfg.hardware.amdgpu.opencl.enable or false) == expected.amdgpuOpencl
        && (cfg.hardware.nvidia-container-toolkit.enable or false) == expected.nvidiaToolkit
        && lib.all (pkg: lib.elem pkg graphicsPkgNames) expected.graphicsPackages
        && lib.all (pkg: lib.elem pkg systemPkgNames) expected.systemPackages
        && lib.all (driver: lib.elem driver videoDrivers) expected.videoDrivers;
    in
    pkgs.runCommand "${name}-gpu-layering"
      {
        pass = if passes then "1" else "0";
        graphicsPackages = lib.concatStringsSep "," graphicsPkgNames;
        systemPackages = lib.concatStringsSep "," systemPkgNames;
        drivers = lib.concatStringsSep "," videoDrivers;
        intel = if gpuCfg.intel.enable then "1" else "0";
        amd = if gpuCfg.amd.enable then "1" else "0";
        nvidia = if gpuCfg.nvidia.enable then "1" else "0";
        graphics = if cfg.hardware.graphics.enable then "1" else "0";
        graphics32 = if cfg.hardware.graphics.enable32Bit then "1" else "0";
        amdgpuInitrd = if (cfg.hardware.amdgpu.initrd.enable or false) then "1" else "0";
        amdgpuOpencl = if (cfg.hardware.amdgpu.opencl.enable or false) then "1" else "0";
        nvidiaToolkit = if (cfg.hardware.nvidia-container-toolkit.enable or false) then "1" else "0";
      }
      ''
        if [[ "$pass" != 1 ]]; then
          echo "Expected GPU layering for ${name}." >&2
          echo "intel=$intel amd=$amd nvidia=$nvidia" >&2
          echo "graphics=$graphics graphics32=$graphics32" >&2
          echo "amdgpuInitrd=$amdgpuInitrd amdgpuOpencl=$amdgpuOpencl nvidiaToolkit=$nvidiaToolkit" >&2
          echo "graphicsPackages=$graphicsPackages" >&2
          echo "systemPackages=$systemPackages" >&2
          echo "drivers=$drivers" >&2
          exit 1
        fi
        touch $out
      '';
```

- [ ] **步骤 2：在 `hosts` 中新增最小 GPU 示例主机并迁移现有 NVIDIA 示例**

把 `hosts = { ... };` 扩展为以下新增结构：

```nix
    example-intel-workstation = base // {
      hostname = "example-intel-workstation";
      profiles = [ "workstation-base" ];
      roles = [ "gpu-intel" ];
      machine.boot.mode = "uefi";
    };

    example-amd-workstation = base // {
      hostname = "example-amd-workstation";
      profiles = [ "workstation-base" ];
      roles = [ "gpu-amd" ];
      machine.boot.mode = "uefi";
    };

    example-intel-ai-workstation = base // {
      hostname = "example-intel-ai-workstation";
      profiles = [ "workstation-base" ];
      roles = [ "gpu-intel" "ai-accelerated" ];
      machine.boot.mode = "uefi";
    };

    example-amd-ai-workstation = base // {
      hostname = "example-amd-ai-workstation";
      profiles = [ "workstation-base" ];
      roles = [ "gpu-amd" "ai-accelerated" ];
      machine.boot.mode = "uefi";
    };

    example-gpu-workstation = base // {
      hostname = "example-gpu-workstation";
      profiles = [ "workstation-base" ];
      roles = [ "gpu-nvidia" "ai-accelerated" ];
      machine.boot.mode = "uefi";
    };
```

- [ ] **步骤 3：导出新的检查目标**

在最终导出的 checks attrset 里追加：

```nix
    example-workstation-graphics-base =
      mkWorkstationGraphicsBaseCheck system "example-workstation"
        hosts.example-workstation;

    example-intel-workstation-gpu =
      mkGpuLayeringCheck system "example-intel-workstation"
        hosts.example-intel-workstation
        {
          intel = true;
          amd = false;
          nvidia = false;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = false;
          amdgpuOpencl = false;
          nvidiaToolkit = false;
          graphicsPackages = [ "intel-media-driver" "intel-vaapi-driver" "vpl-gpu-rt" ];
          systemPackages = [ ];
          videoDrivers = [ ];
        };

    example-amd-workstation-gpu =
      mkGpuLayeringCheck system "example-amd-workstation"
        hosts.example-amd-workstation
        {
          intel = false;
          amd = true;
          nvidia = false;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = true;
          amdgpuOpencl = false;
          nvidiaToolkit = false;
          graphicsPackages = [ ];
          systemPackages = [ ];
          videoDrivers = [ ];
        };

    example-intel-ai-workstation-gpu =
      mkGpuLayeringCheck system "example-intel-ai-workstation"
        hosts.example-intel-ai-workstation
        {
          intel = true;
          amd = false;
          nvidia = false;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = false;
          amdgpuOpencl = false;
          nvidiaToolkit = false;
          graphicsPackages = [ "intel-media-driver" "intel-vaapi-driver" "vpl-gpu-rt" ];
          systemPackages = [ "openvino" "intel-compute-runtime" ];
          videoDrivers = [ ];
        };

    example-amd-ai-workstation-gpu =
      mkGpuLayeringCheck system "example-amd-ai-workstation"
        hosts.example-amd-ai-workstation
        {
          intel = false;
          amd = true;
          nvidia = false;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = true;
          amdgpuOpencl = true;
          nvidiaToolkit = false;
          graphicsPackages = [ ];
          systemPackages = [ "rocminfo" ];
          videoDrivers = [ ];
        };

    example-gpu-workstation-ai-layering =
      mkGpuLayeringCheck system "example-gpu-workstation"
        hosts.example-gpu-workstation
        {
          intel = false;
          amd = false;
          nvidia = true;
          graphics = true;
          graphics32 = true;
          amdgpuInitrd = false;
          amdgpuOpencl = false;
          nvidiaToolkit = true;
          graphicsPackages = [ ];
          systemPackages = [ "cudatoolkit" ];
          videoDrivers = [ "nvidia" ];
        };
```

- [ ] **步骤 4：运行失败验证，确认新检查当前是 RED**

运行：

```bash
nix build .#checks.x86_64-linux.example-workstation-graphics-base
nix build .#checks.x86_64-linux.example-intel-workstation-gpu
```

预期：两个命令都失败。

- 第一个通常会因为 `hardware.graphics.enable` / `enable32Bit` 仍为 `false` 而失败，输出类似：

```text
Expected workstation graphics base for example-workstation.
firmware=1
graphics=0
graphics32=0
```

- 第二个通常会因为 `gpu-intel` 还是未知 role，或 `platform.machine.gpu` 选项尚未定义而失败，输出类似：

```text
Unknown role 'gpu-intel'
```

---

### 任务 2：引入新的 GPU 选项命名空间、role 导出和断言

**文件：**
- 修改：`modules/shared/options.nix`
- 修改：`modules/nixos/core/assertions.nix`
- 修改：`roles/default.nix`
- 新增：`roles/gpu-intel.nix`
- 新增：`roles/gpu-amd.nix`
- 新增：`roles/gpu-nvidia.nix`

- [ ] **步骤 1：先运行 role/选项探针，确认当前还不能解析新命名空间**

运行：

```bash
nix eval --impure --json --expr '
let
  flake = builtins.getFlake (toString ./.);
  host = flake.lib.mkHost {
    hostname = "gpu-role-probe";
    system = "x86_64-linux";
    user = {
      name = "example";
      fullName = "Example User";
      email = "example@example.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
    };
    profiles = [ "workstation-base" ];
    roles = [ "gpu-intel" "gpu-amd" "gpu-nvidia" ];
    machine.boot.mode = "uefi";
    extraModules = [
      {
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
      }
    ];
  };
in host.config.platform.machine.gpu
'
```

预期：FAIL，通常会看到 `Unknown role 'gpu-intel'`，或者 `platform.machine.gpu` 路径不存在。

- [ ] **步骤 2：在 `modules/shared/options.nix` 中建立新的 `platform.machine.gpu` 选项组**

把旧的：

```nix
      nvidia.enable = mkOption {
        type = types.bool;
        default = false;
        description = "是否启用 NVIDIA/CUDA 机器能力。";
      };
```

替换为：

```nix
      gpu = {
        intel.enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 Intel GPU 的基础图形/视频驱动能力。AI/计算运行时由 ai-accelerated 叠加。";
        };

        amd.enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 AMD GPU 的基础图形/视频驱动能力。AI/计算运行时由 ai-accelerated 叠加。";
        };

        nvidia.enable = mkOption {
          type = types.bool;
          default = false;
          description = "是否启用 NVIDIA GPU 的基础图形/视频驱动能力。CUDA 等 AI/计算运行时由 ai-accelerated 叠加。";
        };
      };
```

- [ ] **步骤 3：迁移断言到新命名空间，并增加 `ai-accelerated` 必需条件**

把 `modules/nixos/core/assertions.nix` 改为：

```nix
{ config, lib, ... }:
let
  cfg = config.platform;
in
{
  assertions = [
    {
      assertion =
        cfg.machine.wsl.enable || cfg.machine.boot.mode != "uefi" || cfg.machine.boot.grubDevice == null;
      message = "使用 UEFI 启动时不要设置 platform.machine.boot.grubDevice；GRUB 会以 EFI 方式安装并使用 device = \"nodev\"。";
    }
    {
      assertion =
        cfg.machine.wsl.enable || cfg.machine.boot.mode != "bios" || cfg.machine.boot.grubDevice != null;
      message = "使用传统 BIOS 启动时必须设置 platform.machine.boot.grubDevice，例如 /dev/disk/by-id/...。";
    }
    {
      assertion = !(cfg.machine.wsl.enable && cfg.machine.gpu.nvidia.enable);
      message = "WSL profile 不能启用 platform.machine.gpu.nvidia.enable；GPU/CUDA 能力只能用于非 WSL Linux 主机。";
    }
    {
      assertion =
        !(lib.elem "ai-accelerated" cfg.roles)
        || cfg.machine.gpu.intel.enable
        || cfg.machine.gpu.amd.enable
        || cfg.machine.gpu.nvidia.enable;
      message = "ai-accelerated 需要至少一个 GPU 厂商 role；请同时启用 gpu-intel、gpu-amd 或 gpu-nvidia。";
    }
    {
      assertion = !(cfg.machine.wsl.enable && cfg.desktop.enable);
      message = "WSL 主机不能启用 platform.desktop.enable；请关闭桌面配置或改用非 WSL profile。";
    }
    {
      assertion = !cfg.desktop.enable || cfg.desktop.environment == "plasma";
      message = "platform.desktop.environment 第一版只支持 plasma；请设置为 \"plasma\" 或关闭 platform.desktop.enable。";
    }
    {
      assertion = !cfg.desktop.apps.enable || cfg.desktop.enable;
      message = "platform.desktop.apps.enable 需要 platform.desktop.enable = true；请同时设置 platform.desktop.enable = true 或关闭 platform.desktop.apps.enable。";
    }
  ];
}
```

- [ ] **步骤 4：导出新增 role，并创建三个最小 role 文件**

把 `roles/default.nix` 改为：

```nix
{
  development = ./development.nix;
  fullstack-development = ./fullstack-development.nix;
  ai-tooling = ./ai-tooling.nix;
  container-host = ./container-host.nix;
  remote-admin = ./remote-admin.nix;
  gpu-intel = ./gpu-intel.nix;
  gpu-amd = ./gpu-amd.nix;
  gpu-nvidia = ./gpu-nvidia.nix;
  ai-accelerated = ./ai-accelerated.nix;
}
```

新增 `roles/gpu-intel.nix`：

```nix
{ lib, ... }:
{
  platform.machine.gpu.intel.enable = lib.mkDefault true;
}
```

新增 `roles/gpu-amd.nix`：

```nix
{ lib, ... }:
{
  platform.machine.gpu.amd.enable = lib.mkDefault true;
}
```

新增 `roles/gpu-nvidia.nix`：

```nix
{ lib, ... }:
{
  platform.machine.gpu.nvidia.enable = lib.mkDefault true;
}
```

- [ ] **步骤 5：重新运行探针，确认新 role 与新选项命名空间已经连通**

再次运行步骤 1 的 `nix eval --impure --json --expr ...` 命令。

预期：PASS，输出至少应包含：

```json
{
  "amd": {
    "enable": true
  },
  "intel": {
    "enable": true
  },
  "nvidia": {
    "enable": true
  }
}
```

---

### 任务 3：落地工作站图形基线与 Intel/AMD/NVIDIA 硬件模块

**文件：**
- 修改：`modules/nixos/default.nix`
- 修改：`modules/nixos/hardware/workstation.nix`
- 修改：`modules/nixos/hardware/nvidia.nix`
- 新增：`modules/nixos/hardware/intel.nix`
- 新增：`modules/nixos/hardware/amd.nix`

- [ ] **步骤 1：先运行基线检查，确认图形能力还没有落地**

运行：

```bash
nix build \
  .#checks.x86_64-linux.example-workstation-graphics-base \
  .#checks.x86_64-linux.example-intel-workstation-gpu \
  .#checks.x86_64-linux.example-amd-workstation-gpu
```

预期：FAIL。

- `example-workstation-graphics-base` 会因为 `hardware.graphics.enable` 仍为 `false` 失败。
- `example-intel-workstation-gpu` 会因为 Intel 包还没加到 `hardware.graphics.extraPackages` 失败。
- `example-amd-workstation-gpu` 会因为 `hardware.amdgpu.initrd.enable` 还没打开失败。

- [ ] **步骤 2：在 `modules/nixos/default.nix` 中导入新的 Intel/AMD 硬件模块**

把文件改为：

```nix
{ ... }:
{
  imports = [
    ../shared/options.nix
    ./core/base.nix
    ./core/assertions.nix
    ./boot/grub.nix
    ./users
    ./networking/base.nix
    ./services/cockpit.nix
    ./services/openssh.nix
    ./hardware/intel.nix
    ./hardware/amd.nix
    ./hardware/nvidia.nix
    ./containers/podman.nix
    ./packages/system.nix
    ./desktop/plasma.nix
  ];
}
```

- [ ] **步骤 3：让 `workstation-base` 默认启用图形基线与 32 位兼容**

把 `modules/nixos/hardware/workstation.nix` 改为：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.platform.machine;
in
{
  config = lib.mkMerge [
    {
      hardware.enableRedistributableFirmware = lib.mkDefault true;
      hardware.graphics = {
        enable = lib.mkDefault true;
        enable32Bit = lib.mkDefault true;
      };
    }

    (lib.mkIf pkgs.stdenv.hostPlatform.isx86_64 {
      hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
      hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
    })

    (lib.mkIf cfg.powerProfiles.enable {
      services.power-profiles-daemon.enable = true;
    })

    (lib.mkIf cfg.brightness.enable {
      environment.systemPackages = [ pkgs.brightnessctl ];
    })
  ];
}
```

- [ ] **步骤 4：新增 `modules/nixos/hardware/intel.nix`**

创建文件：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.platform.machine.gpu.intel.enable {
    hardware.graphics.extraPackages = with pkgs; [
      intel-media-driver
      intel-vaapi-driver
      vpl-gpu-rt
    ];
  };
}
```

- [ ] **步骤 5：新增 `modules/nixos/hardware/amd.nix`**

创建文件：

```nix
{
  config,
  lib,
  ...
}:
{
  config = lib.mkIf config.platform.machine.gpu.amd.enable {
    hardware.amdgpu.initrd.enable = true;
  };
}
```

- [ ] **步骤 6：把 NVIDIA 模块收缩为“基础驱动层”**

把 `modules/nixos/hardware/nvidia.nix` 改为：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf config.platform.machine.gpu.nvidia.enable {
    services.xserver.videoDrivers = [ "nvidia" ];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    hardware.nvidia = {
      open = false;
      nvidiaSettings = false;
      package = config.boot.kernelPackages.nvidiaPackages.production;
      nvidiaPersistenced = false;
      powerManagement = {
        enable = true;
        finegrained = false;
      };
    };

    environment.systemPackages = [ pkgs.linuxPackages.nvidia_x11 ];
  };
}
```

- [ ] **步骤 7：重新运行基线检查并确认通过**

再次运行步骤 1 的三条检查构建命令。

预期：PASS，三个 derivation 都成功生成，且不会再出现图形基线缺失或 Intel/AMD 条件未满足的错误。

---

### 任务 4：重构 `ai-accelerated` 并迁移工作站示例到新分层

**文件：**
- 修改：`roles/ai-accelerated.nix`
- 修改：`example/my-host/flake.nix`

- [ ] **步骤 1：先运行 AI 叠加检查，确认当前仍然是 RED**

运行：

```bash
nix build \
  .#checks.x86_64-linux.example-intel-ai-workstation-gpu \
  .#checks.x86_64-linux.example-amd-ai-workstation-gpu \
  .#checks.x86_64-linux.example-gpu-workstation-ai-layering
```

预期：FAIL，通常会因为 `roles/ai-accelerated.nix` 还在写旧的 `platform.machine.nvidia.enable`，或者缺少 `cudatoolkit` / `openvino` / `rocminfo` 等运行时而失败。

- [ ] **步骤 2：把 `roles/ai-accelerated.nix` 改成按厂商叠加运行时**

把文件改为：

```nix
{
  config,
  lib,
  pkgs,
  ...
}:
let
  gpu = config.platform.machine.gpu;
in
{
  config = lib.mkMerge [
    (lib.mkIf gpu.nvidia.enable {
      hardware.nvidia-container-toolkit.enable = true;
      environment.systemPackages = [ pkgs.cudatoolkit ];
    })

    (lib.mkIf gpu.amd.enable {
      hardware.amdgpu.opencl.enable = true;
      environment.systemPackages = [ pkgs.rocmPackages.rocminfo ];
    })

    (lib.mkIf gpu.intel.enable {
      environment.systemPackages = [
        pkgs.openvino
        pkgs.intel-compute-runtime
      ];
    })
  ];
}
```

- [ ] **步骤 3：迁移 `example/my-host/flake.nix` 的工作站示例**

把工作站角色列表和 `machine` 块改为：

```nix
          roles = [
            "development"
            "fullstack-development"
            "ai-tooling"
            "container-host"
            "gpu-nvidia"
            "ai-accelerated"
          ];
          machine = {
            boot.mode = "uefi";
          };
```

也就是删除旧的：

```nix
            nvidia.enable = true;
```

- [ ] **步骤 4：重新运行 AI 叠加检查并确认通过**

再次运行步骤 1 的三条检查构建命令。

预期：PASS。

- `example-intel-ai-workstation-gpu` 应确认 `openvino` 和 `intel-compute-runtime` 已进入系统包。
- `example-amd-ai-workstation-gpu` 应确认 `hardware.amdgpu.opencl.enable = true` 且包含 `rocminfo`。
- `example-gpu-workstation-ai-layering` 应确认 `gpu-nvidia` 仍提供专有驱动，`ai-accelerated` 额外提供 `cudatoolkit` 和 `hardware.nvidia-container-toolkit.enable = true`。

- [ ] **步骤 5：显式验证“没有 GPU 厂商 role 时，ai-accelerated 必须失败”**

运行：

```bash
nix eval --impure --expr '
let
  flake = builtins.getFlake (toString ./.);
  host = flake.lib.mkHost {
    hostname = "ai-without-gpu";
    system = "x86_64-linux";
    user = {
      name = "example";
      fullName = "Example User";
      email = "example@example.com";
      sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEexampleexampleexampleexampleexample";
    };
    profiles = [ "workstation-base" ];
    roles = [ "ai-accelerated" ];
    machine.boot.mode = "uefi";
    extraModules = [
      {
        fileSystems."/" = {
          device = "none";
          fsType = "tmpfs";
        };
      }
    ];
  };
in host.config.system.build.toplevel.drvPath
'
```

预期：FAIL，错误信息必须包含：

```text
ai-accelerated 需要至少一个 GPU 厂商 role；请同时启用 gpu-intel、gpu-amd 或 gpu-nvidia。
```

---

### 任务 5：格式化并完成全量验证

**文件：**
- 验证：本次变更涉及的所有 Nix 文件

- [ ] **步骤 1：运行格式化**

运行：

```bash
nix fmt
```

预期：PASS，所有 Nix 文件完成格式化，不出现语法错误。

- [ ] **步骤 2：先跑一轮聚焦的 GPU 检查**

运行：

```bash
nix build \
  .#checks.x86_64-linux.example-workstation-graphics-base \
  .#checks.x86_64-linux.example-intel-workstation-gpu \
  .#checks.x86_64-linux.example-amd-workstation-gpu \
  .#checks.x86_64-linux.example-intel-ai-workstation-gpu \
  .#checks.x86_64-linux.example-amd-ai-workstation-gpu \
  .#checks.x86_64-linux.example-gpu-workstation-ai-layering
```

预期：PASS，所有新增 GPU 相关检查全部通过。

- [ ] **步骤 3：运行完整回归检查**

运行：

```bash
nix flake check
```

预期：PASS，现有 `ssh-agent`、Plasma、WSL/server/workstation 等其他 eval checks 继续通过，说明这次 GPU 分层改造没有污染现有平台能力。

---

## 自检结论

- spec 中要求的四个核心结果都已覆盖到任务：`workstation-base` 图形基线、GPU 厂商 role、`platform.machine.gpu.<vendor>.enable` 命名空间迁移、`ai-accelerated` 按厂商叠加运行时。
- 没有保留 `TBD`、`TODO`、"稍后处理" 这类占位描述；每个任务都给出了具体文件、代码片段和验证命令。
- 所有新名称保持一致：`gpu-intel` / `gpu-amd` / `gpu-nvidia` role，`platform.machine.gpu.<vendor>.enable` 选项，`example-*-gpu` / `example-*-ai-workstation-gpu` 检查名。

## 完成标准

- `workstation-base` 默认具备 `hardware.graphics.enable = true` 和 `hardware.graphics.enable32Bit = true`。
- 仓库能解析并组合 `gpu-intel`、`gpu-amd`、`gpu-nvidia` 三个新 role。
- 旧的 `platform.machine.nvidia.enable` 已从仓库实现路径中移除。
- `gpu-nvidia` 不再隐式拉入 CUDA/toolkit；这些能力只在 `ai-accelerated` 存在时叠加。
- `gpu-amd + ai-accelerated` 和 `gpu-intel + ai-accelerated` 都有明确实现和回归验证。
- `example/my-host/flake.nix` 已迁移到新分层。
- `nix fmt`、聚焦 GPU checks、`nix flake check` 全部通过。
