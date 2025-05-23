Create softlinks `ln -s` to to executor and key

```bash
#example
ln -s ~/IdeaProjects/sysAdminToolboxBackendTokenExecutor/target/secOpsDispatcher  ./secOpsDispatcher

ln -s /home/mskla/projs/python/sysadmintoolboxfullstackOpen/test_token_key/pub.key ./pub.key
```

```bash
ansible-playbook -i hosts.ini -e @vars.yml  install_dev_signed_executor.yml -vvv
```