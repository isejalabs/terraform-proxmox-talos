# Talos Compatibility

This document tracks which Talos OS versions are compatible with which version of this module, and documents known caveats specific to upgrading *past* a given Talos version boundary.

It's a companion to [Upgrade Methods](upgrade%20methods.md#talos-os-upgrade), which covers the *mechanics* of performing a Talos OS upgrade with this module (the `nodes[].update` procedure). This document instead covers *what to watch out for* depending on which Talos version(s) you're moving between — information that's a function of the target Talos version itself, independent of which module version you're running.

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

### Talos 1.14: `SecurityProfileConfig.workloadIsolation`

> [!IMPORTANT]
>
> **Upgrading past Talos 1.13 → 1.14 silently enables `SecurityProfileConfig.workloadIsolation`.** Talos 1.14 introduces a `sandboxd`-based workload isolation feature that's version-gated purely on the target Talos version, with no awareness of whether the cluster already exists — unlike a plain `talosctl upgrade apply`, this module's `talos_machine_configuration` data source fully regenerates machine config from `talos_version` on every `apply`, so the 1.14 bump brings `workloadIsolation: true` along with it automatically (see [#265](https://redirect.github.com/isejalabs/terraform-proxmox-talos/issues/265)).
>
> Per [Talos's own docs](https://docs.siderolabs.com/talos/v1.14/getting-started/what's-new-in-talos), this is expected to be safe for a cluster using only CSI drivers for storage (CSI node plugins run self-contained in their own privileged pod and are explicitly unaffected) — only the deprecated **in-tree** kubelet volume plugins (e.g. the in-tree iSCSI plugin) actually break. Still, **verify on a non-prod cluster first**: confirm storage CSI pods stay healthy and any `hostPath`-based workloads (monitoring agents, etc.) keep reporting correctly, before rolling the 1.14 bump to production.
