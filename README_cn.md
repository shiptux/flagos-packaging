# flagos-packaging

[[English](./README.md) | 中文]

FlagOS 软件栈的统一发布仓库 —— 从各个上游组件仓库（FlagCX、FlagScale、
FlagTree 等）拉取构建产物，使用一把共享 GPG 密钥签名，生成 APT 与 YUM
仓库元数据，最终通过 GitHub Pages（元数据）+ GitHub Releases（二进制）
发布，让用户可以直接通过 `apt install` / `dnf install` 安装。

## 架构

```
上游仓库 (FlagCX, FlagScale, FlagTree, ...)
  └─ packaging/{debian,rpm}/ + build-*.yml
        └─ artifact (.deb, .rpm)
              ↓
flagos-packaging（本仓库）
  1. 通过 dawidd6/action-download-artifact 拉取产物
  2. GPG 签名（debsigs / rpmsign）
  3. 构建 APT 索引（reprepro）—— Filename 改写指向 Releases URL
  4. 构建 YUM 索引（createrepo_c --baseurl）
  5. 推送 gh-pages 分支（仅元数据，几 MB）
  6. 上传二进制到 GitHub Releases（每 tag 单独一份，无总量上限）
              ↓
最终用户
  └─ apt install libflagcx-nvidia python3-flagtree-nvidia ...
```

为何是 Pages + Releases 双层？Pages 提供稳定的 HTTPS URL 用来托管元数据
（Packages.gz、Release、repodata），Releases 提供按 tag 切分的二进制 URL
（每个文件最大 2 GB，总量无限）；元数据中的 `Filename` 字段指向 Releases。
APT 与 DNF 原生支持这种 "元数据这边、二进制那边" 的拆分，无需用户额外配置。

## 仓库结构

```
flagos-packaging/
├── components/         # 每个上游组件一个 YAML 清单
├── config/             # GPG 公钥、reprepro distributions、YUM .repo 模板
├── scripts/            # 收集 / 签名 / 构建索引 / 发布脚本
├── docs/               # 用户安装指南（中英）+ 维护者文档
├── tests/              # 端到端安装验证
├── .github/workflows/  # publish.yml、refresh-metadata.yml、test-install.yml
└── README.md, README_cn.md, LICENSE, .gitignore
```

## 状态

W1 工作进行中。发布流程的细节参见 `docs/release-process.md`。

## 许可证

Apache 2.0。详见 LICENSE 文件。
