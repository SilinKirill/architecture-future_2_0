data "yandex_compute_image" "boot" {
  count  = var.boot_image_id == null ? 1 : 0
  family = var.boot_image_family
}

resource "yandex_compute_disk" "data" {
  name = "${var.name}-data"
  zone = var.zone
  size = var.disk_size
  type = var.disk_type
}

resource "yandex_compute_instance" "vm" {
  name                      = var.name
  zone                      = var.zone
  platform_id               = var.platform_id
  allow_stopping_for_update = true

  resources {
    cores         = var.cores
    memory        = var.memory
    core_fraction = var.core_fraction
  }

  boot_disk {
    initialize_params {
      image_id = var.boot_image_id == null ? data.yandex_compute_image.boot[0].id : var.boot_image_id
      size     = var.boot_disk_size
      type     = var.boot_disk_type
    }
  }

  secondary_disk {
    disk_id     = yandex_compute_disk.data.id
    device_name = "data"
    auto_delete = false
  }

  network_interface {
    subnet_id          = var.subnet_id
    nat                = var.nat
    security_group_ids = var.security_group_ids
  }

  metadata = merge(var.metadata, {
    ssh-keys = "${var.ssh_user}:${trimspace(var.ssh_public_key)}"
  })
}
