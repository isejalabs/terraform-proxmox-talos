# Terraform Proxmox Talos documentation audit

**Date:** 2026-10-15. **Status:** Assessment complete; static review only. **Baseline:** main after [PR #279](https://github.com/isejalabs/terraform-proxmox-talos/pull/279) merged. **Scope:** Public README and docs, example configurations, generated module reference, root input/output declarations. No plan, live Proxmox apply, or operational procedure was exercised.

## Summary

The repository has moved beyond the original “see the homelab” documentation gap. A reader can now find direct Terraform/OpenTofu examples, a multi-node topology, a complete input example, and substantial storage and upgrade guidance. The depth is a strength: the storage and upgrade guides capture operational details that many modules leave implicit.

The main remaining problem is consistency across layers. The landing page can promise more than the module itself configures; quickstart prerequisites and completion checks are incomplete; the storage type contract is contradictory; and hand-written examples/reference material do not always match the schema. The information architecture also asks new users to navigate several large files without a clear documentation index or task-based route. The module reference is generated, but its output descriptions are empty, reducing the usefulness of the generated interface view.

This review compared the documentation against the current root variables, outputs, provider declarations, and generated docs/module.md. It is a content and approach assessment; example HCL was not run through terraform init/validate, and no compatibility claim was re-tested against a cluster.

## What is working well

- README.md now points readers to direct usage examples before the author’s Terragrunt-based homelab. This properly separates the module’s common path from a larger deployment architecture.
- docs/examples.md gives a low-input single-node configuration, an HA topology, and examples for directory, data-disk, and Proxmox CSI volumes. The examples pin a module tag and include a plan-before-apply step.
- docs/full-example.md collects all root inputs in one place and says which values, paths, and assets need replacing. It is useful as an interface inventory even though it is not self-contained without local assets.
- docs/storage.md explains the difference between Talos volumes and CSI-backed storage, workload requirements, placement, disk ordering, removal, and datastore-change hazards. Its detail is valuable for avoiding data loss.
- docs/upgrade-methods.md separates upgrade types and provides concrete staged Talos upgrade steps, including machine-config version interactions and Proxmox SSH requirements.
- docs/variables.md includes a table of contents and detailed nested-object examples; docs/talos-compatibility.md correctly distinguishes tested ranges from hard provider limits.

## Findings

### 1. The getting-started path does not yet reach a verifiable cluster

docs/examples.md requires a schematic but does not mention the Sealed Secrets certificate and private key, although the module defaults to local paths for both and the variable reference says to generate them. Its minimal example ends at terraform apply; it does not show where the generated kubeconfig is written or how to verify nodes and cluster access. output.tf writes output/kube-config.yaml and output/talos-config.yaml. docs/full-example.md explains the certificate requirement but likewise stops after apply. This leaves the first-run guide incomplete at exactly the point a new user needs to validate success.

Tracked in [#280](https://github.com/isejalabs/terraform-proxmox-talos/issues/280). Keep one canonical quickstart with prerequisites, local asset creation, credentials, init/plan/apply, generated-file locations, a basic kubectl/talosctl check, and a clear statement of what “ready” means.

### 2. README language blurs what the module installs versus what the operator must install

The README says “Everything is set up with a simple terraform apply command” and lists the Proxmox CSI Plugin as something users “will get.” The storage guide later says CSI driver installation, StorageClass, and workload PVCs are user-configured and out of scope. The module does prepare CSI-related Proxmox/Kubernetes resources and can create pre-provisioned PVs, but those are not equivalent to installing and configuring the CSI driver. The README should distinguish resources managed by this module from add-ons and cluster operations left to the caller. The same section should make the local generated assets and SSH/API prerequisites visible before claiming one-command setup.

Suggested direction: replace the broad promise with a short “What this module creates / What you still configure” summary and link to the quickstart and storage guide. This will reduce surprise without moving the detailed CSI instructions into the README.

### 3. The documented storage type contract conflicts with validation and generated docs

docs/storage.md lists partition in its volume-type table and has a later architecture subsection for it, but the same table says it is unavailable. variables.tf validation accepts only directory, disk, and proxmox-csi; partition is rejected. The generated docs/module.md type comment includes partition, which can make it appear supported to consumers. This is a contract conflict between prose, generated interface documentation, and runtime validation—not just an outdated example.

Choose and state one supported set. Until implementation exists, mark partition as planned/unavailable everywhere and remove it from the generated type comment; if it is implemented, validate its behavior and update the restrictions, examples, and compatibility notes together. Add a schema/example review to the docs workflow so these views cannot drift silently.

### 4. The hand-written variable reference contains copy/paste errors, and generated outputs say “n/a”

docs/variables.md calls the cluster input extraManifests instead of extra_manifests, uses vlan instead of vlan_id, and describes proxmox-volume as the default volumes.type although the schema defaults to proxmox-csi. These conflict with variables.tf and docs/module.md; the vlan example is invalid. Also, the generated module reference shows n/a for both outputs because output.tf does not give them descriptions. That leaves users without a concise statement of what each output contains and that the values are sensitive client configuration.

Tracked in [#281](https://github.com/isejalabs/terraform-proxmox-talos/issues/281). Fix the known field/default mismatches, add concise output descriptions in the declarations, then cross-check every example against the typed object schema. Keep the generated reference as the structural source and the curated variable guide for semantics, caveats, and examples.

### 5. The examples teach patterns, but are not independently runnable or checked

The examples are embedded as snippets in docs/examples.md and docs/full-example.md. The HA example asks the user to replace selected blocks in the earlier module block, while storage snippets are assignment fragments; the full example needs local schematic and certificate files at specific paths. This is a reasonable progression for reading, but users cannot clone an example directory and run init, validate, and plan against it, and CI cannot easily detect when a copied block drifts from the module interface. The static review did not validate any of these snippets.

Terraform’s standard module guidance recommends keeping usage examples under a root examples directory, with an explanation for each, and using the external caller’s module source address in copied module blocks ([standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure)). Consider checked-in, self-contained minimal and HA examples with clearly fake local asset placeholders and a documented non-apply workflow. Keep the docs snippets short and link to those canonical files. Add a lightweight CI validation path for examples where local inputs permit it; explicitly identify any example that is illustrative and cannot be planned without a real Proxmox environment.

### 6. The documentation has useful pages but no clear task-based index, and the long guides are hard to scan

The README contains a useful list, but there is no docs/README.md index for readers who land in the directory or need to choose between learning, reference, storage, and operations content. docs/storage.md is 417 lines and docs/upgrade-methods.md is 345 lines. Both have high-level orientation, but neither has a compact in-page contents list for its many sections. docs/variables.md does have a ToC, showing that this works well for long reference content. docs/examples.md also moves quickly from a complete minimal module to replacement fragments without an explicit “choose this path” map.

Add a small docs index organized around reader tasks—start a cluster, choose a topology, configure storage, customize Talos/Cilium, upgrade, troubleshoot—and label each page as tutorial, reference, or operations guide. Add local ToCs to the long storage and upgrade pages, and a brief navigation/decision table to the examples page. Prefer links to canonical detail over duplicating paragraphs across README and guides.

### 7. Secret and state handling is mentioned but not explained as an end-to-end boundary

The examples correctly warn against committing credentials/state and call generated client configurations sensitive. However, the module also writes output/talos-machine-secrets.yaml; the output resource does not set an explicit file permission, while the Talos/kube config files do set 0600. The docs do not clearly inventory these artifacts, explain that Terraform state and saved plan files must be treated as sensitive, or tell users to secure the backend, access, backups, and local output directory. The README’s SOPS recommendation addresses configuration credentials but is not a replacement for state protection.

Document the generated artifacts and their sensitivity, distinguish encrypted configuration from Terraform state, state the backend/access/backup expectations, and ensure the output directory is excluded from version control. Review file permissions for all generated secret-bearing files and describe the actual behavior rather than implying the sensitive output flag encrypts stored values.

### 8. Compatibility and tool-version claims need a clear tested baseline

The README says OpenTofu is tested and Terraform should be compatible, but does not state a tested tool-version range or minimum. The root terraform block pins provider versions but has no required_version. The compatibility matrix ends at module v7.5, while the current usage examples pin v7.6.0; the note says Talos 1.15 is untested “as of v7.5.” The matrix’s policy of recording compatibility changes rather than every module release is reasonable, but the current examples and table do not give readers one coherent, dated tested baseline.

Publish the versions actually exercised for Terraform/OpenTofu, providers, module, Talos, Kubernetes, and any compatibility-critical features; link to the matrix from the example version pins. Add required_version if the module intends to enforce a Terraform floor, or clearly label the versions as tested rather than enforced. Update the compatibility note whenever validation changes, and avoid claiming support based only on plausible provider compatibility.

### 9. Proofreading and terminology cleanup would improve trust

The README contains visible typos (“explecitely,” “intrastructure,” “handing,” “als”) and switches between “K8S,” “Kubernetes,” “terraform,” “Terraform,” “tofu,” and “OpenTofu.” Some variable prose also contains older sample values that differ from the current direct-usage examples. These do not block use, but they make a technically detailed module feel less polished and can make stale examples harder to distinguish from intentional version pins.

Adopt consistent product/CLI terminology, proofread the landing page and variable guide, and mark version values as illustrative or pinned-and-tested. Prefer current versioned upstream documentation links for version-specific Talos behavior.

## Existing related follow-up work

Storage behavior already has issue coverage and should not be split into duplicates: [#277](https://github.com/isejalabs/terraform-proxmox-talos/issues/277) covers datastore changes and recovery; [#237](https://github.com/isejalabs/terraform-proxmox-talos/issues/237) asks about CSI role root-path privileges; and [#191](https://github.com/isejalabs/terraform-proxmox-talos/issues/191), [#192](https://github.com/isejalabs/terraform-proxmox-talos/issues/192), and [#196](https://github.com/isejalabs/terraform-proxmox-talos/issues/196) cover Talos volume behavior and sizing/change semantics.

## Suggested order

1. Complete the direct-user quickstart and verification path in [#280](https://github.com/isejalabs/terraform-proxmox-talos/issues/280).
2. Fix schema alignment and generated interface descriptions in [#281](https://github.com/isejalabs/terraform-proxmox-talos/issues/281).
3. Resolve the unsupported partition contract and clarify the README’s managed-versus-user-managed boundary.
4. Add runnable, reviewable example configurations and a docs index/ToCs; validate snippets against the module schema.
5. Make state and generated-secret handling explicit, then refresh the tested tool/module compatibility baseline and proofread terminology.

## References

- [Terraform standard module structure](https://developer.hashicorp.com/terraform/language/modules/develop/structure) — examples, README scope, and descriptions for variables/outputs.
- [Terraform module development](https://developer.hashicorp.com/terraform/language/modules/develop) — reusable module inputs, outputs, and distribution.
