# Task2Advanced. Удалённый state и CI/CD

Корневая конфигурация [`terraform`](terraform) подключает [модуль ВМ первого задания](../Task1Advanced/modules/vm) и использует его профили `dev`, `stage`, `prod`. Имена ВМ в этом задании — `task2-dev`, `task2-stage` и `task2-prod`. Terraform 1.11.4 хранит состояние в Yandex Object Storage. Ключи имеют вид `task2advanced/<окружение>/terraform.tfstate`. Во время записи S3-бэкенд создаёт временный объект `.tflock` рядом со state. [Документация бэкенда S3](https://developer.hashicorp.com/terraform/language/backend/s3), [настройка Object Storage](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-state-storage)

После открытия pull request GitHub Actions проверяет формат и конфигурацию Terraform и запускает [проверку S3-бэкенда на MinIO](local-check.md) без облачных учётных данных. Изменения в Yandex Cloud выполняет ручной запуск [Task 2 Terraform](../.github/workflows/task2-terraform.yml) с одобрением сохранённого плана.

## Подготовка Yandex Cloud

1. Начните с `dev`. Выберите каталог с активным биллингом и существующую подсеть. Сохраните ID облака, каталога, подсети и зону подсети. Для `stage` и `prod` повторите настройку в отдельных каталогах со своими подсетями. [Создание подсети VPC](https://yandex.cloud/ru/docs/vpc/operations/subnet-create)
2. Создайте отдельный приватный бакет для каждого окружения. Включите версионирование и оставьте публичный доступ закрытым для чтения объектов, списка объектов и настроек. Оставьте блокировку версий объектов выключенной, чтобы Terraform мог удалять временный `.tflock`. Для хранения планов настройте правило жизненного цикла с префиксом `task2advanced/<окружение>/plans/` на удаление текущих и предыдущих версий через 1 день. Для дополнительной защиты бакета можно включить шифрование ключом KMS и выдать доступ к ключу нужным аккаунтам. [Настройка версионирования](https://yandex.cloud/ru/docs/storage/operations/buckets/versioning), [правила жизненного цикла](https://yandex.cloud/ru/docs/storage/operations/buckets/lifecycles), [шифрование бакета](https://yandex.cloud/ru/docs/storage/operations/buckets/encrypt)
3. Для каждого окружения создайте три сервисных аккаунта.
   - Для Object Storage выдайте `storage.editor` на соответствующий бакет и создайте статический ключ доступа. Terraform использует его для чтения state и для создания и удаления файла блокировки. Эту же пару ключей используют задания `plan` и `apply` для передачи плана в приватном бакете.
   - Для `plan` выдайте `compute.viewer` на каталог окружения и создайте авторизованный ключ JSON.
   - Для `apply` выдайте `compute.editor` на каталог окружения и создайте отдельный авторизованный ключ JSON. У обоих аккаунтов Compute Cloud должна быть возможность читать используемую подсеть. Если подсеть размещена в отдельном каталоге, предоставьте доступ там. [Роли Compute Cloud](https://yandex.cloud/ru/docs/compute/security/), [роли Object Storage](https://yandex.cloud/ru/docs/storage/security/), [статический ключ](https://yandex.cloud/ru/docs/iam/operations/authentication/manage-access-keys), [авторизованный ключ](https://yandex.cloud/ru/docs/iam/operations/authentication/manage-authorized-keys)

## Настройка GitHub

В **Settings → Environments** создайте `dev-plan` и `dev-apply`. Для обоих ограничьте **Deployment branches and tags** именем защищённой ветки по умолчанию. В `dev-apply` включите **Required reviewers**, укажите проверяющего и снимите **Allow administrators to bypass configured protection rules**. Если проверяющих несколько, можно включить **Prevent self-review**. Заполняйте данные только в **Environment secrets** и **Environment variables**. Для `stage` и `prod` настройте собственные пары окружений с их аккаунтами, каталогами и бакетами. Доступность Required reviewers зависит от видимости репозитория и тарифа GitHub. [Настройка окружений GitHub Actions](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)

Добавьте в оба окружения одно и то же значение переменной `TF_STATE_BUCKET` и два секрета с ключом Object Storage, `AWS_ACCESS_KEY_ID` и `AWS_SECRET_ACCESS_KEY`. Секрет `YC_SA_KEY_JSON` в `dev-plan` содержит JSON ключа аккаунта для чтения, а в `dev-apply` — JSON ключа аккаунта для изменений. Храните скачанные ключи вне рабочей копии Git.

В окружение `dev-plan` добавьте переменные `YC_CLOUD_ID`, `YC_FOLDER_ID`, `YC_SUBNET_ID`, `YC_ZONE` и `SSH_PUBLIC_KEY`. Значение `SSH_PUBLIC_KEY` — одна строка из файла `.pub`. Переменная `YC_BOOT_IMAGE_ID` позволяет зафиксировать конкретный образ Ubuntu. По умолчанию модуль выбирает актуальный образ семейства `ubuntu-2404-lts`.

## Запуск и проверка в GitHub Actions

1. Когда файл workflow окажется в ветке по умолчанию, откройте **Actions → Task 2 Terraform → Run workflow** и выберите эту ветку. Запуск с `environment=dev`, `operation=deploy` и выключенным `apply` строит план. При пустом state в Summary ожидаются две операции `create`, по одной для ВМ и диска данных. Системный диск создаётся в составе ВМ. До слияния выполните ручную проверку ниже. [Ручной запуск workflow в GitHub](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
2. Запустите тот же сценарий с включённым `apply`. В Summary появятся адреса ресурсов, действия, путь к точному плану в приватном бакете и его SHA-256. Для детальной проверки скачайте этот объект через консоль Yandex Cloud под своей учётной записью с `storage.viewer`, положите его в `terraform/review.tfplan` и из `Task2Advanced` выполните следующее.

   ```sh
   docker compose run --rm terraform init -backend=false -input=false -lockfile=readonly
   docker compose run --rm terraform show review.tfplan
   ```

3. Проверьте коммит и изменения, затем нажмите **Review deployments → Approve and deploy**. Задание `apply` заново инициализирует бэкенд, сверяет хеш и применяет именно этот план. Бинарный план доступен только в бакете. Проверьте в Compute Cloud ВМ `task2-dev` и оба её диска, а в Object Storage — объект `task2advanced/dev/terraform.tfstate`. Чтобы проверить повторный запуск, запустите `deploy` с выключенным `apply`. При неизменных конфигурации, инфраструктуре и образе план не содержит изменений ресурсов.
4. Для очистки выберите тот же `environment`, `operation=destroy` и включите `apply`. Проверьте ожидаемые удаления в плане и одобрите их. После успешного применения Summary сообщает, что state пуст, и в Compute Cloud отсутствуют созданные ВМ и диски. Бакет с историей состояния нужен для последующих запусков.

Для одного окружения одновременно выполняется один запуск workflow. У каждого запуска свой ключ плана. После изменения state Terraform отклонит старый план. План также отклоняется по истечении двух часов или при повторном запуске только задания `apply`. При отказе создайте новый запуск целиком и проверьте свежий план. Во время ожидания одобрения избегайте ручных изменений инфраструктуры.

## Ручная проверка в Yandex Cloud до слияния

Войдите через Yandex Cloud CLI и выберите профиль нужного облака и каталога. Проверьте, что у вашего пользователя есть права на создание ВМ и дисков. Подготовьте приватный бакет и статический ключ, как описано выше. Из `Task2Advanced` задайте переменные для PowerShell. Вводите значения статического ключа через скрытый ввод, чтобы они не попали в историю команд. [Авторизация провайдера Terraform](https://yandex.cloud/ru/docs/terraform/authentication)

```powershell
$env:YC_TOKEN = yc iam create-token
$env:TF_VAR_cloud_id = yc config get cloud-id
$env:TF_VAR_folder_id = yc config get folder-id
$env:TF_VAR_subnet_id = '<ID подсети>'
$env:TF_VAR_zone = '<зона подсети>'
$env:TF_VAR_ssh_public_key = (Get-Content -Raw "$env:USERPROFILE/.ssh/id_ed25519.pub").Trim()
$env:AWS_ACCESS_KEY_ID = Read-Host 'ID статического ключа'
$env:AWS_SECRET_ACCESS_KEY = [System.Net.NetworkCredential]::new('', (Read-Host 'Секретная часть ключа' -AsSecureString)).Password
$bucket = '<имя бакета dev>'
```

Из того же каталога инициализируйте рабочую копию с ключом `dev`. Terraform запускается в Linux-контейнере с зеркалом провайдера из первого задания.

```powershell
docker compose run --rm terraform init -input=false -lockfile=readonly -reconfigure "-backend-config=bucket=$bucket" "-backend-config=key=task2advanced/dev/terraform.tfstate"
docker compose run --rm terraform plan -input=false -lock-timeout=2m -var-file=../../Task1Advanced/envs/dev/terraform.tfvars -var=name=task2-dev "-var=zone=$env:TF_VAR_zone" -out=dev.tfplan
docker compose run --rm terraform show dev.tfplan
# После проверки плана
docker compose run --rm terraform apply -input=false -lock-timeout=2m dev.tfplan
docker compose run --rm terraform output vm
```

Проверьте ВМ, её диски и state по тем же признакам, что и для GitHub Actions. После проверки создайте и изучите план удаления, затем примените его. Команда `state list` должна вывести пустой список.

```powershell
docker compose run --rm terraform plan -destroy -input=false -lock-timeout=2m -var-file=../../Task1Advanced/envs/dev/terraform.tfvars -var=name=task2-dev "-var=zone=$env:TF_VAR_zone" -out=dev-destroy.tfplan
docker compose run --rm terraform show dev-destroy.tfplan
# После проверки плана
docker compose run --rm terraform apply -input=false -lock-timeout=2m dev-destroy.tfplan
docker compose run --rm terraform state list
```

Удалите локальные `.tfplan` после проверки и очистите переменные с ключами. Для локального теста без биллинга и аккаунта Yandex Cloud используйте [сценарий с MinIO](local-check.md).
