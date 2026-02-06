variable "cilium_config" {
  description = "Cilium configuration"
  type = object({
    bootstrap_manifest_path = string
    values_file_path        = string
  })
}

variable "cluster" {
  description = "Cluster configuration"
  type = object({
    gateway                          = string
    gateway_api_version              = string
    kubernetes_version               = string
    name                             = string
    proxmox_cluster                  = string
    allow_scheduling_on_controlplane = optional(bool, false)
    api_server                       = optional(string)
    extra_manifests                  = optional(list(string), [])
    kubelet                          = optional(string)
    machine_features                 = optional(string)
    on_boot                          = optional(bool, true)
    subnet_mask                      = optional(string, "24")
    talos_machine_config_version     = optional(string)
    vip                              = optional(string)
  })
}

variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}

variable "image" {
  description = "Talos image configuration"
  type = object({
    schematic_path        = string
    version               = string
    arch                  = optional(string, "amd64")
    factory_url           = optional(string, "https://factory.talos.dev")
    platform              = optional(string, "nocloud")
    datastore             = optional(string, "local")
    update_schematic_path = optional(string)
    update_version        = optional(string)
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
    datastore     = optional(string, "local-zfs")
    disk_size     = optional(number, 20)
    dns           = optional(list(string))
    igpu          = optional(bool, false)
    mac_address   = optional(string, null)
    update        = optional(bool, false)
    vlan_id       = optional(number, 0)
  }))
}

variable "talos_volumes" {
  type = map(
    object({
      size         = string
      datastore    = optional(string)           # default is to use the main VM's datastore
      machine_type = optional(string, "worker") # "all", "controlplane", "worker"
      type         = optional(string, "disk")   # "directory", "disk", "partition"
    })
  )
  default = {}
  validation {
    // @formatter:off
    condition     = length([for i in var.talos_volumes : i if contains(["all", "controlplane", "worker"], i.machine_type)]) == length(var.talos_volumes)
    error_message = "Volume `machine_type` must be either 'all', 'controlplane' or 'worker'."
    // @formatter:on
  }
  validation {
    // @formatter:off
    condition     = length([for i in var.talos_volumes : i if contains(["disk", "proxmox-csi"], i.type)]) == length(var.talos_volumes)
    error_message = "Volume `type` can be 'disk' or 'proxmox-csi' only; 'directory', 'partition' and other types not supported by this module version."
    // @formatter:on
  }
}

variable "talos_disk_volumes" {
  type = map(
    object({
      size_gb      = number
      datastore    = optional(string)           # default is to use the main VM's datastore
      machine_type = optional(string, "worker") # "all", "controlplane", "worker"
    })
  )
  default = {}
  validation {
    // @formatter:off
    condition     = length([for i in var.talos_disk_volumes : i if contains(["all", "controlplane", "worker"], i.machine_type)]) == length(var.talos_disk_volumes)
    error_message = "Volume `machine_type` must be either 'all', 'controlplane' or 'worker'."
    // @formatter:on
  }
}
