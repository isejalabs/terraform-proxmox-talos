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
    gateway            = string
    gateway_api_version          = string
    kubernetes_version = string
    name               = string
    proxmox_cluster    = string
    on_boot            = optional(bool, true)
    subnet_mask                  = optional(string, "24")
    vip                          = optional(string)
    extra_manifests              = optional(list(string), [])
    kubelet                      = optional(string)
    api_server                   = optional(string)
    talos_machine_config_version = optional(string)
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
    schematic_path    = string
    version           = string
    arch              = optional(string, "amd64")
    factory_url       = optional(string, "https://factory.talos.dev")
    platform          = optional(string, "nocloud")
    proxmox_datastore = optional(string, "local")
    update_schematic_path = optional(string)
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
