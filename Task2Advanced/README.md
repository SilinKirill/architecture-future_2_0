# Task2Advanced. Удалённый state и CI/CD

Конфигурация в `terraform` подключает [модуль ВМ Task1](../Task1Advanced/modules/vm) и использует его профили `dev`, `stage` и `prod`. Состояние хранится в приватном бакете Yandex Object Storage по ключу `task2advanced/<окружение>/terraform.tfstate`. Для конкурентных операций Terraform использует объект `.tflock` рядом с состоянием. [S3-бэкенд Terraform](https://developer.hashicorp.com/terraform/language/backend/s3) · [Object Storage для Terraform](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-state-storage)

## Как проверить без облака

Из папки `Task2Advanced` выполните `docker compose run --rm -T check`. Проверка в MinIO должна закончиться строкой `PASS`. Она подтверждает, что два клиента читают одно состояние и конкурентный запуск получает ошибку блокировки. По завершении удалите локальный стенд командой `docker compose down -v`. [Подробности теста](local-check.md)

На pull request [workflow Task 2 Terraform](../.github/workflows/task2-terraform.yml) запускает тесты модуля Task1, проверку формата Terraform и тест с MinIO. Облачное задание запускается вручную.

## Подготовка Yandex Cloud для dev

1. Используйте каталог и подсеть, проверенные в [Task1](../Task1Advanced/README.md#ручная-проверка-dev-в-yandex-cloud). К этому моменту завершите удаление тестовой ВМ Task1 и её дисков.
2. В консоли облака откройте **Object Storage → Бакеты → Создать бакет**. Выберите уникальное имя, оставьте публичный доступ закрытым и включите версионирование. Блокировку версий объектов оставьте выключенной, чтобы Terraform мог удалять временный `.tflock`. [Создание бакета](https://yandex.cloud/ru/docs/storage/operations/buckets/create) · [Версионирование](https://yandex.cloud/ru/docs/storage/operations/buckets/versioning)
3. Создайте сервисный аккаунт для среды `dev` и назначьте ему `storage.editor` на этот бакет. Выпустите статический ключ доступа. Для ручной проверки этим ключом Terraform работает с бакетом, а IAM-токен пользователя из Task1 даёт доступ к Compute Cloud. [Права на бакет](https://yandex.cloud/ru/docs/storage/security/) · [Статический ключ](https://yandex.cloud/ru/docs/iam/operations/authentication/manage-access-keys)

## Ручная проверка в Yandex Cloud до слияния

Из `Task2Advanced` в PowerShell укажите имя бакета, ID и зону подсети из Task1. Если ключ SSH создан с другим именем, укажите путь к соответствующему файлу `.pub`. [Авторизация провайдера Terraform](https://yandex.cloud/ru/docs/terraform/authentication)

```powershell
$env:YC_TOKEN = yc iam create-token
$env:TF_VAR_cloud_id = yc config get cloud-id
$env:TF_VAR_folder_id = yc config get folder-id
$env:TF_VAR_subnet_id = '<ID подсети>'
$env:TF_VAR_ssh_public_key = (Get-Content -Raw "$env:USERPROFILE/.ssh/id_ed25519.pub").Trim()
$zone = '<зона подсети>'
$bucket = '<имя бакета dev>'
$env:AWS_ACCESS_KEY_ID = Read-Host 'ID статического ключа'
$env:AWS_SECRET_ACCESS_KEY = [System.Net.NetworkCredential]::new('', (Read-Host 'Секретная часть ключа' -AsSecureString)).Password
```

1. Инициализируйте S3-бэкенд и изучите план. При пустом состоянии ожидаются два создаваемых ресурса. Системный диск входит в ресурс ВМ.

   ```powershell
   docker compose run --rm terraform init -input=false -lockfile=readonly -reconfigure "-backend-config=bucket=$bucket" "-backend-config=key=task2advanced/dev/terraform.tfstate"
   docker compose run --rm terraform plan -input=false -lock-timeout=2m '-var-file=../../Task1Advanced/envs/dev/terraform.tfvars' -var=name=task2-dev "-var=zone=$zone" '-out=dev.tfplan'
   docker compose run --rm terraform show dev.tfplan
   ```

2. После проверки примените план. В Compute Cloud найдите ВМ `task2-dev` и оба диска, а в Object Storage — объект `task2advanced/dev/terraform.tfstate`.

   ```powershell
   docker compose run --rm terraform apply -input=false -lock-timeout=2m dev.tfplan
   docker compose run --rm terraform output vm
   ```

3. Запустите новый контейнер и проверьте, что он видит в S3 ресурсы прошлого запуска. При неизменной инфраструктуре и образе повторный план завершается сообщением `No changes`.

   ```powershell
   docker compose run --rm terraform state list
   docker compose run --rm terraform plan -input=false -lock-timeout=2m '-var-file=../../Task1Advanced/envs/dev/terraform.tfvars' -var=name=task2-dev "-var=zone=$zone"
   ```

4. Постройте и отдельно подтвердите план удаления. Проверьте пустой `state list` и отсутствие ВМ и её дисков в Compute Cloud.

   ```powershell
   docker compose run --rm terraform plan -destroy -input=false -lock-timeout=2m '-var-file=../../Task1Advanced/envs/dev/terraform.tfvars' -var=name=task2-dev "-var=zone=$zone" '-out=dev-destroy.tfplan'
   docker compose run --rm terraform show dev-destroy.tfplan
   # После проверки плана
   docker compose run --rm terraform apply -input=false -lock-timeout=2m dev-destroy.tfplan
   docker compose run --rm terraform state list
   ```

Состояние с пустым списком ресурсов и его история остаются в бакете. Если бакет создан только для одноразовой проверки и CI запускать не планируется, его можно удалить вместе с версиями объекта. После работы удалите локальные файлы `.tfplan` и закройте сессию PowerShell с ключами.

## Настройка и запуск GitHub Actions

1. Для CI задайте тому же сервисному аккаунту `compute.editor` на каталог среды и создайте его авторизованный ключ JSON. Статический ключ S3 из подготовки бакета используется отдельно. [Роли Compute Cloud](https://yandex.cloud/ru/docs/compute/security/) · [Авторизованный ключ](https://yandex.cloud/ru/docs/iam/operations/authentication/manage-authorized-keys)
2. В GitHub откройте **Settings → Environments**, создайте `dev` и разрешите развёртывание из ветки по умолчанию. Добавьте туда **Environment variables** `TF_STATE_BUCKET`, `YC_CLOUD_ID`, `YC_FOLDER_ID`, `YC_SUBNET_ID`, `YC_ZONE`, `SSH_PUBLIC_KEY`. Последняя переменная содержит строку из публичного ключа. Необязательная `YC_BOOT_IMAGE_ID` фиксирует образ для повторяемого плана. В **Environment secrets** добавьте `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` и `YC_SA_KEY_JSON`. Для `stage` и `prod` используйте отдельные окружения, каталоги, подсети, бакеты и аккаунты. [Окружения GitHub Actions](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments)
3. Когда файл workflow будет в ветке по умолчанию, откройте **Actions → Task 2 Terraform → Run workflow**. Выберите `dev` и `deploy`, оставьте `apply` выключенным. Проверьте в Summary список операций. При пустом состоянии ожидаются две операции `create`. [Ручной запуск workflow](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow)
4. После проверки запустите workflow с включённым `apply`. Он построит свежий план и применит именно этот файл в том же запуске. Проверьте ВМ, диски и state в консоли облака. Для очистки выберите `destroy`. Сначала запустите план с выключенным `apply`, затем подтвердите удаление запуском с включённым `apply`.

В одном окружении облачные запуски выполняются последовательно. План и ключ Compute Cloud остаются во временной папке раннера до завершения шага. В Summary публикуются только адреса ресурсов и операции. GitHub принимает ручной запуск после появления файла workflow в ветке по умолчанию. До этого приведённый выше сценарий проверяет создание ресурсов и удалённое состояние напрямую из ветки PR.
