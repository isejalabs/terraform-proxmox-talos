# Input Variables Documentation

This documentation describes all input variables for the `terraform-proxmox-talos` module. You will be given detailed description of each variable, its type, default value (if any) and an example usage.

For further usage instructions on using `terraform-proxmox-talos` module, please be referred to the [README](../README.md) file. There's also a [technical module documentation](module.md) available.

## ToC

For a quick overview of all variables, please see the following Table of Contents, linking to the sections with detailed description of the respective variable.

- [cilium_config](#cilium_config)
- [cluster](#cluster)
- [env](#env)
- [image](#image)
- [nodes](#nodes)
- [proxmox](#proxmox)
- [proxmox_api_token](#proxmox_api_token)
- [sealed_secrets_config](#sealed_secrets_config)
- [volumes](#volumes)

# Variables

## cilium_config

The `cilium_config` variable lets you set paths to custom configuration files for the [cilium Helm values file](https://docs.cilium.io/en/stable/helm-reference/) and cilium bootstrap manifest (installation), respectively.

If no files are provided, a decent default configuration is used.

### Definition

| Key                     | Description                                                | Type     | Default / Example                                                                                           |
| ----------------------- | ---------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------- |
| bootstrap_manifest_path |  Path to Cilium `install.yaml` manifest for cilium install | `string` | [`talos/inline-manifests/cilium-install.yaml`](../talos/inline-manifests/cilium-install.yaml)               |
| values_file_path        | Path to Helm `values.yaml` file for cilium install         | `string` | [`talos/inline-manifests/cilium-values.default.yaml`](../talos/inline-manifests/cilium-values.default.yaml) |

### Example

```terraform
bootstrap_manifest_path = "assets/cilium/install.yaml"
values_file_path        = "assets/cilium/values.yaml"
```

## cluster

### Definition

The Kubernetes cluster configuration defines its version and network configuration mainly.

| Key                              | Description                                                                                                                                                                                          | Type           | Default / Example   |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------- | ------------------- |
| gateway                          | **Required** network gateway                                                                                                                                                                         | `string`       | e.g. `"10.1.2.254"` |
| gateway_api_version              | **Required** [GW API version](https://gateway-api.sigs.k8s.io/concepts/versioning)                                                                                                                   | `string`       | e.g. `"v1.2.1"`     |
| kubernetes_version               | **Required** Kubernetes version to set independent from Talos image inbuilt version                                                                                                                  | `string`       | e.g. `"v1.33.0"`    |
| name                             | **Required** Arbitrary name of the Talos cluster                                                                                                                                                     | `string`       | e.g. `"dev-talos"`  |
| proxmox_cluster                  | **Required** Name of the Proxmox cluster used for Promox CSI<br>will get used for `topology.kubernetes.io/region` setting                                                                            | `string`       | e.g. `"proxmox"`    |
| allow_scheduling_on_controlplane | Allow scheduling of workloads on control planes                                                                                                                                                      | `bool`         | `false`             |
| api_server                       | Kube apiserver options (cf. [Talos apiServerConfig](https://www.talos.dev/v1.11/kubernetes-guides/configuration/inlinemanifests/#extramanifests) documentation)                                      | `string`       | `null`              |
| extraManifests                   | `List` of [`extraManifests`](https://www.talos.dev/v1.11/kubernetes-guides/configuration/inlinemanifests/#extramanifests) in Talos, e.g. experimental GW API features, Flux Controller or Prometheus | `list(string)` | `[]`                |
| kubelet                          | Kubelet config values(cf. [Talos kubeletConfig](https://www.talos.dev/v1.11/reference/configuration/v1alpha1/config/#Config.machine.kubelet)                                                         | `string`       | `null`              |
| machine_features                 | Machine features, cf. [Talos featuresConfig](https://www.talos.dev/v1.11/reference/configuration/v1alpha1/config/#Config.machine.features)                                                           | `string`       | `null`              |
| on_boot                          | Specifies whether all VMs will be started during system boot of the Proxmox server                                                                                                                   | `bool`         | `true`              |
| subnet_mask                      | Network subnet mask                                                                                                                                                                                  | `string`       | `"24"`              |
| talos_machine_config_version     | [Version of Talos](https://github.com/siderolabs/talos/releases) to use in generated machine configuration. Per default, the version defined in the `image` is used                                  | `string`       | `"v1.2.3"`          |
| vip                              | [Virtual (shared) IP](https://www.talos.dev/v1.11/talos-guides/network/vip/) for building a high-availability controlplane                                                                           | `string`       | `null`              |

### Example

```terraform
locals {
  gateway_api_version = "v1.3.0" # renovate: github-releases=kubernetes-sigs/gateway-api
}

cluster = {
  gateway             = "10.1.2.254"
  gateway_api_version = local.gateway_api_version
  kubernetes_version  = "v1.33.3" # renovate: github-releases=kubernetes/kubernetes
  name                = "dev-talos"
  proxmox_cluster     = "homelab"

  # optional
  allow_scheduling_on_controlplane = true
  api_server                       = <<-EOT
    extraArgs:
      oidc-issuer-url: "https://authelia.example.com"
      oidc-client-id: "kubectl"
      oidc-username-claim: "preferred_username"
      oidc-username-prefix: "authelia:"
      oidc-groups-claim: "groups"
      oidc-groups-prefix: "authelia:"
  EOT
  extra_manifests                  = [
    "https://github.com/fluxcd/flux2/releases/latest/download/install.yaml",
    "https://raw.githubusercontent.com/kubernetes-sigs/gateway-api/${local.gateway_api_version}/config/crd/experimental/gateway.networking.k8s.io_tlsroutes.yaml",
    "https://raw.githubusercontent.com/prometheus-community/helm-charts/refs/heads/main/charts/kube-prometheus-stack/charts/crds/crds/crd-servicemonitors.yaml",
  ]
  machine_features                 = <<-EOT
    # https://www.talos.dev/v1.8/kubernetes-guides/network/deploying-cilium/#known-issues
    hostDNS:
      forwardKubeDNSToHost: false
  EOT
  kubelet                          = <<-EOT
    registerWithFQDN: true
    extraArgs:
      # Needed for Netbird agent
      # see: https://kubernetes.io/docs/tasks/administer-cluster/sysctl-cluster/#enabling-unsafe-sysctls
      allowed-unsafe-sysctls: net.ipv4.conf.all.src_valid_mark
  EOT
  on_boot                          = false
  talos_machine_config_version     = "v1.2.3"
  vip                              = "10.20.30.40"
}
```

## env

### Definition

By setting the `env` variable (to e.g. `prod`, `qa`, `dev`), resources created by `terraform`/`tofu` will be prefixed with this value, thus ensuring names are not clashing when instantiating the module multiple times for establishing a multi-environment system. If no `env` value is provided, no prefixing is done.
While setting the `env` variable is optional, its usage is strongly recommended when using the `terraform-proxmox-talos` module in parallel in the same Proxmox envorinment.

| Description                            | Type     | Default / Example |
| -------------------------------------- | -------- | ----------------- |
| environment (e.g. `prod`, `qa`, `dev`) | `string` | `""` / `"dev"`    |

Setting the `env` variable, to e.g. `"dev"`, has an effect on the following resources:

| Resource                     | Default Name                                         | env-specific Name                                                                                                                     |
| ---------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Proxmox role for CSI         | `CSI`                                                | `dev-CSI`                                                                                                                             |
| Proxmox user for CSI plugin  | `kubernetes-csi@pve`                                 | `dev-kubernetes-csi@pve`                                                                                                              |
| Proxmox volume names for CSI | `vm-<vmid>-pv-<pvname>`<br><br>e.g. `vm-9999-pv-foo` | `vm-9999-dev-pv-foo`<br><br>another option is adjusting the `vmid` parameter (default `"9999"`) of the [`volumes`](#volumes) variable |
| Downloaded image file        | `talos-ce..15-v1.2.3-nocloud-amd64.img`              | `dev-talos-ce..15-v1.2.3-nocloud-amd64.img`                                                                                           |

### Example

```terraform
env = "dev"
```

## image

### Definition

The `image` parameter not only allows adjusting the downloaded Talos image by defining its extensions (schematic), version and other settings. The two `update_` attributes allow updating to another version or schematic definition; see the [upgrade documentation](upgrading.md) for more details.

| Key                     | Description                                                                                                                                                                       | Type     | Default / Example                    |
| ----------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------ |
| `schematic_path`        | **Required** Path to the file defining the Schematic ID for Talos image                                                                                                           | `string` | e.g. `"assets/talos/schematic.yaml"` |
| `version`               | **Required** [Talos version](https://github.com/siderolabs/talos/releases) with `v` prefix, e.g. `"v1.2.3"`                                                                       | `string` | e.g. `"v1.2.3"`                      |
| `arch`                  | Architecture                                                                                                                                                                      | `string` | `"amd64"`                            |
| `factory_url`           | Alternative [Talos Factory](https://factory.talos.dev/) URL                                                                                                                       | `string` | `"https://factory.talos.dev"`        |
| `platform`              | Typically left set to its default (`"nocloud"`), still allowing alternative configuration for [Talos platform](https://www.talos.dev/v1.10/talos-guides/install/cloud-platforms/) | `string` | `"nocloud"`                          |
| `datastore`             | Proxmox datastore used to store the image. Please do not use a shared storage as the image is expected to be downloaded for each Proxmox node separately                          | `string` | `"local"`                            |
| `update_schematic_path` | Path to an alternative schematic definition to be used when updating a node (c.f. [updating schematic documentation](upgrading.md#talos-schematic-upgrade))                                                                                                                  | `string` | `null`                               |
| `update_version`        | Alternative version definition to be used when updating a node (c.f. [updating Talos OS version documentation](upgrading.md#talos-os-upgrade))                                                                                                                   | `string` | `null`                               |

### Example

```terraform
image = {
  schematic_path = "assets/talos/schematic.yaml"
  version        = "v1.2.3"

  # optional
  arch                  = "arm64"
  factory_url           = "https://factory.example.com"
  platform              = "hcloud"
  datastore             = "local-zfs"
  update_schematic_path = "assets/talos/schematic-update.yaml"
  update_version        = "v4.5.6"
}
```

### Schematic

An example file content for the `schematic` file is shown below:

```yaml
customization:
  systemExtensions:
    officialExtensions:
      - siderolabs/qemu-guest-agent
```

See the [Talos Image Factory documentation](https://github.com/siderolabs/image-factory) for more guidance and examples.

## nodes

### Definition

The `nodes` variable defines the Talos VMs that form the cluster. It consists of a **map** with the _VM name_ as keys having the following attributes:

| Key           | Description                                                                                                | Type           | Default / Example                 |
| ------------- | ---------------------------------------------------------------------------------------------------------- | -------------- | --------------------------------- |
| cpu           | **Required** Number of CPU cores                                                                           | `number`       | e.g. `2`                          |
| host_node     | **Required** Hostname of the Proxmox node the Talos VM should get hosted                                   | `string`       | e.g. `"host1"`                    |
| ip            | **Required** IP address                                                                                    | `string`       | e.g. `"10.1.2.3"`                 |
| machine_type  | **Required** Type of kubernetes node, must be either `"controlplane"` or `"worker"`                        | `string`       | e.g. `"controlplane"`, `"worker"` |
| ram_dedicated | **Required** RAM size in MB                                                                                | `number`       | e.g. `4096`                       |
| vm_id         | **Required** Unique VM id in Proxmox cluster                                                               | `number`       | e.g. `123`                        |
| bridge        | Network bridge the VM connect to                                                                           | `string`       | `"vmbr0"`                         |
| cpu_type      | Proxmox [CPU type](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_cpu_type)                        | `string`       | `"x86-64-v2-AES"`                 |
| datastore     | The Proxmox datastore used to store the VM                                                                 | `string`       | `"local-zfs"`                     |
| disk_size     | VM disk size in GB, i.e. _without_ Unit of Measure suffix                                                  | `number`       | `20`                              |
| dns           | List of DNS servers                                                                                        | `list(string)` | `null`                            |
| igpu          | Passthrough of an iGPU                                                                                     | `bool`         | `false`                           |
| mac_address   | Custom MAC address, if no auto-assignment desired. Can be chosen from Proxmox' `BC:24:11` range            | `string`       | `null`                            |
| update        | If set to `true`, the node will get updated to the [`image.update_version`](#definition-3) and/or [`image.update_schematic`](#definition-3). See the [upgrade documentation](upgrading.md#steps-to-upgrade-talos-os) for more details. | `bool`         | `false`                           |
| vlan_id       | Network VLAN ID                                                                                            | `number`       | `0`                               |

### Example

```terraform
nodes = {
  "controller1" = {
    cpu           = 2
    host_node     = "pve1"
    ip            = "10.20.30.41"
    machine_type  = "controlplane"
    ram_dedicated = 4096
    vm_id         = 141
  }
  "worker1" = {
    cpu           = 4
    host_node     = "pve1"
    ip            = "10.20.30.42"
    machine_type  = "worker"
    ram_dedicated = 16384
    vm_id         = 142

    # optional
    bridge        = "mybridge"
    cpu_type      = "custom-x86-64-v2-AES-AVX"
    datastore     = "nfs"
    disksize      = 30  # 30 GB
    dns           = ["1.1.1.1", "9.9.9.9"]
    igpu          = true
    mac_address   = "BC:24:11:2E:C8:02"
    # update        = true  # leave this commented out usually!
    vlan          = 123
  }
}
```

## proxmox

Configuration for the connection to the Proxmox cluster, according to [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox). See also the module's [authentication documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#authentication) for further instructions.

### Definition

| Key          | Description                                                                                                                                                      | Type     | Default / Example                     |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------- |
| cluster_name | **Required** Name of the talos cluster                                                                                                                           | `string` | e.g. `"proxmox"`                      |
| endpoint     | **Required** Proxmox endpoint to connect to                                                                                                                      | `string` | e.g. `"https://pve.example.com:8006"` |
| insecure     | **Required** Skip endpoint TLS verification if set to `true`                                                                                                     | `bool`   | e.g. `false`                          |
| username     | **Required** Username for the SSH connection. A SSH connection is used to connect to the Proxmox server for operations that are not available in the Proxmox API | `string` | e.g. `"terraform"`                    |

### Example

```terraform
proxmox = {
  cluster_name = "proxmox"
  endpoint     = "https://pve.example.com:8006"
  insecure     = false
  username     = "terraform"
}
```

## proxmox_api_token

Configuration of the Proxmox API token needed for authorization with the Proxmox cluster. See also the [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox) module's [authentication documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#api-token-authentication) for further instructions.

### Definition

| Description           | Type     | Default / Example |
| --------------------- | -------- | ----------------- |
| API token for Proxmox | `string` | `null`            |

### Example

```terraform
proxmox_api_token = "terraform@pve!killertofu=01234567-89ab-cdef-0123-456789abcdef"
```

Proxmox authentication configuration contains confidential data you never should add to a VCS such as git. The following example uses a simple approach by refering to a variable `proxmox_api_token` which you could set as environment variable via `export TF_VAR_proxmox_api_token="<YOUR_API_TOKEN>"`.

Another approach could be:

- Define all proxmox configuration in a `*.auto.tfvars` (or `*.auto.tfvars.json`) variable definitions files, cf. [Variable Definitions (`.tfvars`) Files documentation](https://developer.hashicorp.com/terraform/language/values/variables#variable-definitions-tfvars-files), and `gitignore`the file(s).
- Same as above but encrypt the files with e.g. [SOPS](https://github.com/getsops/sops) so they can be kept in a VCS.

## sealed_secrets_config

### Definition

This optional variable lets you setting the path to the [SealedSecrets](https://github.com/bitnami-labs/sealed-secrets) `certificate` and `key`.
If no paths are given, the defaults are used. That said, you need to generate a certificate and key pair, nevertheless – see the below intructions given in [Generate SealedSecret certificate and key](#generate-sealedsecret-certificate-and-key).

| Key              | Description             | Type     | Default / Example                                         |
| ---------------- | ----------------------- | -------- | --------------------------------------------------------- |
| certificate_path | Path to the certificate | `string` | `"assets/sealed-secrets/certificate/sealed-secrets.cert"` |
| key_path         | Path to the key         | `string` | `"assets/sealed-secrets/certificate/sealed-secrets.key"`  |

### Example

```terraform
sealed_secrets_config = {
  certificate_path = "another/path/to/sealed-secrets.cert"
  key_path         = "another/path/to/sealed-secrets.key"
}
```

### Generate SealedSecret certificate and key

The procedure for generating the SealedSecret certificate and key is covered exhaustively in the [SealedSecret documentation](https://github.com/bitnami-labs/sealed-secrets/blob/main/docs/bring-your-own-certificates.md). In short, you can generate a valid certificate and key pair with the following command:

```sh
openssl req -x509 -days 365 -nodes -newkey rsa:4096 -keyout assets/sealed-secrets/certificate/sealed-secrets.key -out assets/sealed-secrets/certificate/sealed-secrets.cert -subj "/CN=sealed-secret/O=sealed-secret"
```

The command given above places the files in the default path (`"assets/sealed..."`).

## volumes

The `volumes` variable lets you configure additional storage volumes available to the cluster. The `type`s of storage volumes can be divided into two categories:

1. **CSI**: A [Container Storage Interface (CSI)](https://kubernetes.io/docs/concepts/storage/volumes/#csi) is a standardized API that enables the cluster to communicate with external storage systems. For the CSI to be usable, a CSI plugin needs to be set up in the cluster (similarly to a CNI). By defining a volume with the CSI category, a CSI plugin will get installed (currently, [proxmox-csi-plugin](https://github.com/sergelogvinov/proxmox-csi-plugin) only supported) and a [`PersistentVolume`](https://kubernetes.io/docs/concepts/storage/persistent-volumes/) [pre-provisioned](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/#pre-provisioned-volumes). You then only need to define a `PersistentVolumeClaim` in Kubernetes.

   If no CSI volume gets defined, the CSI plugin will get installed nevertheless. You then can leverage [dynamic volume provisioning](https://kubernetes.io/blog/2019/01/15/container-storage-interface-ga/#dynamic-provisioning).

2. **Talos Volume Mounts**: Talos v1.11 and v1.12 introduced so called [User Volumes](https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/storage-and-disk-management/disk-management/user) to treat local disk space specifically. They allow defining a `directory`, additional `disk` or `partition` to be mounted at `/var/mnt/<volume-name>`. The user volumes can be used simply for `hostPath` mounts in Kubernetes, but they can be used for other purposes as well, e.g. for [installing other CSI plugins in Talos](https://docs.siderolabs.com/kubernetes-guides/csi/storage#storage-clusters) (e.g. Longhorn, OpenEBS Mayastor).  
  This gives the possibility to use other storage backends than the inbuilt Proxmox CSI plugin.

### Types

The following volume types are supported:

| Type        | Description                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| directory   | A `directory` volume is simply a directory on the host filesystem mounted at `/var/mnt/<volume name>`. Hence, it's limited by the host’s EPHEMERAL partition. It is _not_ suitable for workloads that require predictable or enforceable storage quotas. |
| disk        | Creates a separate data disk in Proxmox which gets attached to the VM and mounted at `/var/mnt/<volume name>`. The Proxmox datastore to store the disk can be defined separately to the Talos VM. Due to its separate nature, the `disk` volume type is well suited for workloads that require predictable or enforceable storage quotas, e.g. a CSI.                                                                                                                      |
| partition   | **Not available currently**. Maybe subject for a later implementation. ([Issue #162](https://github.com/isejalabs/terraform-proxmox-talos/issues/162))<br><br>Usage of a dedicated partition on the underlying storage device.                                                                                                                                                                                                                                                                                                                             |
| proxmox-csi | Creation of a Persistent Volume (PV) using the [proxmox-csi-plugin](https://github.com/sergelogvinov/proxmox-csi-plugin). Creates a dedicated disk in Proxmox and a `PersistentVolume` in Kubernetes cluster for each volume. The volume's location needs to get specified in the `nodes` parameter to reflect Proxmox node the VM disk needs to be created. Also creates a corresponding `PersistentVolume` in Kubernetes with the same volume name.                      |

### Definition

The `volumes` variable is formed of a **map** consisting of the _volume name_ as key and the following attributes (depending on the `type` chosen, cf. table after the variable definition):

| Key          | Description                                                                                                                                                                                                                                                                                                   | Type     | Default / Example |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------------- |
| datastore    | Proxmox datastore used to store the volume<br><br>Optional for: disk, proxmox-csi                                                                                                                                                                                                                             | `string` | `"local-zfs"`     |
| format       | Disk format (`"raw"`, `"qcow"`)<br><br>Optional for: proxmox-csi                                                                                                                                                                                                                                              | `string` | `"raw"`           |
| machine_type | Type of kubernetes node, must be either `"all"`, `"controlplane"` or `"worker"` (default)<br><br>Optional for: directory, disk, partition                                                                                                                                                                                  | `string` | `"worker"`        |
| node         | Hostname of the Proxmox node where the volume should get stored<br><br>Needed for: proxmox-csi                                                                                                                                                                                                                | `string` | e.g. `"host1"`    |
| size         | Volume size _with_ unit suffix. In the case of `disk` type, only `GB` (or `G`) can be used<br><br>Needed for: all types                                                                                                                                                                                     | `string` | e.g. `"10"`       |
| type         | Typ of volume (`directory`, `disk`, `partition`, `proxmox-volume` (default))<br><br>Needed for: all types                                                                                                                                                                                                     | `string` | `"proxmox-csi"`   |
| vmid         | Alternative VM ID for naming the volume.<br>When using the module in multiple instances in the same Proxmox environment (host), e.g. for `prod` and `qa` instances, you need to set this parameter different per instance. Otherwise, volumes with the same name will clash.<br><br>Optional for: proxmox-csi | `number` | `9999`            |

### Usage of variables per volume `type`

| Variable     | default       | directory | disk | partition | proxmox-csi |
| ------------ | ------------- | :-------: | :--: | :-------: | :---------: |
| size         | –             |     X     |  X   |     X     |      X      |
| type         | `proxmox-csi` |     O     |  O   |     O     |      O      |
| machine_type | `worker`      |     O     |  O   |     O     |      –      |
| datastore    | `local-zfs`   |     –     |  O   |     –     |      O      |
| format       | `raw`         |     –     |  –   |     –     |      O      |
| node         | –             |     –     |  –   |     –     |      X      |
| vmid         | `9999`        |     –     |  –   |     –     |      O      |

> **Legend**:  
> **X** Required variable  
> **O** Optional variable  
> **–** Not used<br>

### Example

```terraform
volumes = {
  # a simple proxmox-csi volume with the bare minimum
  foo = {
    node = "pve1"
    size = "100M"               # size with unit suffix other than 'G' possible for proxmox-csi
  }

  # or more enhanced proxmox-csi volume
  bar = {
    node = "pve1"
    size = "20G"

    # optional
    format    = "qcow"          # variable should be kept set to its default "raw" value
    datastore = "nfs"
    type      = "proxmox-csi"   # default is "proxmox-csi" anyway
    vmid      = "9876"
  }

  # additional data disk
  longhorn = {
    size = "50G"                # size must be given with 'G'/'GB' suffix for 'disk' type
    type = "disk"
  }
}
```

### VM Disks Architecture

Depending on the volume `type` chosen, the volume space get created differently in Proxmox.

#### `directory` and `partition` volume types

> **Note**: The `partition` volume type is currently not implemented due to pending issue [#293](https://redirect.github.com/siderolabs/terraform-provider-talos/issues/293) in [siderolabs/terraform-provider-talos](https://github.com/siderolabs/terraform-provider-talos) module. They are mentioned here for completeness and future reference.

For `directory`, the volume is simply a directory on the host filesystem mounted at `/var/mnt/<volume name>`. Hence, it's limited by the host’s EPHEMERAL partition. The `directory` volume will get created for _all_ Talos VMs in the cluster, depending of their `machine_type` (i.e. `controlplane` or `worker` or `all`).

#### `disk` volume type

For `disk` type, a separate data disk gets created for each Talos VM matching the `machine_type` of the volume definition. For example, if a volume named `data-volume` of type `disk` is defined with `machine_type` set to `worker`, and there are 3 Talos VMs of type `worker` in the cluster, then 3 separate disks named `data-volume` will be created in Proxmox – one for each worker VM. Each disk gets attached to its respective VM and mounted at `/var/mnt/data-volume`. Likewise, multiple disks get created when multiple Talos VMs of the same `machine_type` exist, e.g. `controlplane` or `all` (for both `controlplane`s and `worker`s).

The disks get created and owned by a separate "data VM" as described in the [VMs documentation](vms.md#separation-of-talos-vm-and-data-vm).

#### `proxmox-csi` volume type

When using the `proxmox-csi` volume type, the volume disks get created on the Proxmox node where the Talos VM is hosted. This is because the Proxmox CSI plugin requires local storage access to create and manage the volume disks. Hence, the `node` parameter needs to be set accordingly. Still, the `datastore` parameter can be set to a _shared storage_ (e.g. NFS, CephFS) if desired.

Other than for other volume types, the volume disks for `proxmox-csi` volumes are created only _once_ in Proxmox, thus consuming storage space only _once_ – even when multiple Talos VMs get created.

The respective disk gets attached to the Talos VMs automatically, depending where the `Pod` gets scheduled. However, the disks can be attached only to _one_ Talos VM at a time, as the Proxmox CSI plugin creates `ReadWriteOnce` `PersistentVolume`s only.

Depending on the underlying storage (local or shared), this has the following implications:

- **Local storage**: When using local storage (e.g. `local-zfs`), the volume disk can be attached only to Talos VMs hosted on the same Proxmox node. If the Talos VM hosting the workload using the volume gets migrated to another Proxmox node, the volume will become unavailable until the VM gets migrated back to the original Proxmox node. Still, the volume can be used by other Talos VMs hosted on the same Proxmox node. 
This setup can be useful for workloads that do not require high availability, e.g. for development or testing purposes, or where local storage performance is critical.  

- **Shared storage**: When using shared storage (e.g. NFS, CephFS), the volume disk can be attached to any Talos VM in the cluster, regardless of the Proxmox node hosting the VM. This allows for high availability of workloads using the volume, as the Talos VM can be migrated to any Proxmox node without losing access to the volume. However, performance may be lower compared to local storage, depe  nding on the shared storage solution used.

# Useful Links

- [Cilium](https://docs.cilium.io/en/stable/)
- [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox)
- [Proxmox](https://www.proxmox.com/)
- [sergelogvinov/proxmox-csi-plugin](https://github.com/sergelogvinov/proxmox-csi-plugin)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Talos](https://www.talos.dev/)
- [Talos Image Factory documentation](https://github.com/siderolabs/image-factory)
