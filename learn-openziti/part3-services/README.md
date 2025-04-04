# Part 2 - Separating From The Quickstart

[Ziti TV Part1 - The Beginning](https://www.youtube.com/live/93QZQWdblPU?si=MASCdTOauBIsRQAj)
[* This Ziti TV Part2 - Separating From The Quickstart](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)

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

**sshtarget**
```
docker compose --project-name part3 exec sshtarget mkdir .ssh
docker compose --project-name part3 exec sshtarget cp /openziti/my.pub.key .ssh/authorized_keys
docker compose --project-name part3 exec sshtarget chmod -R 500 .ssh/
```
**home-router**
```
docker compose --project-name part3 exec home-router mkdir .ssh
docker compose --project-name part3 exec home-router cp /openziti/my.pub.key .ssh/authorized_keys
docker compose --project-name part3 exec home-router chmod -R 500 .ssh/
```

## Start the Home-Routr
```
./connect-to-home-router.sh
ziti router run /openziti/home-router/home-router.yaml

## -- or without exec'ing into docker -- ##

docker compose --project-name part3 exec home-router ziti router run /openziti/home-router/home-router.yaml
```


















