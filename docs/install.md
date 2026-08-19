# Installing FlagOS packages

[[中文版](./install_cn.md) | English]

> **Where these commands point.** During the sandbox phase the APT /
> YUM endpoint is `https://shiptux.github.io/flagos-packaging`
> (this repository's GitHub Pages). The production endpoint will move
> to `https://flagos-ai.github.io/flagos-packaging` after upstream
> review of the per-component packaging PRs; at that time these
> commands and the `flagos-<distro>.repo` files will be updated in
> lockstep.

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

Replace package names by the variant you actually want — see the
[component matrix](https://github.com/shiptux/flagos-packaging/blob/main/components/)
for the full list, and
[`docs/compatibility-status.md`](./compatibility-status.md) for which
packages currently work on which distro.

## Fedora / Rocky / OpenEuler / OpenCloudOS / OpenAnolis

Download the `.repo` file matching your distro (the baseurl is
per-distro; no dnf plugin is needed and the command works on both
dnf4 and dnf5):

```sh
sudo curl -fsSL https://shiptux.github.io/flagos-packaging/flagos-<distro>.repo \
  -o /etc/yum.repos.d/flagos.repo

sudo dnf makecache -y   # -y imports the FlagOS signing key
sudo dnf install libflagcx-nvidia python3-flagscale python3-flagtree-nvidia
```

| Distro | `<distro>` slug |
|--------|-----------------|
| Fedora 43 | `fedora43` |
| RHEL/Rocky/Alma 8 | `el8` |
| RHEL/Rocky/Alma 9 | `el9` |
| openEuler 24.03 LTS | `openeuler2403` |
| OpenCloudOS 9 | `opencloudos9` |
| OpenAnolis 8 | `openanolis8` |

## Hardware prerequisites

The packages are runtime-aware but not runtime-bundled — you must have
the right vendor SDK installed before installing the matching package:

| Package suffix | Required runtime |
|----------------|------------------|
| `-nvidia`      | CUDA toolkit 12+ and NVIDIA driver |
| `-metax`       | maca\_sdk from MetaX |
| `-ascend`      | CANN toolkit |
| `-mthreads`    | MUSA toolkit |

`python3-flagtree-*` additionally requires `python3-torch` (pulled
automatically by `apt`/`dnf` via Recommends/Requires).

## Removing

```sh
# Ubuntu/Debian
sudo apt purge 'libflagcx-*' 'python3-flag*'
sudo rm /etc/apt/sources.list.d/flagos.list /etc/apt/keyrings/flagos.gpg

# Fedora etc
sudo dnf remove 'libflagcx-*' 'python3-flag*'
sudo rm /etc/yum.repos.d/flagos.repo
```
