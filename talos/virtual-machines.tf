resource "proxmox_virtual_environment_vm" "this" {
  for_each = var.nodes

  name        = each.key
  node_name = each.value.host_node
  description = each.value.machine_type == "controlplane" ? "Talos Control Plane" : "Talos Worker"
  tags        = each.value.machine_type == "controlplane" ? ["k8s", "control-plane"] : ["k8s", "worker"]
  on_boot     = var.cluster.on_boot
  vm_id       = each.value.vm_id

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  bios          = "seabios"
  stop_on_destroy = true

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu
    type  = each.value.cpu_type
  }

  memory {
    dedicated = each.value.ram_dedicated
  }

  network_device {
    bridge      = each.value.bridge
    mac_address = each.value.mac_address
    vlan_id     = each.value.vlan_id
  }

  # OS Disk
  disk {
    datastore_id = each.value.datastore
    interface    = "scsi0"
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    ssd          = true
    file_format  = "raw"
    size         = 5
    file_id      = proxmox_virtual_environment_download_file.this["${each.value.host_node}_${each.value.update == true ? local.update_image_id : local.image_id}"].id
  }

  # Attach disks from a dedicated Data VM
  # https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_vm#example-attached-disks
  dynamic "disk" {
    for_each = { for idx, val in proxmox_virtual_environment_vm.data_vm["${each.key}"].disk : idx => val }
    iterator = data_disk
    content {
      cache             = data_disk.value["cache"]
      datastore_id      = data_disk.value["datastore_id"]
      discard           = data_disk.value["discard"]
      file_format       = data_disk.value["file_format"]
      iothread          = data_disk.value["iothread"]
      path_in_datastore = data_disk.value["path_in_datastore"]
      size              = data_disk.value["size"]
      ssd               = data_disk.value["ssd"]

      # assign from scsi1 and up
      interface = "scsi${data_disk.key + 1}"
    }
  }

  boot_order = ["scsi0"]

  operating_system {
    type = "l26" # Linux Kernel 2.6 - 6.X.
  }

  initialization {
    datastore_id = each.value.datastore

    # Optional DNS Block.  Update Nodes with a list value to use.
    dynamic "dns" {
      for_each = try(each.value.dns, null) != null ? { "enabled" = each.value.dns } : {}
      content {
        servers = each.value.dns
      }
    }

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.cluster.subnet_mask}"
        gateway = var.cluster.gateway
      }
    }
  }

  dynamic "hostpci" {
    for_each = each.value.igpu ? [1] : []
    content {
      # Passthrough iGPU
      device  = "hostpci0"
      mapping = "iGPU"
      pcie    = true
      rombar  = true
      xvga    = false
    }
  }
}

# Create a Data VM for each Talos VM to attach additional disks
# This separation allows keeping data disks when re-creating Talos VMs upon updates where Talos VM gets destroyed, unfortunately.
resource "proxmox_virtual_environment_vm" "data_vm" {
  for_each = var.nodes

  node_name = each.value.host_node

  # append suffix "-data" and "0" to VM name and vm_id, respectively, to avoid conflicts with Talos VM
  name        = "${each.key}-data"
  vm_id       = "${each.value.vm_id}0"
  description = "Data VM for ${each.value.vm_id} ${each.key} to attach additional disks"
  tags        = ["k8s"]

  started = false
  on_boot = false

  # Main Disk for EPHEMERAL
  disk {
    datastore_id = each.value.datastore
    interface    = "scsi0"
    iothread     = true
    cache        = "writethrough"
    discard      = "on"
    size         = each.value.disk_size
    ssd          = true
  }

  # Additional Data Disks for `disk`-type volumes
  # only in case the disk's machine_type matches the current node's machine_type or is set to "all"
  dynamic "disk" {
    for_each = { for idx, val in var.talos_disk_volumes : idx => val if val.machine_type == each.value.machine_type || val.machine_type == "all" }
    iterator = adisk
    content {
      # Use specified storage or fall back to main VM's datastore
      datastore_id = coalesce(adisk.value["datastore"], each.value.datastore)
      file_format  = "raw"
      iothread     = true
      cache        = "writethrough"
      discard      = "on"
      size         = adisk.value["size_gb"] # size in GB, converted from string with UoM to number 
      ssd          = true

      # assign from scsi1 and up
      # Caveats:
      # - scsiN index might change for disks if other disks are added or removed to the set of additional disks in future,
      #   as disks' index is based on lexical order, not based on its declaration
      # - scsi interface numbers might not be contiguous if volumes are used with different machine_types inbetween
      interface = "scsi${index(keys(var.talos_disk_volumes), adisk.key) + 1}"
    }
  }
}
