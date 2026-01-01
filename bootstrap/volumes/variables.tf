variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}

variable "proxmox_api" {
  type = object({
    cluster_name = string
    endpoint     = string
    insecure     = bool
  })
}

variable "volumes" {
  type = map(
    object({
      datastore = optional(string, "local-zfs")
      format    = optional(string, "raw")
      node      = string
      size      = string
      vmid      = optional(number, 9999)
    })
  )
}
