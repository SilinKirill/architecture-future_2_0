variable "cloud_id" {
  description = "Идентификатор облака Yandex Cloud."
  type        = string
  nullable    = false
}

variable "folder_id" {
  description = "Идентификатор каталога для ВМ и дисков."
  type        = string
  nullable    = false
}

variable "name" {
  description = "Имя виртуальной машины."
  type        = string
  nullable    = false
}

variable "zone" {
  description = "Зона доступности ВМ и существующей подсети."
  type        = string
  nullable    = false
}

variable "subnet_id" {
  description = "Идентификатор существующей подсети VPC."
  type        = string
  nullable    = false
}

variable "cores" {
  description = "Количество vCPU."
  type        = number
  nullable    = false
}

variable "memory" {
  description = "Оперативная память в ГиБ."
  type        = number
  nullable    = false
}

variable "disk_size" {
  description = "Размер отдельного диска данных в ГиБ."
  type        = number
  nullable    = false
}

variable "ssh_public_key" {
  description = "Строка из публичного SSH-ключа OpenSSH."
  type        = string
  nullable    = false
}

variable "boot_image_id" {
  description = "Идентификатор зафиксированного загрузочного образа."
  type        = string
  default     = null
}
