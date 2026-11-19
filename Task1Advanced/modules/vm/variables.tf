variable "name" {
  description = "Имя виртуальной машины. К имени дополнительного диска добавляется суффикс -data."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-z]([a-z0-9-]{0,56}[a-z0-9])?$", var.name))
    error_message = "Имя должно содержать от 1 до 58 символов, начинаться с латинской строчной буквы и заканчиваться буквой или цифрой. Внутри допустимы строчные латинские буквы, цифры и дефис."
  }
}

variable "zone" {
  description = "Зона доступности ВМ и дисков. Подсеть должна находиться в этой же зоне."
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "Идентификатор существующей или переданной вызывающей конфигурацией подсети VPC."
  type        = string
  nullable    = false

  validation {
    condition     = trimspace(var.subnet_id) != ""
    error_message = "Укажите ID подсети VPC."
  }
}

variable "cores" {
  description = "Количество vCPU."
  type        = number
  nullable    = false

  validation {
    condition     = var.cores > 0 && floor(var.cores) == var.cores
    error_message = "Количество vCPU должно быть положительным целым числом."
  }
}

variable "memory" {
  description = "Оперативная память в ГиБ."
  type        = number
  nullable    = false

  validation {
    condition     = var.memory > 0
    error_message = "Размер оперативной памяти должен быть положительным."
  }
}

variable "disk_size" {
  description = "Размер отдельного диска данных в ГиБ."
  type        = number
  nullable    = false

  validation {
    condition     = var.disk_size > 0 && floor(var.disk_size) == var.disk_size
    error_message = "Размер диска данных должен быть положительным целым числом."
  }
}

variable "ssh_public_key" {
  description = "Содержимое публичного SSH-ключа в формате OpenSSH."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^(ssh-|ecdsa-|sk-)[^[:space:]]+ [A-Za-z0-9+/=]+( [^\r\n]*)?$", trimspace(var.ssh_public_key)))
    error_message = "Передайте одну строку из публичного ключа OpenSSH."
  }
}

variable "platform_id" {
  description = "Идентификатор платформы Compute Cloud."
  type        = string
  default     = "standard-v3"
  nullable    = false
}

variable "core_fraction" {
  description = "Гарантированная доля производительности vCPU в процентах."
  type        = number
  default     = 100
  nullable    = false
}

variable "boot_image_family" {
  description = "Семейство публичных образов для системного диска."
  type        = string
  default     = "ubuntu-2404-lts"
  nullable    = false
}

variable "boot_image_id" {
  description = "Идентификатор конкретного образа для системного диска. Имеет приоритет над boot_image_family."
  type        = string
  default     = null
}

variable "boot_disk_size" {
  description = "Размер системного диска в ГиБ."
  type        = number
  default     = 20
  nullable    = false
}

variable "boot_disk_type" {
  description = "Тип системного диска."
  type        = string
  default     = "network-hdd"
  nullable    = false
}

variable "disk_type" {
  description = "Тип отдельного диска данных."
  type        = string
  default     = "network-ssd"
  nullable    = false
}

variable "ssh_user" {
  description = "Имя пользователя, которому передаётся публичный SSH-ключ."
  type        = string
  default     = "ubuntu"
  nullable    = false
}

variable "nat" {
  description = "Выделить публичный IPv4-адрес для ВМ."
  type        = bool
  default     = false
  nullable    = false
}

variable "security_group_ids" {
  description = "Идентификаторы групп безопасности сетевого интерфейса."
  type        = set(string)
  default     = []
  nullable    = false
}

variable "metadata" {
  description = "Дополнительные метаданные ВМ, например user-data для cloud-init."
  type        = map(string)
  default     = {}
  nullable    = false
}
