# Setup cluster

https://docs.k0sproject.io/v1.21.2+k0s.1/k0s-multi-node/#5-add-controllers-to-the-cluster
https://docs.k0sproject.io/v1.35.2+k0s.0/high-availability/

## Build k0s

```bash
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
```

add `--platform=riscv64` on every $(DOCKER) command in Makefile

## HAProxy

Read [high-availability](https://docs.k0sproject.io/v1.35.2+k0s.0/high-availability/) in k0sproject

Installed HAProxy in the LuCI

logged in to the router edit `/etc/haproxy.cfg` with vi and added:

```ini
frontend kubeAPI
    bind :6443
    mode tcp
    default_backend kubeAPI_backend
frontend konnectivity
    bind :8132
    mode tcp
    default_backend konnectivity_backend
frontend controllerJoinAPI
    bind :9443
    mode tcp
    default_backend controllerJoinAPI_backend

backend kubeAPI_backend
    mode tcp
    server k0s-controller1 192.168.8.10:6443 check check-ssl verify none
    server k0s-controller2 192.168.8.11:6443 check check-ssl verify none
    server k0s-controller3 192.168.8.12:6443 check check-ssl verify none
backend konnectivity_backend
    mode tcp
    server k0s-controller1 192.168.8.10:8132 check check-ssl verify none
    server k0s-controller2 192.168.8.11:8132 check check-ssl verify none
    server k0s-controller3 192.168.8.12:8132 check check-ssl verify none
backend controllerJoinAPI_backend
    mode tcp
    server k0s-controller1 192.168.8.10:9443 check check-ssl verify none
    server k0s-controller2 192.168.8.11:9443 check check-ssl verify none
    server k0s-controller3 192.168.8.12:9443 check check-ssl verify none

listen stats
   bind *:9000
   mode http
   stats enable
   stats uri /
```

Now i have a stats page on [http://192.168.8.1:9000](http://192.168.8.1:9000)
