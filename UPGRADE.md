# Upgrade

For most upgrades, especially patch and minor versions, you just need to run `terraform apply`. For upgrades of major versions you need to respect the version-specific instructions given below.

All instructions to upgrade this project from one major release to the next will be documented in this file. Upgrades must be run sequentially, meaning you should not skip upgrade instructions of minor/major releases while upgrading (fix releases can be skipped).

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project tries to adhere to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

For general instructions on how to upgrade, please consult the [Upgrade Methods documentation](docs/upgrade%20methods.md#).

<!--
> [!NOTE]
> [!TIP]
> [!IMPORTANT]
> [!WARNING]
> [!CAUTION]
-->

## [Unreleased]

## [7.0.0]

The safest upgrade path is not having a volume with type `disk` yet. The steps for upgrading are as follows:

1. Upgrade your Talos cluster to v1.12 (cf. [Talos upgrade documentation](docs/upgrade%20methods.md#talos-os-upgrade)).
1. Upgrade this Terraform Talos module to v6.1.x or newer (cf. [Module upgrade documentation](docs/upgrade%20methods.md#terraform-module-version-upgrade)).

If you happen to running your cluster with a `disk`-type volume, you have the following options:

1. Remove the `disk`-type volume(s) temporarily (you already have a backup, haven't you), upgrade Talos to v1.12, upgrade this module to v6.1.x or newer, and re-add the `disk`-type volume(s) again.
1. Alternatively, keep the `disk`-type volume(s) and use [resource targeting](docs/upgrade%20methods.md#resource-targeting), excluding the following terraform resource types for each `terraform apply` run sequentially per node:
   - `module.talos.proxmox_virtual_environment_vm.this["node1"]`
   - `module.talos.talos_machine_configuration_apply.this["node1"]`

## [6.0.2]

> [!IMPORTANT]
>
> If you have `disk` type volumes without specifying an individual `datastore` and the VM is not using `local-zfs`, special care is required when upgrading to this version.

Previously, when not specifying a specific `datastore` for `disk` type volumes, the module defaulted to `local-zfs` datastore erroneously. This is not the desired and documented behaviour (instead, the VM's datastore should be taken when no datastore is specified). As such, a module upgrade will recitify the situation by moving the disk(s) to the same datastore the VM is using.

The following is required to avoid errors during `terraform plan` and `terraform apply`:

While the disk(s) will get moved from `local-zfs` (the former datastore) to the VM's datastore without data loss, special care is required to avoid `terraform plan/apply` errors due to the dynamic behaviour of the VM disk handling logic.

1. Optimally, detach the `disk` type volume(s) from the Main Talos VM(s) (not Data VMs) manually via Proxmox VE UI or CLI. See the [VM architecture documentation](docs/vms.md#separation-of-talos-vm-and-data-vm) for identifying the Main Talos VM(s).
1. Run (`terraform plan` and) `terraform apply` _multiple_ times for getting to a final result. Terraform will produce several errors inbetween – which will get solved with multiple runs, finally.

The error messages produced by `terraform` will look similar to the ones below:

```
* Failed to execute "tofu apply" in ./.terragrunt-cache/cj_qtdX4SVSN2mQL18WDg3O9M74/AXI3wB-PS_BYZEnbtpZ4j1O9g34
  ╷
  │ Error: Provider produced inconsistent final plan
  │
  │ When expanding the plan for
  │ module.talos.proxmox_virtual_environment_vm.this["host.example.com"]
  │ to include new values learned so far during apply, provider
  │ "registry.opentofu.org/bpg/proxmox" produced an invalid new value for
  │ .disk[2].path_in_datastore: was cty.StringVal("vm-1230-disk-3"), but
  │ now cty.StringVal("vm-1230-disk-1").
  │
  │ This is a bug in the provider, which should be reported in the provider's
  │ own issue tracker.
  ╵

  exit status 1
...
* Failed to execute "tofu apply" in ./.terragrunt-cache/cj_qtdX4SVSN2mQL18WDg3O9M74/AXI3wB-PS_BYZEnbtpZ4j1O9g34
  ╷
  │ Error: Defined disk interface not supported. Interface was , but only [ide sata scsi virtio] are supported
  │
  │   with module.talos.proxmox_virtual_environment_vm.this["host.example.com"],
  │   on talos/virtual-machines.tf line 1, in resource "proxmox_virtual_environment_vm" "this":
  │    1: resource "proxmox_virtual_environment_vm" "this" {
  │
  ╵

  exit status 1
```

Should you forget to detach an additional `disk` type volume from the Main Talos VM(s) before running `terraform apply`, you will get an error message similar to the following:

```
* Failed to execute "tofu apply" in ./.terragrunt-cache/cj_qtdX4SVSN2mQL18WDg3O9M74/AXI3wB-PS_BYZEnbtpZ4j1O9g34
  ╷
  │ Error: Cannot move local-zfs:vm-1230-disk-1 to datastore foo in VM 123 configuration, it is not owned by this VM!
  │
  │   with module.talos.proxmox_virtual_environment_vm.this["host.example.com"],
  │   on talos/virtual-machines.tf line 1, in resource "proxmox_virtual_environment_vm" "this":
  │    1: resource "proxmox_virtual_environment_vm" "this" {
  │
  ╵

  exit status 1
```

### [6.0.0]

- **Rename variables** as indicated in the [CHANGELOG.md](CHANGELOG.md#600---2026-01-19) file.
- For tackling the VM destruction caused by breaking change of separating Talos OS and EPHEMERAL disks you have several options:
  1. Recreate the cluster, or
  1. Restore `etcd` data from a backup, or
  1. (Recommeded) leverage **resource targeting** (cf. [upgrade documentation](docs/upgrade%20methods.md#resource-targeting)) to facilitate a rolling upgrade of Talos nodes.
- **Optionally**: As the disks for Talos OS image and EPHEMERAL partition are now separated, you may need to adjust the disk sizes accordingly. You can **decrease the data disk size by 4 GB** for having a similar data usage setup as before.

### [5.0.0]

- **Specify new mandatory variables**, as indicated in the _Added_ section of the [CHANGELOG.md](CHANGELOG.md#500---2025-10-03) file.
- **Rename variables** as indicated in the _Changed_ section of the [CHANGELOG.md](CHANGELOG.md#500---2025-10-03) file.
- If you depend on **scheduling of workloads on control plane** nodes, you need to set [`cluster.allow_scheduling_on_controlplane = true`](docs/variables.md#cluster) (default is `false`) to enable this behaviour again. This is a breaking change as the previous hardcoded setting has been changed for better security and stability of the cluster, but it can be easily adapted by setting the new variable [`cluster.allow_scheduling_on_controlplane`](docs/variables.md#cluster) to `true`.

See the [CHANGELOG.md](CHANGELOG.md#500---2025-10-03) file for further details on renames and additions.

### [4.0.0]

If you used the `nodes[].on_boot` parameter before, you need to move it from the `nodes` variable to the `cluster` variable.

### [3.0.0]

As one of the upgrade procedures – besides recreating the cluster or restoring `etcd` from a backup – you can use **resource targeting** (cf. [upgrade documentation](docs/upgrade%20methods.md#resource-targeting)) to facilitate a rolling upgrade of Talos nodes.

### [2.0.0]

While most tools will accomodate to the new repo URL per `git`'s redirect for the short term, a manual change is necessary for the long term and for adapting to the new repo structure because the module's code will move from the `modules/vehagn-k8s` subfolder to the repo root folder.

Coming from a pre-`v2.0.0` version, you normally have adapted any `source` URL references as part of the transition from `vehagn-k8s-v1.0.0` via the transitional release `vehagn-k8s-v2.0.0` already.

1. If not done yet, set repo `source` URL in terraform/tofu/terragrunt to `isejalabs/terraform-proxmox-talos.git?ref=v2.0.0`.
2. Migrate your state file, depending on `remote_state` configuration. Please consult the documentation for the tool of your choice (terraform, tofu, terragrunt) and state management (e.g. local, remote backend, etc.) for migrating state files.

### [1.0.0]

As one of the upgrade procedures – besides recreating the cluster or restoring `etcd` from a backup – you can use **resource targeting** (cf. [upgrade methods](docs/upgrade%20methods.md#resource-targeting)) to facilitate a rolling upgrade of Talos nodes.

### [0.0.2]

- **Specify new mandatory variables** `nodes`, `cluster` and `image`, as indicated in the _Added_ section of the [CHANGELOG.md](CHANGELOG.md#002---2024-11-17) file.
- Check the usage of the `nodes[].datastore_id` variable in your code. The default changed from `local-enc` to `local-zfs` for better compatibility with different Proxmox VE setups. If you were relying on the default value, you need to set `nodes[].datastore_id = "local-enc"` explicitly for keeping the previous behaviour.
