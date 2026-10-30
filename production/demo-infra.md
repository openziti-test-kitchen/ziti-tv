# Demo infrastructure

Most episodes need a server with a public IP, real DNS names and a certificate the operating system trusts. Set these
up once per episode, ahead of the stream, and keep them out of the show.

## Before you build: move the old demo out of the way

A demo box collects state from earlier episodes. Before a from-nothing run, check what still listens on the
episode's ports and what still runs from its directory:

```bash
sudo ss -ltnp | grep -E ':(80|443|<ports>) '
pgrep -af "<demo dir>|ziti-edge-tunnel"
docker ps -a --format '{{.Names}} {{.Status}}'
```

Stop the old processes, then move the old directory aside instead of deleting it, so nothing is lost:

```bash
mv ~/<demo dir> ~/<demo dir>.bak-<mmdd>
```

Remove stopped containers whose names the new episode reuses. `docker run --name` fails on a name that exists.

## Certificates

Episodes that need a publicly trusted name use a Let's Encrypt wildcard certificate that is already on the box, such
as `*.zititv.demo.openziti.org`. Look before you request a new one:

```bash
sudo ls /etc/letsencrypt/live
sudo openssl x509 -in /etc/letsencrypt/live/<name>/fullchain.pem -noout -ext subjectAltName -enddate
```

Copy the two files where the episode expects them, readable by the demo user:

```bash
sudo cp -L /etc/letsencrypt/live/<name>/fullchain.pem /etc/letsencrypt/live/<name>/privkey.pem "$DEMO_DIR/le/"
sudo chown "$(id -u):$(id -g)" "$DEMO_DIR"/le/*.pem
```

The episode README still shows readers how to get their own certificate. The host says it was done ahead.

## DNS in Route53

A wildcard record such as `*.zititv.demo.openziti.org` may point at a different machine than the one you demo on.
Add specific records for the episode's names instead of editing the wildcard. A specific record wins over the
wildcard for that name only, so everything else that uses the wildcard keeps working.

```powershell
# find the zone, then look at what exists
aws route53 list-hosted-zones --query "HostedZones[?contains(Name,'openziti.org')].[Id,Name]" --output text
$zone = '/hostedzone/<id>'
aws route53 list-resource-record-sets --hosted-zone-id $zone `
  --query "ResourceRecordSets[?contains(Name,'<sub>')].[Name,Type,ResourceRecords[0].Value]" --output text

# create or update the episode's names
$ip = '<public IPv4 of the demo box>'
$changes = @('<name1>','<name2>') | ForEach-Object {
  @{ Action = 'UPSERT'; ResourceRecordSet = @{ Name = "$_.<sub>.demo.openziti.org"; Type = 'A'; TTL = 60
     ResourceRecords = @(@{ Value = $ip }) } } }
@{ Comment = 'ziti tv <date>'; Changes = $changes } |
  ConvertTo-Json -Depth 6 | Set-Content -Encoding ascii $env:TEMP\r53.json
aws route53 change-resource-record-sets --hosted-zone-id $zone --change-batch "file://$env:TEMP\r53.json"
```

Check against a public resolver. A home router caches the old answer for the old record's TTL:

```powershell
Resolve-DnsName <name1>.<sub>.demo.openziti.org -Type A -Server 8.8.8.8 -DnsOnly
ipconfig /flushdns
```

On macOS, flush with `sudo killall -HUP mDNSResponder`.

## Ports

From outside, a port the security group allows answers "connection refused" when nothing listens on it yet. A port
it blocks times out:

```bash
for p in <ports>; do timeout 4 bash -c "</dev/tcp/<ip>/$p" 2>&1 | head -1; done
```

## Extra tunnelers on Windows

Ziti Desktop Edge runs one `ziti-edge-tunnel`. A second, separate instance takes its own IPC prefix, identity
directory and DNS range, so it does not touch ZDEW:

```powershell
# from an elevated prompt, with the release zip for the version the episode uses unpacked into its own directory
& <path>\ziti-edge-tunnel.exe run -I <base>\ids -P <prefix> --dns-ip-range 10.99.0.0/16
```

Then pass `-P <prefix>` to `add`, `ext-jwt-login` and the other IPC commands. Pick a DNS range no other instance
uses. Sign-in callbacks use `localhost:20314` in every tunneler, so sign in from one at a time.

**Keep every octet of the range at 127 or below.** `ziti-edge-tunnel` 1.19.1 on Windows reads the octets as signed
bytes, so `100.232.0.0/16` sets the DNS server to `100.-24.0.1`. On Oct 23 the second tunneler, on that range,
failed live with "ziti context not found". `10.99.0.0/16` avoids it. In the `desktop-edge-win` repo, `start-zet-instance.ps1` starts an
instance: pass it `-DnsIpRange 10.99.0.0/16`.

## The admin console

If the episode shows identities or policies in ZAC, the controller needs the console's SPA binding on its web
listener before air. The quickstart adds it. A controller built by an episode script does not, unless the script
adds it. Check `https://<ctrl>:<port>/zac` before going live.

## Two overlays when the show builds live

When the show opens on the payoff and then builds it from nothing, run the payoff on its own overlay: its own
directory, controller, router and IdP ports, and its own DNS names if it needs them. Then the live build and its
`reset.sh` cannot break the payoff, and the payoff can stay up as the fallback.

## After the show

Tear down what was made for the episode: the overlays (`reset.sh`), the specific Route53 records (same change batch
with `Action = 'DELETE'` and the same values), and the security group rules for the episode's ports.

## Proving claims before the show

Every sentence in a walkthrough that says something works should have been seen working. When a claim is new, have
an agent prove it on a scratch box (unique ports and container names on a shared machine, clean up after), and
write the evidence to a report. On Oct 23, "carol, in no group, still enrolls" was proved this way: Keycloak omits
the `groups` claim entirely for a user in no group, and OpenZiti enrolls her with no role attributes.
