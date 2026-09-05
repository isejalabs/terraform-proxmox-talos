# AGENTS.md

This file provides guidance to AI coding agents (Claude Code, and others reading `AGENTS.md`) when working with code in this repository. `CLAUDE.md` is a symlink to this file.

## About

This is a `terraform`/`tofu` **module** (not a standalone deployable stack) that provisions a Kubernetes cluster on Proxmox VE using Talos Linux as the node OS. It creates Proxmox VMs, generates Talos machine configuration, bootstraps the cluster, and installs core infrastructure: Cilium (CNI), Gateway API, Proxmox CSI Plugin (storage), and Sealed Secrets.

Consumers use this as a `module "talos" { source = "..." }` block from their own root module (see the [isejalabs/homelab](https://github.com/isejalabs/homelab) repo for a real-world usage example, often wrapped with Terragrunt).

## Commands

There is no application build/test suite — this is pure Terraform/OpenTofu HCL. Standard workflow:

```sh
tofu fmt -recursive     # canonical formatting, enforced by CI (dflook/terraform-fmt)
tofu validate
tofu plan
```

- Formatting is auto-fixed on `main` by `.github/workflows/coding-style.yaml` (opens a `style: automated terraform formatting` PR) — don't hand-fix formatting-only diffs, just let `tofu fmt` run.
- `docs/module.md` is auto-generated from variable/output definitions by `terraform-docs` via `.github/workflows/terraform-docs.yaml` on push to `main` — do not hand-edit the generated table content; edit the variable `description`/`type` blocks instead and let CI regenerate it.
- No live Proxmox/Talos environment is available to actually `apply` from this sandbox — changes are validated via `fmt`/`validate`/`plan` and by reasoning about the HCL, not by standing up real infrastructure.

## Architecture

### Module composition (root `main.tf`)

The root module wires together sub-modules in dependency order:

1. **`./talos`** — creates the Talos image, Proxmox VMs, generates and applies Talos machine config, bootstraps the cluster, and produces the kubeconfig used by the `kubernetes` provider (`providers.tf`) for everything downstream.
2. **`./bootstrap/sealed-secrets`** — installs Sealed Secrets, seeded from a cert/key pair.
3. **`./bootstrap/proxmox-csi-plugin`** — installs the Proxmox CSI driver, creates the Proxmox API user/role/secret it needs.
4. **`./bootstrap/volumes`** — for `proxmox-csi`-type volumes only, fans out into `./bootstrap/volumes/proxmox-volume` (creates the Proxmox-side disk) and `./bootstrap/volumes/persistent-volume` (creates the matching Kubernetes `PersistentVolume`), joined by `volume_handle = "<cluster>/<node>/<datastore>/<filename>"`.

Root `variables.tf` is a thin passthrough/validation layer in front of the `./talos` submodule's own `variables.tf` — when changing a variable's shape, both files usually need to change together, and note the root module also **splits `volumes` into `talos_disk_volumes` (type == "disk") and `talos_volumes` (type == "directory")** before passing them down (see `main.tf`), since the `./talos` submodule has separate variables for each.

### `./talos` submodule internals

- **`image.tf`** — builds a Talos Image Factory schematic (`data.http.schematic_id`/`updated_schematic_id`, POSTing the schematic YAML), then downloads the resulting `.raw.gz` image into Proxmox per host node via `proxmox_virtual_environment_download_file`. Two parallel schematic/version pairs exist throughout this module: the "current" one (`image.version`/`schematic_path`) and the "update" one (`image.update_version`/`update_schematic_path`) — this dual-track is what makes rolling Talos OS upgrades possible (see below).
- **`virtual-machines.tf`** — creates one `proxmox_virtual_environment_vm` per node (the Talos OS disk, size 5G, booted from the downloaded image) plus a **separate, stopped "data VM"** (`-data` suffix) per node holding the EPHEMERAL disk and any `disk`-type volumes. This separation is deliberate: the Talos VM gets destroyed/recreated on OS upgrades or `update_schematic`/`update_version` changes, while the data VM (and its disks) survives untouched — see `disk_size`/`update` in `variables.tf` and the comment in `virtual-machines.tf`.
- **`config.tf`** — generates Talos machine config per node from templates in `machine-config/*.yaml.tftpl` (`common`, `control-plane`, `worker`), layering in `talos_config_patches` (global, then per-machine-type, then per-node) as additional config patches, applies it (`talos_machine_configuration_apply`), bootstraps the first control-plane node, waits on `data.talos_cluster_health`, then reads the kubeconfig. Cilium's manifest + Helm values (`cilium_config.bootstrap_manifest_path`/`values_file_path`, pointing at `talos/inline-manifests/*.yaml`) are inlined into the control-plane's machine config as `inline_manifests`, so cluster bring-up doesn't depend on a separate Helm/kubectl step post-bootstrap.
- Nodes are keyed by hostname (`var.nodes` is a `map(object(...))`); `machine_type` must be `"controlplane"` or `"worker"`.

### Talos OS upgrade model

Because the `siderolabs/terraform-provider-talos` provider doesn't support in-place OS upgrades, upgrades are done by flipping a node's `update = true` and re-`apply`ing one node at a time (control planes first), which swaps that node's boot image to `image.update_version`/`update_schematic_path` and destroys/recreates its Talos VM — the data VM is untouched so EPHEMERAL/volume data persists. See [docs/upgrade methods.md](docs/upgrade%20methods.md) for the full node-by-node procedure and rollback notes; this is the standard change process to explain when touching `image.tf`, `variables.tf`'s `nodes[].update`, or `virtual-machines.tf`'s image/disk wiring.

### Storage model

`var.volumes` (root) accepts three types, routed differently by `main.tf`/`talos/config.tf`/`bootstrap/volumes`:

| type | handled by |
|---|---|
| `disk` | `./talos` submodule → extra `disk` block on the data VM, mounted as a Talos User Volume |
| `directory` | `./talos` submodule → Talos User Volume backed by the EPHEMERAL partition (no dedicated disk) |
| `proxmox-csi` | `./bootstrap/volumes` → pre-provisioned Proxmox disk + matching Kubernetes `PersistentVolume` for the Proxmox CSI driver |

See [docs/storage.md](docs/storage.md) for the full rationale and caveats (especially around not letting terraform destroy pre-existing `proxmox-csi` volumes on cluster recreation).

## Conventions specific to this repo

- Variable `description`s and `type` blocks are the source of truth for `docs/module.md` and `docs/variables.md` (terraform-docs generated) — keep them accurate and prefer `optional(...)` with sensible defaults over adding required variables, to preserve backwards compatibility for existing consumers.
- `// @formatter:off` / `// @formatter:on` comments wrap validation conditions to prevent `tofu fmt`/IDE formatters from mangling the long `contains(...)` expressions; keep these markers when editing nearby validation blocks.
- Breaking changes to variable shapes get a corresponding entry in [UPGRADE.md](UPGRADE.md) for the affected major version, and roadmap items are tracked as checkboxes in [README.md](README.md) linked to GitHub issues, not as TODOs in code.
- Renovate (`.github/renovate.json5`) manages dependency bumps; a `# renovate: datasource=... depName=...` comment convention (via its `customManagers` regex) is used to let Renovate track versions embedded in strings inside `.tf`/`.yaml`/`.sh` files that aren't normal provider blocks.
- **Never commit directly to `main`.** All changes, including docs-only ones, go through a feature branch and a pull request (e.g. `git checkout -b docs/my-change`, push, then open a PR) — `main` only receives merges plus the automated `style:`/`docs:` commits from CI (see Commands above).
- **Update [CHANGELOG.md](CHANGELOG.md) for notable changes.** Add an entry under the `[Unreleased]` section (in the matching `Changed`/`Added`/`Removed`/`Fixed` group) alongside any PR that changes behavior, variables, or repo-wide conventions — not for pure CI tweaks or trivial wording fixes. Releases are cut later by moving `[Unreleased]` entries under a new `## [X.Y.Z] - YYYY-MM-DD` heading, following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
