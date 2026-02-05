variable "cilium_config" {
  description = "Cilium configuration"
  type = object({
    bootstrap_manifest_path = string
    values_file_path        = string
  })
  default = {
    bootstrap_manifest_path = "talos/inline-manifests/cilium-install.yaml"
    values_file_path        = "talos/inline-manifests/cilium-values.default.yaml"
  }
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
  validation {
    // @formatter:off
    condition     = length([for n in var.nodes : n if contains(["controlplane", "worker"], n.machine_type)]) == length(var.nodes)
    error_message = "Node machine_type must be either 'controlplane' or 'worker'."
    // @formatter:on
  }
}

variable "proxmox" {
  description = "Proxmox provider configuration"
  type = object({
    cluster_name = string
    endpoint     = string
    insecure     = bool
    username     = string
  })
}

variable "proxmox_api_token" {
  description = "API token for Proxmox"
  type        = string
  sensitive   = true
}

variable "sealed_secrets_config" {
  description = "Sealed-secrets configuration"
  type = object({
    certificate_path = string
    key_path         = string
  })
  default = {
    certificate_path = "assets/sealed-secrets/certificate/sealed-secrets.cert"
    key_path         = "assets/sealed-secrets/certificate/sealed-secrets.key"
  }
}

variable "volumes" {
  description = "Additional storage volumes available to the cluster"
  type = map(
    object({
      # common
      size = string                          # in GB (not GiB)
      type = optional(string, "proxmox-csi") # "directory", "disk", "partition", "proxmox-csi"
      # directory, disk and partition
      machine_type = optional(string, "worker") # "all", "controlplane", "worker"
      # disk and proxmox-csi
      datastore = optional(string) # default is to use the main VM's datastore  
      # proxmox-csi only
      node   = optional(string)
      format = optional(string, "raw")
      vmid   = optional(number, 9999)
    })
  )
  default = {}
  validation {
    // @formatter:off
    condition     = length([for i in var.volumes : i if contains(["directory", "disk", "proxmox-csi"], i.type)]) == length(var.volumes)
    error_message = "Volume `type` must be either 'directory', 'disk' or 'proxmox-csi'. Other types are not supported."
    // @formatter:on
  }
  validation {
    // @formatter:off
    condition     = length([for i in var.volumes : i if contains(["all", "controlplane", "worker"], i.machine_type)]) == length(var.volumes)
    error_message = "Volume `machine_type` must be either 'all', 'controlplane' or 'worker'."
    // @formatter:on
  }
}
