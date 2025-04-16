# Part 4 - Dark Management API

[Ziti TV Part1 - The Beginning](https://www.youtube.com/live/93QZQWdblPU?si=MASCdTOauBIsRQAj)
[Ziti TV Part2 - Separating From The Quickstart](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)
[Ziti TV Part3 - Advanced Services](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)
[* Ziti TV Part4 - Dark Management API](https://www.youtube.com/live/AqLyqgNP3Qk?si=1t5nj64-Uvc6vaYq)

## Backup Part3

Following on from [the work done with Part 3](../part3-services/README.md), let's keep
backing up the work done so far so it can be reverted if needed. Realistically, you can choose to back up
however you want, but a simple way to accomplish the backup is to copy the whole volumne. This backs up
your PKI, config files, and the controller database.

```
docker volume create learn-openziti-part3
docker run --rm \
  -v openziti:/from \
  -v learn-openziti-part3:/to \
  alpine sh -c "cd /from && cp -a . /to"
```

### Restart From Backup

This will recreate your `openziti` volume from your backup - be careful! Make sure any and all containers that used
the `openziti` volume are removed then run:
```
docker volume rm openziti
docker volume create openziti
docker run --rm \
  -v learn-openziti-part3:/from \
  -v openziti:/to \
  alpine sh -c "cd /from && cp -a . /to"
```

## Start Part 4
```
docker compose --project-name part4 up
```

### Connect to `sshtarget`
Just making sure things still work...
```
./connect-to-sshtarget.sh
```

oh no, we need to reenroll the identity! We forgot to move the sshtarget identity to the shared storage. let's fix that
1. open zac, go to identities
1. find sshtarget.zititv, click the three dots (elipses, ...)
1. Choose Reset Enrollment
1. Download and transfer the jwt to `sshtarget` by opening the jwt and "echoing" it to a file. something like this (not exactly):
    
      echo "eyJhbGciOiJSUzI1NiIsImtpZCI6ImUzNjc0MTA3YzlhMzRmMWQwOTc5NjY5MjZhMGI5MDgzN2Q0NTE4OGQiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL2VjMi0zLTE0Mi0yNDUtNjMudXMtZWFzdC0yLmNvbXB1dGUuYW1hem9uYXdzLmNvbTo2NzAwIiwic3ViIjoieVNOc2VGMzRLIiwiYXVkIjpbIiJdLCJleHAiOjE3NDQ5OTY4MDIsImp0aSI6IjkxOGMwM2UyLWUzZDUtNDk2Yi1iYTE0LTQyYzk1NTNmMWMxOSIsImVtIjoib3R0IiwiY3RybHMiOlsidGxzOmVjMi0zLTE0Mi0yNDUtNjMudXMtZWFzdC0yLmNvbXB1dGUuYW1hem9uYXdzLmNvbTo2NzAwIl19.HWd7QUddTG29WATWQsysF-OOsf7GvXFN2nZMYxIRkEILOK-JOUYCIvleWRPUqTjDgMmWiJj4LS0KLYUVdKsYiC4JfMKRr1OabEudE6iAq6tCGSUOGTqzRr4FqFUdnMtzWu3-cNnyMHhENe4G_cos3bu7PU-kTK1rxdCM4O8-9wvOBIFVAtofRj2AoSRzj4gT5HYfB7CcDM" > 

1. install ziti-edge-tunnel: `curl -sSLf https://get.openziti.io/tun/scripts/install-ubuntu.bash | bash`
1. enroll using ziti-edge-tunnel but send the file to shared storage:
    
      ziti-edge-tunnel enroll -j ./sshtarget.jwt -i /openziti/sshtarget.json
      
1. copy your pubkey:

      mkdir $HOME/.ssh
      cp /openziti/my.pub.key $HOME/.ssh/authorized_keys

1. start ziti-edge-tunnel: `ziti-edge-tunnel run-host -i /openziti/sshtarget.json`
1. ssh to `sshtarget` from 'bob'. Replace the private key with your private key (of course)
      
      ssh ziti@sshtarget.zititv -i ~/.encrypted/.ssh/id_ed25519`
      
## Make a Service for our new API

Make a "simple service" using the ZAC.
* **Service Name**: mgmt.api
* **What Identities Can Access**: `mgmt.api.dialers`
* **HOSTNAME / IP**: `controller.ziti`
* **PORT**: `6701`
* **What Identities Can Host**: `mgmt.api.binders`
* **HOSTNAME / IP**: `controller.docker`
* **PORT**: `6701`
* Add `mgmt.api.dialers` to "bob"
* Add `mgmt.api.binders` to the "router-quickstart.zititv" identity

## Turn the Management API Dark

Backup the control file - just in case!
```
cp /openziti/zititv/ctrl.yaml /openziti/zititv/ctrl.yaml.backup.part4
```

Edit the controller config file:
```
vi /openziti/zititv/ctrl.yaml
```

In order to turn the mgmt API dark, we'll need an OpenZiti offload point. We'll use the router we deployed already.
For the router to contact the managment API we'll need to use the IP or hostname of the controller. The controller
will need to bind to an appropriate IP to keep the traffic private to the docker network.

This compose file has new aliases for each container defined. For example the controller is available via the private
docker network at: `controller.docker`.

Make the web section look like this and restart the compose project.
```
web:
  # PUBLIC ENDPOINTS!
  - name: client-oidc
    bindPoints:
      # A host:port string on which network interface to listen on. 0.0.0.0 will listen on all interfaces
      - interface: 0.0.0.0:6700
        address: ec2-3-142-245-63.us-east-2.compute.amazonaws.com:6700
    identity:
      ca:          "/openziti/zititv/pki/root-ca/certs/root-ca.cert"
      key:         "/openziti/zititv/pki/intermediate-ca-quickstart/keys/server.key"
      server_cert: "/openziti/zititv/pki/intermediate-ca-quickstart/certs/server.chain.pem"
      cert:        "/openziti/zititv/pki/intermediate-ca-quickstart/certs/client.chain.pem"
      alt_server_certs:
      - server_cert: "/openziti/live/zititv.demo.openziti.org/fullchain.pem"
        server_key:  "/openziti/live/zititv.demo.openziti.org/privkey.pem"
    options:
      idleTimeout: 5000ms  #http timeouts, new
      readTimeout: 5000ms
      writeTimeout: 100000ms
      minTLSVersion: TLS1.2
      maxTLSVersion: TLS1.3
    apis:
      - binding: edge-client
        options: { }
      - binding: edge-oidc
        options: { }
  # PRIVATE APIS -- soon to be only available via OpenZiti
  - name: management-fabric-zac
    bindPoints:
      # A host:port string on which network interface to listen on. 0.0.0.0 will listen on all interfaces
      - interface: controller.docker:6701
        address: ec2-3-142-245-63.us-east-2.compute.amazonaws.com:6701
    identity:
      ca:          "/openziti/zititv/pki/root-ca/certs/root-ca.cert"
      key:         "/openziti/zititv/pki/intermediate-ca-quickstart/keys/server.key"
      server_cert: "/openziti/zititv/pki/intermediate-ca-quickstart/certs/server.chain.pem"
      cert:        "/openziti/zititv/pki/intermediate-ca-quickstart/certs/client.chain.pem"
      alt_server_certs:
      - server_cert: "/openziti/live/zititv.demo.openziti.org/fullchain.pem"
        server_key:  "/openziti/live/zititv.demo.openziti.org/privkey.pem"
    options:
      idleTimeout: 5000ms  #http timeouts, new
      readTimeout: 5000ms
      writeTimeout: 100000ms
      minTLSVersion: TLS1.2
      maxTLSVersion: TLS1.3
    apis:
      - binding: edge-management
        options: { }
      - binding: fabric
        options: { }
      - binding: zac
        options:
          location: "/openziti/zac/ziti-console-v3.11.2"
          indexFile: index.html
```

Restart the controller:
```
# <ctrl-c> in the running compose environment then re-launch
docker compose --project-name part4 up controller
```

Make sure router can access the controller:
```
curl -sk https://controller.docker:6701
```

Notice ZAC is no longer accessable! Need bob!!!!

Make sure bob has access to the mgmt.api and then hit it!
https://controller.ziti:6701/zac/dashboard




