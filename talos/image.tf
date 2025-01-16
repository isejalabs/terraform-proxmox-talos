locals {
  version    = var.image.version
  schematic  = var.image.schematic
  image_id   = "${talos_image_factory_schematic.this.id}_${local.version}"
  env_prefix = var.env == "" ? "" : "${var.env}-"

  update_version   = coalesce(var.image.update_version, var.image.version)
  update_schematic = coalesce(var.image.update_schematic, local.schematic)
  update_image_id  = "${talos_image_factory_schematic.updated.id}_${local.update_version}"
}

resource "talos_image_factory_schematic" "this" {
  schematic = local.schematic
}

# not used (see https://github.com/vehagn/homelab/issues/106)
# TODO: support change of schematic upon update
resource "talos_image_factory_schematic" "updated" {
  schematic = local.update_schematic
}

resource "proxmox_virtual_environment_download_file" "this" {
  # this.id format: <node>_<schematic>_<version>
  # for_each = toset(distinct([for k, v in var.nodes : "${v.host_node}_${v.update == true ? local.update_image_id : local.image_id}"]))
  # this.id format: <node>_<version>
  for_each = toset(distinct([for k, v in var.nodes : "${v.host_node}_${v.update == true ? local.update_version : local.version}"]))

  node_name    = split("_", each.key)[0]
  content_type = "iso"
  datastore_id = var.image.proxmox_datastore

  # ex.: talos-ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515-v1.8.1-nocloud-amd64.img
  file_name               = "${local.env_prefix}talos-${talos_image_factory_schematic.this.id}-${split("_", each.key)[1]}-${var.image.platform}-${var.image.arch}.img"
  url                     = "${var.image.factory_url}/image/${talos_image_factory_schematic.this.id}/${split("_", each.key)[1]}/${var.image.platform}-${var.image.arch}.raw.gz"
  decompression_algorithm = "gz"
  overwrite               = false
  overwrite_unmanaged     = true
}