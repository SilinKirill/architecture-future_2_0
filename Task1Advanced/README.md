# Task1Advanced. Модуль виртуальной машины

`modules/vm` создаёт одну ВМ Yandex Compute Cloud с системным диском, отдельный диск данных и подключает оба диска к ВМ. Модуль принимает ID подсети, а также передаёт публичный SSH-ключ в метаданные ВМ. У каждого окружения свой корневой модуль, набор переменных и локальный Terraform state.

- `envs/dev` — 2 vCPU, 2 ГиБ RAM, диск данных 10 ГиБ.
- `envs/stage` — 4 vCPU, 8 ГиБ RAM, диск данных 30 ГиБ.
- `envs/prod` — 8 vCPU, 16 ГиБ RAM, диск данных 80 ГиБ.

По умолчанию системный диск — сетевой HDD на 20 ГиБ, диск данных — сетевой SSD. Модуль использует платформу `standard-v3`, образ семейства `ubuntu-2404-lts`, пользователя `ubuntu` и внутренний IPv4. Зона ВМ и дисков должна совпадать с зоной подсети. [Документация ресурса `yandex_compute_instance`](https://yandex.cloud/ru/docs/terraform/resources/compute_instance)

## Интерфейс модуля

При вызове передайте `name`, `zone`, `subnet_id`, `cores`, `memory`, `disk_size` и `ssh_public_key`. `memory` и `disk_size` задаются в ГиБ. Дополнительные входы перечислены в [`modules/vm/variables.tf`](modules/vm/variables.tf). Чтобы выбрать другой тип системного диска, задайте `boot_disk_type`. Чтобы зафиксировать загрузочный образ, передайте `boot_image_id`. Без него Terraform запрашивает актуальный образ семейства `boot_image_family`.

Модуль возвращает `instance_id`, `name`, `internal_ip`, `public_ip`, `disk_id` и `ssh_user`. При выключенном `nat` значение `public_ip` равно `null`. Окружения публикуют эти поля в выходной переменной `vm`.

## Локальные проверки и CI

Из каталога `Task1Advanced` выполните одну команду в PowerShell, Bash или CI с Docker и Docker Compose v2.

```sh
docker compose run --rm -T check
```

Compose использует Terraform `1.11.4` и скачивает провайдер Yandex `0.140.0` через официальный сетевой mirror. При первом запуске потребуется доступ к Docker Hub и `terraform-mirror.yandexcloud.net`. После `fmt -check` выполняются `init -backend=false` и `validate` для модуля и всех трёх окружений. [Настройка зеркала Terraform](https://yandex.cloud/ru/docs/tutorials/infrastructure-management/terraform-modules)

Для каждого `terraform.tfvars` запускаются два теста модуля. Первый проверяет параметры ВМ, системный HDD, подключение отдельного SSD, подсеть, SSH-ключ и выходные переменные. Второй проверяет переопределение типа системного диска, явный ID образа, NAT, группы безопасности и дополнительные метаданные. Ожидаемый результат для каждого окружения — `Success! 2 passed, 0 failed.` Тесты используют `mock_provider`, поэтому им не нужны облачный токен, реальная подсеть или реальные ресурсы. [Документация Terraform о тестовых провайдерах](https://developer.hashicorp.com/terraform/language/tests/mocking)

## Ручная проверка `dev` в Yandex Cloud

1. Выберите каталог с действующим биллингом и существующую подсеть VPC в этом каталоге. Назначьте учётной записи роль `compute.editor` на каталог. При `nat = true` дополнительно нужна роль `vpc.publicAdmin`. Для `dev` проверьте доступность платформы и свободную квоту в зоне подсети на 2 vCPU, 2 ГиБ RAM, 20 ГиБ сетевого HDD и 10 ГиБ сетевого SSD. [Роли Compute Cloud](https://yandex.cloud/ru/docs/compute/security/), [квоты Compute Cloud](https://yandex.cloud/ru/docs/compute/concepts/limits#quotas)
2. Установите Yandex Cloud CLI и выполните `yc init` на хосте. В профиле выберите нужные облако и каталог. Передайте авторизацию контейнеру через переменные окружения. Пример для PowerShell с авторизованным профилем. [Установка и настройка CLI](https://yandex.cloud/ru/docs/cli/quickstart), [авторизация провайдера](https://yandex.cloud/ru/docs/terraform/authentication)

   ```powershell
   $env:YC_TOKEN = $(yc iam create-token)
   $env:YC_CLOUD_ID = $(yc config get cloud-id)
   $env:YC_FOLDER_ID = $(yc config get folder-id)
   ```

   Для Bash используйте `export YC_TOKEN=$(yc iam create-token)` и аналогично задайте `YC_CLOUD_ID` и `YC_FOLDER_ID` через `yc config get`.

3. Создайте локальный файл `envs/dev/cloud.local.tfvars`. Подставьте ID подсети, её зону и строку из своего публичного ключа `.pub`. Если SSH-пары ещё нет, выполните `ssh-keygen -t ed25519` и скопируйте содержимое созданного файла `.pub`. Для SSH по публичному адресу дополнительно передайте `nat = true` и группу безопасности, разрешающую TCP/22 с вашего адреса, в `security_group_ids`. [Создание пары SSH-ключей](https://yandex.cloud/ru/docs/compute/operations/vm-connect/ssh)

   ```hcl
   subnet_id      = "<ID существующей подсети>"
   zone           = "<зона подсети>"
   ssh_public_key = "<строка из публичного ключа OpenSSH>"
   ```

4. Из `Task1Advanced` инициализируйте окружение и проверьте план. При пустом state ожидается `Plan: 2 to add, 0 to change, 0 to destroy.` Отдельными ресурсами будут ВМ и диск данных.

   ```sh
   docker compose run --rm terraform -chdir=envs/dev init -input=false
   docker compose run --rm terraform -chdir=envs/dev plan -input=false -var-file=cloud.local.tfvars
   ```

5. Проверьте и подтвердите план, который выведет `apply`. Выведите параметры ВМ и проверьте в консоли Compute Cloud, что к ней подключены системный диск и диск данных.

   ```sh
   docker compose run --rm terraform -chdir=envs/dev apply -var-file=cloud.local.tfvars
   docker compose run --rm terraform -chdir=envs/dev output -json vm
   ```

6. По завершении удалите созданную ВМ и её диски. Проверьте план удаления перед подтверждением. После успешного `destroy` команда `state list` не выводит адресов ресурсов.

   ```sh
   docker compose run --rm terraform -chdir=envs/dev destroy -var-file=cloud.local.tfvars
   docker compose run --rm terraform -chdir=envs/dev state list
   ```

Для `stage` и `prod` укажите соответствующий каталог в `-chdir`, а параметры облака положите в отдельный `cloud.local.tfvars` внутри этого каталога. Для этих размеров ВМ может потребоваться увеличение зональных квот на vCPU и SSD. Terraform автоматически прочитает `terraform.tfvars` нужного окружения и сохранит его состояние в том же каталоге. Например, для плана `stage` выполните следующее.

```sh
docker compose run --rm terraform -chdir=envs/stage init -input=false
docker compose run --rm terraform -chdir=envs/stage plan -input=false -var-file=cloud.local.tfvars
```
