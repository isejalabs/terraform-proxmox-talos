# Changelog

All _notable_ changes to this project will be documented in this file, following the [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format. It won't include each and every change and commit (e.g. ci or documentation changes), but only the notable changes, in a human-readable format that commit messages sometimes do not provide.

This project tries to adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). Hence, a change to the version number X.Y.Z will indicate a

- **X+1: breaking changes** in **major** version numbers,
- **Y+1: feature updates** (and possbily bug fixes) in **minor** version numbers, and
- **Z+1: bug fixes** only in **patch** version numbers.

Alongside this [CHANGELOG.md](CHANGELOG.md), please consult the [UPGRADE.md](UPGRADE.md) file, which is supposed to get enriched with detailed upgrade instructions for each release, especially for handling breaking changes.

<!--
> [!NOTE]
> [!TIP]
> [!IMPORTANT]
> [!WARNING]
> [!CAUTION]
-->

<!---
## [Unreleased Template]
### Changed

### Added

### Removed

### Fixed

## [X.Y.Z] - YYYY-MM-DD
-->

## [Unreleased]

### Changed

- Documentation: Renamed [docs/upgrading.md](docs/upgrade%20methods.md) to [docs/upgrade methods.md](docs/upgrade%20methods.md) to reflect the following: This file describes various **methods** to "upgrade" (change) various aspects of a Kubernetes cluster, which could be, besides a terraform module version change, e.g., how to upgrade Talos OS version, Kubernetes version, or how to perform a cluster scaling. The file is not describing the upgrade instructions for each release of this terraform module, which are now documented in the new [UPGRADE.md](UPGRADE.md) file (cf. below).

### Added

- Documentation: Added a new [UPGRADE.md](UPGRADE.md) file in the project root with detailed upgrade instructions for each release, especially for handling breaking changes. It documents the actions needed to upgrade this terraform module version in your cluster. This information was kept in the CHANGELOG.md file before, but it got moved to a separate file for better structuring and readability of the CHANGELOG.md file, which is supposed to give a high-level overview of the changes in each release, while the UPGRADE.md file is supposed to give detailed instructions for each release, especially for handling breaking changes.

### Removed

### Fixed

## [7.1.0] - 2026-02-24

### Changed

