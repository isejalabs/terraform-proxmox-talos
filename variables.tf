variable "proxmox" {
  type = object({
    # name         = string
    cluster_name = string
    endpoint     = string
    insecure     = bool
    username     = string
    api_token    = string
  })
  sensitive = true
}

variable "image" {
  description = "Talos image configuration"
  type = object({
    factory_url       = optional(string, "https://factory.talos.dev")
    schematic         = string
    version           = string
    update_schematic  = optional(string)
    update_version    = optional(string)
    arch              = optional(string, "amd64")
    platform          = optional(string, "nocloud")
    proxmox_datastore = optional(string, "local")
  })
}

variable "cluster" {
  description = "Cluster configuration"
  type = object({
    name            = string
    endpoint        = string
    gateway         = string
    talos_version   = string
    proxmox_cluster = string
  })
}

variable "nodes" {
  description = "Configuration for cluster nodes"
  type = map(object({
    host_node     = string
    machine_type  = string
    ip            = string
    vm_id         = number
    cpu           = number
    ram_dedicated = number
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

variable "volumes" {
  type = map(
    object({
      node    = string
      size    = string
      storage = optional(string, "local-zfs")
      vmid    = optional(number, 9999)
      format  = optional(string, "raw")
    })
  )
}

variable "cilium_values" {
  description = "path to values.yaml file for cilium install"
  type        = string
  default     = "talos/inline-manifests/cilium-values.default.yaml"
}

variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}