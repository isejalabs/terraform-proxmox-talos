# ToC
- [cilium_values](#cilium_values)
- [cluster](#cluster)
- [env](#env)
- [image](#image)
- [nodes](#nodes)
- [proxmox](#proxmox)
- [volumes](#volumes)

# Variables
## cilium_values
The `cilium_values` variable lets you provide a custom Helm values file. See [cilium documentation](https://docs.cilium.io/en/stable/helm-reference/) for the Helm reference.
If no file is provided, a default configuration defined in `talos/inline-manifests/cilium-values.default.yaml` is used.

| Description                                        | Type     | Default / Example                                   |
| -------------------------------------------------- | -------- | --------------------------------------------------- |
| Path to Helm `values.yaml` file for cilium install | `string` | `talos/inline-manifests/cilium-values.default.yaml` |
## cluster
### Definition
The Kubernetes cluster configuration defines its version and network configuration mainly.

| Key             | Description                                                                                                                                                                                                                         | Type     | Default / Example   |
| --------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------- |
| endpoint        | **Required** [Kubernetes endpoint address](https://www.talos.dev/v1.10/introduction/prodnotes/#decide-the-kubernetes-endpoint)                                                                                                      | `string` | e.g. `"10.1.2.34"`  |
| gateway         | **Required** network gateway                                                                                                                                                                                                        | `string` | e.g. `"10.1.2.254"` |
| name            | **Required** name                                                                                                                                                                                                                   | `string` | e.g. `"talos"`      |
| proxmox_cluster | **Required** an arbitrary name for the Talos cluster<br>**will get *DEPRECATED* in a future version**                                                                                                                               | `string` | e.g. `"proxmox"`    |
| talos_version   | **Required** [Talos version](https://github.com/siderolabs/talos/releases) with `v` prefix, e.g. `"v1.2.3"`.  Changing this value after cluster creation will destroy the cluster.<br>**will get *DEPRECATED* in a future version** | `string` | e.g. `"v1.2.3"`     |
### Example
```terraform
cluster = {
  endpoint        = "10.1.2.34"
  gateway         = "10.1.2.254"
  name            = "talos"
  proxmox_cluster = "homelab"
  talos_version   = "v1.2.3"
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

| Resource                     | Default Name                            | env-specific Name                                                                                                                         |
| ---------------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Proxmox role for CSI         | `CSI`                                   | `dev-CSI`                                                                                                                                 |
| Proxmox user for CSI plugin  | `kubernetes-csi@pve`                    | `dev-kubernetes-csi@pve`                                                                                                                  |
| Proxmox volume names for CSI | `vm-9999-pv-example`                    | `vm-9999-dev-pv-example`<br><br>another option is adjusting the `vmid` parameter (default `"9999"`) of the [`volumes`](#volumes) variable |
| Downloaded image file        | `talos-ce..15-v1.2.3-nocloud-amd64.img` | `dev-talos-ce..15-v1.2.3-nocloud-amd64.img`                                                                                               |
### Example
```terraform
env = "dev"
```
## image
### Definition
The `image` parameter not only allows adjusting the downloaded Talos image by defining its extensions (schematic), version and other settings.  The two `update_` attributes allow updating to another version or schematic definition. See the **TODO** [update process documentation].

| Key                 | Description                                                                                                                                                                       | Type     | Default / Example                           |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------- |
| `schematic`         | **Required** Schematic ID  for Talos image, typically a file reference                                                                                                            | `string` | e.g.  `file("assets/talos/schematic.yaml")` |
| `version`           | **Required** [Talos version](https://github.com/siderolabs/talos/releases) with `v` prefix, e.g. `"v1.2.3"`                                                                       | `string` | e.g. `"v1.2.3"`                             |
| `arch`              | Architecture                                                                                                                                                                      | `string` | `"amd64"` / `"arm64"`                       |
| `factory_url`       | Alternative [Talos Factory](https://factory.talos.dev/) URL                                                                                                                       | `string` | `"https://factory.talos.dev"`               |
| `platform`          | Typically left set to its default (`"nocloud"`), still allowing alternative configuration for [Talos platform](https://www.talos.dev/v1.10/talos-guides/install/cloud-platforms/) | `string` | `"nocloud"`                                 |
| `proxmox_datastore` | Proxmox datastore used to store the image                                                                                                                                         | `string` | `"local"`                                   |
| `update_schematic`  | Alternative schematic definition to be used when updating a node                                                                                                                  | `string` | `null`                                      |
| `update_version`    | Alternative version definition to be used when updating a node                                                                                                                    | `string` | `null`                                      |
### Example
```terraform
image = {
  schematic = file("assets/talos/schematic.yaml")
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
The `nodes` variable defines the Talos VMs that form the cluster.  It consists of a **map** with the *VM name* as keys having the following attributes:

| Key           | Description                                                                                                | Type     | Default / Example                                |
| ------------- | ---------------------------------------------------------------------------------------------------------- | -------- | ------------------------------------------------ |
| cpu           | **Required** Number of CPU cores                                                                           | `number` | e.g. `2`                                         |
| host_node     | **Required** Hostname of the Proxmox node the Talos VM should get hosted                                   | `string` | e.g. `"host1"`                                   |
| ip            | **Required** IP address                                                                                    | `string` | e.g. `"10.1.2.3"`                                |
| machine_type  | **Required** Type of kubernetes node, must be either `"controlplane"` or `"worker"`                        | `string` | e.g. `"controlplane"`, `"worker"`                |
| ram_dedicated | **Required** RAM size in MB                                                                                | `number` | e.g. `4096`                                      |
| vm_id         | **Required** Unique VM id in Proxmox cluster                                                               | `number` | e.g. `123`                                       |
| bridge        | Network bridge the VM connect to                                                                           | `string` | `"vmbr0"`                                        |
| cpu_type      | Proxmox [CPU type](https://pve.proxmox.com/pve-docs/pve-admin-guide.html#_cpu_type)                        | `string` | `"x86-64-v2-AES"` / `"custom-x86-64-v2-AES-AVX"` |
| datastore_id  | The Proxmox datastore used to store the VM                                                                 | `string` | `"local-zfs"`                                    |
| disk_size     | VM disk size in GB                                                                                         | `number` | `20`                                             |
| igpu          | Passthrough of an iGPU                                                                                     | `bool`   | `false`                                          |
| mac_address   | Custom MAC address                                                                                         | `string` | `null`                                           |
| update        | If set to `true`, the node will get updated to the `image.update_version` and/or `image.update_schematic`. | `bool`   | `false`                                          |
| vlan_id       | Network VLAN ID                                                                                            | `number` | `0`                                              |
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
  }
}
```
## proxmox
Configuration for the connection to the Proxmox cluster, according to [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox). See also the module's [authentication documentation](https://registry.terraform.io/providers/bpg/proxmox/latest/docs#authentication) for further instructions.
### Definition

| Key          | Description                                                                                                                                                      | Type     | Default / Example                                                      |
| ------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ---------------------------------------------------------------------- |
| api_token    | **Required** name                                                                                                                                                | `string` | e.g. `"terraform@pve!killertofu=01234567-89ab-cdef-0123-456789abcdef"` |
| cluster_name | **Required** name of the talos cluster<br>**will get *DEPRECATED* in a future version**                                                                          | `string` | e.g. `"foo"`                                                           |
| endpoint     | **Required** Proxmox endpoint to connect to                                                                                                                      | `string` | e.g. `"https://pve.example.com:8006"`                                  |
| insecure     | **Required** Skip endpoint TLS verification if set to `true`                                                                                                     | `bool`   | e.g. `false`                                                           |
| username     | **Required** Username for the SSH connection. A SSH connection is used to connect to the Proxmox server for operations that are not available in the Proxmox API | `string` | e.g. `"terraform"`                                                     |
### Example
Proxmox authentication configuration contains confidential data you never should add to a VCS such as git. The following example uses a simple approach by refering to a variable `proxmox_api_token` which you could set as environment variable via `export TF_VAR_proxmox_api_token="<YOUR_API_TOKEN>"`.
```terraform
proxmox = {
  api_token    = var.proxmox_api_token
  cluster_name = "foo"
  endpoint     = "https://pve.example.com:8006"
  insecure     = false
  username     = "terraform"
}
```
Another approach could be:
- Define all proxmox configuration in a `*.auto.tfvars` (or `*.auto.tfvars.json`) variable definitions files, cf. [Variable Definitions (`.tfvars`) Files documentation](https://developer.hashicorp.com/terraform/language/values/variables#variable-definitions-tfvars-files), and `gitignore`the file(s).
- Same as above but encrypt the files with e.g. [SOPS](https://github.com/getsops/sops) so they can be kept in a VCS.
## volumes
### Definition
Configuration for Persistent Volumes (PV) using the [proxmox-csi-plugin](https://github.com/sergelogvinov/proxmox-csi-plugin). The `volumes` variable is formed of a **map** consisting of the *volume name* as key and the following attributes:

| Key     | Description                                                                                                                                                                                                                                                                  | Type     | Default / Example |
| ------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------------- |
| node    | **Required** Hostname of the Proxmox node where the volume should get stored                                                                                                                                                                                                 | `string` | e.g. `"host1"`    |
| size    | **Required**  Volume size with                                                                                                                                                                                                                                               | `string` | e.g. `100M`       |
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
- [Proxmox](https://www.proxmox.com/)
- [Talos](https://www.talos.dev/)
- [Talos Image Factory documentation](https://github.com/siderolabs/image-factory)
- [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox)
- [Cilium](https://docs.cilium.io/en/stable/)
