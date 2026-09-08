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

| # | Роль                  | Статус |
|---|-----------------------|--------|
| 1 | `common`              | есть   |
| 2 | `sudoers`             | —      |
| 3 | `unattended_upgrades` | —      |
| 4 | `zabbix_agent`        | —      |
| 5 | `cron_jobs`           | —      |
| 6 | `backup`              | —      |
| 7 | `firewall`            | —      |

Файрвол — последним и с `ansible-playbook ... --check` дважды: им проще всего
отрезать себе доступ.

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
