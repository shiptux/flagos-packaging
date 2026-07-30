# FlagOS on openEuler 24.03 — 现状、进展与计划

> 截至 2026-07-31。工作流详细记录见
> `docs/verification/openeuler-2403/README.md`（发现 F1–F10 与逐项验证日志），
> 上游 PR 状态见 `docs/upstream-pr-tracker.md`（第 14–16 行）。

## 一句话现状

**"本月内 openEuler 24.03 可安装、可测试"的目标在软件层面已达成**：
用户按文档三条命令即可从公开源安装 FlagOS 包（cp311 原生构建），
编译链已验证到 cubin；剩余的 GPU 真机冒烟被平台环境问题阻塞（非软件问题）。

## 已完成

### 1. 发布链路（flagos-packaging 仓库）

- **`.oe2403` 产物路由**：`rpm/openeuler2403/` 目录只发布 openEuler
  原生构建的包，不再是装不上的 Fedora 副本（`python(abi)` 不匹配）。
- **per-distro `.repo` 文件**：`flagos-<distro>.repo` baseurl 写死，
  修复了 `$releasever_short` 无法解析的问题（F1）；安装文档改为
  dnf4/dnf5 通用的 curl 方式（F2）。
- **收集侧**：components 清单的 artifact pattern 改为真正的正则
  （顺带修复了 glob-写法在 `name_is_regexp` 下的潜伏 bug），
  自动拉取上游的 `-oe2403-` 产物；补齐 flagsparse 清单。
- **apt 侧护栏**：跳过超过 gh-pages 100MB 上限的 deb（flagtree 0.6.0
  的 deb 已达 240MB），避免整个发布失败。

### 2. 上游仓库（模板：spec 能力检测 + 双发行版 CI 矩阵）

| 仓库 | PR | 状态 |
|------|----|------|
| FlagSparse | #29 | **已合并**（2026-07-15），main 持续产出 oe2403 产物 |
| FlagSparse | #36（--prefix /usr 跟进） | CI 全绿，待 review |
| FlagAttention | #35 | CI 全绿，review 意见已处理，待复看 |
| FlagTree | #794 | CI 18 项全绿 + **已 APPROVED**，待合并；同时恢复了因上游 main 历史重写而丢失的全部打包配置（F9） |

模板内容：`%pyproject_wheel` 缺失时的 pip 兜底（F4）、openEuler dist
标签补偿、spec 注释宏转义（F7）、setuptools-scm 版本兜底（F8）、
fedora43 + openeuler2403 双矩阵（Fedora 产物名不变）。

### 3. 端到端验证（全部实测通过）

- **线上安装**：全新 openEuler 24.03 容器按文档流程安装
  flagsparse / flag-attention / flagtree（89MB 二进制来自 GitHub
  Releases），导入检查全过（2026-07-23）。
- **AOT 编译冒烟**：无 GPU、无驱动环境下 `triton.compile` 完整产出
  `ttir → ttgir → llir → ptx → cubin`（sm_80），wheel 自带 ptxas
  可用——编译链风险已闭环，未覆盖面只剩驱动交互层。
- **测试镜像**：`docs/verification/openeuler-2403/gpu-smoke/` 提供
  三个 Dockerfile 变体（一次性冒烟 / 参数化 sshd 环境 / 网页后台
  专用极简版）+ 两个冒烟脚本；基镜像 `openeuler/cuda:13.0.0-oe2403lts`
  可从 Docker Hub 或 openEuler 官方 oepkgs 仓库获取。

## 当前包覆盖（openEuler 源内）

| 包 | 状态 |
|----|------|
| python3-flagsparse | ✅ 稳定（上游已合并，来源可靠） |
| python3-flagtree-nvidia（cp311） | ✅ 可装（来源是未合并 PR 的 CI 产物，有 7 天过期风险） |
| python3-flag-attention | ⚠️ 时有时无（同上；7-26 因产物过期从源里消失过一次） |
| 其余 python3 包 | ❌ 未开始 openEuler 维度（见计划） |
| C++ 包（flagcx / libtriton-jit / flagfft） | ❌ 未开始（依赖 CUDA-on-openEuler 工具链方案） |

## 已知问题 / 风险

1. **产物过期抖动**：未合并 PR 的 CI artifact 仅保留 7 天，周期性
   publish 时包会从源里消失。根治 = 合并 #35 / #794。
2. **flagtree 无 deb**：0.6.0 deb 超 100MB 被跳过；正解是 Releases
   flat-repo（未实现）。
3. **CUDA 版本沟**：openEuler 官方 CUDA 镜像只有 CUDA 13（oe2403），
   而 flagcx RPM 依赖 `libcudart.so.12`——C++ 组件重建时必须一起解决。
4. **GPU 平台适配**：受限平台（网页后台构建、sshd 检测疑似按
   Debian 系假设）导致真机冒烟未完成；镜像侧 sshd 已离线验证正常，
   已加 `service ssh start` 兼容 shim。
5. deb 侧 artifact pattern 存在与 rpm 侧同样的 glob-vs-regex
   潜伏 bug（未修，影响未知）。
6. 上游评审吞吐：13 个基础打包 PR 仍有 9 个无人 review，
   是扩大 openEuler 覆盖面的最大瓶颈。

## 计划

**近期（1-2 周）**

1. 真机 GPU 冒烟（平台 sshd 问题解决后；`GPU SMOKE PASS` 即闭环）。
2. 推动 #35 复看、#794 合并（已 APPROVED），消除产物过期抖动。
3. flag-gems 复制模板：钉版放宽（F6）+ torch 包名映射
   （openEuler 为 `python3-pytorch`，F5）；前提是其基础打包 PR 合并。

**中期（本季度）**

4. torch 系五件套（dnn/blas/audio/tensor/quantum）模板复制——
   机械工作，卡在上游基础 PR 评审。
5. flagscale：依赖 typer / hydra-core 在 openEuler 缺失，
   需拍板（文档引导 pip / 一并打包 / EUR）。
6. C++ 组件 openEuler 重建：先解决构建容器内 CUDA 12 工具链来源
   （NVIDIA rhel9 仓 / redist tarball / 跟进 cuda13 链接）。
7. spec 提交 EUR（openEuler 用户仓）试构建，作为正式入仓预检。

**长期（申请官方入仓）**

8. 挂靠 sig-AI 提软件包引入申请。**硬前置：上游各组件需要正式
   release tag**（src-openeuler 的 spec 必须指向可下载 tarball）——
   建议尽早向上游提出。
9. 依赖链梳理（不联网构建、license 复核）与维护人承诺。

## 快速上手（复制即用）

```sh
# openEuler 24.03 上安装：
sudo curl -fsSL https://shiptux.github.io/flagos-packaging/flagos-openeuler2403.repo \
  -o /etc/yum.repos.d/flagos.repo
sudo dnf makecache -y
sudo dnf install python3-flagtree-nvidia python3-flagsparse

# GPU 环境冒烟（脚本在仓库 docs/verification/openeuler-2403/gpu-smoke/）：
python3 aot_smoke.py      # 无卡即可，验证编译链
python3 gpu_smoke.py      # 需要卡，验证真实执行
```
