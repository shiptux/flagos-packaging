# Installing FlagOS packages

[[中文版](./install_cn.md) | English]

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

Replace package names by the variant you actually want — see the
[component matrix](https://github.com/flagos-ai/flagos-packaging/blob/main/components/)
for the full list.

## Fedora / Rocky / OpenEuler / OpenCloudOS / OpenAnolis

```sh
sudo dnf config-manager addrepo \
  --from-repofile=https://flagos-ai.github.io/flagos-packaging/flagos.repo

sudo dnf install libflagcx-nvidia python3-flagscale python3-flagtree-nvidia
```

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
