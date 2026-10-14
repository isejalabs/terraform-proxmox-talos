locals {
  first_control_plane_node_ip = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"][0]
  kubernetes_endpoint         = coalesce(var.cluster.vip, local.first_control_plane_node_ip)
  extra_manifests = concat(var.cluster.extra_manifests, [
    "https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.cluster.gateway_api_version}/standard-install.yaml",
  ])

  # Talos Machine Configuration patches
  talos_config_patches_all          = coalesce([for k, v in var.talos_config_patches : v.path if v.machine_type == "all"], [])
  talos_config_patches_controlplane = coalesce([for k, v in var.talos_config_patches : v.path if v.machine_type == "controlplane"], [])
  talos_config_patches_worker       = coalesce([for k, v in var.talos_config_patches : v.path if v.machine_type == "worker"], [])

  # Talos 1.14+ moves several settings out of the monolithic v1alpha1 document into dedicated
  # configuration documents (KubeletConfig, KubeNodeConfig, KubeAPIServerConfig, etc.) and rejects
  # a config that sets the same thing in both places. See docs/talos-compatibility.md for details.
  talos_version_for_node = {
    for k, v in var.nodes : k => var.cluster.talos_machine_config_version != null ? var.cluster.talos_machine_config_version : (v.update == true ? var.image.update_version : var.image.version)
  }
  talos_version_major_minor_for_node = {
    for k, v in local.talos_version_for_node : k => regex("^v(\\d+)\\.(\\d+)", v)
  }
  talos_1_14_plus_for_node = {
    for k, v in local.talos_version_major_minor_for_node : k => (
      tonumber(v[0]) > 1 || (tonumber(v[0]) == 1 && tonumber(v[1]) >= 14)
    )
  }

  # `cluster.kubelet` is a single free-form v1alpha1 `machine.kubelet` patch; on 1.14+,
  # `registerWithFQDN` moved to the new `KubeNodeConfig` document while the rest (extraArgs,
  # image, config, clusterDNS, ...) stays on the new `KubeletConfig` document. Split them here so
  # each lands on the document Talos now expects it on.
  kubelet_parsed             = yamldecode(coalesce(var.cluster.kubelet, "{}"))
  kubelet_register_with_fqdn = try(local.kubelet_parsed.registerWithFQDN, null)
  kubelet_config_fields      = { for k, v in local.kubelet_parsed : k => v if k != "registerWithFQDN" }
  kubelet_config_yaml        = length(local.kubelet_config_fields) > 0 ? yamlencode(local.kubelet_config_fields) : null

  # `cluster.api_server` sets `certSANs` under v1alpha1; the new `KubeAPIServerConfig` document
  # renamed that field to `certExtraSANs` (everything else, e.g. `extraArgs`, kept its name).
  api_server_parsed = yamldecode(coalesce(var.cluster.api_server, "{}"))
  api_server_renamed = merge(
    { for k, v in local.api_server_parsed : k => v if k != "certSANs" },
    contains(keys(local.api_server_parsed), "certSANs") ? { certExtraSANs = local.api_server_parsed.certSANs } : {},
  )
  api_server_config_yaml = length(local.api_server_renamed) > 0 ? yamlencode(local.api_server_renamed) : null

  # `machine.features.hostDNS` is deprecated in Talos 1.14 in favor of the `ResolverConfig`
  # document's own `hostDNS` field (https://docs.siderolabs.com/talos/v1.14/networking/host-dns);
  # everything else under `machine.features` stays there.
  machine_features_parsed    = yamldecode(coalesce(var.cluster.machine_features, "{}"))
  machine_features_host_dns  = try(local.machine_features_parsed.hostDNS, null)
  machine_features_rest      = { for k, v in local.machine_features_parsed : k => v if k != "hostDNS" }
  machine_features_rest_yaml = length(local.machine_features_rest) > 0 ? yamlencode(local.machine_features_rest) : null
  host_dns_yaml              = local.machine_features_host_dns != null ? yamlencode(local.machine_features_host_dns) : null
}

resource "talos_machine_secrets" "this" {
  // Changing talos_version causes trouble as new certs are created
}

data "talos_client_configuration" "this" {
  cluster_name         = var.cluster.name
  client_configuration = talos_machine_secrets.this.client_configuration
  nodes                = [for k, v in var.nodes : v.ip]
  endpoints            = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
}

resource "terraform_data" "cilium_bootstrap_inline_manifests" {
  input = [
    {
      name     = "cilium-bootstrap"
      contents = file("${var.cilium_config.bootstrap_manifest_path}")
    },
    {
      name = "cilium-values"
      contents = yamlencode({
        apiVersion = "v1"
        kind       = "ConfigMap"
        metadata = {
          name      = "cilium-values"
          namespace = "kube-system"
        }
        data = {
          "values.yaml" = file("${var.cilium_config.values_file_path}")
        }
      })
    }
  ]
}

