# Documentation assessment

**Assessed:** 2026-10-15  
**Baseline:** `main` after [PR #279](https://github.com/isejalabs/terraform-proxmox-talos/pull/279) merged.

## Summary

The documentation now has a useful path from the README to direct Terraform/OpenTofu examples, including a minimal cluster, a multi-node topology, storage variants, and one full configuration containing the module inputs together. The repository also has substantial reference material for variables, storage behavior, VM architecture, upgrades, and Talos compatibility. The central remaining risks are correctness at the copy/paste boundary and missing first-run steps in the minimal example.

This was a static documentation review. Example HCL was compared with the root module schema and generated module reference, and output file paths were checked against `output.tf`. No Terraform/OpenTofu plan or live Proxmox apply was run.

## What is working well

- `README.md` now directs users to standalone examples before the larger Terragrunt-based homelab implementation.
- `docs/examples.md` gives a direct module configuration, an HA control-plane/worker topology, storage examples, token handling, and separate-state guidance.
- `docs/full-example.md` puts the major inputs into a single realistic configuration and calls out local asset and storage caveats.
- The deeper references cover important operational hazards: CSI placement and persistence, Talos/data VM separation, staged upgrades, and Talos-version-specific behavior.

## Findings

### 1. The quickstart prerequisites and first-use path are incomplete

The prerequisites in `docs/examples.md` mention the Talos schematic but omit the Sealed Secrets certificate and private key. The module defaults to local paths for both, and `docs/variables.md` says they must be generated even when default paths are used. The full example makes this requirement clearer than the minimal path. After `terraform apply`, the quickstart also does not show how to use the generated kubeconfig to check that the nodes joined. `output.tf` writes kubeconfig and Talos client config files under `output/`, but a first-time user should not need to inspect Terraform source to discover that.

Tracked in [#280](https://github.com/isejalabs/terraform-proxmox-talos/issues/280).

### 2. The detailed variable reference has copy/paste mismatches

`docs/variables.md` currently spells the cluster field as `extraManifests` instead of `extra_manifests`; its node example uses `vlan` instead of `vlan_id`; and the `volumes.type` description says `proxmox-volume` is the default although the accepted/default value is `proxmox-csi`. These disagree with `variables.tf` and `docs/module.md`. At least the node example is invalid as written, which undermines the variable reference as a reliable source when constructing a full input object.

Tracked in [#281](https://github.com/isejalabs/terraform-proxmox-talos/issues/281).

### 3. Compatibility information needs version-aware upkeep

`docs/talos-compatibility.md` intentionally records validated ranges rather than adding a row for every module release. Its current caveat says Talos 1.15 is untested “as of v7.5,” while the new examples pin v7.6.0. This is not necessarily a compatibility error—the document explains its update policy—but future compatibility checks should update the version qualifier and matrix when validated support changes so readers can tell how current the evidence is.

## Existing follow-up work

Several deeper storage documentation topics already have issues and should be handled there rather than duplicated: [#277](https://github.com/isejalabs/terraform-proxmox-talos/issues/277) covers safe datastore changes and recovery; [#237](https://github.com/isejalabs/terraform-proxmox-talos/issues/237) asks why the CSI role needs root-path privileges; and [#191](https://github.com/isejalabs/terraform-proxmox-talos/issues/191), [#192](https://github.com/isejalabs/terraform-proxmox-talos/issues/192), and [#196](https://github.com/isejalabs/terraform-proxmox-talos/issues/196) track Talos volume behavior and size/change semantics.

## Suggested order

1. Address [#280](https://github.com/isejalabs/terraform-proxmox-talos/issues/280) so the minimal example includes the assets and steps needed to reach a verifiable cluster.
2. Address [#281](https://github.com/isejalabs/terraform-proxmox-talos/issues/281) so the detailed variable reference matches the actual schema and examples are copyable.
3. Continue the existing storage documentation work in its current issues, and keep the compatibility note tied to the latest validated module/Talos pair when the matrix changes.
