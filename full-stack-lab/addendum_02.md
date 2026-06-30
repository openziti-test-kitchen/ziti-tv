# Addendum 02

## Locked (from Q13-Q16)

- Front-door hostname: `learning.openziti.local`.
- Echo app languages: C, C#, Python, Java, Go, JavaScript, Swift.
- Guaranteed redundant paths: none required now. Overrides D3's "2+ paths" requirement and build-order step 5.
- LAN: flat subnet, all machines reach the Docker host's published ports directly.

## D3 adjustment

- Still build the `home -> internet -> vpc1 -> vpc2` path and show its circuit.
- Do not engineer guaranteed redundant legs yet. Mesh stays single-path until requested.
