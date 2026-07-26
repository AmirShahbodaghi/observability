VENV_DIR = $(HOME)/.venv/prometheus
PYTHON = $(VENV_DIR)/bin/python
PIP = $(VENV_DIR)/bin/pip
ANSIBLE_GALAXY = $(VENV_DIR)/bin/ansible-galaxy
GALAXY_SERVER = https://your-registery/repository/galaxy.ansible.com/

.PHONY: setup clean activate-help

# Default target runs setup
setup: $(VENV_DIR)/bin/activate

$(VENV_DIR)/bin/activate: requirements.txt
	@echo "==> Creating Virtualenv..."
	python3 -m venv $(VENV_DIR)
	@echo "==> Upgrading Pip..."
	$(PIP) install -U pip
	@echo "==> Installing Requirements..."
	$(PIP) install -r requirements.txt
	@echo "==> Installing Ansible Collections..."
	@if [ -f requirements.yml ]; then \
		$(ANSIBLE_GALAXY) collection install -r requirements.yml --server $(GALAXY_SERVER); \
# 	else \
# 		$(ANSIBLE_GALAXY) collection install community.docker --server $(GALAXY_SERVER); \
# 	fi
	@echo "==> Setup finished!"

clean:
	@echo "==> Removing Virtualenv..."
	rm -rf $(VENV_DIR)
