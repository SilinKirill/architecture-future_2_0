terraform {
  required_version = "= 1.11.4"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.140.0"
    }
  }
}

provider "yandex" {}

variable "name" {
  description = "Имя виртуальной машины."
  type        = string
}

variable "zone" {
  description = "Зона доступности ВМ и подсети."
  type        = string
}

variable "subnet_id" {
  description = "Идентификатор существующей подсети в заданной зоне."
  type        = string
}

variable "cores" {
  description = "Количество vCPU."
  type        = number
}

variable "memory" {
  description = "Оперативная память в ГиБ."
  type        = number
}

variable "disk_size" {
  description = "Размер диска данных в ГиБ."
  type        = number
}

variable "ssh_public_key" {
  description = "Содержимое публичного SSH-ключа."
  type        = string
}

variable "nat" {
  description = "Назначить публичный IPv4-адрес."
  type        = bool
  default     = false
}

variable "security_group_ids" {
  description = "Группы безопасности интерфейса."
  type        = set(string)
  default     = []
}

variable "boot_image_id" {
  description = "Идентификатор конкретного загрузочного образа."
  type        = string
  default     = null
}

variable "boot_disk_type" {
  description = "Тип системного диска."
  type        = string
  default     = "network-hdd"
  nullable    = false
}

module "vm" {
  source = "../../modules/vm"

  name               = var.name
  zone               = var.zone
  subnet_id          = var.subnet_id
  cores              = var.cores
  memory             = var.memory
  disk_size          = var.disk_size
  ssh_public_key     = var.ssh_public_key
  nat                = var.nat
  security_group_ids = var.security_group_ids
  boot_image_id      = var.boot_image_id
  boot_disk_type     = var.boot_disk_type
}

output "vm" {
  description = "Параметры созданной ВМ, её адреса и идентификатор диска данных."
  value = {
    instance_id = module.vm.instance_id
    name        = module.vm.name
    internal_ip = module.vm.internal_ip
    public_ip   = module.vm.public_ip
    disk_id     = module.vm.disk_id
    ssh_user    = module.vm.ssh_user
  }
}
