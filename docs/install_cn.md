# 安装 FlagOS 软件包

[[English](./install.md) | 中文]

> **关于命令里的地址。** sandbox 阶段 APT / YUM 仓库的访问入口是
> `https://shiptux.github.io/flagos-packaging`（即本仓库的 GitHub
> Pages）。等到各上游组件的 packaging PR review 通过后，生产入口会
> 切换到 `https://flagos-ai.github.io/flagos-packaging`，届时下面
> 的命令和各 `flagos-<distro>.repo` 文件会同步更新。

## Ubuntu / Debian

```sh
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://shiptux.github.io/flagos-packaging/pubkey.gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/flagos.gpg

echo "deb [signed-by=/etc/apt/keyrings/flagos.gpg] \
  https://shiptux.github.io/flagos-packaging/apt stable main" | \
  sudo tee /etc/apt/sources.list.d/flagos.list

sudo apt update
sudo apt install libflagcx-nvidia python3-flagscale python3-flagtree-nvidia
```

将包名替换为你实际需要的变体 —— 完整的组件清单见
[components/](https://github.com/shiptux/flagos-packaging/blob/main/components/)，
当前各发行版可装哪些包见
[`docs/compatibility-status.md`](./compatibility-status.md)。

## Fedora / Rocky / OpenEuler / OpenCloudOS / OpenAnolis

下载与你的发行版对应的 `.repo` 文件（baseurl 按发行版写死；不需要
任何 dnf 插件，dnf4 / dnf5 通用）：

```sh
sudo curl -fsSL https://shiptux.github.io/flagos-packaging/flagos-<distro>.repo \
  -o /etc/yum.repos.d/flagos.repo

sudo dnf makecache -y   # -y 用于导入 FlagOS 签名公钥
sudo dnf install libflagcx-nvidia python3-flagscale python3-flagtree-nvidia
```

| 发行版 | `<distro>` 取值 |
|--------|-----------------|
| Fedora 43 | `fedora43` |
| RHEL/Rocky/Alma 8 | `el8` |
| RHEL/Rocky/Alma 9 | `el9` |
| openEuler 24.03 LTS | `openeuler2403` |
| OpenCloudOS 9 | `opencloudos9` |
| OpenAnolis 8 | `openanolis8` |

## 硬件前置条件

软件包"知道"自己依赖哪些运行时，但不会捆绑安装这些运行时 —— 在安装对应
后端的包之前，需要先准备好相应的厂商 SDK：

| 包名后缀     | 所需运行时                          |
|--------------|-------------------------------------|
| `-nvidia`    | CUDA 工具包 12+ 与 NVIDIA 驱动      |
| `-metax`     | MetaX 提供的 maca\_sdk             |
| `-ascend`    | 昇腾 CANN 工具包                    |
| `-mthreads`  | 摩尔线程 MUSA 工具包                |

`python3-flagtree-*` 还依赖 `python3-torch`，由 `apt`/`dnf` 通过
Recommends/Requires 自动拉取。

## 卸载

```sh
# Ubuntu/Debian
sudo apt purge 'libflagcx-*' 'python3-flag*'
sudo rm /etc/apt/sources.list.d/flagos.list /etc/apt/keyrings/flagos.gpg

# Fedora 等
sudo dnf remove 'libflagcx-*' 'python3-flag*'
sudo rm /etc/yum.repos.d/flagos.repo
```
