# Storage

This document covers the storage options supported by this terraform module. The following sections explain

- the different [volume types](#storage-volumes),
- the special handling of [proxmox-csi](#proxmox-csi-storage-need-to-know) and [disk](#disk-volumes-need-to-know) volume types, and
- how they are created in [Proxmox and Talos](#vm-disks-architecture).

## Storage Volumes

The [`volumes`](variables.md#volumes) variable lets you configure additional storage volumes available to the cluster. The `type`s of storage volumes can be divided into two categories:

1. **CSI**: A [Container Storage Interface (CSI)](https://kubernetes.io/docs/concepts/storage/volumes/#csi) is a standardized API that enables the cluster to communicate with external storage systems. For the CSI to be usable, a CSI plugin needs to be set up in the cluster (similarly to a CNI).

   By defining a volume with the CSI category, a CSI plugin will get installed (currently, [proxmox-csi-plugin](https://github.com/sergelogvinov/proxmox-csi-plugin) only supported) and a [`PersistentVolume`](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) [pre-provisioned](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/#pre-provisioned-volumes). You then only need to define a `PersistentVolumeClaim` in Kubernetes.

   If no CSI volume gets defined, you then can leverage [dynamic volume provisioning](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/#dynamic-provisioning) – by completing the [user-configured requirements](#user-configured-requirements).

2. **Talos Volume**: Talos v1.11 and v1.12 introduced so called [User Volumes](https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/storage-and-disk-management/disk-management/user) to treat local disk space specifically. They allow defining a `directory`, additional `disk` or `partition` to be mounted at `/var/mnt/<volume-name>`. The user volumes can be used simply for `hostPath` mounts in Kubernetes, but they can be used for other purposes as well, e.g. for [installing other CSI plugins in Talos](https://docs.siderolabs.com/kubernetes-guides/csi/storage#storage-clusters) (e.g. Longhorn, OpenEBS Mayastor).  
   This gives the possibility to use other storage backends than the inbuilt Proxmox CSI option.

### Types

The following volume types are supported:

| Type        | Description |
| ----------- | ----------- |
| directory   | A `directory` volume is simply a directory on the host filesystem mounted at `/var/mnt/<volume name>`. Hence, it's limited by the host’s EPHEMERAL partition. It is _not_ suitable for workloads that require predictable or enforceable storage quotas. |
| disk        | Creates a separate data disk in Proxmox which gets attached to the VM and mounted at `/var/mnt/<volume name>`. The Proxmox datastore to store the disk can be defined separately to the Talos VM. Due to its separate nature, the `disk` volume type is well suited for workloads that require predictable or enforceable storage quotas, e.g. a CSI. |
| partition   | **Not available currently**. Maybe subject for a later implementation ([Issue #162](https://github.com/isejalabs/terraform-proxmox-talos/issues/162)).<br><br>Usage of a dedicated partition on the underlying storage device. |
| proxmox-csi | Creation of a Persistent Volume (PV) using the [proxmox-csi-plugin](https://github.com/sergelogvinov/proxmox-csi-plugin). Creates a dedicated disk in Proxmox and a `PersistentVolume` in Kubernetes cluster for each volume. The volume's location needs to get specified in the `nodes` parameter to reflect Proxmox node the VM disk needs to be created. Also creates a corresponding `PersistentVolume` in Kubernetes with the same volume name. |

## Proxmox-CSI Storage – Need to know

This section covers important information about the `proxmox-csi` volume type, which is based on the [Proxmox-CSI driver](https://github.com/sergelogvinov/proxmox-csi-plugin). It includes details about the required [addional configuration](#additional-configuration) for using the Proxmox-CSI driver, as well as considerations for [pre-provisioning vs. dynamic provisioning](#pre-provisioning-vs-dynamic-provisioning-and-volume-naming) and [volume naming](#volume-naming-overview). Finally, it provides guidance on how to [prevent existing volumes from getting destroyed by terraform](#prevent-existing-volumes-from-getting-destroyed-by-terraform) when destroying and recreating the cluster.

### Additional Configuration

The [Proxmox-CSI](https://github.com/sergelogvinov/proxmox-csi-plugin) driver needs the following configuration. The check-marked items are done by the terraform module already while the remaining items need to be setup outside of the terraform module. See the official [Proxmox-CSI documentation](https://github.com/sergelogvinov/proxmox-csi-plugin?tab=readme-ov-file#installation) for further details on the configuration and installation of the driver. The following sections also include examples for the driver installation and storage class definition.

#### Pre-configured Requirements

The following requirements are pre-configured by the terraform module, so you don't need to worry about them:

- [x] **Proxmox _User_ with API Access**: A Proxmox user with sufficient permissions to create and manage storage volumes via the Proxmox API. The user credentials need to get provided to the Proxmox-CSI driver.
      The terraform module creates a Proxmox user named `<env>-kubernetes-csi@pve` and a role `<env>-CSI` with the required permissions automatically.
- [x] **Kubernetes _Secret_ for Proxmox API Credentials**: A Kubernetes `Secret` containing the Proxmox API user credentials (username and password or API token) needs to get created in the Kubernetes cluster. The Proxmox-CSI driver uses this secret to authenticate with the Proxmox API (leveraging the user specified before).

- [x] **Kubernetes _Namespace_ for Proxmox-CSI Driver**: A dedicated Kubernetes `Namespace` for the Proxmox-CSI driver needs to get created in the Kubernetes cluster. The driver components (e.g. `DaemonSet`, `Deployment`, etc.) need to get deployed in this namespace.

  The namespace created by terraform module is named `csi-proxmox` and needs to be used for the driver installation.

- [x] **Kubernetes _Topology Labels_**: To enable topology-aware volume provisioning and scheduling, the Proxmox-CSI driver relies on Kubernetes topology labels that represent the Proxmox node's topology (e.g. region, zone, etc.). These labels need to get defined on the Kubernetes nodes to allow the Proxmox-CSI driver to make informed decisions about where to provision volumes and schedule pods based on the underlying Proxmox node's topology.

  The terraform module automatically adds the following labels `topology.kubernetes.io/zone=<proxmox_node_name>` and `topology.kubernetes.io/region=<proxmox_cluster_name>` to each Kubernetes node, where `<proxmox_node_name>` is the name of the respective Proxmox node (used by `volumes[].node`) and `<proxmox_cluster_name>` is formed of the Proxmox cluster name (`cluster.proxmox_cluster`), as the driver can be used for multiple Proxmox clusters.

- [x] (Optional) **Kubernetes _Persistent Volume_ for Proxmox-CSI Volumes**: For each volume of type `proxmox-csi` defined in the `volumes` variable, a corresponding Kubernetes `PersistentVolume` will get created in the Kubernetes cluster. The `PersistentVolume` will have the same name as the volume name defined in the terraform configuration and is referring a `StorageClass` named `proxmox-csi` – which needs to get created in order to use preprovisioning.

  If you don't specify any `proxmox-csi` volumes in the `volumes` variable, no `PersistentVolume`s will get created by the terraform module. However, you can leverage [dynamic volume provisioning](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/#dynamic-provisioning).

#### User-Configured Requirements

The following requirements need to get configured by the user to be able to use the Proxmox-CSI driver and the `proxmox-csi` volume type (see also the official [Proxmox-CSI documentation](https://github.com/sergelogvinov/proxmox-csi-plugin?tab=readme-ov-file#installation) for further details):

- [ ] **Proxmox-CSI _Driver_ Installation**: The Proxmox-CSI driver needs to get installed in the Kubernetes cluster to be able to use the `proxmox-csi` volume type.

  Installation of the CSI driver is out-of-scope of this terraform module. It can be installed via Helm chart (cf. [`helmCharts` kustomize example](#helm-chart-deployment-kustomize-example) below).

- [ ] **_Storage Class_ Definition**: One or more `StorageClass`es need to get defined in the Kubernetes cluster to specify the Proxmox-CSI driver as the provisioner for volume provisioning. The `StorageClass` can include parameters such as `datastore`, `fstype`, `reclaimPolicy`, etc.

  You need to define at minimum a `StorageClass` named `proxmox-csi` used for `PersisentVolume`s preprovisioned by the `volumes` variable.

  The `StorageClass` definition is out-of-scope of this terraform module. It can be defined via Helm chart values (cf. [`values.yaml` example](#valuesyaml-example) below) or via separate Kubernetes manifests.

- [ ] **_PersistentVolumeClaim_ Definition**: To use the `proxmox-csi` volumes in Kubernetes workloads, `PersistentVolumeClaim`s need to get defined to bind the pre-provisioned `PersistentVolume`s created by the Proxmox-CSI driver to the workloads.

#### Helm Chart Deployment – Kustomize Example

The following kustomize example shows how to deploy the Proxmox-CSI driver via its Helm chart.

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

helmCharts:
  - name: proxmox-csi-plugin
    repo: oci://ghcr.io/sergelogvinov/charts
    version: 0.5.3
    releaseName: proxmox-csi-plugin
    includeCRDs: true
    namespace: csi-proxmox
    valuesFile: values.yaml
```

#### values.yaml Example

At minimum, a `StorageClass` named `proxmox-csi` needs to get defined in the `values.yaml` file which will be used for any pre-provisioned volumes defined in the `volumes` variable. Adjust the parameters according to your setup.

You can define additional `StorageClass`es as needed.

```yaml
# values.yaml
storageClass:
  - name: proxmox-csi
    cache: writethrough
    fstype: ext4
    reclaimPolicy: Retain
    ssd: true
    storage: local-zfs
    mountOptions:
      - noatime
```

### Pre-provisioning vs. Dynamic Provisioning – and volume naming

Kubernetes supports two main methods for provisioning storage volumes: pre-provisioning and [dynamic provisioning](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/#dynamic-provisioning). The methods not only define the approach for volume provisioning, they also have a big influence on the volume **naming**.

#### Key Differences

- **Pre-provisioning**: In this method, storage volumes are created manually or via automation before they are used by Kubernetes workloads. This can be accomplished by using the `volumes` variable: The module creates a `PersistentVolume` for each volume of type `proxmox-csi` defined in the `volumes` variable automatically. These `PersistentVolume`s are then available for binding to `PersistentVolumeClaim`s in Kubernetes workloads.

  The `PV`s **name** matches the volume name, hence it can get referenced in `PersistentVolumeClaim`s and identified in Proxmox easily.

- **Dynamic provisioning**: In this method, storage volumes are created on-demand when a `PersistentVolumeClaim` is created in Kubernetes. The Proxmox-CSI driver can dynamically provision storage volumes based on the `StorageClass` parameters when a `PersistentVolumeClaim` is created without a pre-provisioned `PersistentVolume` available.

  The `PV`s name is chosen by Kubernetes automatically and uses an arbitrary naming scheme.

#### Volume Naming Overview

| Resource / Provisioning Method | Pre-provisioning | Dynamic provisioning |
| ------------------------------ | ---------------- | -------------------- |
| Kubernetes `PersistentVolume` Name | Volume name defined in `volumes` variable, e.g. `foo` | Automatically generated name, e.g. `pvc-1234abcd-5678-efgh-9012-ijklmnopqrst` |
| Proxmox Disk Name (derived from the `PV` name)<br><br>Naming scheme: `vm-<vmid>-<env>-<volume-name>`<br><br> | Example: `vm-9999-foo` (where `9999` is the default value for the `volumes.vmid` variable which can be adjusted as needed) | Example: `vm-9999-pvc-1234abcd-5678-efgh-9012-ijklmnopqrst` |

### Prevent existing volumes from getting destroyed by terraform

When destroying and recreating the cluster, existing volumes of type `proxmox-csi` get destroyed by terraform by default, as they are defined in terraform configuration and thus managed by terraform. This can lead to data loss if the volumes contained any data.

You can prevent existing volumes from getting destroyed by terraform when destroying and recreating the cluster. This can be achieved by removing them from terraform state and importing them into terraform state after the cluster's destruction and before its recreation. The following steps need to be carried out:

1. **Removing the existing volumes from terraform state**: You can remove the existing volumes from terraform state using the `terraform state rm` command. This way, terraform will not be aware of the existing volumes and won't attempt to destroy them when destroying the cluster. The remove command would look like this:

   ```sh
    terraform state rm 'module.volumes.module.proxmox-volume["<volume_name>"].restapi_object.proxmox-volume'
   ```

   where `<volume_name>` is the name of the volume as defined in your terraform configuration, double quoted.

   The following command can be used to iterate over all proxmox volumes in terraform and remove their state without having to specify the volume names manually:

   ```sh
   for i in $(terragrunt state list | grep module.volumes.module.proxmox-volume); do terragrunt state rm "$i"; done
   ```

   This will remove the state for all volumes of type `proxmox-csi` from terraform state.

1. **Destroying the cluster**: After removing the existing volumes from terraform state, you can destroy the cluster using the `terraform destroy` command. This will destroy all resources defined in your terraform configuration except for the volumes that have been removed from state.
1. **Importing the existing volumes into terraform state**: You can import the existing volumes into terraform state using the `terraform import` command. This way, terraform will be aware of the existing volumes and won't attempt to destroy them when destroying the cluster.

   The import command would look like this:

   ```sh
   terraform state import 'module.volumes.module.proxmox-volume["<volume_name>"].restapi_object.proxmox-volume' /api2/json/nodes/<proxmox_node>/storage/<datastore>/content/<datastore>:vm-<vmid>-<env>-<volume_name>
   ```

   where
   - `<volume_name>` is the name of the volume as defined in your terraform configuration,
   - `<proxmox_node>` is the name of the Proxmox node where the volume is located,
   - `<datastore>` is the identifier of the datastore in Proxmox,
   - `<vmid>` VM ID, and
   - `<env>` is the value of the _optional_ `env` variable used in your terraform configuration (if any, otherwise it is not part of the volume name, including the `-` for separating it from the volume name).

   The following command imports the volume named `foo` located on Proxmox node `pve1` in datastore `local-zfs` and the (default) vmid `9999` – with and without an example environment `dev` – into terraform state:

   ```sh
   # without any environment
   terraform state import 'module.volumes.module.proxmox-volume["foo"].restapi_object.proxmox-volume' /api2/json/nodes/pve1/storage/local-zfs/content/local-zfs:vm-9999-foo

   # with example environment env="dev"
   terraform state import 'module.volumes.module.proxmox-volume["foo"].restapi_object.proxmox-volume' /api2/json/nodes/pve1/storage/local-zfs/content/local-zfs:vm-9999-dev-foo
   ```

1. **Recreating the cluster**: After importing the existing volumes into terraform state, you can recreate the cluster using the `terraform apply` command. This will create all resources defined in your terraform configuration, including the `PV`s for the volumes that have been imported into state.

Please note that you still need to ensure that the existing volumes are defined in your terraform configuration (in the `volumes` variable) with the same configuration as they have in Proxmox to prevent terraform from attempting to modify them during the apply phase.

## Disk Volumes – Need to know

Disk volumes are created as additional disks in Proxmox (besides the `/var` EPHEMERAL disk). They are owned by a separate data VM and attached to the respective Talos VM (cf. [separation of Talos VM and data VM](vms.md#separation-of-talos-vm-and-data-vm)).

When using disk volumes, be aware of the following limitations and implications when using [multiple disk volumes](#multiple-disk-volumes-handling) and when [removing a disk volume](#removing-a-disk-volume-the-need-for-manual-handling).

### Multiple disk volumes handling

#### The problem with lexical ordering of disk volumes

Adding (or removing) a disk volume of type `disk` can lead to **changes of exising disk** volumes (or those left after the removal). This is due to two limitations:

1. The order of disks in Proxmox does not equal their order in the `volumes` variable, instead the **lexical order** of the volume names defines their order in Proxmox. This creates an issue when another disk volume gets added with a name that is lexically before the existing disk volume(s).
1. Disks don't have a unique identifier in Proxmox which could identify them during their lifecycle. This creates a general issue in managing the disks in Proxmox: Any change to list of disks (adding or removing a disk) leads 

**Example 1 – adding another disk:** Given an initial configuration with one disk volume defined in the `volumes` variable...

```hcl
# initial configuration with one disk volume
volumes = {
  test-disk1 = {
    size = "1Gi"
    type = "disk"
  }
}
```

... and a configuration change adding a new disk volume _after_ the 1st/existing disk:

```hcl
# configuration change adding a new disk volume
volumes = {
  test-disk1 = {
    size = "1Gi"
    type = "disk"
  }
  atest-disk2 = {     <-- new disk volume added after the existing disk
    size = "2Gi"
    type = "disk"
  }
}
```

The Terraform plan reveals that the existing 1st disk used by the `test-disk1` volume gets updated in-place with a size change from `1Gi` to `2Gi` and a new disk volume gets added with a size of `1Gi` (which will be used for the former only disk `test-disk1` and not for the added 2nd volume `atest-disk`). This is because the order of the disk volumes in Proxmox is defined by the **lexical order of the volume names** in the `volumes` variable: 1st disk volume in Proxmox `atest-disk2` (with `2Gi`), while the 2nd disk volume is formed of `test-disk1` (with size `1Gi`) in Proxmox:

```terraform
$ terraform plan
...
# module.talos.proxmox_virtual_environment_vm.data_vm["work-01.example.com"] will be updated in-place
~ resource "proxmox_virtual_environment_vm" "data_vm" {
      id                                   = "123"
      name                                 = "work-01.example.com-data"
      tags                                 = [
          "k8s",
      ]
      # (31 unchanged attributes hidden)
    ~ disk {
        ~ size              = 1 -> 2        <-- size change of the existing 1st disk
          # (11 unchanged attributes hidden)
      }
    + disk {
        + aio          = "io_uring"
        + backup       = true
        + cache        = "writethrough"
        + datastore_id = "local-enc"
        + discard      = "on"
        + file_format  = "raw"
        + interface    = "scsi2"
        + iothread     = true
        + replicate    = true
        + size         = 1                  <-- 2nd disk volume added is the former only disk with 1 GiB size
        + ssd          = true
      }
      # (1 unchanged block hidden)
  }
```

When **removing a disk** from a set of disks, the same issue can occur, even when the disks are in lexical order in the `volumes` variable. In addition to the issue with the lexical ordering, there is also an issue with terraform's handling of removing disk volumes as described in a [dedicated section](#removing-a-disk-volume-the-need-for-manual-handling).

#### How to deal with the issues arising from multiple disk volumes

There's no real solution to the issue with the current implementation, as it is based on the limitations of Proxmox and the management. However, there are some options to mitigate the issue:

1. The best way to deal with the issue is to avoid it in the first place by **only using one disk volume** of type `disk` in the `volumes` variable.
1. When using multiple disk volumes, nevertheless, try to **add or remove only volumes whose name comes after existing volume names** in regards to their lexical order.
1. If naming the volumes in a way that their lexical order matches the desired order of the disks in Proxmox is not possible, you need to **remove all conflicting disk volumes from the `volumes` variable**, apply the changes to remove the disks from Proxmox, and then add the conflicting disk volumes again including the desired configuration.

    You need to make sure to **backup any important data** on the disks before removing them from Proxmox, as this process will lead to data loss on the respective disks. If the disks are used for a storage backend that uses replication, you can mitigate the risk of data loss by ensuring that the data is replicated to other disks before removing the disks from Proxmox and use [resource targeting](upgrading.md#resource-targeting) to apply the change to only one disk.

### Removing a disk volume – the need for manual handling

#### The problem with terraform's handling of removing resources

When a disk volume of type `disk` gets removed from the `volumes` variable, terraform will attempt to remove the respective disk from Proxmox. Besides the general potential issue of data loss, this can lead to two issues in the current implementation:

1. **Issue with disk attachment to Talos VM**: When removing a disk volume, terraform will attempt to remove the respective disk from both the data VM and the Talos VM in Proxmox. Unfortunately, terraform is not able to remove the disk from both VMs properly because it is trying the removal in the wrong order (data VM before Talos VM instead of from Talos VM first).
1. **Issue with terraform not removing the disks according the plan**: When removing a disk volume, terraform will show in the plan that the respective disk gets removed from Proxmox. However, when applying the changes, terraform will not carry out the changes accordingly. This looks like an issue in the terraform provider, as it is not able to remove the disk from Proxmox as planned and also not detecting that the disks are still present in Proxmox after the pseudo-apply (see upstream issue [bpg/terraform-provider-proxmox#2596](https://redirect.github.com/bpg/terraform-provider-proxmox/issues/2596), tracked internally as [#197](https://redirect.github.com/isejalabs/terraform-proxmox-talos/issues/197)).

#### How to deal with the issues arising from terraform's handling of removing disk volumes

The best way to deal with the issues is to **combine manual handling and terraform** when removing a disk volume of type `disk`:

1. First, **manually remove the disk from Proxmox** via the Proxmox UI or API. Make sure to remove the disk from  the Talos VM first and then from the data VM to avoid issues with disk attachment. 
1. Then, remove the disk volume from the `volumes` variable in your terraform configuration and **apply the changes with terraform**.

A future version of the terraform provider might solve the issue [#197](https://redirect.github.com/isejalabs/terraform-proxmox-talos/issues/197) with removing the disks properly, which would allow to remove disk volumes with terraform without manual intervention.

## Architecture of the Volumes in Proxmox and Talos

Depending on the volume [`type`](#types) chosen, the volume space get created differently in Proxmox.

### `directory` and `partition` volume types

> [!NOTE] 
> The `partition` volume types is currently not implemented due to its difficulty to provisioning and partioning disks in Proxmox. It is mentioned here for completeness and future reference.

The `directory` and `partition` volume types do not require separate disks in Proxmox. The `directory` volume type simply creates a directory on the host filesystem and mounts it at `/var/mnt/<volume name>`. Hence, it's limited by the host’s EPHEMERAL partition.

The `partition` volume type would require a separate partition on the underlying storage device, which is currently not implemented.

By default, the volume types `directory` (and `disk`) get created for all _Worker_ Kubernetes nodes (Talos VMs with [`nodes[].machine_type="worker"`](variables.md#definition-4)) in the cluster. You can adjust the volume creation to specific Talos VM types by setting the optional `machine_type` parameter to `controlplane`, `worker` (default) or `all` in the [`volumes[]`](variables.md#definition-8) definition. This might be useful for special use cases, when workloads are supposed to run on control plane nodes as well (which can get achieved by setting [`cluster.allow_scheduling_on_controlplane="true"`](variables.md#definition-1)).

You can list the created volumes in Talos with the `talosctl get mountstatus` command, which will show the respective mountpoints (e.g. `/var/mnt/test-dir1`).

```sh
❯ talosctl get mountstatus -n 10.7.8.195
NODE         NAMESPACE   TYPE          ID              VERSION   SOURCE      TARGET               FILESYSTEM   VOLUME
...
10.7.8.195   runtime     MountStatus   /var/mnt        5                     /var/mnt             none         /var/mnt
10.7.8.195   runtime     MountStatus   /var/run        3                     /var/run             none         /var/run
10.7.8.195   runtime     MountStatus   /var/run/lock   2                     /var/run/lock        none         /var/run/lock
10.7.8.195   runtime     MountStatus   EPHEMERAL       5         /dev/sdb1   /var                 xfs          EPHEMERAL
10.7.8.195   runtime     MountStatus   u-test-dir1     2                     /var/mnt/test-dir1   none         u-test-dir1
```

### `disk` volume type

For `disk` type, a separate data disk gets created for each Talos VM matching the `machine_type` – similar to the `directory` and `partition` volume types. However, unlike those types, the `disk` type creates a separate disk in Proxmox for each Talos VM with the respecitve `machine_type`.

The disks get created and owned by a separate "data VM" as described in the [VMs documentation](vms.md#separation-of-talos-vm-and-data-vm) and attached to their respective worker and/or controlplane VMs.The disks get formatted with the XFS filesystem automatically and mounted at the respective mountpoint here `/var/mnt/<volume_name>`. 

You can list the created volumes in Talos with the `talosctl disk list` command (for seeing the disks) and the `talosctl get mountstatus` command, which will show the respective mountpoints (e.g. `/var/mnt/test-disk1`) and their size.

The **disks** created (here with `sdc` as the disk for the `disk` volume type and `sda` and `sdb` as the OS and EPHEMERAL disks, see [separation of Talos VM and data VM](vms.md#separation-of-talos-vm-and-data-vm)):

```sh
❯ talosctl get disks -n 10.7.8.155
NODE         NAMESPACE   TYPE   ID      VERSION   SIZE     READ ONLY   TRANSPORT   ROTATIONAL   WWID   MODEL           SERIAL
10.7.8.155   runtime     Disk   loop0   2         4.1 kB   true
10.7.8.155   runtime     Disk   loop1   2         692 kB   true
10.7.8.155   runtime     Disk   loop2   2         75 MB    true
10.7.8.155   runtime     Disk   sda     2         5.4 GB   false       virtio                          QEMU HARDDISK          <-- OS disk
10.7.8.155   runtime     Disk   sdb     2         6.4 GB   false       virtio                          QEMU HARDDISK          <-- EPHEMERAL disk
10.7.8.155   runtime     Disk   sdc     4         1.1 GB   false       virtio                          QEMU HARDDISK          <-- data disk disk
10.7.8.155   runtime     Disk   sr0     2         4.2 MB   false       sata        true                QEMU DVD-ROM
```

Likewise, the **mountpoints** created (here with `/var/mnt/test-disk1` as the mountpoint for the `disk` volume type, and also showing an example mountpoint for the `directory` volume type):

```sh
❯ talosctl get mountstatus -n 10.7.8.155
NODE         NAMESPACE   TYPE          ID              VERSION   SOURCE      TARGET                FILESYSTEM   VOLUME
...
10.7.8.155   runtime     MountStatus   /var/mnt        8                     /var/mnt              none         /var/mnt
10.7.8.155   runtime     MountStatus   /var/run        3                     /var/run              none         /var/run
10.7.8.155   runtime     MountStatus   /var/run/lock   2                     /var/run/lock         none         /var/run/lock
10.7.8.155   runtime     MountStatus   EPHEMERAL       7         /dev/sdb1   /var                  xfs          EPHEMERAL
10.7.8.155   runtime     MountStatus   u-test-dir1     2                     /var/mnt/test-dir1    none         u-test-dir1
10.7.8.155   runtime     MountStatus   u-test-disk1    2         /dev/sdc    /var/mnt/test-disk1   xfs          u-test-disk1
```

### `proxmox-csi` volume type

When using the `proxmox-csi` volume type, _one_ volume disk gets created on the Proxmox node as specified in the `volumes.node` attribute. Other than for other volume types, the volume disks for `proxmox-csi` volumes are created only _once_ in Proxmox, thus consuming storage space only _once_ – even when multiple Talos VMs get created on the same node.

The respective disk gets attached to the Talos VMs automatically, depending where the `Pod` gets scheduled. However, the disks can be attached only to _one_ Talos VM at a time, as the Proxmox CSI plugin creates `ReadWriteOnce` `PersistentVolume`s only.

The scheduling of the `Pod` using the volume is determined by Kubernetes and depends on the availability of the volume on the respective Proxmox node. Depending on the underlying storage (local or shared), this has the following implications:

- **Local storage**: When using local storage (e.g. LVM, ZFS), the volume disk can be attached only to Talos VMs hosted on the same Proxmox node. If the Talos VM hosting the workload using the volume gets offline or migrated to another Proxmox node, the volume will become unavailable until the VM gets available back on the original Proxmox node. Still, the volume can be used by other Talos VMs hosted on the same Proxmox node.
  This setup can be useful for workloads that do not require high availability or where local storage performance is critical.

- **Shared storage**: When using shared storage (e.g. NFS, CephFS), the volume disk can be attached to any Talos VM in the cluster, regardless of the Proxmox node hosting the VM. This allows for high availability of workloads using the volume, as the Talos VM can be migrated to any Proxmox node without losing access to the volume. However, performance may be lower compared to local storage, depending on the shared storage solution used.

The [Proxmox CSI documentation](https://github.com/sergelogvinov/proxmox-csi-plugin?tab=readme-ov-file) provides further details on the implications of using local vs. shared storage with the Proxmox-CSI driver: 

![ProxmoxClusers!](https://github.com/sergelogvinov/proxmox-csi-plugin/blob/main/docs/proxmox-regions.gif)

## Further Reading

- [Vegard Stenhjem Hagen](https://github.com/vehagn)'s [blog](https://blog.stonegarden.dev) has a great article on using the Proxmox-CSI plugin with Kubernetes, which also includes a detailed walkthrough of the setup process and configuration: [Kubernetes Proxmox Container Storage Interface](https://blog.stonegarden.dev/articles/2024/06/k8s-proxmox-csi/).
- The official documentation of the Proxmox-CSI plugin also provides useful information on the installation, configuration and usage of the driver: [Proxmox-CSI Plugin Documentation](https://github.com/sergelogvinov/proxmox-csi-plugin?tab=readme-ov-file#overview).
- The [Talos documentation](https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/storage-and-disk-management/disk-management/user) on user volumes provides insights into the different types of Talos volumes and their configuration: [Talos User Volumes](https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/storage-and-disk-management/disk-management/user).
