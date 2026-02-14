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

If no files are provided, a decent [default configuration](../talos/inline-manifests/) is used.

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

While setting the `env` variable is optional, its usage is strongly recommended when using the `terraform-proxmox-talos` module in parallel in the same Proxmox environment.

| Description                            | Type     | Default / Example |
| -------------------------------------- | -------- | ----------------- |
| environment (e.g. `prod`, `qa`, `dev`) | `string` | `""` / `"dev"`    |

### Example

```terraform
env = "dev"
```

Setting the `env` variable, to e.g. `"dev"`, has an effect on the following resources:

| Resource                     | Default Name (without `env` set) | `env`-specific Name |
| ---------------------------- | -------------------------------- | ------------------- |
| Proxmox role for CSI:<br>`<env>-CSI` | `CSI`                    | `dev-CSI`           |
| Proxmox user for CSI plugin:<br>`<env>-kubernetes-csi@pve` | `kubernetes-csi@pve` | `dev-kubernetes-csi@pve`|
| Proxmox disk names for CSI:<br>`vm-<vmid>-<env>-<volname>` | `vm-9999-foo` | `vm-9999-dev-pv-foo`<br><br>While adjusting the [`volumes.vmid`](#definition-8) parameter (default `"9999"`) variable looks like another option to prevent name clashes in a multi-environment, the recommended way is using the `env` variable for separating *multiple environments* and using the `volumes.vmid` for separating proxmox-csi volumes/disks from a potential *VM with the same ID* (where this VM's ID cannot get changed) |
| Downloaded image file        | `talos-ce..15-v1.2.3-nocloud-amd64.img` | `<env>-talos-<schematic>-<version>-<platform>-<arch>.img`<br>e.g. `dev-talos-ce..15-v1.2.3-nocloud-amd64.img` |

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
    disk_size     = 30      # 30 GB
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

The `volumes` variable lets you configure additional storage volumes available to the cluster. The supported storage options are described in the [storage documentation](storage.md).


### Definition

The `volumes` variable is formed of a **map** consisting of the _volume name_ as key and the following attributes (depending on the `type` chosen, cf. table after the variable definition):

| Key          | Description                                                                                                                                                                                                                                                                                                   | Type     | Default / Example |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------------- |
| size         | **Required** Volume size with unit suffix, with _differing_ Unit of Measure (UoM) handling per volume `type`:<br>- `directory`: size can have any value and will be ignored as it's not relevant<br>- `disk`: only `GB` (or `G` and `GiB`) can be used, no `M`, `T` or other magnitude<br>- `proxmox-csi`: UoM needs to omit the `B`(Byte) suffix, i.e. `10G` mean `10GB`<br><br>Needed for: all types (can't get omited for `directory` type) | `string` | e.g. `"10G"`       |
| datastore    | Proxmox datastore used to store the volume<br><br>Optional for: disk, proxmox-csi                                                                                                                                                                                                                             | `string` | `"local-zfs"`     |
| format       | Disk format (`"raw"`, `"qcow"`)<br><br>Optional for: proxmox-csi                                                                                                                                                                                                                                              | `string` | `"raw"`           |
| machine_type | Type of kubernetes node, where the Talos [User Volume](https://docs.siderolabs.com/talos/v1.12/configure-your-talos-cluster/storage-and-disk-management/disk-management/user) should get created. Must be either `"all"`, `"controlplane"` or `"worker"` (default)<br><br>Optional for: directory, disk, partition                                                                                                                                                                     | `string` | `"worker"`        |
| node         | Hostname of the Proxmox node where the volume should get stored<br><br>Needed for: proxmox-csi                                                                                                                                                                                                                | `string` | e.g. `"host1"`    |
| type         | Type of volume (`directory`, `disk`, `proxmox-volume` (default)). See the [storage documentation](storage.md) for more details.<br><br>Needed for: all types                                                                                                                                                                                                     | `string` | `"proxmox-csi"`   |
| vmid         | Alternative VM ID for *naming* the volume. Do not mix up with the VM ID the volume gets bound to – which is driven by the proxmox-csi plugin dynamically.<br><br>When using a volume in multiple instances in the same Proxmox environment, e.g. for `prod` and `qa` instances, you need to use the [`env`](#env) variable for proper separation. The purpose of the `vmid` attribute is separation from a potential unrelated VM with the same ID (where the VM's ID cannot get changed) – or where the default `9999` is not your liking.<br><br>Optional for: proxmox-csi | `number` | `9999`            |

### Usage of variables per volume `type`

| Variable     | default       | directory | disk | partition* | proxmox-csi |
| ------------ | ------------- | :-------: | :--: | :--------: | :---------: |
| size         | –             |     X     |  X   |     X      |      X      |
| type         | `proxmox-csi` |     X     |  X   |     X      |      O      |
| machine_type | `worker`      |     O     |  O   |     O      |      –      |
| datastore    | `local-zfs`   |     –     |  O   |     –      |      O      |
| format       | `raw`         |     –     |  –   |     –      |      O      |
| node         | –             |     –     |  –   |     –      |      X      |
| vmid         | `9999`        |     –     |  –   |     –      |      O      |

> **Legend**:  
> **X** Required variable  
> **O** Optional variable  
> **–** Not used  
> _*_ Not available currently  

### Example

```terraform
volumes = {
  # proxmox-csi volume
  my-pv = {
    node = "pve1"
    size = "100M"               # size UoM without 'B' (Byte)

    # optional
    format    = "raw"           # in most cases variable should be kept to its default "raw" value
    datastore = "nfs"
    type      = "proxmox-csi"   # default is "proxmox-csi" anyway
    vmid      = "9876"
  }

  # additional data disk
  test-disk = {
    size = "50GB"               # size must be given with 'G' ('GB'/`GiB`) suffix for 'disk' type
    type = "disk"
    
    # optional
    machine_type = "all"
    datastore    = "local-ssd"
  }

  # directory volume mount
  host-dir = {
    size = "0GB"                # size attribute is mandatory, though will be ignored
    type = "directory"
    
    # optional
    machine_type = "controlplane"
  }
}
```

### Additional Configuration

Both CSI and Talos Volumes require additional configuration *outside* of this terraform module, i.e. in your Kubernetes cluster. You will need to setup a CSI (also in the case of proxmox-csi) and declare `PersistentVolumeClaim`s. Please refer to the [storage documentation](storage.md#additional-configuration) for more details.

# Useful Links

- [Cilium](https://docs.cilium.io/en/stable/)
- [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox)
- [Proxmox](https://www.proxmox.com/)
- [sergelogvinov/proxmox-csi-plugin](https://github.com/sergelogvinov/proxmox-csi-plugin)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Talos](https://www.talos.dev/)
- [Talos Image Factory documentation](https://github.com/siderolabs/image-factory)
