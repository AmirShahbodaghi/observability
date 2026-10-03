#!/usr/bin/env bash
set -e

VENV_PATH="$HOME/.venv/prometheus"
GALAXY_SERVER="https://reg-devops.tamin.ir/repository/galaxy.ansible.com/"

echo "==> Creating virtual environment at $VENV_PATH..."
python3.13 -m venv "$VENV_PATH"

echo "==> Activating virtual environment..."
source "$VENV_PATH/bin/activate"

# Skip pip self-upgrade since the internal PyPI mirror is missing newer wheels
echo "==> Skipping pip upgrade (using existing pip version)..."

echo "==> Installing Python dependencies..."
pip install -r requirements.txt

echo "==> Installing Ansible collections..."
ansible-galaxy collection install community.docker --server "$GALAXY_SERVER"

echo "==> Environment setup complete! Run 'source $VENV_PATH/bin/activate' to start working."
