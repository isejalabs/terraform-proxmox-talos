variable "proxmox_api" {
  type = object({
    endpoint  = string
    insecure  = bool
    api_token = string
  })
  sensitive = true
}

variable "volume" {
  type = object({
    name    = string
    node    = string
    size    = string
    storage = optional(string, "local-enc")
    vmid    = optional(number, 9999)
    format  = optional(string, "raw")
  })
}

variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}
