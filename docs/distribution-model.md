# Distribution Model: Vendor-Hosted Repository

This document explains why FlagOS packages live in a vendor-hosted
repository (this one) rather than being submitted to Debian / Fedora /
Ubuntu main archives — and shows the well-established precedent.

## TL;DR

- We ship from `flagos-ai.github.io/flagos-packaging` (Pages metadata
  + Releases binaries), users add our `.list` / `.repo` and run
  `apt install` / `dnf install` like any other package.
- This is the same model **Docker CE, NVIDIA CUDA, Microsoft Edge,
  Google Chrome, PostgreSQL official, and HashiCorp** all use.
- It's not "second-class" packaging — it's the standard pattern for
  software that has version pinning, bundled dependencies, vendor
  release cadence, or proprietary components, none of which fit a
  general-purpose distro archive's policies.

## Why Docker CE isn't in Fedora main

Docker Inc. ships Docker CE from their own YUM repo:

```
https://download.docker.com/linux/fedora/docker-ce.repo
```

Fedora's main archive instead carries `moby-engine` (the FOSS upstream
the same code is built from). Reasons Docker CE stays vendor-hosted:

- **No duplication of what's in main**: Fedora already has
  `moby-engine`; adding Docker CE would be the same code with Docker
  Inc. branding, against Fedora's "one canonical version" principle.
- **Bundled dependencies**: Docker CE includes specific pinned
  versions of `containerd` and `runc`. Fedora packages those
  separately and prefers shared-library use.
- **Release cadence mismatch**: Docker's stable channel ships at its
  own pace; Fedora releases freeze for stable updates.

User experience is identical to a main-archive package:

```sh
dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
dnf install docker-ce
```

## Why FlagOS uses the same model

FlagOS packages have several properties that mirror Docker CE's:

| Property | Docker CE | FlagOS (e.g. FlagTree) |
|----------|-----------|------------------------|
| Bundled dependencies | containerd, runc | LLVM, pybind11, NVIDIA ptxas+cuobjdump |
| Proprietary components | none | NVIDIA ptxas+cuobjdump (CUDA EULA) |
| Tight version pinning | yes | yes (Triton tracks LLVM commit-by-commit) |
| Distinct release cadence | yes | yes (per-component upstreams) |
| Single-vendor curation | yes | yes |

Any one of these would be enough to keep us out of Debian / Fedora
main; together they make a vendor-hosted repo the natural fit.

## Other established vendor repos

| Vendor | URL pattern | Reason for vendor-host |
|--------|--------------|--------------------------|
| Docker | download.docker.com/linux/fedora | Bundled deps, version pinning |
| NVIDIA CUDA | developer.download.nvidia.com/compute/cuda/repos/ | Proprietary, EULA |
| Microsoft Edge | packages.microsoft.com/yumrepos/edge/ | Proprietary |
| Google Chrome | dl.google.com/linux/chrome/rpm/stable/ | Proprietary |
| PostgreSQL | yum.postgresql.org | Multiple parallel versions |
| HashiCorp (Terraform, Vault) | rpm.releases.hashicorp.com | Vendor release cadence |
| MongoDB | repo.mongodb.org | Curated SSPL releases |
| Elasticsearch | artifacts.elastic.co/packages/ | Proprietary X-Pack components |

## What this means for FlagOS packaging policy

1. **Don't aim for Debian / Fedora main** — that's a different
   product. Aim for a clean vendor repo that interoperates with
   `apt` / `dnf` standardly.
2. **Bundled libraries are acceptable** as long as their licenses
   allow redistribution. Document each one in `debian/copyright` and
   the RPM `%license` block. We've done this for FlagTree; FlagGems
   gets the same treatment when its build works.
3. **Proprietary EULA components are acceptable** — NVIDIA's CUDA
   EULA explicitly allows redistribution of `ptxas` and `cuobjdump`
   alongside applications that use them. We honor this with attribution.
4. **Future "split for main" work is optional, not required** — if
   downstream Debian / Fedora maintainers want a main-archive variant,
   they can fork and unbundle. That's a downstream choice; our job is
   to ship a working vendor repo first.
5. **GPG-sign everything** — vendor repos are GPG-signed with a
   well-known public key (Docker's, NVIDIA's, ours). Users add the
   key once at repo setup; it gates the trust chain.

## End-user install command (the goal)

```sh
# Ubuntu / Debian
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://flagos-ai.github.io/flagos-packaging/pubkey.gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/flagos.gpg
echo "deb [signed-by=/etc/apt/keyrings/flagos.gpg] \
  https://flagos-ai.github.io/flagos-packaging/apt stable main" | \
  sudo tee /etc/apt/sources.list.d/flagos.list
sudo apt update
sudo apt install python3-flagtree-nvidia

# Fedora / Rocky / OpenEuler
sudo dnf config-manager addrepo \
  --from-repofile=https://flagos-ai.github.io/flagos-packaging/flagos.repo
sudo dnf install python3-flagtree-nvidia
```

That's exactly the Docker CE / NVIDIA CUDA install flow, adapted to
the FlagOS namespace.
