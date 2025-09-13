# ToC

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

The `cilium_config` variable lets you set a paths to custom configuration files for the [cilium Helm values file](https://docs.cilium.io/en/stable/helm-reference/) and
cilium bootstrap manifest (installation), respectively.

If no files are provided, a decent default configuration is used.

### Definition

| Key | Description | Type     | Default / Example                                   |
| ----| ----------- | -------- | --------------------------------------------------- |
| bootstrap_manifest_path | Path to Cilium `install.yaml` manifest for cilium install | `string` | [`talos/inline-manifests/cilium-install.yaml`](../talos/inline-manifests/cilium-install.yaml) |
| values_file_path | Path to Helm `values.yaml` file for cilium install | `string` | [`talos/inline-manifests/cilium-values.default.yaml`](../talos/inline-manifests/cilium-values.default.yaml) |

### Example

```terraform
bootstrap_manifest_path = "assets/cilium/install.yaml"
values_file_path        = "assets/cilium/values.yaml"
```

## cluster

### Definition

The Kubernetes cluster configuration defines its version and network configuration mainly.

| Key                | Description                                                                                                                                                                                                                        | Type     | Default / Example   |
| ------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------- |
| gateway            | **Required** network gateway                                                                                                                                                                                                       | `string` | e.g. `"10.1.2.254"` |
| gateway_api_version | **Required** [GW API version](https://gateway-api.sigs.k8s.io/concepts/versioning) | `string` | e.g. `"v1.2.1"` |
| kubernetes_version | **Required** Kubernetes version to set independent from Talos image inbuilt version                                                                                                                                                | `string` | e.g. `"v1.33.0"`    |
| name               | **Required** name                                                                                                                                                                                                                  | `string` | e.g. `"talos"`      |
| proxmox_cluster    | **Required** an arbitrary name for the Talos cluster<br>**will get _DEPRECATED_ in a future version**                                                                                                                              | `string` | e.g. `"proxmox"`    |
| api_server | Kube apiserver options (cf. [Talos apiServerConfig](https://www.talos.dev/v1.11/kubernetes-guides/configuration/inlinemanifests/#extramanifests) documentation) | `string` | `null` |
| extraManifests | `List` of [`extraManifests`](https://www.talos.dev/v1.11/kubernetes-guides/configuration/inlinemanifests/#extramanifests) in Talos | `list(string)` | `[]` |
| kubelet | Kubelet config values(cf. [Talos kubeletConfig](https://www.talos.dev/v1.11/reference/configuration/v1alpha1/config/#Config.machine.kubelet) | `string` | `null` |
| on_boot            | Specifies whether all VMs will be started during system boot of the Proxmox server                                                                                                                                                 | `bool`   | `true`              |
| subnet_mask | Network subnet mask | `string` | `"24"` |
| talos_machine_config_version | [Version of Talos](https://github.com/siderolabs/talos/releases) to use in generated machine configuration. Per default, the version defined in the `image` is used | `string` | `"v1.2.3"`     |
| vip | [Virtual (shared) IP](https://www.talos.dev/v1.11/talos-guides/network/vip/) for building a high-availability controlplane | `string` | `null` |

### Example

```terraform
cluster = {
  gateway            = "10.1.2.254"
  gateway_api_version          = "v1.3.0" # renovate: github-releases=kubernetes-sigs/gateway-api
  kubernetes_version = "v1.33.3" # renovate: github-releases=kubernetes/kubernetes
  name               = "talos"
  proxmox_cluster    = "homelab"

  # optional
  api_server                   = <<-EOT
    extraArgs:
      oidc-issuer-url: "https://authelia.example.com"
      oidc-client-id: "kubectl"
      oidc-username-claim: "preferred_username"
      oidc-username-prefix: "authelia:"
      oidc-groups-claim: "groups"
      oidc-groups-prefix: "authelia:"
  EOT
  extra_manifests              = [
    "https://github.com/fluxcd/flux2/releases/latest/download/install.yaml"
  ]
  kubelet                      = <<-EOT
    extraArgs:
      # Needed for Netbird agent
      # see: https://kubernetes.io/docs/tasks/administer-cluster/sysctl-cluster/#enabling-unsafe-sysctls
      allowed-unsafe-sysctls: net.ipv4.conf.all.src_valid_mark
  EOT
  on_boot            = false
  talos_machine_config_version = "v1.2.3"
  vip                          = "10.1.2.33"
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

The `image` parameter not only allows adjusting the downloaded Talos image by defining its extensions (schematic), version and other settings. The two `update_` attributes allow updating to another version or schematic definition. See the **TODO** [update process documentation].

| Key                 | Description                                                                                                                                                                       | Type     | Default / Example                          |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------ |
| `schematic_path` | **Required** Path to the file defining the Schematic ID for Talos image | `string` | e.g. `"assets/talos/schematic.yaml"` |
| `version`           | **Required** [Talos version](https://github.com/siderolabs/talos/releases) with `v` prefix, e.g. `"v1.2.3"`                                                                       | `string` | e.g. `"v1.2.3"`                            |
| `arch`              | Architecture                                                                                                                                                                      | `string` | `"amd64"` / `"arm64"`                      |
| `factory_url`       | Alternative [Talos Factory](https://factory.talos.dev/) URL                                                                                                                       | `string` | `"https://factory.talos.dev"`              |
| `platform`          | Typically left set to its default (`"nocloud"`), still allowing alternative configuration for [Talos platform](https://www.talos.dev/v1.10/talos-guides/install/cloud-platforms/) | `string` | `"nocloud"`                                |
| `proxmox_datastore` | Proxmox datastore used to store the image                                                                                                                                         | `string` | `"local"`                                  |
| `update_schematic_path`  | Alternative schematic definition to be used when updating a node                                                                                                                  | `string` | `null`                                     |
| `update_version`    | Alternative version definition to be used when updating a node                                                                                                                    | `string` | `null`                                     |

### Example

```terraform
image = {
  schematic_path = "assets/talos/schematic.yaml"
  version   = "v1.2.3"
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

| Key           | Description                                                                                                | Type           | Default / Example                                |
| ------------- | ---------------------------------------------------------------------------------------------------------- | -------------- | ------------------------------------------------ |
| cpu           | **Required** Number of CPU cores                                                                           | `number`       | e.g. `2`                                         |
| host_node     | **Required** Hostname of the Proxmox node the Talos VM should get hosted                                   | `string`       | e.g. `"host1"`                                   |
| ip            | **Required** IP address                                                                                    | `string`       | e.g. `"10.1.2.3"`                                |
| machine_type  | **Required** Type of kubernetes node, must be either `"controlplane"` or `"worker"`                        | `string`       | e.g. `"controlplane"`, `"worker"`                |
| ram_dedicated | **Required** RAM size in MB                                                                                | `number`       | e.g. `4096`                                      |
| vm_id         | **Required** Unique VM id in Proxmox cluster                                                               | `number`       | e.g. `123`                                       |
| bridge        | Network bridge the VM connect to                                                                           | `string`       | `"vmbr0"`                                        |
| cpu_type      | Proxmox [CPU type](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_cpu_type)                        | `string`       | `"x86-64-v2-AES"` / `"custom-x86-64-v2-AES-AVX"` |
| datastore_id  | The Proxmox datastore used to store the VM                                                                 | `string`       | `"local-zfs"`                                    |
| disk_size     | VM disk size in GB                                                                                         | `number`       | `20`                                             |
| dns           | List of DNS servers                                                                                        | `list(string)` | `null`                                           |
| igpu          | Passthrough of an iGPU                                                                                     | `bool`         | `false`                                          |
| mac_address   | Custom MAC address                                                                                         | `string`       | `null`                                           |
| update        | If set to `true`, the node will get updated to the `image.update_version` and/or `image.update_schematic`. | `bool`         | `false`                                          |
| vlan_id       | Network VLAN ID                                                                                            | `number`       | `0`                                              |

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

    # optional
    dns           = ["1.1.1.1", "8.8.8.8"]
  }
  "worker1" = {
    cpu           = 4
    host_node     = "pve1"
    ip            = "10.20.30.42"
    machine_type  = "worker"
    ram_dedicated = 16384
    vm_id         = 142

    # optional
    dns           = ["8.8.8.8", "9.9.9.9"]
  }
}
```

## proxmox

Configuration for the connection to the Proxmox cluster, according to [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox). See also the module's [authentication documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#authentication) for further instructions.

### Definition

| Key          | Description                                                                                                                                                      | Type     | Default / Example                                                      |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ---------------------------------------------------------------------- |
| cluster_name | **Required** name of the talos cluster<br>**will get _DEPRECATED_ in a future version**                                                                          | `string` | e.g. `"foo"`                                                           |
| endpoint     | **Required** Proxmox endpoint to connect to                                                                                                                      | `string` | e.g. `"https://pve.example.com:8006"`                                  |
| insecure     | **Required** Skip endpoint TLS verification if set to `true`                                                                                                     | `bool`   | e.g. `false`                                                           |
| username     | **Required** Username for the SSH connection. A SSH connection is used to connect to the Proxmox server for operations that are not available in the Proxmox API | `string` | e.g. `"terraform"`                                                     |

### Example

```terraform
proxmox = {
  cluster_name = "foo"
  endpoint     = "https://pve.example.com:8006"
  insecure     = false
  username     = "terraform"
}
```

## proxmox_api_token

Configuration of the Proxmox API token needed for authorization with the Proxmox cluster. See also the [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox) module's [authentication documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#api-token-authentication) for further instructions.

### Definition

| Description | Type | Default / Example |
| ------------| ---- | ----------------- |
| API token for Proxmox | `string` | `null` |

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
| Key | Description | Type | Default / Example |
|-|-|-|-|
| certificate_path | Path to the certificate | `string` | `"assets/sealed-secrets/certificate/sealed-secrets.cert"` |
| key_path | Path to the key | `string` | `"assets/sealed-secrets/certificate/sealed-secrets.key"` |

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

### Definition

Configuration for Persistent Volumes (PV) using the [proxmox-csi-plugin](https://github.com/sergelogvinov/proxmox-csi-plugin). The `volumes` variable is formed of a **map** consisting of the _volume name_ as key and the following attributes:

| Key     | Description                                                                                                                                                                                                                                                                  | Type     | Default / Example |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------------- |
| node    | **Required** Hostname of the Proxmox node where the volume should get stored                                                                                                                                                                                                 | `string` | e.g. `"host1"`    |
| size    | **Required** Volume size with                                                                                                                                                                                                                                                | `string` | e.g. `100M`       |
| format  | Disk format (`"raw"`, `"qcow"`)                                                                                                                                                                                                                                              | `string` | `"raw"`           |
| storage | Proxmox datastore used to store the volume                                                                                                                                                                                                                                   | `string` | `"local-zfs"`     |
| vmid    | Alternative VM ID for naming the volume.<br>When using the module in multiple instances in the same Proxmox environment (host), e.g. for `prod` and `qa` instances, you need to set this parameter different per instance. Otherwise, volumes with the same name will clash. | `number` | `9999`            |

### Example

```terraform
volumes = {
  foo = {
    node = "pve1"
    size = "100M"
  }
  bar = {
    node = "pve1"
    size = "20G"
  }
}
```

# Useful Links

- [Cilium](https://docs.cilium.io/en/stable/)
- [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox)
- [Proxmox](https://www.proxmox.com/)
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)
- [Talos](https://www.talos.dev/)
- [Talos Image Factory documentation](https://github.com/siderolabs/image-factory)
