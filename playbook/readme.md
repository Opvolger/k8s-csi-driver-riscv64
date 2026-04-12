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
# will crash 1ste time on install helm, network changes.
ansible-playbook k0s_init.yaml -i inventory/ --user opvolger --ask-pass --ask-become-pass -vv --limit "nuc.cluster,"
# next run!
ansible-playbook k0s_init.yaml -i inventory/ --user opvolger -vv --limit "nuc.cluster,"
ansible-playbook k0s_setup_network.yaml -i inventory/ --user opvolger -vv --limit "nuc.cluster,"
# change ip in inventory!
ansible-playbook k0s_install_update.yaml -i inventory/ --user opvolger -vv
# shutdown before power off the cluster!
ansible-playbook k0s_shutdown_cluster.yaml -i inventory/ --user opvolger -vv
```
