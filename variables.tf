variable "cilium_config" {
  description = "Cilium configuration"
  type = object({
    bootstrap_manifest_path = optional(string, "talos/inline-manifests/cilium-install.yaml")
    values_file_path        = optional(string, "talos/inline-manifests/cilium-values.default.yaml")
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
  description = "Configuration for cluster nodes, including optional host devices passed through to each node's VM"
  type = map(object({
    cpu                  = number
    host_node            = string
    ip                   = string
    machine_type         = string
    ram_dedicated        = number
    vm_id                = number
    bridge               = optional(string, "vmbr0")
    cpu_limit            = optional(number)
    cpu_type             = optional(string, "x86-64-v2-AES")
    cpu_units            = optional(number)
    datastore            = optional(string, "local-zfs")
    disk_size            = optional(number, 20)
    dns                  = optional(list(string))
    igpu                 = optional(bool, false)
    mac_address          = optional(string, null)
    talos_config_patches = optional(list(string), [])
    update               = optional(bool, false)
    # Proxmox startup/shutdown behaviour of the VM. Lower `order` starts first and stops last.
    # `down_delay` is the shutdown timeout in seconds before Proxmox kills the VM (default 180).
    startup = optional(object({
      order      = optional(number)
      up_delay   = optional(number)
      down_delay = optional(number)
    }))
    # Each device must use exactly one host USB ID/port or cluster-wide USB mapping.
    usb_devices = optional(list(object({
      host    = optional(string)
      mapping = optional(string)
      usb3    = optional(bool, false)
    })), [])
    vlan_id = optional(number, 0)
  }))
  validation {
    // @formatter:off
    condition     = length([for n in var.nodes : n if contains(["controlplane", "worker"], n.machine_type)]) == length(var.nodes)
    error_message = "Node machine_type must be either 'controlplane' or 'worker'."
    // @formatter:on
  }
  validation {
    // @formatter:off
    condition = alltrue(flatten([
      for node in values(var.nodes) : [
        for device in node.usb_devices : (device.host != null) != (device.mapping != null)
      ]
    ]))
    error_message = "Each USB device must set exactly one of 'host' or 'mapping'."
    // @formatter:on
  }
  validation {
    // @formatter:off
    condition     = alltrue([for node in values(var.nodes) : node.cpu_units == null || (node.cpu_units >= 1 && node.cpu_units <= 262144)])
    error_message = "Node cpu_units must be between 1 and 262144."
    // @formatter:on
  }
  validation {
    // @formatter:off
    condition     = alltrue([for node in values(var.nodes) : node.cpu_limit == null || (node.cpu_limit >= 0 && node.cpu_limit <= 128)])
    error_message = "Node cpu_limit must be between 0 (unlimited) and 128."
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

variable "talos_config_patches" {
  description = "Paths to additional Talos Machine Configuration patches"
  type = list(
    object({
      path         = string
      machine_type = optional(string, "all") # "all", "controlplane", "worker"
    })
  )
  default = []
  validation {
    // @formatter:off
    condition     = length([for i in var.talos_config_patches : i if contains(["all", "controlplane", "worker"], i.machine_type)]) == length(var.talos_config_patches)
    error_message = "`machine_type` must be either 'all', 'controlplane' or 'worker'."
    // @formatter:on
  }
}

variable "volumes" {
  description = "Additional storage volumes: directory and disk use Talos User Volumes; proxmox-csi creates Proxmox disks and Kubernetes PersistentVolumes. Partition volumes are not supported."
  type = map(
    object({
      # common
      size = string                          # in GB (not GiB)
      type = optional(string, "proxmox-csi") # "directory", "disk", "proxmox-csi"
      # directory and disk
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
