# Documentation guide

Use this index to find the module documentation by task.

## Get a cluster running

- [Direct usage examples](examples.md) — prerequisites, a single-node quickstart, a highly available topology, and storage snippets. Start here when using the module directly from Terraform or OpenTofu.
- [Complete input example](full-example.md) — one configuration showing every top-level input, with notes about values and local files to replace.
- [Input variables](variables.md) — types, defaults, constraints, and per-variable examples.

## Choose and operate storage

- [Storage options](storage.md) — Talos directory/disk volumes and Proxmox CSI-backed pre-provisioned volumes, including placement and lifecycle caveats.

## Upgrade and compatibility

- [Upgrade methods](upgrade-methods.md) — procedures for Talos, Kubernetes, and cluster changes.
- [Talos compatibility](talos-compatibility.md) — tested module/Talos combinations and known version-specific caveats.
- [Upgrade notes](../UPGRADE.md) — breaking changes by module release.
- [Changelog](../CHANGELOG.md) — notable changes by release.

The module bootstraps core cluster components. For application deployment, StorageClasses, PVCs, and other post-bootstrap operations, follow the linked guides and your cluster's operational procedures. The author's [homelab](https://github.com/isejalabs/homelab) is a larger Terragrunt-based multi-environment implementation; it is optional context, not a prerequisite for using this module.
