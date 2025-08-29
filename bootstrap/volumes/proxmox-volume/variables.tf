variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}

variable "proxmox_api" {
  type = object({
    api_token = string
    endpoint  = string
    insecure  = bool
  })
  sensitive = true
}

variable "volume" {
  type = object({
    name    = string
    node    = string
    size    = string
    format  = optional(string, "raw")
    storage = optional(string, "local-enc")
    vmid    = optional(number, 9999)
  })
}
