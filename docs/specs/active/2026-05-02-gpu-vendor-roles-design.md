# GPU 厂商 role 与 AI 加速分层设计

## 背景

当前仓库的工作站图形能力分层还不完整：

- `profiles/workstation-base.nix` 只声明工作站形态、桌面、电源和亮度等默认值，没有统一启用通用图形栈。
- `modules/nixos/hardware/workstation.nix` 目前只负责固件、CPU 微码、电源与亮度工具，没有承担工作站通用图形基线。
- 仓库里只有 `modules/nixos/hardware/nvidia.nix` 这一份厂商专用 GPU 模块，`Intel` 和 `AMD` 还没有对应的图形/视频加速落点。
- `roles/ai-accelerated.nix` 当前直接把 `platform.machine.nvidia.enable = true` 作为默认值，语义上把“这台机器有 NVIDIA GPU 基础能力”和“这台机器需要 AI/CUDA 运行时”混在了一起。

用户已经确认新的分层目标：

- `workstation-base` 负责所有工作站共享的图形基础能力。
- `Intel`、`AMD`、`NVIDIA` 的专用能力通过 role 打开。
- `ai-accelerated` 不再代表某个单一厂商，而是在已经启用某个 GPU 厂商 role 的前提下，继续叠加该厂商的 AI/计算运行时，例如 `CUDA`、`ROCm`、`OpenVINO`。
- 一台机器允许同时启用多个 GPU 厂商 role，以表达混合显卡能力。

## 用户已确认的边界

- `workstation-base` 需要包含通用图形基线，而不是只做纯文本桌面开关。
- `workstation-base` 需要包含 32 位图形兼容，以覆盖 `Steam`、`Wine`、`Proton` 这类场景。
- 厂商专用能力通过 role 开启，而不是直接塞回 `workstation-base`。
- `ai-accelerated` 是叠加层：只有在已经选择对应厂商 role 后，才继续引入该厂商的 AI/计算运行时。
- 允许同一主机同时启用多个 GPU 厂商 role。

## 目标

- 所有使用 `workstation-base` 的非 WSL 工作站默认具备通用图形栈、Mesa 与 32 位图形兼容能力。
- 新增 `gpu-intel`、`gpu-amd`、`gpu-nvidia` 三个 role，用于表达厂商基础 GPU 能力。
- 将 GPU 厂商能力的控制入口统一到 `platform.machine.gpu.<vendor>.enable` 命名空间。
- 为 `Intel`、`AMD`、`NVIDIA` 分别提供独立的 NixOS 硬件模块，承载各自的基础图形/视频/驱动能力。
- 将 `ai-accelerated` 重构为条件叠加层：根据已启用的 GPU 厂商 role，分别叠加 `CUDA`、`ROCm`、`OpenVINO/oneAPI` 相关运行时。
- 保持 `profile` 负责“机器基线”，`role` 负责“能力组合”，`module` 负责“具体系统落地”的现有平台分层。

## 非目标

- 不在第一版中实现混合显卡下的 `PRIME sync/offload`、总线 ID 自动发现或多 GPU 调度策略。
- 不在第一版中添加 `Nouveau`、`RADV` 调优开关、超频、风扇控制、GPU 监控仪表盘等高级特性。
- 不在第一版中支持按具体显卡代际自动判断“该装 `intel-media-driver` 还是 `intel-vaapi-driver`”。第一版采用面向现代桌面机器的固定默认组合。
- 不做向后兼容别名，例如同时长期保留 `platform.machine.nvidia.enable` 与 `platform.machine.gpu.nvidia.enable` 两套入口。仓库内调用点统一迁移到新命名空间。
- 不为每个 AI 框架预装完整开发环境，例如完整 PyTorch/TensorFlow 栈；第一版只提供底层运行时和必要工具包落点。
- 不把 Steam、Wine、容器镜像、模型服务或开发工具链塞进 GPU 厂商基础 role。

## 决策摘要

本设计采用以下固定决策：

