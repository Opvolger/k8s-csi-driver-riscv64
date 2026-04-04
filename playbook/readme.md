# Install k0s cluster

## Flash OS

Use Raspberry Imager, enable ssh

Append following line to /boot/config.txt

```ini
[all]
enable_uart=1
```

## Playbook

```bash
ansible-playbook k0s_install.yaml -i inventory/ --user opvolger --ask-pass --ask-become-pass
ansible-playbook shutdown_cluster.yaml -i inventory/ --user opvolger --ask-pass --ask-become-pass
```