data "talos_machine_configuration" "this" {
  for_each     = var.nodes
  cluster_name = var.cluster.name
  # This is the Kubernetes API Server endpoint.
  # ref - https://www.talos.dev/latest/introduction/prodnotes/#decide-the-kubernetes-endpoint
  cluster_endpoint = "https://${local.kubernetes_endpoint}:6443"
  # @formatter:off
  talos_version = var.cluster.talos_machine_config_version != null ? var.cluster.talos_machine_config_version : (each.value.update == true ? var.image.update_version : var.image.version)
  # @formatter:on
  machine_type    = each.value.machine_type
  machine_secrets = talos_machine_secrets.this.machine_secrets
  config_patches = concat([
    templatefile("${path.module}/machine-config/common.yaml.tftpl", {
      dns                        = each.value.dns
      node_name                  = each.value.host_node
      cluster_name               = var.cluster.proxmox_cluster
      kubernetes_version         = var.cluster.kubernetes_version
      hostname                   = each.key
      kubelet                    = var.cluster.kubelet
      machine_features           = var.cluster.machine_features
      talos_1_14_plus            = local.talos_1_14_plus_for_node[each.key]
      kubelet_config_yaml        = local.kubelet_config_yaml
      kubelet_register_with_fqdn = local.kubelet_register_with_fqdn
      machine_features_rest_yaml = local.machine_features_rest_yaml
      host_dns_yaml              = local.host_dns_yaml
    }),
    each.value.machine_type == "controlplane" ?
    templatefile("${path.module}/machine-config/control-plane.yaml.tftpl", {
      talos_volumes          = var.talos_volumes
      talos_disk_volumes     = var.talos_disk_volumes
      allow_scheduling       = var.cluster.allow_scheduling_on_controlplane
      ip                     = each.value.ip
      mac_address            = try(lower(each.value.mac_address), null)
      gateway                = var.cluster.gateway
      subnet_mask            = var.cluster.subnet_mask
      vip                    = var.cluster.vip
      extra_manifests        = jsonencode(local.extra_manifests)
      api_server             = var.cluster.api_server
      inline_manifests       = jsonencode(terraform_data.cilium_bootstrap_inline_manifests.output)
      talos_1_14_plus        = local.talos_1_14_plus_for_node[each.key]
      api_server_config_yaml = local.api_server_config_yaml
      kubernetes_version     = var.cluster.kubernetes_version
    }) :
    templatefile("${path.module}/machine-config/worker.yaml.tftpl", {
      talos_volumes      = var.talos_volumes
      talos_disk_volumes = var.talos_disk_volumes
      ip                 = each.value.ip
      mac_address        = try(lower(each.value.mac_address), null)
      gateway            = var.cluster.gateway
      subnet_mask        = var.cluster.subnet_mask
    })
    ],
    local.talos_config_patches_all,
    each.value.machine_type == "controlplane" ?
    local.talos_config_patches_controlplane :
    local.talos_config_patches_worker,
    each.value.talos_config_patches,
  )
}

resource "talos_machine_configuration_apply" "this" {
  depends_on                  = [proxmox_virtual_environment_vm.this]
  for_each                    = var.nodes
  node                        = each.value.ip
  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.this[each.key].machine_configuration
  lifecycle {
    # re-run config apply if vm changes
    replace_triggered_by = [proxmox_virtual_environment_vm.this[each.key]]
  }
}

resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.this]
  # Bootstrap with the first control plane node.
  # VIP not yet available at this stage, so can't use var.cluster.vip
  # ref - https://www.talos.dev/v1.9/talos-guides/network/vip/#caveats
  node                 = local.first_control_plane_node_ip
  client_configuration = talos_machine_secrets.this.client_configuration
}

data "talos_cluster_health" "this" {
  depends_on = [
    talos_machine_configuration_apply.this,
    talos_machine_bootstrap.this
  ]
  skip_kubernetes_checks = false
  client_configuration   = data.talos_client_configuration.this.client_configuration
  control_plane_nodes    = [for k, v in var.nodes : v.ip if v.machine_type == "controlplane"]
  worker_nodes           = [for k, v in var.nodes : v.ip if v.machine_type == "worker"]
  endpoints              = data.talos_client_configuration.this.endpoints
  timeouts = {
    read = "10m"
  }
}

resource "talos_cluster_kubeconfig" "this" {
  depends_on = [
    talos_machine_bootstrap.this,
    data.talos_cluster_health.this
  ]
  # The kubeconfig endpoint will be populated from the talos_machine_configuration cluster_endpoint
  node                 = local.first_control_plane_node_ip
  client_configuration = talos_machine_secrets.this.client_configuration
  timeouts = {
    read = "1m"
  }
}