- `workstation-base` 的通用图形基线仍由 `modules/nixos/hardware/workstation.nix` 落地，而不是把系统选项直接写进 profile。
- 新增 `platform.machine.gpu.intel.enable`、`platform.machine.gpu.amd.enable`、`platform.machine.gpu.nvidia.enable` 三个布尔选项。
- 新增 `gpu-intel`、`gpu-amd`、`gpu-nvidia` 三个 role；这些 role 只负责打开对应 GPU 厂商基础能力开关。
- `modules/nixos/hardware/nvidia.nix` 迁移到新命名空间下工作；同时新增 `modules/nixos/hardware/intel.nix` 与 `modules/nixos/hardware/amd.nix`。
- Intel 基础 role 第一版固定添加 `intel-media-driver`、`intel-vaapi-driver`、`vpl-gpu-rt` 作为视频加速闭包；Intel 图形计算/AI 运行时留给 `ai-accelerated`。
- AMD 基础 role 第一版不额外引入 `ROCm/OpenCL` 包，继续依赖 Mesa 默认图形栈，并仅补充 `amdgpu` 的启动期/驱动侧基础配置；`ROCm/OpenCL` 留给 `ai-accelerated`。
- `ai-accelerated` 不再直接选择某个厂商，而是根据 `platform.machine.gpu.*.enable` 条件叠加对应 AI/计算运行时。
- GPU 厂商 role 允许多选，不在断言层禁止组合；仅对明显冲突或无意义的情形保留约束，例如 `WSL` 不能启用 `gpu-nvidia` 这一类已有语义约束需要同步更新到新命名空间。

## 任务规模判断

该任务预计至少修改以下文件：

- `modules/shared/options.nix`
- `modules/nixos/default.nix`
- `modules/nixos/core/assertions.nix`
- `modules/nixos/hardware/workstation.nix`
- `modules/nixos/hardware/nvidia.nix`
- `roles/ai-accelerated.nix`
- `roles/default.nix`
- `example/my-host/flake.nix`
- `lib/platform/checks.nix`

同时需要新增：

- `modules/nixos/hardware/intel.nix`
- `modules/nixos/hardware/amd.nix`
- `roles/gpu-intel.nix`
- `roles/gpu-amd.nix`
- `roles/gpu-nvidia.nix`

整体明显超过 3 个文件，属于大任务，应先完成 spec，再进入实施计划。

## 分层设计

### `workstation-base` 的职责

`workstation-base` 继续表达“这是物理工作站的默认基线”，不直接承担厂商身份。它通过现有 `modules/nixos/hardware/workstation.nix` 提供所有工作站共享的图形能力，包括：

- `hardware.enableRedistributableFirmware = true`
- `hardware.graphics.enable = true`
- `hardware.graphics.enable32Bit = true`
- 基于 Mesa 的通用桌面 3D 图形能力

这样所有 `workstation-base` 主机都会有一套统一的桌面图形基础能力，而更具体的厂商能力继续通过 role 叠加。

### GPU 厂商 role 的职责

新增三个 role：

- `gpu-intel`
- `gpu-amd`
- `gpu-nvidia`

这些 role 的职责只有一件事：声明“当前主机具备该厂商 GPU 的基础能力”。它们本身不直接写一大段系统配置，而是把对应的 `platform.machine.gpu.<vendor>.enable` 设为 `true`。

这样做的原因：

- role 语义保持稳定，表达的是“能力组合”，而不是实现细节。
- 底层硬件实现仍留在 `modules/nixos/hardware/*.nix`，符合仓库当前架构。
- `ai-accelerated` 可以只根据平台选项判断，不需要反向解析 role 名称。

### `ai-accelerated` 的职责

`ai-accelerated` 调整为“AI/计算运行时叠加层”，不再等价于 `NVIDIA`。其行为改为：

- 如果启用了 `platform.machine.gpu.nvidia.enable`，则叠加 `CUDA` 与 `nvidia-container-toolkit` 等 NVIDIA 计算运行时。
- 如果启用了 `platform.machine.gpu.amd.enable`，则叠加 `ROCm` / `OpenCL` 相关运行时与诊断工具。
- 如果启用了 `platform.machine.gpu.intel.enable`，则叠加 `OpenVINO` / `oneAPI` 图形计算运行时与相关工具。

如果某台机器启用了 `ai-accelerated`，但没有启用任何 GPU 厂商 role，第一版应在评估期直接报错，而不是静默无效。这样可以避免 role 语义漂移成“也许以后会有 GPU”。

## 平台选项设计

### 新增选项

在 `modules/shared/options.nix` 的 `platform.machine` 下新增：

- `platform.machine.gpu.intel.enable`: `bool`，默认 `false`，表示是否启用 Intel GPU 基础能力。
- `platform.machine.gpu.amd.enable`: `bool`，默认 `false`，表示是否启用 AMD GPU 基础能力。
- `platform.machine.gpu.nvidia.enable`: `bool`，默认 `false`，表示是否启用 NVIDIA GPU 基础能力。

