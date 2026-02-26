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
| [**VM Configuration Changes**](#vm-configuration-changes)                 | Apply changes to **VM configurations** (e.g. CPU, memory), or **scale the cluster** (by adding or removing nodes from the cluster). |
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

1. First, set [`image.update_version`](variables.md#definition-3) to the required version you want to update to.
1. In the following, you will process each node subsequently. Set [`nodes[1].update = true`](variables.md#definition-4) for the 1st node and run `terraform apply`.
1. Set `nodes[2].update = true` for the 2nd node, _leave_ the previous node's `update = true` and run `terraform apply`.
1. Similarily to before, set `nodes[3].update = true` for the 3rd node, leave the previous nodes' `update = true` and run `terraform apply`.
1. ...
1. Set `nodes[n].update = true` for the n-th node, leave the previous nodes' `update = true` and run `terraform apply`.
1. After upgrading all nodes, set `image.version` to match the update version and reset `update = false` for all [nodes](variables.md#definition-4).

Also, **monitor the cluster health** closely during and after the upgrade process before carrying out the upgrade for the next node(s).

> [!TIP]
>
> There is a more elaborate description of the steps in [Vegard's blog post](https://blog.stonegarden.dev/articles/2024/08/talos-proxmox-tofu/#upgrading-the-cluster).

> [!TIP]
>
> **Multiple nodes can be upgraded in parallel** by setting `update = true` for multiple nodes before running `terraform apply` (e.g. a control plane and a worker node on another Proxmox host). When upgrading multiple nodes in parallel, ensure to exclude at minimum 1 control plane and a minimum of x worker nodes (depending on the workload deployed and availability of services during the change).

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