- Stop VMs on destroy instead of shutting them down to avoid issues with dangling VMs in Proxmox VE when destroying the cluster with `terraform destroy` (cf. #114).

### Added

- Added `smbios` configuration to the VM resource. This helps the Proxmox CSI Driver to identify nodes correctly, thus the plugin will work more reliably and faster (cf. #180). Note: It doesn't remove the need for node labels, and it doesn't free you up guiding deployments with node selectors and affinities, which are still required for the Proxmox CSI Driver to work correctly.

## [7.0.0] - 2026-02-24

> [!CAUTION]
> :boom: **BREAKING CHANGE** :boom:
>
> Please consult [UPGRADE.md](UPGRADE.md#700) documentation for detailed upgrade instructions, including instructions for handling the breaking changes introduced in this release.

> [!NOTE]
> This release got published as `v6.1.0` first, but due to the breaking changes introduced in this release, it got renamed to `v7.0.0` for better reflecting the breaking changes and for following semantic versioning properly.

This module version adds support for Talos v1.12, which comes along with an incompatibility with Talos v1.11 and below, unfortunately. Besides increasing Talos compatibility, also the `directory` type for `volumes` got added, which is a new feature introduced in Talos v1.12. A new and enriched [storage documentation](docs/storage.md) explains the 3 storage options available in this terraform module and their usage.

### Changed

- **Breaking:** The compatibility changed for this module minor version. The minimum Talos version supported is now v1.12 (#182, #187). See the _Upgrade Note_ and _Compatibility Note_ sections below for further details.

### Added

- Added functionality to apply the DNS configuration in Talos via Machine Config (#185). Previously, DNS was configured via Cloud Init in Proxmox only. While this looks redundant, it ensures that Talos itself has a proper DNS configuration, too, and it prepares this module for a potential hybrid scenario.
- Added support for `directory` type [`volumes`](https://github.com/isejalabs/terraform-proxmox-talos/blob/main/docs/variables.md#volumes) (#188). This is a new volume type introduced in Talos v1.12 (besides `partition` type which is not supported by this module version, yet). This allows to use storage space on the EPHEMERAL partition as volumes in Talos, which can be used for various use cases (e.g. for `hostPath` or for additional space for other CSI solutions (e.g. OpenEBS, Longhorn)). See the [`volumes` variable documentation](https://github.com/isejalabs/terraform-proxmox-talos/blob/main/docs/variables.md#volumes) for further details and examples.
- Added a dedicated [storage documentation](docs/storage.md) covering the different storage options supported by this module, including their additional configuration needed and special handling (#194, #198).

### Compatibility Note

The module now supports Talos v1.12 and newer, and is incompatible with Talos v1.11 (and below).

| Module/Talos Version | not using `disk` feature | using `disk` feature |
| -------------------- | ------------------------ | -------------------- |
| v5.0                 | >=1.8                    | not available        |
| v6.0                 | >=1.10                   | >=1.11, <=1.12       |
| v7.0                 | >=1.12                   | >=1.12               |

### Dependencies

- update `cilium/cilium` v1.18.4 → v1.18.7 (#201)
- update `terraform proxmox` v0.89.1 → v0.96.0 (#199)
- update `terraform talos` v0.9.0 → v0.10.1 (#185)

| Component            | Version |
| -------------------- | ------- |
| cilium/cilium        | 1.18.7  |
| cilium/cilium-cli    | 0.18.9  |
| Mastercard/restapi   | 2.0.1   |
| terraform kubernetes | 2.38.0  |
| terraform proxmox    | 0.96.0  |
| terraform talos      | 0.10.1  |

## [6.0.2] - 2026-01-29

> [!CAUTION]
> :boom: **BREAKING CHANGE** for some cases :boom:
>
> While released as patch version, accidentially, this release is introducing breaking changes _if_ you're using `disk` type volumes. Please read the [UPGRADE.md](UPGRADE.md#602) documentation carefully before upgrading.

This release is fixing an issue with `disk` type volumes. The module is still limited to Talos v1.10 (or v1.11 when using the `disk` feature) as minimum versions and v1.11 as maximum supported version.

### Fixed

- **Breaking possibly:** Fixed an issue for `disk` type where `volumes[].datastore` was not properly defaulting to the VM's datastore (`nodes[].datastore`) if not specified explicetely (#179).

### Compatibility Note

The minimum (and maximum) supported Talos versions are still the same as mentioned for the v6.0.0 major release, as patch releases do not change functionality. It will stay this way within the v6.0 minor series (as any v6.0.x patch version will not alter functionality). Only v6.1 of this Terraform Talos provider will support Talos v1.12 and newer.

## [6.0.1] - 2026-01-26

This is a patch release fixing an issue with `disk` type volumes. The module is still limited to Talos v1.10 (or v1.11 when using the `disk` feature) as minimum versions and v1.11 as maximum supported version.

### Fixed

- Fixed issue #177 where a `disk` type volume got interpreted as proxmox-csi volume, causing an error during `terraform plan` (#178).

### Compatibility Note

The minimum (and maximum) supported Talos versions are still the same as mentioned for the v6.0.0 major release, as patch releases do not change functionality. It will stay this way within the v6.0 minor series (as any v6.0.x patch version will not alter functionality). Only v6.1 of this Terraform Talos provider will support Talos v1.12 and newer.

## [6.0.0] - 2026-01-19

> [!CAUTION]
> :boom: **BREAKING CHANGE** :boom:
>
> Please consult [UPGRADE.md](UPGRADE.md#600) documentation for detailed upgrade instructions, including instructions for handling the breaking changes introduced in this release.

This release introduces a major change in the VM and disk architecture by separating the Talos OS disk from the EPHEMERAL and additional data disks, among some name harmonizations of variables. While coming along with several breaking changes, this release enhances upgradeability, flexibility, maintainability and storage options.

The module is limited to Talos v1.10 (or v1.11 when using the `disk` feature) as minimum versions and v1.11 as maximum supported version. It will stay this way within the v6.0 minor series (as any v6.0.x patch version will not alter functionality). Only v6.1 of this Terraform Talos provider will support Talos v1.12 and newer. See _Compatibility Note_ section below for further details.

### Changed

- **Breaking:** Split up disk setup and VM into 2 disks and 2 VMs (#144). As this change is destroying the former primary disk, please consult the **Upgrade Note** below for further instructions.

  The new VM and disk architecture is as follows (cf. [VM architecture documentation](docs/vms.md#separation-of-talos-vm-and-data-vm)):
  - Main/Talos VM is holding primary (existing) disk with Talos OS (with EFI,
    META and STATE) partitions. The disk has a fixed size of `5 GB` because
    current Talos image size is ~4 GB.
  - (NEW) 2nd disk is holding `/var` with EPHEMERAL data (with e.g. `etcd`).
    In addition, a new "data_vm" (which is offline and just acts as a
    placeholder). The VM id is the Talos VM ID suffixed by `0` and the VM name
    ia suffixed by `-data` (e.g. VM ID `123` and VM name `k8s1.example.com`
    become `1230` and `k8s1.example.com-data`, respectively).
    The data disk has a variable size which is configurable. As the new data
    disk is not holding the OS any longer, you can decrease its size by 4 GB
    for having a similar data usage setup as before.
  - The data_vm's disk is attached to the main Talos VM.

  While being a dramatic change, it has the following benefits:
  - Easier upgrades of Talos OS by just replacing the Talos VM's disk while keeping the data disks untouched (similar to a `talosctl upgrade --preserve=true`). Hence, Talos OS upgrades do not destroy `etcd` or any other data any longer.
  - No need for more than one controlplane node as `etcd` is kept in a single CP node setup.

- **Breaking:** Renamed variable `image.proxmox_datastore` to `image.datastore` (#148, #153).
- **Breaking:** Renamed variable `nodes[].datastore_id` to `nodes[].datastore` (#148, #153).
- **Breaking:** Renamed variable `volumes[].storage` to `volumes[].datastore` (#154).

### Added

- Added possibility to define addtional **data disks** (#175). An additional data disk can be be used e.g. for `hostPath` or for additional space for other CSI solutions (e.g. OpenEBS, Longhorn). This feature leverages the `User Volume` feature introduced in [Talos v1.11](https://docs.siderolabs.com/talos/v1.11/configure-your-talos-cluster/storage-and-disk-management/disk-management/user). See the enriched [`volumes` variable documentation](https://github.com/isejalabs/terraform-proxmox-talos/blob/main/docs/variables.md#volumes) – which, BTW, is indicating support for further Volume Types `directory` (#161) and `partition` (#162) in future releases (#159) based on Talos v1.12.
- Documented [how to upgrade](docs/upgrade%20methods.md) several aspects of the Talos cluster (e.g. upgrade Talos OS version, Kubernetes version, terraform module version, incl. breaking changes and resource targeting).
- Documented the new VM architecture with [separation of Talos VM and Data VM](docs/vms.md#separation-of-talos-vm-and-data-vm).

### Fixed

- Fixed definition of `volumes` variable to allow no volume getting specified (#166).

### Compatibility Note

The minimum Talos version requirement changed due to the new disk management features leveraged here:

- If _not_ using `disk` feature, Talos v1.10 is required at minimum nevertheless (due to separating EPHEMERAL partition from OS disk). It appears that 6.0.x module version is supported by newer Talos versions, e.g. v1.12.
- If using `disk` feature, Talos v1.11 is required at minimum (due to leveraging `User Volume` feature). Talos v1.12 forms the _maximum_ supported version due to incompatible changes introduced in Talos v1.12.
- When requiring Talos v1.12, you have the option of not using the `disk` feature or waiting for module version v6.1 which is supposed to support Talos v1.12 and newer.

| Module/Talos Version | not using `disk` feature | using `disk` feature |
| -------------------- | ------------------------ | -------------------- |
| v5.0                 | >=1.8                    | not available        |
| v6.0                 | >=1.10                   | >=1.11, <=1.12       |
| v6.1                 | >=1.12                   | >=1.12               |

### Dependencies

- update `terraform talos` v0.82.0 → v0.89.1 (#143)

| Component            | Version |
| -------------------- | ------- |
| cilium/cilium        | 1.18.4  |
| cilium/cilium-cli    | 0.18.9  |
| Mastercard/restapi   | 2.0.1   |
| terraform kubernetes | 2.38.0  |
| terraform proxmox    | 0.89.1  |
| terraform talos      | 0.9.0   |

## [5.0.1] - 2025-12-11

### Fixed

- Added missing `Sys.Audit` PVE role permission, needed by `proxmox-csi-plugin`
  version `v0.16.0` (Helm chart version `v0.5.0`) onwards (#140)
- Added additional PVE role permissions for supporting (zfs) replication feature

### Dependencies

- update `cilium/cilium` v1.18.2 → v1.18.4 (#132, #133)
- update `cilium/cilium-cli` v0.18.7 → v0.18.9 (#131, #138)

| Component            | Version |
| -------------------- | ------- |
| cilium/cilium        | 1.18.4  |
| cilium/cilium-cli    | 0.18.9  |
| Mastercard/restapi   | 2.0.1   |
| terraform kubernetes | 2.38.0  |
| terraform proxmox    | 0.82.0  |
| terraform talos      | 0.9.0   |

## [5.0.0] - 2025-10-03

> [!CAUTION]
> :boom: **BREAKING CHANGE** :boom:
>
> Please consult [UPGRADE.md](UPGRADE.md#500) documentation for detailed upgrade instructions, including instructions for handling the breaking changes introduced in this release.

While this is a release with breaking changes which need your attention in configuring new variables (or just changing their name), it also brings *a lot* of new features. Most of them got ported from [vehagn/homelab](https://github.com/vehagn/homelab) where @vehagn and @karteekiitg implemented some nice things in the area of Talos machine configuration 🙏. Apart from that, there is a small subset implemented by @sebiklamar, and of course some indispensable component updates brought in by @renovate.

### Changed

- **Breaking:** Moved `proxmox.api_token` variable out of `promox` struct into
  a separate variable `proxmox_api_token` (#95).
- **Breaking:** Renamed variable `cluster.talos_version` to
  `cluster.talos_machine_config_version` (#101).
- **Breaking:** Renamed variable `image.schematic` to
  `image.schematic_path`.
- **Breaking:** Renamed variable `image.update_schematic` to
  `image.update_schematic_path`.
- **Breaking possibly:** Renamed variable `cilium_values` to `cilium_config`.
  As this is an _optional_ variable, it's only a breaking change for those who
  used the variable before.
  Please also see below for an additional sub-variable for governing cilium
  bootstrapping.
- **Breaking possibly:** Do not allow scheduling of workloads on control plane
  nodes, per default. Also made this configurable (cf. #124).
- Changed variable `cluster.talos_machine_config_version` (former
  `cluster.talos_version`) to be _optional_ (#94, #98).

### Added

- **Breaking:** Added _mandatory_ variable `cluster.gateway_api_version` to
  track GW API version. Previously, the GW API version was hardcoded to
  `v1.2.1`, and now, it can be set independent of the module version flexibly.
- **Breaking:** Added _mandatory_ variable `cluster.kubernetes_version` to
  track k8s version.
- Added _optional_ variable `cilium_config.bootstrap_manifest_path` allowing
  usage of a custom Cilium bootstrapping manifest (#95).
- Added _optional_ variable `cluster.allow_scheduling_on_controlplane` to
  allow scheduling of workloads on control plane nodes (#124).
- Added _optional_ variable `cluster.api_server` to define kube apiserver
  options (cf. [Talos apiServerConfig](https://www.talos.dev/v1.11/kubernetes-guides/configuration/inlinemanifests/#extramanifests)
  documentation)(#91).
- Added _optional_ variable `cluster.extra_manifests` to specify
  [`extraManifests`](https://www.talos.dev/v1.11/kubernetes-guides/configuration/inlinemanifests/#extramanifests)
  in Talos (#96).
- Added _optional_ variable `cluster.kubelet` to define kubelet config values,
  cf. [Talos kubeletConfig](https://www.talos.dev/v1.11/reference/configuration/v1alpha1/config/#Config.machine.kubelet)
  documentation)(#97).
- Added _optional_ variable `cluster.machine_features` to adjust individual
  Talos features, cf. [Talos featuresConfig](https://www.talos.dev/v1.11/reference/configuration/v1alpha1/config/#Config.machine.features)
  documentation)(#127).
- Added _optional_ variable `cluster.subnet_mask` for defining the network
  subnet mask (defaulting to `24`) (#86).
- Added _optional_ variable `cluster.vip` for leveraging a
  [Virtual (shared) IP](https://www.talos.dev/v1.11/talos-guides/network/vip/)
  (#86, #93).
  This allows HA usage scenarios in providing only one IP to clients to reach
  the control planes (requires all control planes residing in the same layer 2
  subnet).
- Added _optional_ variable `sealed_secrets_config` that can be supplied with
  alternative paths to the certificate and key for the `SealedSecrets`
  bootstrapping (#95). The default paths equal the present behaviour.
- Enabled kube-controller-manager, etcd, and kube-scheduler metrics (#116).
- Output Talos Machine Secrets (#102).
- Provide examples also for optional variables in the respective _Examples_
  sections.

### Removed

- **Breaking:** Removed the `registerWithFQDN` cluster setting from the Talos
  machine config. You need to configure this within the new `cluster.kubelet`
  variable, explicitely (cf. Examples section in the documentation).
- **Breaking possibly:** The scope of preloaded GW API manifests changed to
  only include CRDs with grade `standard`. As such, the `TLSRoute`
  experimental CRD got removed. Please leverage the new variable
  `cluster.extra_manifests` to include it as `extraManifest` in Talos
  (cf. [`cluster` variable documentation](docs/variables.md#cluster) for an
  [example](docs/variables.md#example-1)).
- Removed the `cluster.endpoint` variable. It is chosen automatically from the
  VIP or the first control plane node.

### Fixed

- Improved the way to install cilium with `inlineManifests` (#92).
- Use `cilium-cli` image instead of `cilium-cli-ci` image to install cilium
  (#103).
- Remove outdated `enableCiliumEndpointSlice` stanza from default cilium Helm
  configuration. This stanza got superseded by `CiliumEndpointSlice.enabled`,
  hence this should be a null-operation as it had no effect previously.
- Changing the `cluster.talos_machine_config_version` (former
  `cluster.talos_version`) variable does not destroy all VM nodes any longer
  (#38, #90).

### Dependencies

| Component            | Version |
| -------------------- | ------- |
| cilium/cilium        | 1.18.2  |
| cilium/cilium-cli    | 0.18.7  |
| Mastercard/restapi   | 2.0.1   |
| terraform kubernetes | 2.38.0  |
| terraform proxmox    | 0.82.0  |
| terraform talos      | 0.9.0   |

## [4.0.0] - 2025-08-30

> [!CAUTION]
> :boom: **BREAKING CHANGE** :boom:
>
> Please consult [UPGRADE.md](UPGRADE.md#400) documentation for detailed upgrade instructions, including instructions for handling the breaking changes introduced in this release.

### Changed

- **Breaking possibly:** The `on_boot` parameter got moved from the `nodes` variable to the `cluster` variable for controlling VM startup during boot (#115). It makes more sense setting it for all VMs used in a cluster.

If you used the `on_boot` parameter before, you need to move it from the `nodes` variable to the `cluster` variable.

## [3.0.0] - 2025-08-29

> [!CAUTION]
> :boom: **BREAKING CHANGE** :boom:
>
> Please consult [UPGRADE.md](UPGRADE.md#300) documentation for detailed upgrade instructions, including instructions for handling the breaking changes introduced in this release.

### Changed

- **Breaking:** The VM image now respects the schematic id and thus allows safe
  changes/upgrades of the schematic definition going further. While this
  fixes the workaround introduced in v0.0.1, it is a breaking change, which destroys and recreates all Talos VMs. See the upgrade notes how to apply a rolling upgrade.
- Update GW API version v1.1.0 → v1.2.1 (#109).
  See also [GW API v1.2 upgrade notes](https://gateway-api.sigs.k8s.io/guides/#v12-upgrade-notes)

### Added

- Add optional `dns` configuration for cluster nodes (#110)
- Add optional `on_boot` variable to control VM startup during boot (#112)
- Created modules documentation (auto-generated) and a more elaborated documentation
  for the variables, including examples (cf. `docs/` folder).

### Dependencies

- update `cilium/cilium` v1.18.0 → v1.18.1 (#82)
- update `terraform proxmox` v0.81.0 → v0.82.0 (#100)

## [2.1.0] - 2025-08-10

> [!TIP]
> Ensure to use Talos version `v1.9.3` at minimum. This is due to a bug in the terraform talos provider which causes issues with Talos v1.9.2 and below ([GH issue #20](https://github.com/isejalabs/terraform-proxmox-talos/issues/20)). Please consult [UPGRADE.md](UPGRADE.md#210) documentation for detailed upgrade instructions, including instructions for handling the breaking changes introduced in this release.

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
  consumers depend on a decent default configuration of the module. Hence,
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

> [!CAUTION]
> :boom: **BREAKING CHANGE** :boom:
>
> Please consult [UPGRADE.md](UPGRADE.md#200) documentation for detailed upgrade instructions, including instructions for handling the breaking changes introduced in this release.

### Changed

- **Breaking:** Repo ownership changed from @sebiklamar to @isejalabs.
- **Breaking:** In addition, there's a change in the repo structure by splitting up the terraform modules to multiple repos. As such, terraform module `vehagn-k8s` will change its name to `terraform-proxmox-talos`, while version tags will strip off the module name, i.e. change from `vehagn-k8s-v2.0.0` to `v2.0.0`.

No further code changes, i.e. functionality equals the `v1.0.0` version.

## [1.0.0] - 2024-12-23

> [!CAUTION]
> :boom: **BREAKING CHANGE** :boom:
>
> Please consult [UPGRADE.md](UPGRADE.md#100) documentation for detailed upgrade instructions, including instructions for handling the breaking changes introduced in this release.

### Changed

- **Breaking:** Proxmox volume and downloaded file (talos image) respect
  the environment (`var.env`) in the volume (e.g. `vm-9999-dev-foo`) and
  filename (e.g. `dev-talos-<schematic>-v1.8.4-nocloud-amd64.img`) if specified
  (optionally).
  This allows multiple environments (e.g. `dev`, `staging`,
  `prod`) on the same Proxmox VE host without colliding volume names or image
  filenames.

  Unfortunately, this is a breaking change as it changes the names of the
  volumes and downloaded image files and thus forces recreation of all VMs.
  See the upgrade notes how to apply a rolling upgrade.

### Dependencies

- update terraform kubernetes v2.35.0 → v2.35.1 (#19)
- update terraform proxmox v0.68.1 → v0.69.0 (#17)
- update dependency cilium/cilium v1.16.4 → v1.16.5;
  beware potential issue with DNS, see siderolabs/talos#10002: Cilium 1.16.5
  breaks external DNS resolution with forwardKubeDNSToHost enabled)

## [0.3.0] - 2024-12-14

### Added

- new optional `nodes[].disk_size` parameter for VM disk size (defaulted to
  vehagn's `20` GB size)
- new optional `nodes[].bridge` parameter for network bridge (defaulted to
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

- Introduced this [CHANGELOG](CHANGELOG.md) document which is following [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) approach.
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

> [!CAUTION]
> :boom: **BREAKING CHANGE** :boom:
>
> Please consult [UPGRADE.md](UPGRADE.md#002) documentation for detailed upgrade instructions, including instructions for handling the breaking changes introduced in this release.

### Added

- use variables for node and other env.specific config

### Changed

- **Breaking:** requires definition of nodes, cluster, image as variables (or terragrunt input)
- **Breaking possibly:** change default `nodes[].datastore_id` back to `local-zfs` (was: `local-enc`)

## [0.0.1] - 2024-11-17

First implementation of
[vehagn/homelab/tofu/kubernetes](https://github.com/vehagn/homelab/commit/4e517fa18656a1d112041516b03a0d8164989123)
as dedicated terraform module

Notable changes to the upstream version are:

### Added

- optional `nodes[].vlan_id` parameter for defining VLAN ID
- install gateway api manifests before cilium deployment (cherry-picking
  [vehagn/homelab PR 78](https://github.com/vehagn/homelab/pull/78/commits))

### Changed

- `nodes[].datastore_id` defaulted to `local-enc` (was: `local-zfs`)
- `nodes[].mac_address` optional
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
