Rename `vars` to `vars.yml`, `hosts` to `hosts.yml`. Populate them, then run with

```bash
ansible-playbook -i hosts.ini -e @vars.yml install_signed_executor.yml -vvv
```