module "talos" {
  source = "./talos"

  # use a dedicated variable for disk volumes only, with size as number in GB with UoM
  talos_disk_volumes = {
    for k, v in var.volumes :
    k => {
      datastore    = v.datastore
      machine_type = v.machine_type
      # convert size from string to number by removing UoM (cf. #171)
      # strip only "GiB" suffix, whereas for other UoMs an error should be thrown
      # pending issue #174 (upstream #1511) to support other units
      size_gb = tonumber(replace(v.size, "/[GiB]/", ""))
    } if v.type == "disk"
  }
  # hand over volumes of type `directory` only, else an empty list
  talos_volumes = coalesce({ for k, v in var.volumes : k => v if v.type == "directory" }, {})

  # take over configuration from main
  providers = {
    proxmox = proxmox
  }
  cilium_config = var.cilium_config
  cluster       = var.cluster
  image         = var.image
  nodes         = var.nodes
  env           = var.env
}

module "sealed_secrets" {
  depends_on = [module.talos]
  source     = "./bootstrap/sealed-secrets"

  providers = {
    kubernetes = kubernetes
  }

  cert = var.sealed_secrets_config
}

module "proxmox_csi_plugin" {
  depends_on = [module.talos]
  source     = "./bootstrap/proxmox-csi-plugin"

  providers = {
    proxmox    = proxmox
    kubernetes = kubernetes
  }

  proxmox = var.proxmox
  env     = var.env
}

module "volumes" {
  depends_on = [module.proxmox_csi_plugin]
  source     = "./bootstrap/volumes"

  providers = {
    restapi    = restapi
    kubernetes = kubernetes
  }
  proxmox_api = var.proxmox
  volumes     = coalesce({ for k, v in var.volumes : k => v if v.type == "proxmox-csi" }, {})
  env         = var.env
}
