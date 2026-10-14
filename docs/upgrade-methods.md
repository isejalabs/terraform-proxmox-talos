# Upgrading the Talos Kubernetes Cluster

This document describes the procedures for upgrading various components of the Talos Kubernetes cluster managed by this `terraform-proxmox-talos` module.

## Overview

### Types of Cluster Upgrades

There are several use cases of upgrades, updates or just changes to the cluster.
Upgrades can involve changes to the Talos OS version, Kubernetes version, VM configurations, and other aspects of the cluster.

| Use Case                                                                  | Description                                                                                                                         |
| ------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| [**Talos OS Upgrade**](#talos-os-upgrade)                                 | Upgrading the **Talos OS version** running on the cluster                                                                           |
| [**Talos Schematic Version Upgrade**](#talos-schematic-upgrade)           | Upgrading the **Talos schematic version** used for generating node configurations.                                                  |
| [**Kubernetes Version Upgrade**](#kubernetes-version-upgrade)             | Upgrading the **Kubernetes version** managed by Talos.                                                                              |
| [**VM Configuration Changes**](#vm-configuration-changes)                 | Apply changes to **VM configurations** (e.g. CPU, memory), **scale the cluster** (by adding or removing nodes), or **relocate a node** to a different Proxmox host. |
| [**Terraform Module Version Upgrade**](#terraform-module-version-upgrade) | Upgrading the underlying `terraform-proxmox-talos` **module version**.                                                              |
| [**Upgrade of inbuilt components**](#upgrade-of-inbuilt-components)       | Upgrading **inbuilt components** like CNI, CSI, etc., which are shipped with this terraform module (e.g. Cilium, Gateway API).      |

These use cases will get described in the following sections.

### Before you upgrade – Important Considerations

> [!TIP]
> It's recommended to perform the upgrade in a non-production environment first to validate the process and ensure that there are no unexpected issues.

Most of the upgrades are a disruptive operation causing a destruction and recreation of the VM or important components of the Kubernetes cluster (e.g. etcd, CNI pods). Hence, you need to take care of the following aspects when performing a Talos OS upgrade:

- **Backup**: It is highly recommended to take a backup of the cluster state and any important data before starting the upgrade process.
- **Cluster Health**: Monitor the health of the Kubernetes cluster during the upgrade process to ensure that the control plane and worker nodes remain operational.
- **Data Persistence**: Ensure that any important data stored on the node is persisted outside of the Talos VM. This is typically done by using the separate data VM for EPHEMERAL and other data disks. In other cases, ensure that data is backed up appropriately or there's a replica available on another node which is not part of the upgrade step.

> [!TIP]
> A **cluster health check** (`module.talos.data.talos_cluster_health.this`) is part of the configuration process and waits for its successful termination. Hence, you can start the next action safely once terraform processes a configuration change successfully.

### ❤️ `terraform` = `tofu` = `terragrunt` ❤️

This module and its documentation is compatible with both [**Terraform**](https://www.hashicorp.com/en/products/terraform) and [**OpenTofu**](https://opentofu.org/) (a fork of Terraform). The upgrade procedures described here apply equally to both tools. In addition, there is [**Terragrunt**](https://terragrunt.gruntwork.io/) which acts as a wrapper and is beneficial for managing multiple environments and configurations with more DRY-style.

While the module's author preference is using `terragrunt` as a wrapper and using `tofu` over `terraform`, in the following, the term `terraform` is used to refer to any of these tools interchangeably. Luckily, the commands and their parameters are the same for all three tools – where not stated differently.

## Talos OS Upgrade

One of the most critical upgrades in a Kubernetes cluster lifecycle is upgrading the Talos OS version running on the nodes.

### Preamble

Due to the nature of the setup as terraform-managed setup, you cannot follow the official Talos OS upgrade procedure using `talosctl upgrade apply` command. This is because the Talos OS version and any other aspects of the image, cluster and nodes configuration are managed by terraform. Unfortunately, the [terraform talos provider from Siderolabs](https://github.com/siderolabs/terraform-provider-talos) does not support in-place Talos OS upgrades at the moment (GH issue [#140](https://redirect.github.com/siderolabs/terraform-provider-talos/issues/140)).

Luckily, [Vegard Stenhjem Hagen](https://github.com/vehagn), the author of the initial terraform-provider-talos module version ([vehagn/homelab//tofu/kubernets](https://github.com/vehagn/homelab/tree/140fbc249b26c622c0e2ab413c3aca9eb5014f8e)), has provided a workaround to perform Talos OS and Schematic version upgrades. The approach is described in his [blog post](https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/#upgrading-the-cluster) and summarized below.

In short, a Talos OS upgrade is performed by setting the [`nodes[].update`](variables.md#definition-4) variable to `true` for each node, one-by-one, and running `terraform apply` subsequently. This will download the new image, also fitting the schematic definition, and boot the VM with the new image.

Due to the new image, this will cause a destruction and recreation of the Talos VM for the respective node, while the data VM (holding EPHEMERAL and other data disks) remains untouched. Thus, data stored on the data VM is preserved across the Talos OS upgrade (similar to a `talosctl upgrade --preserve=true`).

> [!TIP]
>
> Starting with version 6.0 of terraform-provider-talos, this module supports Talos OS upgrades with only one control plane (thx to [PR #144](https://github.com/isejalabs/terraform-proxmox-talos/pull/144)). Thus, it's strictly not needed anymore to [scaling up the cluster](#cluster-scaling) with at minimum a 2nd control plane node (temporarily or permanently) or [backing up and restoring etcd](https://docs.siderolabs.com/talos/v1.9/build-and-extend-talos/cluster-operations-and-maintenance/disaster-recovery). This is good for development or test environments. However, it's still recommended to have 3 control plane nodes for production clusters for high availability, and to have a backup of etcd and other critical aspects (e.g. PV data) of your cluster.

### Steps to upgrade Talos OS

> [!IMPORTANT]
> It's recommended to **upgrade control plane nodes first**, followed by worker nodes. This ensures that the control plane is always running the latest Talos OS version, which is important for cluster stability and compatibility.

> [!NOTE]
> Please note that a Talos upgrade will _not_ perform an upgrade of Kubernetes version. It is recommended to perform the Kubernetes upgrade separately (and _not_ set [`cluster.kubernetes_version`](variables.md#definition-1) as part of the Talos OS upgrade). See also [Kubernetes Version Upgrade](#kubernetes-version-upgrade) section.

Carry out the following steps to **upgrade Talos nodes one by one**:

0. If your configuration pins [`cluster.talos_machine_config_version`](variables.md#definition-1) to an explicit version (rather than leaving it `null`), **temporarily unset it** before starting — see [Interaction with `talos_machine_config_version`](#interaction-with-talos_machine_config_version) below for why this matters.
1. Set [`image.update_version`](variables.md#definition-3) to the required version you want to update to.
1. In the following, you will process each node subsequently, **control planes first**. Set [`nodes[1].update = true`](variables.md#definition-4) for the 1st node and run `terraform apply`.
1. Set `nodes[2].update = true` for the 2nd node, _leave_ the previous node's `update = true` and run `terraform apply`.
1. Similarily to before, set `nodes[3].update = true` for the 3rd node, leave the previous nodes' `update = true` and run `terraform apply`.
1. ...
1. Set `nodes[n].update = true` for the n-th node, leave the previous nodes' `update = true` and run `terraform apply`.
1. After upgrading all nodes, set `image.version` to match the update version, reset `update = false` (or remove the attribute) for all [nodes](variables.md#definition-4), and — if you unset `cluster.talos_machine_config_version` in step 0 — re-pin it to the same version now. Run `terraform apply` once more and confirm it converges to a clean (or drift-free) plan.

Also, **monitor the cluster health** closely during and after the upgrade process before carrying out the upgrade for the next node(s).

> [!TIP]
>
> There is a more elaborate description of the steps in [Vegard's blog post](https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/#upgrading-the-cluster).

> [!TIP]
>
> **Multiple nodes can be upgraded in parallel** by setting `update = true` for multiple nodes before running `terraform apply` (e.g. a control plane and a worker node on another Proxmox host). When upgrading multiple nodes in parallel, ensure to exclude at minimum 1 control plane and a minimum of x worker nodes (depending on the workload deployed and availability of services during the change).

> [!TIP]
>
> Before upgrading, check [Talos Compatibility](talos-compatibility.md) for known caveats specific to the Talos version you're moving to or past (e.g. a behavior change introduced starting at a given version) — those are tracked separately from this mechanical procedure since they're a function of the target Talos version, not of this module.

> [!TIP]
>
> VM recreation during this procedure needs the same `ssh-agent`-authenticated access to the Proxmox host described under [Moving a Node to Another Proxmox Host](#moving-a-node-to-another-proxmox-host) — not just for host moves. Confirm a key is loaded and reachable (`ssh-add -l`) before starting each node's step, especially the control plane step: a VM creation failure there (e.g. `unable to authenticate user "root" over SSH`) happens *after* the old VM is already destroyed, leaving the cluster with no control plane until it's resolved.

> [!TIP]
>
> If a `host_node` runs more than one of your nodes, don't be surprised that the old-version `module.talos.proxmox_download_file.this[...]` entry for that host survives in the plan after you've upgraded only some of them — it's keyed per `host_node` + image version/schematic hash, and is only destroyed once *every* node on that host no longer references it. This is expected and safe: the previous image stays available on that host for any node still mid-rollout, and gets cleaned up automatically once the last one transitions.

> [!TIP]
>
> If your environment only permits `apply` from a CI-gated or otherwise protected branch (e.g. a GitOps repo), each step above becomes its own commit → PR → merge → apply cycle. A cluster with *n* nodes needs *n* + 1 such cycles (one per node, plus the finalization step) — budget time accordingly, and don't skip verifying cluster health between cycles just because a merge was fast.

### Interaction with `talos_machine_config_version`

[`cluster.talos_machine_config_version`](variables.md#definition-1) lets you pin the machine-config *format* (as opposed to `image.version`/`image.update_version`, which govern the actual OS image) to an explicit Talos version. When set, it applies to **every node identically, regardless of that node's own `update` flag** — it does not participate in the node-by-node staging described above at all.

This only matters when the staged rollout crosses a Talos version boundary that changes the machine-config format itself (see [Talos Compatibility](talos-compatibility.md) for known boundaries, e.g. Talos 1.14's multi-document config migration). If `talos_machine_config_version` stays pinned to the *old* version while you flip `update = true` node-by-node, every node — including ones not yet updated — keeps generating the *old* config format, so the new image on an updated node may receive a config it doesn't expect. If you instead pin it to the *new* version up front, every node (including ones still on the old image) jumps to the new config format immediately, defeating the purpose of staging.

To stage both the image **and** the config format together, node-by-node:

1. **Unset** `cluster.talos_machine_config_version` (leave it `null`) before starting. With it `null`, each node's machine-config format falls back to tracking its own `update` flag (the same `image.version`/`image.update_version` choice used for the image itself), so the format and the image version move together, one node at a time.
1. Proceed through the [staged rollout steps](#steps-to-upgrade-talos-os) above as normal.
1. Only in the finalization step, once every node has `update = true` (or `image.version` already matches `image.update_version` for all of them), re-pin `cluster.talos_machine_config_version` to the new version — alongside resetting `update = false` and converging `image.version`.

If you don't use `talos_machine_config_version` at all (leave it `null` permanently), none of this applies — every node already tracks its own `update` flag by default.

## Talos Schematic Upgrade

Upgrading the Talos schematic version is similar to upgrading the Talos OS version, here change `image.update_schematic_path` and `image.schematic_path`, instead of `image.update_version` and `image.version`:

1. Create a new [`schematic`](variables.md#schematic) file and ensure that [`image.update_schematic_path`](variables.md#definition-3) is pointing to that file. It's not recommended to change the existing schematic file in-place because this will cause a change of the image for _all nodes at once_ and upgrade the nodes at the same time.
1. Same process as for [Talos OS version upgrade](#steps-to-upgrade-talos-os). Set [`nodes[1].update = true`](variables.md#definition-4) for the 1st node and run `terraform apply`. Proceed with the other nodes one-by-one as [described above](#steps-to-upgrade-talos-os).
1. After upgrading all nodes, set the previous schematic file content to the same as used for the upgrade. Alternatively, set [`image.schematic_path`](variables.md#definition-3) to match the new schematic file path if you want to keep several schematic files in parallel instead of a single one which is version controlled.
1. Also reset `update = false` for all [nodes](variables.md#definition-4).

## Kubernetes Version Upgrade

> [!IMPORTANT]
>
> It's important to note that upgrading the Talos OS version does not automatically upgrade the Kubernetes version running on the cluster. This might lead to incompatibilities between Talos OS and Kubernetes versions if the Kubernetes version is kept over several Talos OS upgrade.
>
> You can find the compatible Kubernetes versions for each Talos OS version in the [Support Matrix](https://docs.siderolabs.com/talos/v1.12/getting-started/support-matrix) and [Talos release notes](https://docs.talos.dev/v1.12/release-notes/).

The Kubernetes version is managed separately through the [`cluster.kubernetes_version`](variables.md#definition-1) variable.
Talos will _not_ pick a compatible Kubernetes version when not setting this variable. It is recommended to upgrade the Kubernetes version _after_ and _each time_ when performing a Talos OS upgrade. This is to keep both versions, Talos OS and Kubernetes, aligned. Furthermore, only newer Talos OS versions support newer Kubernetes versions.

When setting a new `cluster.kubernetes_version`, a `terraform apply` would cause Talos to perform an upgrade of the Kubernetes components on each node (control plane and worker nodes) _in parallel_ – which is not recommended as this would cause the control plane to become unresponsive. Instead, a rolling upgrade should be performed, upgrading control plane nodes first, followed by worker nodes. Unfortunately, there is no `nodes[].update` mechanism for upgrading the Kubernetes version separately. Thus, you need to follow the steps below using a combination of an _imperative_ and _declarative_ approach, using `talosctl` and `terraform`.

### Steps to upgrade Kubernetes version

> [!NOTE]
>
> The approach is a **hybrid method** of first performing an _rolling upgrade_ using `talosctl` command, and finally reconcile the state with terraform.
> Using `talosctl` will ensure that only one control plane node is upgraded at a time, keeping the cluster operational during the upgrade process. Also, images of `kubelet`, `kube-apiserver`, `kube-schedule`, `etcd` and other components are pre-pulled to the nodes to minimize downtime and test for image availability (cf. [Talos Upgrading Kubernetes documentation](https://docs.siderolabs.com/kubernetes-guides/advanced-guides/upgrading-kubernetes) for details).

Perform the following 2 steps for upgrading the Kubernetes version:

1. First, run

   ```
   talosctl --nodes <control-plane-node> upgrade-k8s --to <new-k8s-version>
   ```

   for a rolling upgrade. Replace `<control-plane-node>` with one of the control plane nodes hostname or IP and `<new-k8s-version>` with the desired Kubernetes version (e.g. `v1.35.0`).

1. Set [`cluster.kubernetes_version`](variables.md#definition-1) to the required Kubernetes version as used before and run `terraform apply`.

Despite of the somewhat imperative approach using `talosctl`, this will ensure that the cluster is upgraded safely in a rolling manner, while finally reconciling the state with terraform. Should there be any drift detected by terraform, it will be corrected accordingly, even if you would select a different Kubernetes version.

## VM Configuration Changes

### Cluster Scaling

VMs get handled in Proxmox according to their configuration using the [`nodes` variable](variables.md#nodes). By adding (or removing) elements to the `nodes` variable, VMs get created (or removed) in Proxmox while at the same time control plane or worker nodes get added/removed in the Talos Kubernetes cluster automatically. This allows for (horizontal) **scaling the cluster** easily by adding or removing nodes as needed.

Likewise, vertical cluster scaling can be achieved by changing configuration parameters of the VMs (e.g. CPU cores, memory) will cause the respective VMs to get updated accordingly in Proxmox. Depending on the parameter changed, this might require a reboot of the VM. Hence, take care of not putting too many nodes offline at the same time when changing a parameter applicable for multiple VMs. This can be done by changing the parameter only for one VM step-by-step or use [resource targeting](#resource-targeting).

#### Ramping up

Add a new entry to the [`nodes` variable](variables.md#nodes) (picking an unused `vm_id`) and run `terraform apply`. For a **control plane** node specifically, the module's own [`talos_cluster_health`](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/cluster_health) data source gates the apply on the new node actually joining `etcd` and reporting healthy before `apply` returns — a successful `apply` already means it has joined, no manual polling needed. Verify directly afterward anyway (`kubectl get nodes`, `talosctl etcd members`).

> [!TIP]
>
> Adding a temporary 2nd control plane node this way is also the mechanism [Moving a Node to Another Proxmox Host](#moving-a-node-to-another-proxmox-host) below relies on for single-control-plane clusters.

#### Ramping down

Removing a node is not simply deleting its entry from the `nodes` variable. The VM resource is configured with `stop_on_destroy = true`, which is a hard Proxmox-level stop, not a graceful Talos/Kubernetes shutdown — skipping a graceful removal first risks a stuck `etcd` member (control plane node) or workloads killed without a clean drain. Before editing `nodes`, retire the node gracefully:

```sh
talosctl reset --nodes <node-ip> --graceful --reboot
```

This cordons the node in Kubernetes, drains its workloads, and — for a control plane node — leaves the `etcd` cluster cleanly, before wiping and shutting the node down. `--graceful` evicts pods immediately rather than waiting for a replacement to become ready elsewhere first — that's an ordinary Kubernetes `drain` characteristic, not something this module controls; it matters mainly for workloads that can't tolerate even a brief gap (consider `maxSurge`/multiple replicas/a storage class mountable from two nodes at once for those).

For a control plane node, confirm it actually left `etcd` before removing its entry:

```sh
talosctl --nodes <any-remaining-control-plane-ip> etcd members
```

Then remove its entry from `nodes` and run `terraform apply`.

> [!NOTE]
>
> If `terraform apply` then errors with something like `cluster health check failed` / `unexpected nodes with IPs [...]`, even though the node's VM was already destroyed successfully (confirmed in Proxmox) — the departed node's Kubernetes `Node` object doesn't get removed automatically just because the underlying VM did, and [`talos_cluster_health`](https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/cluster_health) fails on that stale, now-unreachable peer. Confirm with `kubectl get nodes` (the departed node shows `NotReady`), delete it (`kubectl delete node <name>`), and re-run `terraform apply` — it converges cleanly (`0 added, 0 changed, 0 destroyed`) once the stale object is gone. This doesn't mean the removal failed; the infrastructure change already took effect, the health check is just pickier than a plain VM destroy.

### Moving a Node to Another Proxmox Host

Relocating a node's physical placement (`nodes[].host_node`) without changing its logical identity (name, IP, `vm_id`) otherwise.

Changing `host_node` on an existing entry is **not** a live migration: the node's OS disk image is downloaded per-`host_node`, so changing it forces the VM to be destroyed on the old host and recreated on the new one — the same kind of destruction-and-recreation as any other [VM parameter change that can't be applied in place](#changing-other-vm-parameters). `terraform plan` shows this as `proxmox_virtual_environment_vm.this[...] must be replaced`.

- **Worker node**: change `host_node` in place on the existing entry and `terraform apply`. A worker losing its one instance briefly during the move carries no cluster-quorum risk.
- **Control plane node with other control plane nodes already present**: safe to change `host_node` in place as long as the remaining control plane nodes keep `etcd` quorum throughout — for a 3-node control plane, briefly taking one down to relocate it is the normal rolling-maintenance case. [Drain and leave `etcd` gracefully first](#ramping-down), same as any other control plane node removal, then change `host_node` and `apply`.
- **Control plane node in a single-control-plane cluster**: changing `host_node` in place would destroy and recreate the *only* control plane node directly — a full control plane outage for the duration, with real quorum risk if anything goes wrong mid-move. The safer path:
  1. [Add a second, interim control plane node](#ramping-up) on the target host and confirm it's healthy and in `etcd`.
  2. [Gracefully retire the original](#ramping-down) (drain, `etcd leave`, remove its entry, `apply`).

  This keeps the cluster on 2 control plane nodes only for the brief overlap window, never on zero.

> [!TIP]
>
> Starting with version 6.0 of `terraform-provider-talos`, this module supports [Talos OS upgrades](#talos-os-upgrade) with only one control plane node (see the note in [Preamble](#preamble)). That mechanism is specific to the `nodes[].update` flag and doesn't extend to a `host_node` change — the interim-node workaround above is still the safe path for relocating the sole control plane node of a single-control-plane cluster to a different Proxmox host.

> [!IMPORTANT]
>
> Two things that look like they could be the cause of a failed move are usually something else instead:
>
> - The `bpg/proxmox` Terraform provider needs direct SSH access (not just the Proxmox API) to the **target** Proxmox host for some disk operations when creating the new VM. If the session running `terraform apply` has no `ssh-agent` key authorized on that host, VM creation fails with `unable to authenticate user "root" over SSH`, even though everything else (API calls, Talos bootstrap) would otherwise work fine — this is not a sign that the control plane's VIP is unreachable or that `etcd leave` was skipped.
> - The stale-`Node`-object gotcha from [Ramping down](#ramping-down) applies here identically when retiring the original node.
>
> Separately, a control plane's VIP can take a short moment (roughly a minute) to become reachable again after migrating to a new node, due to ordinary ARP/routing propagation delay — transient, not a sign that something went wrong.

### Changing other VM parameters

You can change other VM parameters as available in the Proxmox [`nodes` variable](variables.md#nodes). A `terraform apply` will apply the changes accordingly.

Often, changing certain VM parameters (e.g. CPU, memory, disk size, network configuration) will cause a reboot or even destruction and recreation of the respective VM. When changing such parameters affecting multiple nodes at once, take care of not putting too many nodes offline at the same time. This can be done by changing the parameter only for one VM step-by-step or use [resource targeting](#resource-targeting). Also, especially in the case of destruction and recreation of VM resources, watch out for data persistence aspects, i.e. by having another replica of the data available on another node or backing up important data before applying the change.

### Changing other cluster parameters

Likewise, changing other cluster parameters as available in the [`cluster` variable](variables.md#cluster) (e.g. `extra_manifests`, `machine_features`) will cause the respective changes to be applied to the Talos Kubernetes cluster. A `terraform apply` will apply the changes accordingly.

## Terraform Module Version Upgrade

### Semantic Versioning, Changelog and Upgrade Notes

#### Semantic Versioning

> [!CAUTION]
>
> Never use `HEAD` or `main` branch references for the module source in production environments. Always use a specific version tag to ensure stability and predictability of your infrastructure.

Handling upgrades of the underlying `terraform-proxmox-talos` module version is similar to other terraform modules. Special care needs to be taken when there are breaking changes introduced in a new module version. As this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html), breaking changes will be introduced in major version upgrades only (e.g. v5.x.x to v6.x.x). Minor and patch version upgrades (e.g. v6.0.0 to v6.1.0 or v6.1.0 to v6.1.1) will be backward compatible.

#### Changelog

When upgrading the module version, please refer to the [Changelog](../CHANGELOG.md) for details on changes introduced in the new version. This document details additions, changes allowing you to leverage new features. It will also document deprecations and removals of features, variables and other aspects of the module, including any breaking changes introduced in the new version, which require special attention when upgrading.

#### Upgrade Notes

Some module version might introduce breaking changes which require manual intervention, e.g. changing variable names or adjusting configurations due to deprecated features. In rare cases, there might be changes requiring a destruction and recreation of resources managed by Terraform. The necessary steps will be documented in the [UPGRADE.md](../UPGRADE.md) document for each release. 

Follow the instructions provided in the [UPGRADE.md](../UPGRADE.md) document for any specific upgrade steps required.

### Steps to upgrade the module version

#### General Upgrade Steps

1. Update the module source reference in your `terragrunt.hcl` or `main.tf` file to point to the new version of the `terraform-proxmox-talos` module.
1. Review the [UPGRADE.md](../UPGRADE.md) document for any breaking changes or special upgrade instructions and follow the instructions provided for the new version.
1. Run `terraform init` to initialize the module with the new version. In some cases, you might need to run `terraform init -upgrade` to ensure all providers are updated as well.
1. Run `terraform plan` to see the changes that will be applied to your infrastructure.
1. If the plan looks good, run `terraform apply` to apply the changes and upgrade your infrastructure.
1. Monitor the upgrade process and ensure that all resources are updated successfully. Check the health of your Kubernetes cluster, the status of your nodes after the upgrade as well as the health of the workload running in the cluster.

#### Time for new features

When upgrading to a new module version, it's also a good time to review the new features and improvements introduced in the new version. Check the [Changelog](../CHANGELOG.md) for details on new features and consider leveraging them in your configuration to enhance your cluster's capabilities – after being sure you're still having a stable cluster.

### Resource Targeting

> [!TIP]
>
> Resource targeting is especially useful when upgrading the module version which might introduce breaking changes affecting multiple nodes at once. As such, this method can also be used for other upgrade scenarios described in this document (e.g. instead of using the [`nodes[].update` vehicle](#steps-to-upgrade-talos-os) which is just another, inbuilt notation of using the `-target` flag).
>
> You could also facilitate resource targeting for e.g.
>
> - Kubernetes version upgrades (using the `module.talos.data.talos_machine_configuration.this` resource),
> - VM configuration changes affecting multiple nodes at once (using the `module.talos.proxmox_virtual_environment_vm.this` resource).

In some cases, it might be necessary to use [Resource Targeting](https://developer.hashicorp.com/terraform/tutorials/state/resource-targeting) to upgrade specific resources managed by the module. This can be useful when you want (or need) to upgrade only certain aspects of the cluster without affecting others.

Resource targeting can be achieved by using the `-target` or `-exclude` flags with the `terraform apply` command. This allows you to specify which resources should be included or excluded from the apply operation. The `-exclude` flag is particularly useful when you want to exclude certain nodes from being upgraded during a module version upgrade or other configuration changes. Thus, you can perform a rolling upgrade of nodes by excluding some nodes in each `terraform apply` run.

The following command applies the new configuration by ommitting the change for nodes with names `controlplane2.example.com` and `worker2.example.com`, thus applying the change only to (potential) `controlplane1.example.com` and `worker1.example.com` hosts, for example:

```sh
terraform apply \
  -exclude 'module.talos.proxmox_virtual_environment_vm.this["controlplane2.example.com"]' \
  -exclude 'module.talos.proxmox_virtual_environment_vm.this["worker2.example.com"]'
```

The following command gives a list of all relevant nodes to be targeted or excluded for a rolling upgrade:

```sh
terraform state list | grep module.talos.proxmox_virtual_environment_vm.this
```

> [!IMPORTANT]
>
> When applying a critical change, be sure to exclude at minimum 1 control plane and a minimum of x worker nodes (depending on the workload deployed and availability of services during the change). Just add additional `-exclude` parameters if needed.

## Upgrade of inbuilt components

This section will handle the upgrade procedures of inbuilt components shipped with this terraform module, like Cilium CNI and Gateway API. It also covers [Proxmox CSI Plugin](https://github.com/sergelogvinov/proxmox-csi-plugin) which is really shipped with this module, rather it needs to installed on-top.

| Component                                                                 | Version configurable | Upgrade procedure                        |
| ------------------------------------------------------------------------- | -------------------- | ---------------------------------------- |
| [Cilium](https://cilium.io/)                                              | No                   | [See below](#cilium-upgrade) (Helm chart)            |
| [Gateway API](https://gateway-api.sigs.k8s.io/)                           | Yes                  | [See below](#gateway-api-upgrade) (variable `cluster.gateway_api_version`)       |
| [Proxmox CSI Plugin](https://github.com/sergelogvinov/proxmox-csi-plugin) | No                   | [See below](#proxmox-csi-plugin-upgrade) (Helm chart)|

### Cilium Upgrade

Out of the [3 stable branches](https://docs.cilium.io/en/stable/contributing/release/organization/) of [Cilium CNI](https://cilium.io/) (say 1.17, 1.18 and 1.19), this module is shipping with the most recent **previous minor** version of Cilium (here 1.18, i.e. X.Y-1.Z), i.e. `oldstable` in Debian terminology. This ensures that the Cilium version is stable and well tested, while still being relatively up-to-date, including bug fixes (cf. Cilium's [backporting process](https://docs.cilium.io/en/stable/contributing/release/backports/)). 

The Cilium version used is hardcoded in the module and documented in the [Changelog](../CHANGELOG.md). It is only used for the initial **installation** of Cilium, but not managed after that.

Thus, if you want to upgrade to another version of Cilium, you will have to install the [Cilium Helm chart](https://docs.cilium.io/en/stable/installation/k8s-install-helm/) on-top to upgrade the Cilium to another version.

### Gateway API Upgrade

#### Gateway API Version

The [Gateway API](https://gateway-api.sigs.k8s.io/) version can be upgraded by changing the [`cluster.gateway_api_version`](variables.md#definition-1) variable to the desired version. A `terraform apply` will apply the change accordingly. Check the [Cilium Gateway API documentation](https://docs.cilium.io/en/stable/network/servicemesh/gateway-api/gateway-api/) as well as the [Gateway API conformance documentation](https://gateway-api.sigs.k8s.io/implementations/#cilium) for details on compatibility and upgrade considerations before selecting a new version for the Gateway API.

#### Gateway API Standard and Experimental Channels

This module deploys the Gateway API CRDs and controller using the **standard installation** manifest from the Gateway API project. The manifest URL is constructed using the `cluster.gateway_api_version` variable as follows:
`https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.cluster.gateway_api_version}/standard-install.yaml`.

If you want to use the **experimental installation** channel instead, you will have to manually install or upgrade the Gateway API CRDs and controller outside of this module. This can be done by applying the experimental installation manifest from the Gateway API project: 
`https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.cluster.gateway_api_version}/experimental-install.yaml`. You can add this manifest to the [`cluster.extra_manifests`](variables.md#definition-1) variable to have it managed by Talos and a `terraform apply` as well. Alternatively, you can apply the manifest using `kubectl apply --server-side -f <manifest-url>` or declare it in e.g. `kustomize` YAML files.

See the [Gateway API installation documentation](https://gateway-api.sigs.k8s.io/guides/getting-started/#installing-gateway-api) for details on installing or upgrading the Gateway API CRDs and controller.

### Proxmox CSI Plugin Upgrade

While being crucial to get [`proxmox-csi`-type volumes](storage.md#types) working, the [Proxmox CSI Plugin](https://github.com/sergelogvinov/proxmox-csi-plugin) is not shipped with this module. You will have to install and configure the Proxmox CSI Plugin [Helm chart](https://artifacthub.io/packages/helm/proxmox-csi/proxmox-csi-plugin) as part of your Kubernetes management, outside of terraform. You will find instructions in the storage documentation for the [proxmox-csi configuration](storage.md#additional-configuration).
