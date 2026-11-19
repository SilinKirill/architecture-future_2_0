output "instance_id" {
  description = "Идентификатор виртуальной машины."
  value       = yandex_compute_instance.vm.id
}

output "name" {
  description = "Имя виртуальной машины."
  value       = yandex_compute_instance.vm.name
}

output "internal_ip" {
  description = "Внутренний IPv4-адрес."
  value       = yandex_compute_instance.vm.network_interface[0].ip_address
}

output "public_ip" {
  description = "Публичный IPv4-адрес при включённом NAT."
  value       = var.nat ? yandex_compute_instance.vm.network_interface[0].nat_ip_address : null
}

output "disk_id" {
  description = "Идентификатор дополнительного диска данных."
  value       = yandex_compute_disk.data.id
}

output "ssh_user" {
  description = "Пользователь для подключения по SSH."
  value       = var.ssh_user
}
