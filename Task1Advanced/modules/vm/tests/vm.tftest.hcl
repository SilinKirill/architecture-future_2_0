mock_provider "yandex" {
  mock_data "yandex_compute_image" {
    defaults = {
      id = "mock-ubuntu-image"
    }
  }
}

variables {
  subnet_id      = "mock-subnet"
  ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA mock-only"
}

run "private_vm_and_data_disk" {
  command = apply

  assert {
    condition = alltrue([
      yandex_compute_instance.vm.resources[0].cores == var.cores,
      yandex_compute_instance.vm.resources[0].memory == var.memory,
      yandex_compute_instance.vm.zone == var.zone,
      yandex_compute_instance.vm.boot_disk[0].initialize_params[0].image_id == "mock-ubuntu-image",
      yandex_compute_instance.vm.boot_disk[0].initialize_params[0].size == 20,
      yandex_compute_instance.vm.boot_disk[0].initialize_params[0].type == "network-hdd",
    ])
    error_message = "ВМ должна использовать CPU, RAM, зону окружения и загружаться с HDD на основе образа из семейства."
  }

  assert {
    condition = alltrue([
      yandex_compute_disk.data.size == var.disk_size,
      yandex_compute_disk.data.type == "network-ssd",
      yandex_compute_disk.data.zone == var.zone,
      one(yandex_compute_instance.vm.secondary_disk).disk_id == yandex_compute_disk.data.id,
      output.disk_id == yandex_compute_disk.data.id,
    ])
    error_message = "Диск данных должен создаваться отдельно, подключаться к ВМ и экспортировать свой ID."
  }

  assert {
    condition = alltrue([
      yandex_compute_instance.vm.network_interface[0].subnet_id == var.subnet_id,
      !yandex_compute_instance.vm.network_interface[0].nat,
      output.public_ip == null,
      output.internal_ip == yandex_compute_instance.vm.network_interface[0].ip_address,
      yandex_compute_instance.vm.metadata["ssh-keys"] == "ubuntu:${var.ssh_public_key}",
      output.ssh_user == "ubuntu",
    ])
    error_message = "ВМ должна использовать заданную подсеть, передавать ключ Ubuntu и иметь только внутренний адрес."
  }

  assert {
    condition     = output.instance_id == yandex_compute_instance.vm.id && output.name == var.name
    error_message = "Модуль должен экспортировать имя и ID созданной ВМ."
  }
}

run "explicit_image_and_nat" {
  command = plan

  variables {
    boot_disk_type     = "network-ssd"
    boot_image_id      = "mock-pinned-image"
    nat                = true
    security_group_ids = ["mock-security-group"]
    metadata           = { user-data = "#cloud-config" }
  }

  assert {
    condition = alltrue([
      length(data.yandex_compute_image.boot) == 0,
      yandex_compute_instance.vm.boot_disk[0].initialize_params[0].image_id == var.boot_image_id,
      yandex_compute_instance.vm.boot_disk[0].initialize_params[0].type == var.boot_disk_type,
      yandex_compute_instance.vm.network_interface[0].nat,
      yandex_compute_instance.vm.network_interface[0].security_group_ids == var.security_group_ids,
      yandex_compute_instance.vm.metadata["user-data"] == var.metadata["user-data"],
    ])
    error_message = "Настройки загрузочного диска, NAT, группы безопасности и дополнительные метаданные должны передаваться в ВМ."
  }
}
