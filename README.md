## About

A `terraform`/`tofu` module for creating a [Kubernetes](https://kubernetes.io/) cluster on [Proxmox VE](https://www.proxmox.com/en/proxmox-virtual-environment), using [Talos Linux](https://talos.dev) as the governing declarative K8S OS.


## What's in the pocket

You will get:

- [Kubernetes](https://kubernetes.io/) cluster based on
- [Talos Linux](https://talos.dev) (a secure, immutable, and minimal
  distribution, explecitely designed for K8S) with
- [Cilium](https://cilium.io) as a [CNI](https://www.cni.dev),
- [Gateway API](https://gateway-api.sigs.k8s.io/) as next-generation
   Kubernetes Ingress,
- [Proxmox CSI Plugin](https://github.com/sergelogvinov/proxmox-csi-plugin) for providing storage,
- [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets) providing a safe store for your [`Secrets`](https://kubernetes.io/docs/concepts/configuration/secret/) – even inside a public repository –,
- all running as QEMU/KVM VMs on [Proxmox VE](https://www.proxmox.com/en/proxmox-virtual-environment).

Everything is set up with a simple `terragrunt apply` command.

This module is designed for being minimalistic by bootstrapping a Kubernetes cluster with core intrastructure CNI, CSI and Secrets.  Of course, you can add more Kubernetes features, e.g. [Argo CD](https://argo-cd.readthedocs.io/en/stable/) and [Cert-manager](https://cert-manager.io/), by defining [kustomize](https://kustomize.io/) YAML code on-top.

## Usage

### Documentation

- [Module Technical Documentation](docs/module.md)
- [Input Variables Documentation](docs/variables.md)

### Example

For seeing an example usage of the module, please be referred to the [author](https://github.com/sebiklamar/)'s implementation of the module in [isejalab/homelab](https://github.com/isejalabs/homelab).  You will see this module being used in a multi-environment (e.g. dev, qa, prod), not only leveraging [Terragrunt](https://terragrunt.gruntwork.io/) as a DRY-style wrapper for `terraform`/`tofu`.  Copious amounts of [YAML](https://yaml.org/) using [kustomize](https://kustomize.io/) and its [transformer](https://github.com/kubernetes-sigs/kustomize/blob/master/examples/transformerconfigs/README.md), patches and components features will provide more [DRY](https://de.wikipedia.org/wiki/Don%E2%80%99t_repeat_yourself) capabilities.

    
## Roadmap and more features


If you think a feature is worth being implemented inside this terraform/tofu module, feel free starting a community [discussion](https://github.com/isejalabs/terraform-proxmox-talos/discussions).  You can also look for existing [feature requests](https://github.com/isejalabs/terraform-proxmox-talos/issues?q=is%3Aissue%20state%3Aopen%20type%3AFeature) created in the [issue tracker](https://github.com/isejalabs/terraform-proxmox-talos/issues) which is governed by the author's [homelab project](https://github.com/orgs/isejalabs/projects/1).

## Requirements

1. **Required**: You need to have one or more
    [**Proxmox**](https://www.proxmox.com/en/proxmox-virtual-environment) nodes to run the VMs on.  A Proxmox cluster is required in the case of multiple nodes.
2. **Free Choice**: The module is tested to running well with
   [**OpenTofu**](https://opentofu.org/), while it should be compatible with [**Terraform**](https://www.terraform.io/) as well.
3. **Recommended**: It's recommended using
   [**Terragrunt**](https://terragrunt.gruntwork.io/) as a wrapper when aiming for multiple incarnations of the module.  Plain `terraform`/`tofu` calling without using `terragrunt` as a wrapper should also work.
4. **Recommended**: It's recommended using [**SOPS**](https://getsops.io/)
   for encrypting your Terraform credentials (e.g. Proxmox login).  This allows storing all your Terraform configuration in version control.
6. **Recommended**: For daily operations of the cluster you should have
   K8S **CLI tools** such als `kubectl`, `kustomize`, `cilium`, and `kubeseal`.
5. **Optional**: You could have CLI tool `talosctl` for checking your
   Talos cluster.  It's not really needed because even upgrades are done using declarative IaC – in a good and bad manner (see siderolabs/terraform-provider-talos#140).
   
   Upgrades are handled setting the `nodes.[].update` variable to `true`, subsequently for all nodes.


## Credits

This module would not exist without [**Vegard Stenhjem Hagen**](https://github.com/vehagn)'s excellent work on his [@vehagn/homelab/tofu/kubernets](https://github.com/vehagn/homelab/tree/140fbc249b26c622c0e2ab413c3aca9eb5014f8e) implementation.  Besides variables and releases/tags, some other small changes got added, making this terraform module more usable in different environments.  See the [Changelog](CHANGELOG.md) for a full list of changes. And don't miss out checking Vegard's helpful [blog](https://blog.stonegarden.dev/), where he's giving brilliant explainations on Kubernetes topics, and of course his [homelab implementation](https://github.com/vehagn/homelab).