描述文字应明确：

- 这些选项表达的是“基础图形/视频/驱动能力”，不是完整开发栈。
- AI/计算运行时由 `ai-accelerated` 这类 role 继续叠加。

### 旧选项迁移

现有 `platform.machine.nvidia.enable` 需要从 `modules/shared/options.nix` 中删除，并把所有仓库内引用迁移到 `platform.machine.gpu.nvidia.enable`。迁移范围至少包括：

- `modules/nixos/core/assertions.nix`
- `modules/nixos/hardware/nvidia.nix`
- `roles/ai-accelerated.nix`
- `example/my-host/flake.nix`
- `lib/platform/checks.nix`

第一版不保留兼容别名，因为这会把后续逻辑继续绑在旧命名上，增加条件分支和维护成本。

## NixOS 模块设计

### `modules/nixos/hardware/workstation.nix`

在保留固件、CPU 微码、电源和亮度逻辑的基础上，增加工作站共享图形基线：

- 使用 `lib.mkDefault` 开启 `hardware.graphics.enable = true`
- 使用 `lib.mkDefault` 开启 `hardware.graphics.enable32Bit = true`

这里不设置 `services.xserver.videoDrivers`，也不写厂商专有包。该模块只负责跨厂商通用基线。

### `modules/nixos/hardware/intel.nix`

新模块在 `platform.machine.gpu.intel.enable = true` 时生效。第一版基础能力包括：

- 向 `hardware.graphics.extraPackages` 固定添加 `intel-media-driver`、`intel-vaapi-driver`、`vpl-gpu-rt`
- 不在基础 role 中引入 `intel-compute-runtime`、`OpenVINO` 或其他 oneAPI 图形计算运行时，这些统一留给 `ai-accelerated`

第一版不引入总代际探测逻辑，也不自动切换老旧 Intel GPU 的更细分驱动策略。

### `modules/nixos/hardware/amd.nix`

新模块在 `platform.machine.gpu.amd.enable = true` 时生效。第一版基础能力包括：

- 依赖 `hardware.graphics.enable = true` 提供 AMD/Mesa 图形基线
- 需要时启用 `hardware.amdgpu.initrd.enable = true`，以提升典型 AMD 工作站的显卡驱动可用性和启动阶段体验
- 第一版不向 `hardware.graphics.extraPackages` 添加 AMD 专用包，因为 AMD 的桌面 3D / Vulkan / 视频加速基线继续依赖 Mesa 默认驱动栈；`ROCm/OpenCL` 明确留给 `ai-accelerated`

第一版不处理 `legacySupport`、超频和特定代际 quirks。

### `modules/nixos/hardware/nvidia.nix`

现有模块迁移到 `platform.machine.gpu.nvidia.enable = true` 条件下工作。基础职责包括：

- 设置 `services.xserver.videoDrivers = [ "nvidia" ]`
- 确保 `hardware.graphics.enable = true`
- 确保 `hardware.graphics.enable32Bit = true`
- 配置 `hardware.nvidia` 基础驱动选项

与当前实现相比，`CUDA` 和 `nvidia-container-toolkit` 不再默认属于“厂商基础能力”，而是迁移到 `ai-accelerated` 的 NVIDIA 条件分支中。这样 `gpu-nvidia` 可以表达“我要专有驱动的桌面/图形能力”，而不会自动把整套 AI 计算环境带进所有机器。

### `modules/nixos/default.nix`

需要导入新增的 `./hardware/intel.nix` 与 `./hardware/amd.nix`，让 GPU 厂商 role 打开的平台选项能够实际落地。

## Role 设计

### `roles/gpu-intel.nix`

仅设置：

```nix
platform.machine.gpu.intel.enable = lib.mkDefault true;
```

### `roles/gpu-amd.nix`

仅设置：

```nix
platform.machine.gpu.amd.enable = lib.mkDefault true;
```

### `roles/gpu-nvidia.nix`

仅设置：

```nix
platform.machine.gpu.nvidia.enable = lib.mkDefault true;
```

### `roles/default.nix`

新增上述三个 role 的导出，并保留现有其他 role。

## `ai-accelerated` 设计

### 基础原则

`ai-accelerated` 只负责“已有 GPU 厂商能力之上的 AI/计算运行时”，不负责表达某台机器是否拥有该厂商 GPU。

### 条件叠加行为

在 `roles/ai-accelerated.nix` 中，根据 `config.platform.machine.gpu.*.enable` 条件叠加：

