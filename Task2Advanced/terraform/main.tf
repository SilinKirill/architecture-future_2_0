terraform {
  required_version = "= 1.11.4"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.140.0"
    }
  }

  backend "s3" {
    endpoints = {
      s3 = "https://storage.yandexcloud.net"
    }
    region                      = "ru-central1"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
    use_lockfile                = true
  }
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
}

module "vm" {
  source = "../../Task1Advanced/modules/vm"

  name           = var.name
  zone           = var.zone
  subnet_id      = var.subnet_id
  cores          = var.cores
  memory         = var.memory
  disk_size      = var.disk_size
  ssh_public_key = var.ssh_public_key
  boot_image_id  = var.boot_image_id
}

output "vm" {
  description = "Идентификаторы ВМ и диска данных, внутренний адрес и пользователь SSH."
  value = {
    instance_id = module.vm.instance_id
    name        = module.vm.name
    internal_ip = module.vm.internal_ip
    disk_id     = module.vm.disk_id
    ssh_user    = module.vm.ssh_user
  }
}
