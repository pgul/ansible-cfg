# Тонкая обёртка над ansible из локального venv.
# HOSTS=<pattern> ограничивает прогон: make check HOSTS=srv-misc-1
ANSIBLE  := .venv/bin/ansible
PLAYBOOK := .venv/bin/ansible-playbook
LINT     := .venv/bin/ansible-lint
HOSTS    ?= all
LIMIT    := --limit '$(HOSTS)'

.PHONY: deps ping facts lint check apply

deps:            ## Поставить collections из requirements.yml
	.venv/bin/ansible-galaxy collection install -r requirements.yml

ping:            ## Проверить связность
	$(ANSIBLE) $(HOSTS) -m ansible.builtin.ping

facts:           ## Показать, что за серверы в инвентаре
	$(PLAYBOOK) playbooks/facts.yml $(LIMIT)

lint:            ## Статическая проверка
	$(LINT)

check:           ## Прогон вхолостую с диффом — ВСЕГДА делать перед apply
	$(PLAYBOOK) site.yml $(LIMIT) --check --diff

apply:           ## Применить по-настоящему
	$(PLAYBOOK) site.yml $(LIMIT) --diff
