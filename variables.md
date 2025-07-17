# Variables
## env
By setting the `env` variable (to e.g. `prod`, `qa`, `dev`), resources created by `terraform`/`tofu` will be prefixed with this value, thus ensuring names are not clashing. If no `env` value is provided no prefixing is done.
While setting the `env` variable is optional, its usage is strongly recommended when using the `terraform-proxmox-talos` module in parallel in the same Proxmox envorinment. 

| Description                            | Type     | Default / Example |
| -------------------------------------- | -------- | ----------------- |
| environment (e.g. `prod`, `qa`, `dev`) | `string` | `""` / `"dev"`    |
Setting the `env` variable, to e.g. `"dev"`, has an effect on the following resources:

| Resource                     | Default Name                            | env-specific Name for `"dev"`                                                                                                             |
| ---------------------------- | --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| Proxmox role for CSI         | `CSI`                                   | `dev-CSI`                                                                                                                                 |
| Proxmox user for CSI plugin  | `kubernetes-csi@pve`                    | `dev-kubernetes-csi@pve`                                                                                                                  |
| Proxmox volume names for CSI | `vm-9999-pv-mongodb`                    | `vm-9999-dev-pv-mongodb`<br><br>another option is adjusting the `vmid` parameter (default `"9999"`) of the [`volumes`](#volumes) variable |
| Downloaded image file        | `talos-ce..15-v1.2.3-nocloud-amd64.img` | `dev-talos-ce..15-v1.2.3-nocloud-amd64.img`                                                                                               |

## `image`
The `image` parameter not only allows adjusting the downloaded Talos image be defining its extensions (schematic), version and other settings.  The two `update_` attributes allow updating to another version or schematic definition.

| Key                 | Description                                                                                                 | Type     | Default / Example                                                                                                                                                                                     |
| ------------------- | ----------------------------------------------------------------------------------------------------------- | -------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `schematic`         | **required** Schematic ID ***TODO URL*** for Talos image, typically a file reference                        | `string` | e.g.  `file("assets/talos/schematic.yaml")`<br><br>Example file content:<br>```yaml<br>customization:<br>  systemExtensions:<br>    officialExtensions:<br>      - siderolabs/qemu-guest-agent<br>``` |
| `version`           | **required** [Talos version](https://github.com/siderolabs/talos/releases) with `v` prefix, e.g. `"v1.2.3"` | `string` | e.g. `"v1.2.3"`                                                                                                                                                                                       |
| `arch`              | architecture                                                                                                | `string` | `"amd64"` / `"arm64"`                                                                                                                                                                                 |
| `factory_url`       | alternative [Talos Factory](https://factory.talos.dev/) URL                                                 | `string` | `"https://factory.talos.dev"`                                                                                                                                                                         |
| `platform`          |                                                                                                             | `string` | `"nocloud"`                                                                                                                                                                                           |
| `proxmox_datastore` | Proxmox datastore used to store the image                                                                   | `string` | `"local"`                                                                                                                                                                                             |
| `update_schematic`  |                                                                                                             | `string` | `null`                                                                                                                                                                                                |
| `update_version`    |                                                                                                             | `string` | `null`                                                                                                                                                                                                |
## `cluster`
Cluster configuration

| Key             | Description             | Type     | Default / Example   |
| --------------- | ----------------------- | -------- | ------------------- |
| endpoint        | **required** IP address | `string` | e.g. `"10.1.2.34"`  |
| gateway         | **required**            | `string` | e.g. `"10.1.2.254"` |
| proxmox_cluster | **required**            | `string` | e.g. `"foo"`        |
| talos_version   | **required**            | `string` | e.g. `"v1.2.3"`     |
## proxmox
Configuration for the connection to the Proxmox cluster, according to [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox).

| Key          | Description                            | Type     | Default / Example                                                      |
| ------------ | -------------------------------------- | -------- | ---------------------------------------------------------------------- |
| cluster_name | **required** name of the talos cluster | `string` | e.g. `"foo"`                                                           |
| endpoint     | **required** name                      | `string` | e.g. `"https://pve.example.doc:8006/"`                                 |
| insecure     | **required** name                      | `bool`   | e.g. `false`                                                           |
| username     | **required** name                      | `string` | e.g. `"root"`                                                          |
| api_token    | **required** name                      | `string` | e.g. `"terraform@pve!killertofu=01234567-89ab-cdef-0123-456789abcdef"` |
## nodes
| Key           | Description                                                                         | Type     | Default / Example                                |
| ------------- | ----------------------------------------------------------------------------------- | -------- | ------------------------------------------------ |
| host_node     | **required** name of the talos cluster                                              | `string` |                                                  |
| machine_type  | **required** type of kubernetes node, must be either `"controlplane"` or `"worker"` | `string` | e.g. `"controlplane"`, `"worker"`                |
| ip            | **required** IP address                                                             | `string` | e.g. `"10.1.2.3"`                                |
| vm_id         | **required** unique VM id in Proxmox cluster                                        | `number` | e.g. `123`                                       |
| cpu           | **required** number of CPU cores                                                    | `number` |                                                  |
| ram_dedicated | **required** RAM size in MB                                                         | `number` |                                                  |
| bridge        | network bridge the VM connect to                                                    | `string` | `"vmbr0"`                                        |
| cpu_type      |                                                                                     | `string` | `"x86-64-v2-AES"` / `"custom-x86-64-v2-AES-AVX"` |
| datastore_id  | The Proxmox datastore used to store the VM                                          | `string` | `"local-zfs"`                                    |
| disk_size     | VM disk size in GB                                                                  | `number` | `20`                                             |
| igpu          |                                                                                     | `bool`   | `false`                                          |
| mac_address   | Custom MAC address                                                                  | `string` | `null`                                           |
| update        |                                                                                     | `bool`   | `false`                                          |
| vlan_id       |                                                                                     | `number` | `0`                                              |
## volumes
| Key     | Description                            | Type     | Default / Example |
| ------- | -------------------------------------- | -------- | ----------------- |
| node    | **required** name of the talos cluster | `string` |                   |
| size    |                                        | `string` |                   |
| storage |                                        | `string` | `"local-zfs"`     |
| vmid    |                                        | `number` | `9999`            |
| format  |                                        | `string` | `"raw"`           |
## cilium_values
The `cilium_values` variable lets you provide a custom Helm values file. See [cilium documentation](https://docs.cilium.io/en/stable/helm-reference/) for the Helm reference.
If no file is provided a default configuration defined in `talos/inline-manifests/cilium-values.default.yaml` is used.

| Description                                        | Type     | Default                                             |
| -------------------------------------------------- | -------- | --------------------------------------------------- |
| path to Helm `values.yaml` file for cilium install | `string` | `talos/inline-manifests/cilium-values.default.yaml` |
# Useful Links
- [Cilium](https://docs.cilium.io/en/stable/)
- [bgp/terraform-provider-proxmox](https://github.com/bpg/terraform-provider-proxmox)
- [Proxmox](https://www.proxmox.com/)
- [Talos](https://www.talos.dev/)
- [Talos Image Factory documentation](https://github.com/siderolabs/image-factory)