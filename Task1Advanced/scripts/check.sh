#!/bin/sh
set -eu

terraform fmt -check -recursive

module_dir=modules/vm
terraform -chdir="$module_dir" init -backend=false -input=false
terraform -chdir="$module_dir" validate

for environment in dev stage prod; do
    printf '\nПроверка окружения %s\n' "$environment"
    environment_dir="envs/$environment"
    terraform -chdir="$environment_dir" init -backend=false -input=false
    terraform -chdir="$environment_dir" validate
    terraform -chdir="$module_dir" test -var-file="../../$environment_dir/terraform.tfvars"
done