- NVIDIA：`cudatoolkit`、`hardware.nvidia-container-toolkit.enable = true`，以及确有必要的辅助驱动包
- AMD：启用 `hardware.amdgpu.opencl.enable = true`，并安装最小诊断工具，例如 `rocmPackages.rocminfo`
- Intel：安装 `openvino` 与 `intel-compute-runtime`，形成最小 Intel AI / 图形计算运行时闭包

第一版优先提供“运行时与诊断工具”闭包，不在 `ai-accelerated` 中直接预装大体量开发框架。

### 断言要求

如果启用了 `ai-accelerated`，但 `platform.machine.gpu.intel.enable`、`amd.enable`、`nvidia.enable` 全部为 `false`，则应在评估期失败，并给出明确错误：`ai-accelerated` 需要至少一个 GPU 厂商 role。

## 断言与错误处理

需要同步更新现有断言：

- `WSL` 主机不能启用 `platform.machine.gpu.nvidia.enable`
- 与旧 `platform.machine.nvidia.enable` 相关的错误信息全部迁移到新命名空间

同时新增断言：

- `ai-accelerated` 需要至少一个 GPU 厂商能力开关为 `true`

第一版不禁止 `gpu-intel + gpu-nvidia`、`gpu-amd + gpu-nvidia`、`gpu-intel + gpu-amd` 这类多厂商组合，因为用户已明确要求支持混合显卡表达能力。

## 示例与检查更新

### `example/my-host/flake.nix`

当前 `workstation` 示例主机：

- 现在通过 `machine.nvidia.enable = true` 表达 NVIDIA 能力
- 同时启用了 `ai-accelerated`

迁移后应改为：

- `roles` 中加入 `gpu-nvidia`
- 删除旧的 `machine.nvidia.enable = true`
- 保留 `ai-accelerated`，使其在已有 NVIDIA role 的基础上继续叠加 `CUDA`

这样示例主机更清楚地表达了“GPU 厂商能力”和“AI 计算能力”的分层关系。

### `lib/platform/checks.nix`

需要同步更新所有对 `platform.machine.nvidia.enable` 的断言或示例检查，使其与新 role / 新选项命名一致。若现有 checks 中已有 GPU 工作站相关样例，应继续覆盖：

- `workstation-base` 的通用图形基线
- `gpu-nvidia` 的专有驱动能力
- `ai-accelerated` 在 NVIDIA 主机上的 CUDA 叠加

如有必要，也应增加或调整针对 `gpu-intel`、`gpu-amd` 的评估覆盖，以避免新增 role 长期无人验证。

## 文件边界

### `profiles/workstation-base.nix`

保持现有职责，不新增厂商身份相关配置。该 profile 仍只设置工作站形态与桌面等平台默认值。

### `modules/shared/options.nix`

新增 `platform.machine.gpu` 选项组，并删除旧的扁平 `platform.machine.nvidia.enable` 选项。

### `modules/nixos/hardware/*.nix`

每个文件只承载一个 GPU 厂商或一个工作站共享硬件基线，避免把所有图形逻辑重新塞回单文件。

### `roles/*.nix`

GPU 厂商 role 只设置平台选项默认值；`ai-accelerated` 负责 AI/计算运行时叠加，不再表达厂商身份。

## 验证计划

实现完成后至少运行：

```bash
nix fmt
nix flake check
```

验证重点：

- `workstation-base` 主机默认具备 `hardware.graphics.enable = true` 与 `enable32Bit = true`
- `gpu-intel`、`gpu-amd`、`gpu-nvidia` 三个 role 均可被 `mkHost` 正确解析
- `gpu-nvidia + ai-accelerated` 的示例主机评估成功，并保留 CUDA 能力
- `ai-accelerated` 在没有任何 GPU 厂商 role 时会按预期失败
- 现有 WSL 断言仍然生效，防止 `WSL` 主机误配 `gpu-nvidia`

## 验收标准

- `workstation-base` 不再缺少通用图形栈与 32 位兼容。
- 仓库中存在 `gpu-intel`、`gpu-amd`、`gpu-nvidia` 三个可组合 role。
- GPU 厂商能力的入口统一到 `platform.machine.gpu.<vendor>.enable`。
- `NVIDIA` 基础驱动能力与 `CUDA`/AI 运行时成功解耦。
- `ai-accelerated` 能根据厂商 role 条件叠加对应 AI 运行时，而不是默认等价于 `NVIDIA`。
- 示例主机与 checks 已迁移到新分层，不再引用旧的 `platform.machine.nvidia.enable`。
