INV := inventory/hosts.yml

deploy-%:
	ansible-playbook site.yml --tags $* -i $(INV)

verify-%:
	ansible-playbook playbooks/verify.yml --tags $* -i $(INV)

start-%:
	ansible-playbook playbooks/lifecycle.yml --tags $* -e service_action=start -i $(INV)

stop-%:
	ansible-playbook playbooks/lifecycle.yml --tags $* -e service_action=stop -i $(INV)

restart-%:
	ansible-playbook playbooks/lifecycle.yml --tags $* -e service_action=restart -i $(INV)

reset-%:
	ansible-playbook playbooks/lifecycle.yml --tags $* -e service_action=reset -i $(INV)

syntax:
	ansible-playbook site.yml --syntax-check
	ansible-playbook playbooks/lifecycle.yml --syntax-check
	ansible-playbook playbooks/verify.yml --syntax-check