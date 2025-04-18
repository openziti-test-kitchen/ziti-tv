# Part 3 - Advanced Services

* [Ziti TV Part1 - The Beginning](https://www.youtube.com/live/93QZQWdblPU?si=MASCdTOauBIsRQAj)
* [Ziti TV Part2 - Separating From The Quickstart](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)
* [* Ziti TV Part3 - Advanced Services](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)
* [Ziti TV Part4 - Dark Management API](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)

## Backup Part2

Following on from [the work done with Part 2](../part2-adding-a-second-router/README.md), let's keep
backing up the work done so far so it can be reverted if needed. Realistically, you can choose to back up
however you want, but a simple way to accomplish the backup is to copy the whole volumne. This backs up
your PKI, config files, and the controller database.

```
docker volume create learn-openziti-part2
docker run --rm \
  -v openziti:/from \
  -v learn-openziti-part2:/to \
  alpine sh -c "cd /from && cp -a . /to"
```

### Restart From Backup

This will recreate your `openziti` volume from your backup - be careful! Make sure any and all containers that used
the `openziti` volume are removed then run:
```
docker volume rm openziti
docker volume create openziti
docker run --rm \
  -v learn-openziti-part2:/from \
  -v openziti:/to \
  alpine sh -c "cd /from && cp -a . /to"
```

## Helpful `ziti` CLI 

The sourcing of the ziti completion has been moved into the Dockerfile! If you rebuild your image, and down -v/up
your compose project you should have ziti <tab> completion in all your `zubuntu` images. If not, remember you can
either run this manually or add it to the bottom of each container's `$HOME/.bashrc`
```
source <(ziti completion bash)
```

## Allow ssh to the new Container
Each time we make a new part, we are making new containers and we need to add the pubkey back to the sshtarget 
as well as home-router to allow ssh'ing.

```
# **sshtarget**
docker compose --project-name part3 exec sshtarget mkdir .ssh
docker compose --project-name part3 exec sshtarget cp /openziti/my.pub.key .ssh/authorized_keys
docker compose --project-name part3 exec sshtarget chmod -R 500 .ssh/

# **home-router**
docker compose --project-name part3 exec home-router mkdir .ssh
docker compose --project-name part3 exec home-router cp /openziti/my.pub.key .ssh/authorized_keys
docker compose --project-name part3 exec home-router chmod -R 500 .ssh/
```

## Start the Home-Router
```
./connect-to-home-router.sh
ziti router run /openziti/home-router/home-router.yaml

## -- or without exec'ing into docker -- ##

docker compose --project-name part3 exec home-router ziti router run /openziti/home-router/home-router.yaml
```

## Modify Home-Router for Intercept

connect to the home-router using `./connect-to-home-router.sh` then issue:
```
chmod 700 /home/ziti/.ssh
chmod 600 /home/ziti/.ssh/authorized_keys
chown -R ziti:ziti /home/ziti/.ssh
```

Create a key to ssh with:
```
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -C "your_email@example.com"

# add the pubkey to authorized keys
cat .ssh/id_ed25519.pub >> .ssh/authorized_keys
```

## SSH to `sshtarget` from `home-router`

```
cat .ssh/id_ed25519.pub
```

add this to the `sshtarget` `$HOME/.ssh/authorized_keys` file

ssh to `sshtarget` from `home-router`
```
ssh part2.ssh -i .ssh/id_ed25519
```

## Rename Routers to `*.zititv`

* `router-quickstart.zititv`
* `home-router.zititv`

## Make Addressable SSH Service



ziti edge login localhost:6700 -u admin -p $ZITI_PWD -y

ziti edge delete config "acme.wildcard.dial"
ziti edge create config "acme.wildcard.dial" intercept.v1 '{
    "addresses":["*.zititv"],
    "protocols":["tcp"],
    "portRanges":[{"low":80, "high":80},{"low":443, "high":443}],
    "dialOptions": {"identity": "$dst_hostname"}
}'

ziti edge delete config "acme.wildcard.bind"
ziti edge create config "acme.wildcard.bind" host.v1      '{
    "forwardProtocol":true,
    "allowedProtocols":["tcp","udp"],
    "forwardAddress":true,
    "allowedAddresses":["*.zititv"],
    "forwardPort":true,
    "allowedPortRanges":[ {"low":80, "high":80},{"low":443, "high":443}],
    "listenOptions": {"bindUsingEdgeIdentity":true}
}'

ziti edge delete service "acme.challenge.service"
ziti edge create service "acme.challenge.service" --configs "acme.wildcard.bind,acme.wildcard.dial"

ziti edge delete service-policy acme.challenge.service.bind
ziti edge create service-policy acme.challenge.service.bind Bind --service-roles "@acme.challenge.service" --identity-roles "#acme.challenge.service.binders"

ziti edge delete service-policy acme.challenge.service.dial
ziti edge create service-policy acme.challenge.service.dial Dial --service-roles "@acme.challenge.service" --identity-roles "#acme.challenge.service.dialers"



# make sshtarget idnetity

install ziti-edge-tunnel
```
curl -sSLf https://get.openziti.io/tun/scripts/install-ubuntu.bash | bash

ziti-edge-tunnel enroll -i sshtarget.id.json -j sshtarget.id.jwt

ziti-edge-tunnel run-host -i ./sshtarget.id.json
```













