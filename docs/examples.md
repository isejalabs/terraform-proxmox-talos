# Module usage examples

This guide shows direct Terraform/OpenTofu usage without Terragrunt. See [input variables](variables.md) for all options and [storage options](storage.md) for storage behavior and caveats. A [complete configuration](full-example.md) brings every top-level input together.

## Prerequisites

- Proxmox VE with a VM bridge and datastore available.
- A Proxmox API token and SSH access for the configured Proxmox user.
- Reserved IP addresses for the nodes and a reachable gateway.
- Terraform or OpenTofu and a Talos Image Factory schematic file (see [image configuration](variables.md#image)).

Keep credentials out of version control. The examples expose the token as a sensitive root variable populated from TF_VAR_proxmox_api_token.

## Minimal single-node cluster

A single control-plane node is useful for a lab or evaluation, but is not highly available. Replace the example addresses, Proxmox host, versions, and VM ID with values for your environment.

Create a root configuration such as main.tf:

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
~~~

Initialize and review the plan, then apply:

~~~sh
export TF_VAR_proxmox_api_token='terraform@pve!provider=REPLACE-WITH-TOKEN-SECRET'
terraform init
terraform plan
terraform apply
~~~

Use a secrets manager, ignored .tfvars file, or SOPS for local and CI use. Do not commit credentials or generated state. The module writes Talos and Kubernetes client configuration beneath its output directory; treat these files as sensitive and protect shared state accordingly.

## Multiple control-plane and worker nodes

For a highly available control plane, use an odd number of control-plane nodes (commonly three) and set a Talos VIP in cluster.vip. Ensure the VIP is unused and reachable on the node network. Every VM needs a unique ID and IP address.

Replace the cluster and nodes blocks above with the following. This example places two workers and three control-plane VMs across three Proxmox hosts; the module does not require one VM per host.

~~~terraform
cluster = {
  gateway             = "10.20.30.1"
  gateway_api_version = "v1.3.0"
  kubernetes_version  = "v1.33.3"
  name                = "lab"
  proxmox_cluster     = "proxmox"
  vip                 = "10.20.30.40"
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
~~~

## Storage examples

Configure additional volumes with the volumes map. Each entry needs a size and type.

### Directory on workers

A directory volume mounts under /var/mnt on matching Talos nodes and uses the node's existing filesystem capacity.

~~~terraform
volumes = {
  container-data = {
    size         = "0GB" # required by the input; ignored for directory volumes
    type         = "directory"
    machine_type = "worker"
  }
}
~~~

### Additional data disk per matching node

A disk volume creates and attaches a separate Proxmox disk for each matching Talos VM. Talos formats and mounts it; disk sizes use GB units.

~~~terraform
volumes = {
  worker-data = {
    size         = "50GB"
    type         = "disk"
    machine_type = "worker"
    datastore    = "local-zfs"
  }
}
~~~

### Proxmox CSI volume

A proxmox-csi volume creates one disk on the named Proxmox node for the CSI plugin. It is not replicated. With local storage it is usable only by workloads on VMs hosted on that Proxmox node. CSI volume sizes omit the trailing B. Workloads still need Kubernetes StorageClass and PersistentVolumeClaim configuration; see [storage options](storage.md#proxmox-csi-volume-type).

~~~terraform
volumes = {
  database-data = {
    node      = "pve1"
    size      = "100G"
    type      = "proxmox-csi"
    datastore = "local-zfs"
    format    = "raw"
  }
}
~~~

You can combine volume entries in the same map. Review the [storage guide](storage.md) for placement, persistence, migration, and workload configuration caveats.

## Multiple independent clusters

When creating multiple clusters in the same Proxmox environment, use separate Terraform state and a distinct env value for each instance to help avoid naming collisions. Keep VM IDs and IP addresses unique.

~~~terraform
env = "dev"
~~~

The [homelab implementation](https://github.com/isejalabs/homelab) shows a larger Terragrunt-based multi-environment setup.
