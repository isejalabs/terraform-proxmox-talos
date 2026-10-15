# Canonical examples

These root configurations call the module from a local checkout, so you can review them against the source in this repository before using them. They deliberately use a local Terraform state file; protect it because it contains sensitive values. For a real deployment, configure a remote backend with access controls and backups before the first apply.

- [Minimal cluster](minimal/) — one control-plane node for a lab or evaluation; not highly available.
- [High-availability cluster](high-availability/) — three control-plane nodes and two workers spread over three Proxmox hosts.
- [Full configuration](full/) — one configuration showing every top-level input and all three supported storage types. See the [narrative guide](../docs/full-example.md) for topology and storage caveats.

## Before initializing

Each example expects these files relative to its own directory:

- `assets/talos/schematic.yaml` — your Talos Image Factory schematic.
- `assets/sealed-secrets/certificate/sealed-secrets.cert` and `sealed-secrets.key` — the Sealed Secrets certificate and private key.

Create the directories and certificate in the example directory. Keep the private key and generated `output/` files out of version control. The repository `.gitignore` excludes them. The schematic may encode extensions and configuration choices for your environment; generate it using the [Talos Image Factory](https://factory.talos.dev/) and follow [the image input guidance](../docs/variables.md#image).

~~~sh
mkdir -p assets/talos assets/sealed-secrets/certificate
# Save your Image Factory schematic as assets/talos/schematic.yaml.
openssl req -x509 -days 365 -nodes -newkey rsa:4096 \
  -keyout assets/sealed-secrets/certificate/sealed-secrets.key \
  -out assets/sealed-secrets/certificate/sealed-secrets.cert \
  -subj "/CN=sealed-secret/O=sealed-secret"
chmod 600 assets/sealed-secrets/certificate/sealed-secrets.key
export TF_VAR_proxmox_api_token='terraform@pve!provider=REPLACE-WITH-TOKEN-SECRET'
~~~

Replace all example IP addresses, hostnames, VM IDs, datastores, and versions with values for your environment. The Proxmox API token is supplied through the environment instead of a file committed to the example.

## Validate and plan

Run commands from the selected example directory:

~~~sh
terraform init -backend=false
terraform validate
~~~

Validation checks the configuration shape without creating infrastructure. Once the assets, token, endpoint, networking, and Proxmox resources are configured, inspect a plan before applying:

~~~sh
terraform plan
~~~

Planning may contact configured providers. Review the complete plan and confirm the target Proxmox environment before running `terraform apply`; applying creates VMs and Kubernetes resources. These examples have not been applied to a live Proxmox environment.

For released-module usage, replace the local module `source = "../.."` with a pinned Git source, for example `github.com/isejalabs/terraform-proxmox-talos?ref=v7.6.0`, and follow the matching release's documentation.
