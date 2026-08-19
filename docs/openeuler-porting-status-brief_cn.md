# FlagOS on openEuler 24.03 · 进展简报

> 截至 2026-07-31。详细工程记录见 `openeuler-porting-status_cn.md`。

## 一句话结论

**"本月内 openEuler 24.03 可安装、可测试"的软件层目标已达成**——用户三条命令即可从公开源装上 FlagOS 包（openEuler 原生 cp311 构建），编译链已验证到 cubin（sm_80）。唯一未闭环项是 GPU 真机冒烟，卡在平台环境问题，非软件问题。

## 进展

- **发布链路打通**：openEuler 原生产物独立发布（不再是装不上的 Fedora 副本），per-distro 源文件、产物自动收集、大包护栏均已就位。
- **上游 PR**：
  - FlagSparse #29 **已合并**，main 持续产出 openEuler 产物
  - FlagTree #794 **已 APPROVED**，待合并（并恢复了上游历史重写丢失的全部打包配置）
  - FlagAttention #35、FlagSparse #36 CI 全绿，待评审
- **端到端实测通过**：全新 openEuler 容器按文档装 flagsparse/flag-attention/flagtree，导入全过；无卡环境下 `triton.compile` 完整产出到 cubin，编译链风险闭环。

## 当前包覆盖

| 包 | 状态 |
|----|------|
| python3-flagsparse | ✅ 稳定（上游已合并） |
| python3-flagtree-nvidia | ✅ 可装（源为未合并 PR 产物，有 7 天过期风险） |
| python3-flag-attention | ⚠️ 时有时无（同上，过期时会从源里消失） |
| 其余 Python 包 | ❌ 未开始 |
| C++ 包（flagcx/libtriton-jit/flagfft） | ❌ 未开始（阻于 CUDA-on-openEuler 工具链） |

## 主要风险

1. **产物过期抖动**：未合并 PR 的 CI 产物仅存 7 天，会周期性从源里消失 → 根治即合并 #35/#794。
2. **CUDA 版本沟**：openEuler 官方 CUDA 镜像只有 CUDA 13，而 C++ 组件依赖 CUDA 12 运行时——重建时必须一并解决。
3. **上游评审吞吐**：13 个基础打包 PR 中 9 个仍无人评审，是扩大覆盖面的**最大瓶颈**。
4. **GPU 真机冒烟**：受限于平台环境适配，尚未完成（镜像侧已离线验证正常）。

## 计划

- **近期**：完成 GPU 真机冒烟；推动 #35/#794 合并消除过期抖动；flag-gems 套用模板。
- **中期**：torch 系五件套模板化复制（机械工作，卡在上游评审）；flagscale 缺失依赖拍板；C++ 组件重建（先解决 CUDA 12 工具链来源）。
- **长期**：申请官方入仓（挂靠 sig-AI）。**硬前置：上游各组件需正式 release tag**，建议尽早向上游提出。

## 快速上手

```sh
sudo curl -fsSL https://shiptux.github.io/flagos-packaging/flagos-openeuler2403.repo \
  -o /etc/yum.repos.d/flagos.repo
sudo dnf makecache -y
sudo dnf install python3-flagtree-nvidia python3-flagsparse
```
