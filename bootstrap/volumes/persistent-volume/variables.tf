variable "volume" {
  description = "Volume configuration"
  type = object({
    capacity           = string
    name               = string
    volume_handle      = string
    access_modes       = optional(list(string), ["ReadWriteOnce"])
    cache              = optional(string, "writethrough")
    driver             = optional(string, "csi.proxmox.sinextra.dev")
    fs_type            = optional(string, "ext4")
    mount_options      = optional(list(string), ["noatime"])
    ssd                = optional(bool, true)
    storage            = optional(string, "local-zfs")
    storage_class_name = optional(string, "proxmox-csi")
    volume_mode        = optional(string, "Filesystem")
  })
}
