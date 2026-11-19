#!/bin/sh
set -eu
export TF_IN_AUTOMATION=1
run_dir=$(mktemp -d)
cd "$run_dir"
key="review/${run_dir##*/}/terraform.tfstate"

for client in writer reader; do
  mkdir "$client"
  cp /fixture/main.tf "$client/"
  terraform -chdir="$client" init -input=false -backend-config="key=$key"
done

terraform -chdir=writer apply -auto-approve -input=false >writer.log 2>&1 &
writer_pid=$!
trap 'touch release' EXIT
for attempt in $(seq 1 45); do
  [ ! -e locked ] || break
  if ! kill -0 "$writer_pid" 2>/dev/null; then cat writer.log; exit 1; fi
  sleep 1
done
test -f locked
if terraform -chdir=reader plan -no-color -lock-timeout=0s >reader.log 2>&1; then
  echo "Ожидалась блокировка при конкурентном plan"; exit 1
fi
grep -F "Error acquiring the state lock" reader.log
touch release
wait "$writer_pid" || { cat writer.log; exit 1; }

test "$(terraform -chdir=reader output -raw marker)" = "remote-state-ok"
terraform -chdir=reader plan -detailed-exitcode -input=false
# Проверяем и рабочий root из CI. Подменяем адрес S3 и используем отдельный кеш.
(
  export TF_DATA_DIR="$run_dir/cloud-cache"
  cd /repo/Task2Advanced/terraform
  terraform init -input=false -lockfile=readonly \
    -backend-config="bucket=sprint-state" -backend-config="key=$key" \
    -backend-config='endpoints={s3="http://minio:9000"}' -backend-config='use_path_style=true'
  terraform validate
  terraform state list | grep -Fx 'terraform_data.marker'
)
test ! -e writer/terraform.tfstate
test ! -e reader/terraform.tfstate
terraform -chdir=reader destroy -auto-approve -input=false
test -z "$(terraform -chdir=writer state list)"
echo "PASS: S3 state доступен обоим клиентам, конкурентный plan заблокирован, ресурс удалён."
