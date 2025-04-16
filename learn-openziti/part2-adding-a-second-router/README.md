# Part 2 - Separating From The Quickstart

[Ziti TV Part1 - The Beginning](https://www.youtube.com/live/93QZQWdblPU?si=MASCdTOauBIsRQAj)
[* Ziti TV Part2 - Separating From The Quickstart](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)
[Ziti TV Part3 - Advanced Services](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)
[Ziti TV Part4 - Dark Management API](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)

## Backup Part1

Following on from [the work done with Part 1](../part1-all-in-one/README.md), it will be a good idea to 
back up the work done so far so it can be reverted if needed. Realistically, you can choose to back up
however you want, but a simple way to accomplish the backup is to copy the whole volumne. This backs up
your PKI, config files, and the controller database.

```
docker volume create learn-openziti-part1
docker run --rm \
  -v openziti:/from \
  -v learn-openziti-part1:/to \
  alpine sh -c "cd /from && cp -a . /to"
```

## Separate the Containers

This part focuses on migrating away from starting the controller and router in a single process and allows
you to move them to separate containers. The quickstart creates the configuration files and PKI necessary
for a standard configuration. These files can then be used by separate containers/processes.

As a reminder, the ZAC should still be available at your wildcard url. For the Ziti TV, this was:
https://controller.zititv.demo.openziti.org:6700/zac/

The work to separate the controller and router was done primarily within the compose file. Compare the two
files to see the differences. Notably these are:
* two containers, one for controller, one for the router
* controller container doesn't run ssh now, instead it runs `ziti controller run` only
* router container doesn't run ssh now, instead it runs `ziti router run` only
* ports separated - each container has a single port exposed
* reduced/removed the environment variables as these are primarily only needed by the quickstart to create
  config files and PKI
* addition of the `sshtarget` container so we can still ssh to a target
* addition of the `home-router` container, emulating a router deployed somewhere else
* addition of the `home` network, introducing a new, isolated network

Change into the `part2-adding-a-second-router` folder and start the project with a project name.
```
cd part2-adding-a-second-router
docker compose --project-name part2 up
```

## Helpful `ziti` CLI Tip

Don't forget that you can source the ziti CLI completion command and get <tab> completion!
```
source <(ziti completion bash)
```

## Enable ssh on the `sshtarget`

Convinience scripts are added to allow you to easily connect to the containers. They are merely simple wrappers 
that call docker compose with the proper --project-name.

Connect to ssh target using `./connect-to-ssh-target.sh`

Inside the container, set it up for you to ssh into the new container:
```
mkdir .ssh
cp /openziti/my.pub.key .ssh/authorized_keys
chmod -R 500 .ssh/
```

### Modify the Bind Config

Now, instead of using [ZTHA as we used in Part1](https://openziti.io/docs/learn/core-concepts/zero-trust-models/overview/#host-access-ztha),
[change to using a ZTNA approach](https://openziti.io/docs/learn/core-concepts/zero-trust-models/overview/#network-access-ztna).

Open the ZAC and find the service created in Part1 named `ssh-to-docker`. Once there, find the associated host(`bind`)
policy and update the offload target address for the ssh service from 127.0.0.1 to `sshtarget`. Here we are using
ZTNA so the sshd service needs to be addressable from the first router named `router-quickstart`. As both are containers
associated to the `openziti` docker network, that is the case. The compose file and docker will surface a route to
the hostname of the `sshtarget` container for the router to use to connect to sshd from the router.

Once ready, `ssh` to the `sshtarget` from anywhere!

## Enable ssh on the `home-router` (the failure at the end of Ziti TV)

With the controller and router separated and a separate `sshtarget`, let's add a second router in a different network.
This router will be in our `home` network, isolated from the controller and router, available only through the actual
home network or actual internet!

### Create an Edge Router in the OpenZiti Controller

Either exec into the controller container, or authenticate to the OpenZiti Controller using the `ziti` CLI. Once
authenticated, create the `home-router` using the following command. We'll assign this router as tunneling enabled (`-t`)
as well as assign an attribute to the router for later use `homenetwork`, finally writing the .jwt to a file named
`home-router.jwt`.
```
ziti edge create edge-router home-router -o home-router.jwt -a homenetwork -t
```

### Copy the JWT To the home-router Container

In the Ziti TV, we exec'ed into the controller to authenticate and create the second router. Then we used 
docker cp to copy the JWT from the controller container to the host OS, and then from the host OS to the 
`home-router` container. From the base OS (not within the docker containers):

```
docker cp part2-controller-1:/home/ziti/home-router.jwt .
docker cp ./home-router.jwt part2-controller-1:/home/ziti/home-router.jwt
```

### Enrolling and running `home-router`

With the JWT in the `home-router` container, we then enrolled the router and ran it and verified it connected and formed links!
Exec into the `home-router` using `./connect-to-home-router.sh`

![NOTE]
> It's useful to use the `/openziti` folder for any persistent data. This will allow you to `down -v` the compose file if you
> want to generate fresh containers for any reason without losing the persisted data

**Create the router's config file:**
```
mkdir /openziti/home-router
ziti create config router edge --routerName the-home-router > /openziti/home-router/home-router.yml
```

**Enroll the router:**
```
ziti router enroll /openziti/home-router/home-router.yml --jwt /home/ziti/home-router.jwt
```

**Run the router:**
```
ziti router run /openziti/home-router/home-router.yml
```

**Ziti TV Fix - Add Authorized Keys**

During the Ziti TV, the `sshd` connection was refused. This was because the compose file was incorrect. The problem with the
compose file has been corrected. The second issue was there was no `authorized_keys` file present. Once inside the container,
set it up for sshing by doing the same as before:
```
mkdir .ssh
cp /openziti/my.pub.key .ssh/authorized_keys
chmod -R 500 .ssh/
```















