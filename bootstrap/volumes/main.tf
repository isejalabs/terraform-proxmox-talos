module "proxmox-volume" {
  for_each = var.volumes
  source   = "./proxmox-volume"

  providers = {
    restapi = restapi
  }

  volume = {
    datastore = each.value.datastore
    format    = each.value.format
    name      = each.key
    node      = each.value.node
    size      = each.value.size
    vmid      = each.value.vmid
  }
  env = var.env
}

module "persistent-volume" {
  for_each = var.volumes
  source   = "./persistent-volume"

  providers = {
    kubernetes = kubernetes
  }

  volume = {
    capacity      = each.value.size
    name          = each.key
    datastore     = each.value.datastore
    volume_handle = "${var.proxmox_api.cluster_name}/${module.proxmox-volume[each.key].node}/${module.proxmox-volume[each.key].datastore}/${module.proxmox-volume[each.key].filename}"
  }
}
