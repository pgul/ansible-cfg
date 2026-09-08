# ansible-cfg

Конфигурация пяти личных серверов (Ubuntu + один Fedora).

## Установка на управляющей машине

```bash
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
make deps          # коллекции из requirements.yml в ./collections
```

`ansible.cfg` подхватывается автоматически, если запускать из корня репозитория.

## Рабочий цикл

```bash
make ping                  # связность
make facts                 # что за машины в инвентаре
make lint                  # статическая проверка
make bootstrap HOSTS=happy # разовая подготовка нового хоста
make check HOSTS=oc        # вхолостую, с диффом
make apply HOSTS=oc        # применить на одном хосте
make apply                 # применить везде
```

Правило: **`check` → `apply` на одном хосте → `apply` на всех.** Без исключений
для «мелких» правок.

## Структура

```
ansible.cfg              настройки клиента
inventory/hosts.yml      список серверов и групп
inventory/group_vars/    переменные по группам
site.yml                 главный плейбук: какие роли на каких хостах
playbooks/               одноразовые/диагностические плейбуки
roles/<name>/
  defaults/main.yml      переменные роли, включая развилку по ОС
  tasks/main.yml         что делать
  handlers/main.yml      реакции на изменения (рестарты сервисов)
  templates/             jinja2-шаблоны конфигов
```

### Две вещи, на которых легко обжечься

**Приоритет переменных.** Отличия Ubuntu/Fedora лежат в `defaults/main.yml`
словарём вида `common_base_packages_by_os`, а не в `roles/<name>/vars/`.
Причина: `defaults/` — самый низкий приоритет, его свободно перебивает
`host_vars/`; а `vars/` — наоборот, один из самых высоких, и он бы молча
перебил `host_vars/`. Именно так `host_vars/happy.yml` может сказать
«здесь ntpsec, а не chrony», и роль это услышит.

**Факты только как `ansible_facts.*`.** В `ansible.cfg` выставлено
`inject_facts_as_vars = False`, поэтому привычных `ansible_os_family`
и `ansible_distribution` нет — надо писать `ansible_facts.os_family`.
Это будущее поведение по умолчанию (ansible-core 2.24); включено заранее,
чтобы устаревшая форма падала сейчас, а не превратилась в `undefined` потом.
Переменные подключения (`ansible_user`, `ansible_host`) — не факты,
их это не касается.

## Порядок внедрения ролей

| # | Роль                  | Что делает                                              | Статус |
|---|-----------------------|---------------------------------------------------------|--------|
| 0 | `playbooks/bootstrap` | биндинги dnf5 на Fedora; разово на новый хост            | есть   |
| 1 | `common`              | пакеты, таймзона, синхронизация времени                  | есть   |
| 2 | `sudoers`             | `/etc/sudoers.d/*` с обязательным `validate: visudo -cf` | —      |
| 3 | `auto_updates`        | `unattended-upgrades` (Ubuntu) / `dnf-automatic` (Fedora)| —      |
| 4 | `zabbix_agent`        | пакет из дистрибутива, конфиг шаблоном                   | —      |
| 5 | `cron_jobs`           | скрипты в `/usr/local/sbin` + systemd timers или cron    | —      |
| 6 | `firewall`            | iptables + iptables-persistent / iptables-services       | —      |

Бэкап настроен вручную и в Ansible пока не заводится.

`site.yml` обязан оставаться пригодным для честного `--check`: всё, что нельзя
выполнить вхолостую, живёт в `playbooks/bootstrap.yml` и запускается разово.

### Парк машин

| хост   | ОС           | особенности                       |
|--------|--------------|-----------------------------------|
| happy  | Fedora 44    | ntpsec вместо chrony, containerd, prometheus, firewalld выключен |
| us     | Ubuntu 26.04 | 0.9 GiB RAM — самая тесная        |
| oc     | Ubuntu 26.04 |                                   |
| ho     | Ubuntu 26.04 | 32 vCPU, гость Proxmox            |
| spelik | Ubuntu 26.04 |                                   |
| node   | Ubuntu 26.04 |                                   |

Все хосты доступны только через `~/.ssh/config` (порт 922, `ProxyCommand udp-link`),
поэтому в инвентаре нет ни `ansible_host`, ни `ansible_port`.

### Принятые решения

- **Файрвол:** iptables, сохранение через `iptables-persistent` (Ubuntu) и
  `iptables-services` (Fedora). Правила — из одного jinja2-шаблона, чтобы модель
  правил была общая; различается только способ сохранения.
- **Zabbix:** пакет `zabbix-agent` из репозиториев дистрибутива. Версии в Ubuntu
  и Fedora разойдутся — конфиг пишем совместимым с младшей из них.
- **Файрвол внедряем последним** и обязательно так: сначала `--check --diff`,
  потом `apply` на одном хосте, **не закрывая вторую ssh-сессию к нему**, пока не
  убедишься, что доступ жив.

## Секреты

Пока их нет. Когда появятся (пароли БД, токены Zabbix, ключи бэкапа):

```bash
echo 'длинный-пароль' > ~/.ansible/vault-pass-ansible-cfg
chmod 600 ~/.ansible/vault-pass-ansible-cfg
# раскомментировать vault_password_file в ansible.cfg
.venv/bin/ansible-vault create inventory/group_vars/all/vault.yml
```

Файл пароля держать **вне** репозитория. В `vault.yml` переменные именовать
с префиксом `vault_`, а в открытых `group_vars` ссылаться на них —
так видно, откуда что берётся.
