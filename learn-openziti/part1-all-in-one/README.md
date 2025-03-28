# Part 1 - Mar 21 2005

In part one we'll be starting off making an OpenZiti overlay network in a single command.

This example uses docker as a playground environment. If you have your own virtual machines, VPS or other, and you don't want to use docker you don't need to. The docker-related setup is just to get you a clean environment which you can start/stop/tear down entirely, quickly and easily.

## Docker Related Prerequisites

Make a docker volume. This volume is where all the persistent files will be stored. You don't need to call it `openziti` but if you don't, you'll need to change the compose file accordingly. 

Compose is being used to allow for more than one machine to start/stop. Further in the series we will want to explore more with adding more routers, adding other services, etc. Using compose will make this task simple.

Since it will be done in docker, it's not a perfect representation of the real world. There's no systemd and docker is not really intended for the purpose I'm using it for here. 

## Build the Docker Image - Based from Ubuntu

The image uses ubuntu, hence the image tag used of "zubuntu". If you have a favorite distro you want to use, try it but it was only tested and used on Ziti TV with ubuntu. :)

Numerous tools are built into the image that are useful that are not normally installed in a docker container. This is done purely for educational purposes. It's not meant to be considered "a good idea"™. It's just quite handy, if you have docker already, to make a small world that you can control and manipulate relatively easily. The user inside the container will be named `ziti` and will have `sudo` access which.

```
docker build -t zubuntu .
```

## Create a Volume

This is where all persisted data will go allowing you to change the configurations, delete files, grab files, etc. 

I chose to use an external volume for this series just in case someone (me) makes a mistake and runs `down -v`. If you ever want to start all over, the normal `compose down -v` **will not** work as expected because the volume is marked `external`. If you are well-versed with docker, you don't need an external volume. You can modify accordingly.

```
docker volume create openziti
```

## LetsEncrypt Certificates

This is optional, but having a wildcard certificate for your overlay has a couple of benefits. First, it'll allow you to install the UI and not have to deal with the dreaded "Your connection is not private" errors associated with self-signed certs. It also will allow you to install `zrok` some day, which is part of the series I hope to get to as well as install and use BrowZer so it is probably worth the pain.

You need a registrar of choice and you'll need to be able to add a specific TXT record to the registrar. Every registrar is different. I suggest you find a good tutorial on this if you're not familiar but you'll want a **wildcard** domain setup.

Once you have access to a DNS registrar and can create a `*.your.domain` record, you'll be able to also add at `TXT` record and you're ready to start the certbot challenge. This is the __MANUAL__ mechanism, not acceptable for automation but for this series, it should be sufficient.

When ready, run:
```
docker run -it --rm \
  -v openziti:/etc/letsencrypt \
  certbot/certbot certonly \
    --manual \
    --preferred-challenges dns \
    --agree-tos \
    -d "*.zititv.demo.openziti.org" -d zititv.demo.openziti.org \
    --email clint@company.io
```

You will see:
```
Requesting a certificate for *.zititv.demo.openziti.org and zititv.demo.openziti.org

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Please deploy a DNS TXT record under the name:

_acme-challenge.zititv.demo.openziti.org.

with the following value:

WStxwUr1HWlpeZHkbBdvcLaCj6woiLa7PmQdmTqMoR0

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
Press Enter to Continue
```

You now need to add this record to your registrar. Once your registrar returns the record, you can click Enter to contine. Check if the record is there however you like, for example:
```
dig TXT _acme-challenge.zititv.demo.openziti.org +short
"WStxwUr1HWlpeZHkbBdvcLaCj6woiLa7PmQdmTqMoR0"
```

When you succeed you'll see this and you'll be ready to continue:
```
Successfully received certificate.
Certificate is saved at: /etc/letsencrypt/live/zititv.demo.openziti.org/fullchain.pem
Key is saved at:         /etc/letsencrypt/live/zititv.demo.openziti.org/privkey.pem
This certificate expires on 2025-06-19.
These files will be updated when the certificate renews.

NEXT STEPS:
- This certificate will not be renewed automatically. Autorenewal of --manual certificates requires the use of an authentication hook script (--manual-auth-hook) but one was not provided. To renew this certificate, repeat this same certbot command before the certificate's expiry date.

- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
If you like Certbot, please consider supporting our work by:
 * Donating to ISRG / Let's Encrypt:   https://letsencrypt.org/donate
 * Donating to EFF:                    https://eff.org/donate-le
- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
```

### Chown the OpenZiti Volume

As the user inside the docker container is `ziti` and we'll do most things as this user, it'll be easier if you can modify the files as that user. To do that, you need to run another command to chown the mount:
```
docker run -it --rm --user root -v openziti:/openziti zubuntu chown -R ziti:ziti /openziti
```

### Run the Compose File

At this point, you'll be ready to start this compose file. Sure, it's somewhat silly at this point since there's only a single container being run, but it'll allow us to build onto this compose file later and add things as we go.

Choose if you prefer running the containers interactively or in 'daemon' mode where they run in the background. Personally, I run them in the forground so that when I ctrl-c and exit the terminal, the containers stop running automatically. If you prefer them to run forever, add `-d` to the command.

Start docker now:
```
docker compose up #-d
```

## Running OpenZiti

Here it is, time to start an entirely functional OpenZiti overlay network. Yes, it's one command but there are a few things that are important to note.

First, I have __already__ registered a domain name with LetsEncrypt and I have __already__ obtained certificates for my domain.
```
ziti edge quickstart \
    --ctrl-address ${EXTERNAL_DNS} \
    --ctrl-port ${ZITI_CTRL_ADVERTISED_PORT} \
    --router-address ${EXTERNAL_DNS} \
    --router-port ${ZITI_ROUTER_PORT} \
    --password ${ZITI_PWD} \
    --home /openziti/zititv
```

### Starting From the Beginning

To start from the beginning of this series you simply need to clean up the docker containers that are running, and delete the volume.
```
docker compose down -v
docker volume rm openziti
```




