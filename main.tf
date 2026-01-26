module "talos" {
  source = "./talos"

  # hand over volumes of type `disk` only, else an empty list
  talos_volumes = coalesce({ for k, v in var.volumes : k => v if v.type == "disk" }, {})

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
