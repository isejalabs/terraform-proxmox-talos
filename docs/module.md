# Module Technical Documentation

The following is a technical documentation of the module, [auto-generated](https://github.com/terraform-docs/terraform-docs) from the modules's `variables.tf`, `providers.tf`, `output.tf` and other files.  Hence, it's always up-to-date with the latest module implementation.

For the [input variables](#inputs) see also the dedicated [Variables Documentation](variables.md).  Besides some example code, it is giving more details as Terraform does not provide the possibility to document special types such as `object` and `map` – which are used by the module extensively.  There's a workaround available (cf. ['How to describe an object type variable in Terraform?'](https://stackoverflow.com/questions/72183481/how-to-describe-an-object-type-variable-in-terraform)), though this is producing output in the descriptions table column which cannot be read thoroughly.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | 2.38.0 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | 0.82.0 |
| <a name="requirement_restapi"></a> [restapi](#requirement\_restapi) | 1.20.0 |
| <a name="requirement_talos"></a> [talos](#requirement\_talos) | 0.9.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | n/a |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_proxmox_csi_plugin"></a> [proxmox\_csi\_plugin](#module\_proxmox\_csi\_plugin) | ./bootstrap/proxmox-csi-plugin | n/a |
| <a name="module_sealed_secrets"></a> [sealed\_secrets](#module\_sealed\_secrets) | ./bootstrap/sealed-secrets | n/a |
| <a name="module_talos"></a> [talos](#module\_talos) | ./talos | n/a |
| <a name="module_volumes"></a> [volumes](#module\_volumes) | ./bootstrap/volumes | n/a |

## Resources

| Name | Type |
|------|------|
| [local_file.kube_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.machine_configs](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |
| [local_file.talos_config](https://registry.terraform.io/providers/hashicorp/local/latest/docs/resources/file) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_cilium_values"></a> [cilium\_values](#input\_cilium\_values) | path to values.yaml file for cilium install | `string` | `"talos/inline-manifests/cilium-values.default.yaml"` | no |
| <a name="input_cluster"></a> [cluster](#input\_cluster) | Cluster configuration | <pre>object({<br/>    endpoint           = string<br/>    gateway            = string<br/>    kubernetes_version = string<br/>    name               = string<br/>    proxmox_cluster    = string<br/>    talos_version      = string<br/>    on_boot            = optional(bool, true)<br/>  })</pre> | n/a | yes |
| <a name="input_env"></a> [env](#input\_env) | environment (e.g. prod, qa, dev) | `string` | `""` | no |
| <a name="input_image"></a> [image](#input\_image) | Talos image configuration | <pre>object({<br/>    schematic         = string<br/>    version           = string<br/>    arch              = optional(string, "amd64")<br/>    factory_url       = optional(string, "https://factory.talos.dev")<br/>    platform          = optional(string, "nocloud")<br/>    proxmox_datastore = optional(string, "local")<br/>    update_schematic  = optional(string)<br/>    update_version    = optional(string)<br/>  })</pre> | n/a | yes |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Configuration for cluster nodes | <pre>map(object({<br/>    cpu           = number<br/>    host_node     = string<br/>    ip            = string<br/>    machine_type  = string<br/>    ram_dedicated = number<br/>    vm_id         = number<br/>    bridge        = optional(string, "vmbr0")<br/>    cpu_type      = optional(string, "x86-64-v2-AES")<br/>    datastore_id  = optional(string, "local-zfs")<br/>    disk_size     = optional(number, 20)<br/>    dns           = optional(list(string))<br/>    igpu          = optional(bool, false)<br/>    mac_address   = optional(string, null)<br/>    update        = optional(bool, false)<br/>    vlan_id       = optional(number, 0)<br/>  }))</pre> | n/a | yes |
| <a name="input_proxmox"></a> [proxmox](#input\_proxmox) | n/a | <pre>object({<br/>    api_token    = string<br/>    cluster_name = string<br/>    endpoint     = string<br/>    insecure     = bool<br/>    username     = string<br/>  })</pre> | n/a | yes |
| <a name="input_volumes"></a> [volumes](#input\_volumes) | n/a | <pre>map(<br/>    object({<br/>      node    = string<br/>      size    = string<br/>      format  = optional(string, "raw")<br/>      storage = optional(string, "local-zfs")<br/>      vmid    = optional(number, 9999)<br/>    })<br/>  )</pre> | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_kube_config"></a> [kube\_config](#output\_kube\_config) | n/a |
| <a name="output_talos_config"></a> [talos\_config](#output\_talos\_config) | n/a |
<!-- END_TF_DOCS -->