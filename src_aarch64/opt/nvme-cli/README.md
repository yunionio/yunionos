# Download

```bash
$ docker run -ti --rm --name=nvme -t arm64v8/ubuntu bash
root@48a1821be0da:/# apt update && apt install -y nvme-cli

$ docker cp nvme:/usr/sbin/nvme .
```

# Clean

```bash
$ sh -c 'rm -rf $(cat ./.gitignore)'
```
