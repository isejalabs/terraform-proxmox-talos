variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}

variable "volume" {
  type = object({
    datastore = optional(string, "local-zfs")
    format    = optional(string, "raw")
    name      = string
    node      = string
    size      = string
    vmid      = optional(number, 9999)
  })
}
