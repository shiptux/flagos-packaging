# 安装 FlagOS 软件包

[[English](./install.md) | 中文]

## Ubuntu / Debian

```sh
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://flagos-ai.github.io/flagos-packaging/pubkey.gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/flagos.gpg

echo "deb [signed-by=/etc/apt/keyrings/flagos.gpg] \
  https://flagos-ai.github.io/flagos-packaging/apt stable main" | \
  sudo tee /etc/apt/sources.list.d/flagos.list

sudo apt update
sudo apt install libflagcx-nvidia python3-flagscale python3-flagtree-nvidia
```

将包名替换为你实际需要的变体 —— 完整的组件清单见
[components/](https://github.com/flagos-ai/flagos-packaging/blob/main/components/)。

## Fedora / Rocky / OpenEuler / OpenCloudOS / OpenAnolis

```sh
sudo dnf config-manager addrepo \
  --from-repofile=https://flagos-ai.github.io/flagos-packaging/flagos.repo

sudo dnf install libflagcx-nvidia python3-flagscale python3-flagtree-nvidia
```

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
