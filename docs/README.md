# Documentation guide

Use this index to find the module documentation by task.

## Learn and start a cluster

- [Direct usage examples](examples.md) — tutorial with prerequisites, a single-node quickstart, a highly available topology, and storage snippets. Start here when using the module directly from Terraform or OpenTofu.
- [Canonical root configurations](../examples/) — self-contained minimal, high-availability, and full Terraform roots that can be reviewed and validated from a repository checkout.
- [Complete input example](full-example.md) — reference configuration showing every top-level input, with notes about values and local files to replace.
- [Input variables](variables.md) — reference for types, defaults, constraints, and per-variable examples.

## Configure storage

- [Storage options](storage.md) — guide to Talos directory/disk volumes and Proxmox CSI-backed pre-provisioned volumes, including placement and lifecycle caveats.

## Operate and upgrade

- [Upgrade methods](upgrade-methods.md) — operational procedures for Talos, Kubernetes, VM, and module changes.
- [Talos compatibility](talos-compatibility.md) — tested module/Talos combinations and known version-specific caveats.
- [Upgrade notes](../UPGRADE.md) — breaking changes by module release.
- [Changelog](../CHANGELOG.md) — notable changes by release.

The [README](../README.md) explains what the module manages and what remains the caller’s responsibility. The module bootstraps core cluster components. For application deployment, StorageClasses, PVCs, and other post-bootstrap operations, follow the linked guides and your cluster's operational procedures. The author's [homelab](https://github.com/isejalabs/homelab) is a larger Terragrunt-based multi-environment implementation; it is optional context, not a prerequisite for using this module.
