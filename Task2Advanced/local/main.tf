terraform {
  required_version = "= 1.11.4"
  backend "s3" {
    bucket                      = "sprint-state"
    region                      = "us-east-1"
    endpoints                   = { s3 = "http://minio:9000" }
    use_path_style              = true
    use_lockfile                = true
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

resource "terraform_data" "marker" {
  input = "remote-state-ok"

  # Первый процесс держит блокировку, пока второй проверяет конкуренцию.
  provisioner "local-exec" {
    command = "touch ../locked && while [ ! -f ../release ]; do sleep 1; done"
  }
}

output "marker" {
  value = terraform_data.marker.output
}
