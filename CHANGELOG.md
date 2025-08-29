# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]
### Changed
### Added
### Removed
### Fixed
### Dependencies


## [3.0.0] - 2025-08-29

:boom: **BREAKING CHANGE** :boom:

### Changed

- **Breaking:** The VM image now respects the schematic id and thus allows safe
  changes/upgrades of the schematic definition going further.  While this
  fixes the workaround introduced in v0.0.1, it is a breaking change, needing
  a rebuild of the cluster.  This is due to the change of the filename and
  schematic resource id, causing terraform/tofu to rebuild every VM at the same
  time -- without safeguarding mechanisms known from
  `update_version`/`update_schematic` (#106). 
- Update GW API version v1.1.0 → v1.2.1 (#109)
  see also [GW API v1.2 upgrade notes](https://gateway-api.sigs.k8s.io/guides/#v12-upgrade-notes)

### Added

- Add optional `dns` configuration for cluster nodes (#110)
- Add optional `on_boot` variable to control VM startup during boot (#112)
  
### Dependencies

- update `cilium/cilium` v1.18.0 → v1.18.1 (#82)
- update `terraform proxmox` v0.81.0 → v0.82.0 (#100)

## [2.1.0] - 2025-08-10

### Upgrade Note

Ensure to use Talos version `v1.9.3` at minimum (cf. #20).

### Added

- docs: documented variables incl. examples in docs/ folder

### Changed

- Disable Talos' `forwardKubeDNSToHost` setting b/c it's incompatible with the
  cilium's `bpf.masquerade` option (#77).
  This change is only required for consumers who have `bpf.masquerade` option
  enabled in their cilium `values.yaml` -- which it is not in this module's
  default version supplied (which can get overriden per input variable
  `cilium_values` or when redeploying cilium after its installation).
  As this module does not allow altering the Talos machine configuration, yet,
  consumers depend on a decent default configuration of the module.  Hence,
  altering the default setting in this module and planning to make the Talos
  machine configurable per module (#79).

### Removed

- Removed unused `ingressController` config in cilium defaults;
  as `ingressController` was disabled anyway, this is a cosmetic change (#48)

### Dependencies

- update cilium/cilium v1.16.5 → v1.18.0 (#74 et al.)
- update terraform kubernetes v2.35.1 → v2.38.0 (#73 et al.)
- update terraform proxmox v0.69.0 → v0.81.0 (#75 et al.)

## [2.0.1] - 2025-01-16

This is a "null operation" release without any changes. It serves as a test
for any consumers who use automatic release notify or update tools (e.g.
`dependabot`, `renovate`) after the repo move and restructuring, which also
caused a change in the release tag naming scheme.

## [2.0.0] - 2025-01-16

### Changed

**BREAKING CHANGE**:

- Repo ownership changed from @sebiklamar to @isejalabs.
- In addition, there's a change in the repo structure by splitting up the
  terraform modules to multiple repos. As such, terraform module `vehagn-k8s`
  will change its name to `terraform-proxmox-talos`, while version tags will
  strip off the module name, i.e. change from `vehagn-k8s-v2.0.0` to `v2.0.0`.

No further code changes, i.e. functionality equals the `v1.0.0` version.

**Upgrade Notice**:
While most tools will accomodate to the new repo URL per `git`'s redirect for
the short term, a manual change is necessary for the long term and for adapting
to the new repo structure because the module's code will move from the
`modules/vehagn-k8s` subfolder to the repo root folder.

Coming from a pre-`v2.0.0` version you normally have adapted any `source` URL
references as part of the transition from `vehagn-k8s-v1.0.0` via the
transitional release `vehagn-k8s-v2.0.0` already.

1. If not done yet, set repo `source` URL in terraform/tofu/terragrunt to
   `isejalabs/terraform-proxmox-talos.git?ref=v2.0.0`.
2. Migrate your state file, depending on `remote_state` configuration. Read the
   [release notes for vehagn-k8s-v2.0.0](https://github.com/isejalabs/terraform-proxmox-talos/releases/tag/vehagn-k8s-v2.0.0)
   for further instructions.

## [1.0.0] - 2024-12-23

### Changed

**BREAKING CHANGE:**

- proxmox volume and downloaded file (talos image) respect
  the environment (`var.env`) in the volume (e.g. `vm-9999-dev-foo`) and
  filename (e.g. `dev-talos-<schematic>-v1.8.4-nocloud-amd64.img`) if specified
  (optionally); there's no known and tested upgrade path other than destroying
  the whole custer as a change to the download image will re-trigger creation of
  all VMs: `terragrunt` doesn't have a parameter `-target` for `plan`/`apply`
  for targeting individual machines instead of all machines affected by a
  changed image, and there's also no resource `import` function available for
  the talos provider; for `terraform`/`tofu`-only setups the `-target` approach
  could be an alternative (untested)

### Dependencies

- update terraform kubernetes v2.35.0 → v2.35.1 (#19)
- update terraform proxmox v0.68.1 → v0.69.0 (#17)
- update dependency cilium/cilium v1.16.4 → v1.16.5;
  beware potential issue with DNS, see siderolabs/talos#10002: Cilium 1.16.5
  breaks external DNS resolution with forwardKubeDNSToHost enabled)

## [0.3.0] - 2024-12-14

### Added

- new optional `nodes.[].disk_size` parameter for VM disk size (defaulted to
  vehagn's `20` GB size)
- new optional `nodes.[].bridge` parameter for network bridge (defaulted to
  vehagn's `vmbr0`)

### Changed

- hosts are registered in k8s with their FQDN (#15)
  UPGRADE NOTICE: you will need to remove existings hosts registered with their
  short hostname from the (kubernetes) cluster manually as the FQDN host version
  will be re-added to the cluster instead of replacing its short hostname
  counterpart (per `kubectl delete node <node-short-hostname>`)
  <br>
  Otherwise you'll get a stalled
  `tofu: module.talos.data.talos_cluster_health.this: Still reading... [10m0s elapsed]`

### Dependencies

- update terraform kubernetes v2.33.0 → v2.35.0 (#9, #14)
- update terraform proxmox v0.67.1 → v0.68.1 (#10)

## [0.2.0] - 2024-12-08

### Added

- Keep a Changelog
- proxmox csi role & user get env-specific prefix (per `var.env`), default is
  empty (e.g. `dev-CSI` and default `CSI`)
- CPU configurable (default CPU stays `x86-64-v2-AES`, though not hard-coded any
  longer)

### Fixed

- treat path to cilium values as file (regression, bootstrapping not working)

### Dependencies

- update dependency cilium/cilium v1.16.2 → v1.16.4 (#13)

## [0.1.0] - 2024-12-04

First 0.1 version which is feature-par with upstream terraform module (plus
additions)

### Added

- cilium values configurable: cilium `values.yaml` can be provided as input
  variable (`cilium_values`); otherwise an inbuilt default will be used
  (`talos/inline-manifests/cilium-values.default.yaml`), since as v0.0.1 version

## [0.0.3] - 2024-11-23

### Added

- implemented proxmox-csi volumes and sealed secrets
  (leaving remaining feature configuration of cilium values instead of
  hard-coding)

### Changed

- allow 1 controller node only instead of min. 3

### Dependencies

- update terraform talos to v0.6.1 (#6)
- update terraform kubernetes to v2.33.0 (#7)
- update terraform proxmox to v0.67.1 (#8)

## [0.0.2] - 2024-11-17

### Added

- use variables for node and other env.specific config

### Changed

**BREAKING CHANGE:**

- requires definition of nodes, cluster, image as variables (or terragrunt input)
- change default `nodes.[].datastore_id` back to `local-zfs` (was: `local-enc`)

## [0.0.1] - 2024-11-17

First implementation of
[vehagn/homelab/tofu/kubernetes](https://github.com/vehagn/homelab/commit/4e517fa18656a1d112041516b03a0d8164989123)
as dedicated terraform module

Notable changes to the upstream version are:

### Added

- optional `nodes.[].vlan_id` parameter for defining VLAN ID
- install gateway api manifests before cilium deployment (cherry-picking
  [vehagn/homelab PR 78](https://github.com/vehagn/homelab/pull/78/commits))

### Changed

- `nodes.[].datastore_id` defaulted to `local-enc` (was: `local-zfs`)
- `nodes.[].mac_address` optional
- changed CPU model to `x86-64-v2-AES` (was: `host`)
- overwrite existing downloaded file from other module instance, hence limiting
  clashing with other module instances in the same proxmox cluster
- implemented initial workaround for `schematic_id` issue (see
  vehagn/homelab#106) by not depending on the `schematic_id` in the resource id
  by having 2 instances of `proxmox_virtual_environment_download_file`
  (impl. option 4, cf.
  https://github.com/vehagn/homelab/issues/106#issuecomment-2481303369)

### Removed

- removed talos extensions:
  - `siderolabs/i915-ucode`
  - `siderolabs/intel-ucode`

→ implemented in v0.0.2 to make this variable

### Known Issues

- [x] node configuration hard-coded in module; needs to be moved to input variables
      in `terragrunt.hcl`
      → implemented in v0.0.2
- [x] sealed secrets and subsequent k8s bootstrapping not working yet - though you
      get a working k8s cluster (w/ cilium even)
      → implemented in v0.0.2
- [x] cilium values not configurable
      → implemented in v0.2.0
- [x] resources in proxmox clashing with other instances of this module in the same
      proxmox cluster (due to same name used)
      → initial implementation in v0.2.0 and finalized in v1.0.0
- [x] `schematic.yaml` is hard-coded and should be definable as variable
      → implemented in v0.0.2
