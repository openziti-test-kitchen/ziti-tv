# Part 2 - Separating From The Quickstart

backup part1
```
docker volume create learn-openziti-part1
docker run --rm \
  -v openziti:/from \
  -v learn-openziti-part1:/to \
  alpine sh -c "cd /from && cp -a . /to"
```

url to zac: https://controller.zititv.demo.openziti.org:6700/zac/services


convert over to running individuals, paving the way to using the contorller/router image
add ssh target -- we aren't running ssh d any more
change the service accordingly

turnit all on this time let's use a project name::
```
cd part2-adding-a-second-router
docker compose --project-name part2 up
```

reminder on how to restart the quickstart
```
ziti edge quickstart \
    --ctrl-address ${EXTERNAL_DNS} \
    --ctrl-port ${ZITI_CTRL_ADVERTISED_PORT} \
    --router-address ${EXTERNAL_DNS} \
    --router-port ${ZITI_ROUTER_PORT} \
    --password ${ZITI_PWD} \
    --home /openziti/zititv
```

make our life easier:
```
source <(ziti completion bash)
```

















