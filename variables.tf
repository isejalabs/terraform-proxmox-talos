variable "cilium_values" {
  description = "path to values.yaml file for cilium install"
  type        = string
  default     = "talos/inline-manifests/cilium-values.default.yaml"
}

variable "cluster" {
  type = object({
    endpoint        = string
    gateway         = string
    name            = string
    proxmox_cluster = string
    talos_version   = string
  })
  description = <<EOT
  Cluster configuration with attributes:
  - `endpoint`: [Kubernetes endpoint address](https://www.talos.dev/v1.10/introduction/prodnotes/#decide-the-kubernetes-endpoint)
  - `name`: Name for cluster
  - `gateway`: Network gateway
  - `proxmox_cluster`: An arbitrary name for the Talos cluster; **subject for deprecation** in a future version
  - `talos_version`: [Talos version](https://github.com/siderolabs/talos/releases) with `v` prefix, e.g. `v1.2.3`; **subject for deprecation** in a future version
  EOT
}
variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}
variable "image" {
  description = "Talos image configuration"
  type = object({
    schematic         = string
    version           = string
    arch              = optional(string, "amd64")
    factory_url       = optional(string, "https://factory.talos.dev")
    platform          = optional(string, "nocloud")
    proxmox_datastore = optional(string, "local")
    update_schematic  = optional(string)
    update_version    = optional(string)
  })
}

variable "nodes" {
  description = "Configuration for cluster nodes"
  type = map(object({
    cpu           = number
    host_node     = string
    ip            = string
    machine_type  = string
    ram_dedicated = number
    vm_id         = number
    bridge        = optional(string, "vmbr0")
    cpu_type      = optional(string, "x86-64-v2-AES")
    datastore_id  = optional(string, "local-zfs")
    disk_size     = optional(number, 20)
    igpu          = optional(bool, false)
    mac_address   = optional(string, null)
    update        = optional(bool, false)
    vlan_id       = optional(number, 0)
  }))
}

variable "proxmox" {
  type = object({
    api_token    = string
    cluster_name = string
    endpoint     = string
    insecure     = bool
    username     = string
  })
  sensitive = true
}

variable "volumes" {
  type = map(
    object({
      node    = string
      size    = string
      format  = optional(string, "raw")
      storage = optional(string, "local-zfs")
      vmid    = optional(number, 9999)
    })
  )
}
