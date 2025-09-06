variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}

variable "volume" {
  type = object({
    name    = string
    node    = string
    size    = string
    format  = optional(string, "raw")
    storage = optional(string, "local-zfs")
    vmid    = optional(number, 9999)
  })
}
