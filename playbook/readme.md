# Install k0s cluster

## Flash OS

Use Raspberry Imager, enable ssh

Append following line to /boot/config.txt

```ini
[all]
enable_uart=1
```

Append following line to /boot/firmware/cmdline.txt

```ini
cgroup_memory=1 cgroup_enable=memory
```

## Playbook

```bash
ansible-playbook k0s_install.yaml -i inventory/ --user opvolger --ask-pass --ask-become-pass -vv
ansible-playbook shutdown_cluster.yaml -i inventory/ --user opvolger --ask-pass --ask-become-pass -vv
```
