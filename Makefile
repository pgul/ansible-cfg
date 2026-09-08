# Thin wrapper around ansible from the local venv.
# HOSTS=<pattern> narrows a run: make check HOSTS=oc
ANSIBLE  := .venv/bin/ansible
PLAYBOOK := .venv/bin/ansible-playbook
LINT     := .venv/bin/ansible-lint
HOSTS    ?= all
LIMIT    := --limit '$(HOSTS)'
# REMOTE_USER=root — for a brand new server where the gul user does not exist yet.
REMOTE_USER ?=
AS       := $(if $(REMOTE_USER),--user '$(REMOTE_USER)',)

.PHONY: deps ping facts lint bootstrap check apply

deps:            ## Install collections from requirements.yml
	.venv/bin/ansible-galaxy collection install -r requirements.yml

ping:            ## Check connectivity
	$(ANSIBLE) $(HOSTS) -m ansible.builtin.ping

facts:           ## Show what the inventory hosts actually are
	$(PLAYBOOK) playbooks/facts.yml $(LIMIT)

lint:            ## Static checks
	$(LINT)

bootstrap:       ## One-off host preparation; REMOTE_USER=root for a new one (not check-safe)
	$(PLAYBOOK) playbooks/bootstrap.yml $(LIMIT) $(AS)

check:           ## Dry run with diff — ALWAYS do this before apply
	$(PLAYBOOK) site.yml $(LIMIT) --check --diff

apply:           ## Apply for real
	$(PLAYBOOK) site.yml $(LIMIT) --diff
