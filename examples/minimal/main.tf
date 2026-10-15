variable "proxmox_api_token" {
  description = "Proxmox API token, preferably supplied through TF_VAR_proxmox_api_token."
  type        = string
  sensitive   = true
}

module "talos_cluster" {
  source = "../.."

  proxmox_api_token = var.proxmox_api_token

  # The example uses the repository checkout as its local module source.
  # Resolve these module-owned files from this example's directory.
  cilium_config = {
    bootstrap_manifest_path = "${path.module}/../../talos/inline-manifests/cilium-install.yaml"
    values_file_path        = "${path.module}/../../talos/inline-manifests/cilium-values.default.yaml"
  }

  proxmox = {
    cluster_name = "proxmox"
    endpoint     = "https://pve.example.com:8006"
    insecure     = false
    username     = "terraform"
  }

  cluster = {
    gateway             = "10.20.30.1"
    gateway_api_version = "v1.3.0"
    kubernetes_version  = "v1.33.3"
    name                = "lab"
    proxmox_cluster     = "proxmox"
  }

  image = {
    schematic_path = "assets/talos/schematic.yaml"
    version        = "v1.11.0"
  }

  nodes = {
    controlplane1 = {
      cpu           = 2
      host_node     = "pve1"
      ip            = "10.20.30.41"
      machine_type  = "controlplane"
      ram_dedicated = 4096
      vm_id         = 141
    }
  }
}
