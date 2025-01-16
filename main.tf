module "talos" {
  source = "./talos"

  providers = {
    proxmox = proxmox
  }

  cilium = {
    values  = file(var.cilium_values)
    install = file("${path.module}//talos/inline-manifests/cilium-install.yaml")
  }

  cluster = var.cluster
  image   = var.image
  nodes   = var.nodes
  env     = var.env
}

module "sealed_secrets" {
  depends_on = [module.talos]
  source     = "./bootstrap/sealed-secrets"

  providers = {
    kubernetes = kubernetes
  }

  // openssl req -x509 -days 365 -nodes -newkey rsa:4096 -keyout sealed-secrets.key -out sealed-secrets.cert -subj "/CN=sealed-secret/O=sealed-secret"
  cert = {
    cert = file("${path.module}/assets/sealed-secrets/certificate/sealed-secrets.cert")
    key  = file("${path.module}/assets/sealed-secrets/certificate/sealed-secrets.key")
  }
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
  volumes     = var.volumes
  env         = var.env
}
