variable "proxmox" {
  type = object({
    cluster_name = string
    endpoint = string
    insecure = bool
  })
}

variable "env" {
  description = "environment (e.g. prod, qa, dev)"
  type        = string
  default     = ""
}