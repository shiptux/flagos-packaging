# FlagOS on openEuler 24.03 · 进展同步（社区版）

> 截至 2026-07-31。本文用于向 openEuler 社区同步 FlagOS 打包适配进展，并就后续协作点交流。

## 一、一句话进展

FlagOS 在 **openEuler 24.03 已可安装、可测试**：用户三条命令即可从公开源装上 openEuler 原生构建的 FlagOS 软件包（cp311），Triton 编译链已在无卡环境下完整验证到 cubin（sm_80）。目前正推进 GPU 真机验证与更广的包覆盖，欢迎社区一起把这条路走通。

## 二、已完成

- **openEuler 原生打包与发布链路**：软件包按 openEuler 24.03 原生构建（非 Fedora 移植副本），发布源、`.repo` 配置、产物收集均已就位，可从公开源直接安装。
- **上游融入进行中**：FlagSparse 打包已合并进上游主线并持续产出 openEuler 产物；FlagTree、FlagAttention 的打包适配已通过 CI，正在合入。
- **端到端安装已实测**：全新 openEuler 24.03 容器按文档流程安装 flagsparse / flag-attention / flagtree，导入检查全部通过；编译链（`ttir → ttgir → llir → ptx → cubin`）在无 GPU 环境下完整跑通。

## 三、当前包覆盖（openEuler 源内）

| 包 | 状态 |
|----|------|
| python3-flagsparse | ✅ 稳定（已融入上游主线） |
| python3-flagtree-nvidia | ✅ 可安装 |
| python3-flag-attention | ✅ 可安装（随上游 PR 合入后转为长期稳定） |
| 其余 Python 包 | 🔜 模板已就绪，逐步展开 |
| C++ 组件（flagcx / libtriton-jit 等） | 🔜 待 openEuler 上的 CUDA 工具链方案明确后开展 |

## 四、测试环境现状（重点，也是协作邀请）

**目前我们的 GPU 测试资源以 NVIDIA（A100）为主**，现阶段的实机验证也主要覆盖 NVIDIA/CUDA 内容。

需要如实说明验证边界，避免误解：
- 这台 A100 测试机为 **Ubuntu 环境**，上述 NVIDIA/CUDA 的实机验证（安装、导入、算子数值正确性等）目前是在 **Debian/deb 链路**上完成的，已较为充分。
- **openEuler / RPM 链路**这边，已完成的是端到端安装与编译链到 cubin 的验证（无 GPU 环境即可）；**openEuler 上的 GPU 真机执行冒烟尚在推进**——主要是在现有平台上启用 openEuler 镜像的流程较为繁琐，我们已尝试了几种方案、目前接近可行，预计不久即可补齐这一环（这部分我们自行推进，暂不需额外协助）。

关于协作，我们更希望在**国产化及多后端 GPU 环境**上得到社区支持：

- FlagOS 面向多种硬件后端，而我们手上目前主要是 NVIDIA 环境，暂缺**国产 GPU 等其他后端**的测试条件。**若社区伙伴能提供相应环境，或牵线对应芯片厂商，我们非常欢迎**——这能帮助我们把 openEuler 上的多后端覆盖尽快推进，也更契合国产化生态共建的方向。

## 五、希望与社区探讨的方向

1. **官方入仓路径**：计划挂靠 sig-AI 提交软件包引入申请。一个前置条件是上游各组件提供正式 release tag（src-openeuler 的 spec 需指向可下载的发布 tarball），我们会同步向上游推进，也想听取社区在入仓流程上的建议。
2. **openEuler 上的 CUDA 工具链**：openEuler 官方 CUDA 镜像目前为 CUDA 13，而部分 C++ 组件依赖 CUDA 12 运行时。这一层如何在 openEuler 上对齐，是 C++ 组件展开的前提，期待与社区共同确认可行方案。
3. **依赖缺口**：个别组件依赖的少数 Python 库（如 typer / hydra-core）在 openEuler 源内暂缺，是否随包引入或走用户仓（EUR），也想听社区意见。

## 六、后续计划

- **近期**：完成 openEuler + GPU 真机冒烟；将现有打包模板复制到更多 Python 组件。
- **中期**：torch 相关组件批量适配；明确 CUDA 工具链方案后开展 C++ 组件；向 EUR 提交试构建作为入仓预检。
- **长期**：完成官方入仓申请与依赖链、许可证梳理。

## 七、快速上手

```sh
# openEuler 24.03 上安装：
sudo curl -fsSL https://shiptux.github.io/flagos-packaging/flagos-openeuler2403.repo \
  -o /etc/yum.repos.d/flagos.repo
sudo dnf makecache -y
sudo dnf install python3-flagtree-nvidia python3-flagsparse
```

---

*欢迎社区伙伴就上述任一方向交流；测试环境、入仓流程、工具链方案等方面的协助，我们都非常期待。*
