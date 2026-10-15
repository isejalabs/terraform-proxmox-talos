# Complete cluster configuration

This reference puts every top-level module input in one configuration. It combines a three-node control plane, two workers, network and image settings, optional Talos settings, and three storage types. Start with [the smaller usage examples](examples.md) if you only need a minimal or focused example.

Treat this as a template: replace the example addresses, versions, Proxmox hostnames, VM IDs, datastore names, and file paths with values for your environment. The configuration provisions infrastructure when applied.

## Required local assets and credentials

The schematic, Sealed Secrets certificate, and private key must exist at the paths shown below. See the [image documentation](variables.md#image) and [Sealed Secrets documentation](variables.md#sealed_secrets_config) for how to create them. Keep the private key and Proxmox API token out of version control. Export the token as a root input variable:

~~~sh
export TF_VAR_proxmox_api_token='terraform@pve!provider=REPLACE-WITH-TOKEN-SECRET'
~~~

## main.tf

~~~terraform
variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

module "talos_cluster" {
  source = "github.com/isejalabs/terraform-proxmox-talos?ref=v7.6.0"

  proxmox_api_token = var.proxmox_api_token

  proxmox = {
    cluster_name = "proxmox"
    endpoint     = "https://pve.example.com:8006"
    insecure     = false
    username     = "terraform"
  }

  cluster = {
    gateway                          = "10.20.30.1"
    gateway_api_version              = "v1.3.0"
    kubernetes_version               = "v1.33.3"
    name                             = "lab"
    proxmox_cluster                  = "proxmox"
    allow_scheduling_on_controlplane = false
    api_server                       = null
    extra_manifests                  = []
    kubelet                          = null
    machine_features                 = null
    on_boot                          = true
    subnet_mask                      = "24"
    talos_machine_config_version     = null
    vip                              = "10.20.30.40"
  }

  image = {
    schematic_path        = "assets/talos/schematic.yaml"
    version               = "v1.11.0"
    arch                  = "amd64"
    factory_url           = "https://factory.talos.dev"
    platform              = "nocloud"
    datastore             = "local"
    update_schematic_path = null
    update_version        = null
  }

  nodes = {
    controlplane1 = {
      cpu                  = 2
      host_node            = "pve1"
      ip                   = "10.20.30.41"
      machine_type         = "controlplane"
      ram_dedicated        = 4096
      vm_id                = 141
      bridge               = "vmbr0"
      cpu_type             = "x86-64-v2-AES"
      datastore            = "local-zfs"
      disk_size            = 20
      dns                  = ["10.20.30.1"]
      igpu                 = false
      mac_address          = null
      talos_config_patches = []
      update               = false
      usb_devices          = []
      vlan_id              = 0
    }
    controlplane2 = {
      cpu           = 2
      host_node     = "pve2"
      ip            = "10.20.30.42"
      machine_type  = "controlplane"
      ram_dedicated = 4096
      vm_id         = 142
    }
    controlplane3 = {
      cpu           = 2
      host_node     = "pve3"
      ip            = "10.20.30.43"
      machine_type  = "controlplane"
      ram_dedicated = 4096
      vm_id         = 143
    }
    worker1 = {
      cpu           = 4
      host_node     = "pve1"
      ip            = "10.20.30.51"
      machine_type  = "worker"
      ram_dedicated = 8192
      vm_id         = 151
    }
    worker2 = {
      cpu           = 4
      host_node     = "pve2"
      ip            = "10.20.30.52"
      machine_type  = "worker"
      ram_dedicated = 8192
      vm_id         = 152
    }
  }

  cilium_config = {
    bootstrap_manifest_path = "talos/inline-manifests/cilium-install.yaml"
    values_file_path        = "talos/inline-manifests/cilium-values.default.yaml"
  }

  sealed_secrets_config = {
    certificate_path = "assets/sealed-secrets/certificate/sealed-secrets.cert"
    key_path         = "assets/sealed-secrets/certificate/sealed-secrets.key"
  }

  talos_config_patches = []

  volumes = {
    worker-directory = {
      size         = "0GB"
      type         = "directory"
      machine_type = "worker"
    }
    worker-disk = {
      size         = "50GB"
      type         = "disk"
      machine_type = "worker"
      datastore    = "local-zfs"
    }
    database-data = {
      node      = "pve1"
      size      = "100G"
      type      = "proxmox-csi"
      datastore = "local-zfs"
      format    = "raw"
      vmid      = 9999
    }
  }

  env = "dev"
}
~~~

The sample explicitly sets optional inputs and VM settings on controlplane1. Nodes that omit optional fields use the module defaults listed in [input variables](variables.md). For an HA control plane, place the three control-plane VMs on separate Proxmox hosts when possible and ensure the VIP is unused on the node network.

The storage map includes a directory and a per-node data disk on workers, plus a Proxmox CSI volume located on pve1. A CSI volume on local storage is available only to workloads running on VMs hosted by that Proxmox node; the CSI disk is not replicated. Review [storage options](storage.md) for placement and persistence behavior.

After creating the required assets, initialize and inspect the plan before applying:

~~~sh
terraform init
terraform plan
terraform apply
~~~

