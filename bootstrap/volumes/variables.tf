variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}

variable "proxmox_api" {
  type = object({
    api_token    = string
    cluster_name = string
    endpoint     = string
    insecure     = bool
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