# Interop matrix - live smoke results

What was actually run and verified on the lab (not just built). The full grid renderer is
`scripts/interop-matrix.sh`; this file records the hand-run smoke that proved cross-language
dialing works over the overlay.

## Setup verified

- All 6 Linux SDK images build: zo-sdk-go, zo-sdk-py, zo-sdk-js, zo-sdk-cs, zo-sdk-java, zo-sdk-c.
  (Swift, zo-sdk-swift, is Apple-only by design; it runs as a macOS host edge, not a Linux container.)
- `scripts/provision-interop.sh` created the 14 services (echo.<lang> / http.<lang>), 14 identities
  (isrv-<lang> / icli-<lang>), the single `dial-interop` Dial policy, and the per-language Bind policies, and
  enrolled all 14 identities to JSON.

## echo matrix (live), client (row) dialing server (column)

```
client\server   go    py    js    java   c     cs
go              OK    OK    OK    OK    OK    parked
py              OK    OK    OK    OK    OK    parked
js              OK    OK    OK    OK    OK    parked
java            OK    OK    OK    OK    OK    parked
c               OK    OK    OK    OK    OK    parked
cs             parked parked parked parked parked parked
```

- go, py, js, java, c: fully interoperable in BOTH directions (a verified 5x5 green block). This is the headline
  proof, any of these languages as client speaks to any as server over Ziti, identical bytes, no tunneler, no open
  ports. (go/py/js/java verified in a clean run; C verified after its exit-code fix: `exit 0, RESULT ok echo
  c->go 28ms`.)
- cs (C#): PARKED. The image builds and the program follows the contract, but the OpenZiti.NET native context
  could not reliably load the enrolled identity at runtime (`configuration-not-found`). A long fix attempt did not
  converge, so C# is a known gap, not a blocker. The matrix is proven without it.
- swift: the Apple-only host edge (no Linux container), documented separately, not part of this Linux smoke.

## Notes

- SDK dialing is controller-mediated (dial by service name), so no OS DNS / resolv.conf wiring is needed (unlike
  the tproxy tunneler demo).
- In the build sandbox, host bind mounts and `docker exec`/`run` stdout are mangled/swallowed, so this smoke used
  create + `docker cp` identity + start, judged by exit code, and read logs via `docker logs`. In a normal
  Docker Desktop / WSL shell, `compose/interop.yml` (bind mounts) + `scripts/interop-matrix.sh` render the grid
  directly.
