# Complete cluster configuration

The [full example root configuration](../examples/full/main.tf) brings every top-level module input together in one place. It combines a three-node control plane, two workers, network and image settings, optional Talos settings, and directory, disk, and Proxmox CSI storage examples.

Start with the [canonical examples guide](../examples/README.md) for prerequisites, local assets, state handling, validation, and planning. Replace the example addresses, versions, Proxmox hostnames, VM IDs, datastore names, and file paths in `examples/full/main.tf` with values for your environment before planning. Applying the configuration provisions infrastructure.

The three control-plane VMs should be placed on separate Proxmox hosts when possible, and the VIP must be unused on the node network. Nodes that omit optional settings use the defaults listed in the [input variables reference](variables.md).

The storage map includes a directory and a per-node data disk for workers, plus a Proxmox CSI volume located on `pve1`. A CSI volume on local storage is available only to workloads running on VMs hosted by that Proxmox node; the CSI disk is not replicated. Review [storage options](storage.md) for placement and persistence behavior.
