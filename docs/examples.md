# Module usage examples

This guide shows direct Terraform/OpenTofu usage without Terragrunt. See [input variables](variables.md) for all options and [storage options](storage.md) for storage behavior and caveats. A [complete configuration](full-example.md) brings every top-level input together.

## Prerequisites

- Proxmox VE with a VM bridge and datastore available.
- A Proxmox API token and SSH access for the configured Proxmox user.
- Reserved IP addresses for the nodes and a reachable gateway.
- Terraform or OpenTofu and a Talos Image Factory schematic file (see [image configuration](variables.md#image)).

Keep credentials out of version control. The examples expose the token as a sensitive root variable populated from TF_VAR_proxmox_api_token.

Before initializing Terraform/OpenTofu, create the Talos Image Factory schematic at the path configured by image.schematic_path. The module also requires the Sealed Secrets certificate and private key at the paths in sealed_secrets_config (defaults shown below):

~~~sh
mkdir -p assets/talos assets/sealed-secrets/certificate
# Save your Image Factory schematic as assets/talos/schematic.yaml.
openssl req -x509 -days 365 -nodes -newkey rsa:4096 \
  -keyout assets/sealed-secrets/certificate/sealed-secrets.key \
  -out assets/sealed-secrets/certificate/sealed-secrets.cert \
  -subj "/CN=sealed-secret/O=sealed-secret"
chmod 600 assets/sealed-secrets/certificate/sealed-secrets.key
~~~

The key is installed as a Kubernetes Secret and Terraform state contains sensitive material. Never commit the key, generated client configurations, state, or saved plan files. Use an encrypted, access-controlled state backend and protect its backups. The assets/ and output/ paths must remain local and excluded from version control.

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

Use a secrets manager, an ignored .tfvars file, or SOPS for local and CI credentials. Terraform's sensitive flag redacts display; it does not encrypt values in state.

After apply completes, the module writes the following files beneath output/:

- output/kube-config.yaml — Kubernetes client configuration.
- output/talos-config.yaml — Talos client configuration.
- output/talos-machine-config-<node>.yaml — generated per-node machine configuration.
- output/talos-machine-secrets.yaml — Talos cluster secrets; protect it as a credential.

Verify the cluster using the generated kubeconfig:

~~~sh
export KUBECONFIG=output/kube-config.yaml
kubectl cluster-info
kubectl get nodes -o wide
~~~

The bootstrap is complete when the API responds and every expected node reaches Ready. The cluster is not highly available with this single-node topology. Protect the state backend and backups, and keep local assets/ and output/ files out of version control.
