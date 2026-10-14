# Talos Compatibility

This document tracks which Talos OS versions are compatible with which version of this module, and documents known caveats specific to upgrading *past* a given Talos version boundary.

It's a companion to [Upgrade Methods](upgrade-methods.md#talos-os-upgrade), which covers the *mechanics* of performing a Talos OS upgrade with this module (the `nodes[].update` procedure). This document instead covers *what to watch out for* depending on which Talos version(s) you're moving between — information that's a function of the target Talos version itself, independent of which module version you're running.

## Compatibility Matrix

| Module Version | not using `disk` feature | using `disk` feature |
| --------------- | ------------------------- | --------------------- |
| v5.0            | >=1.8                     | not available          |
| v6.0            | >=1.10                    | >=1.11, <=1.12          |
| v7.0            | >=1.12                    | >=1.12                 |

> [!NOTE]
> These ranges reflect what's been validated and documented, not a hard limit enforced by this module or its `siderolabs/talos` provider dependency — the provider's own version constraint (`talos/providers.tf`) has no upper bound. A module version working with a newer Talos release than listed here is plausible, but hasn't necessarily been verified; see the per-version caveats below for known exceptions.
>
> This table isn't actively maintained release-by-release going forward — rows are added when a module release changes the supported range (as tracked historically in [CHANGELOG.md](../CHANGELOG.md)'s "Compatibility Note" sections for v5.0/v6.0/v7.0), or when a notable caveat below warrants a new entry.

## Per-Talos-Version Caveats

Caveats in this section apply to the target Talos version regardless of which module version you're on, since they stem from Talos's own behavior, not this module's code.

### Talos 1.14: multi-document machine config (fixed, two known gaps remain)

> [!IMPORTANT]
>
> **Talos 1.14 moves several `v1alpha1` fields into dedicated configuration documents** (`KubeletConfig`, `KubeNodeConfig`, `KubeAPIServerConfig`, `KubeControllerManagerConfig`, `KubeSchedulerConfig`, `KubeProxyConfig`, `KubeFlannelCNIConfig`, etc. — see [Talos's document map](https://docs.siderolabs.com/talos/v1.14/reference/configuration/document-map)) and rejects a config that sets the same thing in both places. Since this module fully regenerates machine config from `talos_version` on every `apply` (unlike a plain `talosctl upgrade`, which only swaps the OS image), this previously broke any apply targeting a 1.14+ contract outright (see [#269](https://redirect.github.com/isejalabs/terraform-proxmox-talos/issues/269)).
>
> **Fixed** as of this module version: machine config generation is now version-gated, emitting the affected fields on their new document for 1.14+. Verified end-to-end against a real Talos 1.14.2 cluster bootstrap.
>
> **Two known gaps remain** (no confirmed 1.14+ replacement identified yet — tracked in [#269](https://redirect.github.com/isejalabs/terraform-proxmox-talos/issues/269)):
> - `machine.features.hostDNS` is dropped for 1.14+, falling back to Talos's own default.
> - `cluster.allowSchedulingOnControlPlanes = true` is dropped for 1.14+ — the default (`false`) is verified correct, but setting this to `true` will not take effect on 1.14+ yet.
>
> **If your own `talos_config_patches` files set any of the migrated fields** (e.g. a `cluster.controllerManager`/`cluster.scheduler` leader-election patch), they'll need their own 1.14+ variant too — this module can't migrate a consumer's own patch files automatically.
>
> **If a cluster was already bootstrapped on 1.14+ before this fix**, Talos will have deployed the default Flannel CNI DaemonSet once at initial bootstrap; a config change alone won't retroactively remove it — clean up the `kube-flannel` DaemonSet/ClusterRole/ClusterRoleBinding/ServiceAccount/ConfigMap manually (and restart any pods that got stuck from the resulting broken networking) after applying the fix.

### Talos 1.14: `SecurityProfileConfig.workloadIsolation`

> [!IMPORTANT]
>
> **Upgrading past Talos 1.13 → 1.14 silently enables `SecurityProfileConfig.workloadIsolation`.** Talos 1.14 introduces a `sandboxd`-based workload isolation feature that's version-gated purely on the target Talos version, with no awareness of whether the cluster already exists — unlike a plain `talosctl upgrade apply`, this module's `talos_machine_configuration` data source fully regenerates machine config from `talos_version` on every `apply`, so the 1.14 bump brings `workloadIsolation: true` along with it automatically (see [#265](https://redirect.github.com/isejalabs/terraform-proxmox-talos/issues/265)).
>
> Per [Talos's own docs](https://docs.siderolabs.com/talos/v1.14/getting-started/what's-new-in-talos), this is expected to be safe for a cluster using only CSI drivers for storage (CSI node plugins run self-contained in their own privileged pod and are explicitly unaffected) — only the deprecated **in-tree** kubelet volume plugins (e.g. the in-tree iSCSI plugin) actually break. Still, **verify on a non-prod cluster first**: confirm storage CSI pods stay healthy and any `hostPath`-based workloads (monitoring agents, etc.) keep reporting correctly, before rolling the 1.14 bump to production.
