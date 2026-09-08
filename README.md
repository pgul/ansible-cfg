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
make ping                       # связность
make facts                      # что за машины в инвентаре
make lint                       # статическая проверка
make check HOSTS=srv-misc-1     # вхолостую, с диффом
make apply HOSTS=srv-misc-1     # применить на одном хосте
make apply                      # применить везде
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
  defaults/main.yml      переменные роли (переопределяемые)
  vars/<os_family>.yml   отличия Debian vs RedHat
  tasks/main.yml         что делать
  handlers/main.yml      реакции на изменения (рестарты сервисов)
  templates/             jinja2-шаблоны конфигов
```

Отличия между Ubuntu и Fedora решаются через `vars/{{ ansible_os_family }}.yml`
внутри роли, а не через `when:` в каждой задаче.

## Порядок внедрения ролей

| # | Роль                  | Что делает                                              | Статус |
|---|-----------------------|---------------------------------------------------------|--------|
| 1 | `common`              | пакеты, таймзона, синхронизация времени                  | есть   |
| 2 | `sudoers`             | `/etc/sudoers.d/*` с обязательным `validate: visudo -cf` | —      |
| 3 | `auto_updates`        | `unattended-upgrades` (Ubuntu) / `dnf-automatic` (Fedora)| —      |
| 4 | `zabbix_agent`        | пакет из дистрибутива, конфиг шаблоном                   | —      |
| 5 | `cron_jobs`           | скрипты в `/usr/local/sbin` + systemd timers или cron    | —      |
| 6 | `firewall`            | iptables + iptables-persistent / iptables-services       | —      |

Бэкап настроен вручную и в Ansible пока не заводится.

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
