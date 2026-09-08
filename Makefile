# Тонкая обёртка над ansible из локального venv.
# HOSTS=<pattern> ограничивает прогон: make check HOSTS=srv-misc-1
ANSIBLE  := .venv/bin/ansible
PLAYBOOK := .venv/bin/ansible-playbook
LINT     := .venv/bin/ansible-lint
HOSTS    ?= all
LIMIT    := --limit '$(HOSTS)'
# REMOTE_USER=root — для совсем нового сервера, где пользователя gul ещё нет.
REMOTE_USER ?=
AS       := $(if $(REMOTE_USER),--user '$(REMOTE_USER)',)

.PHONY: deps ping facts lint bootstrap check apply

deps:            ## Поставить collections из requirements.yml
	.venv/bin/ansible-galaxy collection install -r requirements.yml

ping:            ## Проверить связность
	$(ANSIBLE) $(HOSTS) -m ansible.builtin.ping

facts:           ## Показать, что за серверы в инвентаре
	$(PLAYBOOK) playbooks/facts.yml $(LIMIT)

bootstrap:       ## Разовая подготовка хоста; REMOTE_USER=root для нового (не check-safe)
	$(PLAYBOOK) playbooks/bootstrap.yml $(LIMIT) $(AS)

lint:            ## Статическая проверка
	$(LINT)

check:           ## Прогон вхолостую с диффом — ВСЕГДА делать перед apply
	$(PLAYBOOK) site.yml $(LIMIT) --check --diff

apply:           ## Применить по-настоящему
	$(PLAYBOOK) site.yml $(LIMIT) --diff
