# The walkthrough README

The markdown in `live-stream/<year>/<mm-dd>/README.md` and each `learn-openziti/partN-<topic>/README.md` is a
**public, reader-facing walkthrough**. Viewers work through it on their own machines after the show. It is not a
run-of-show for the host; that is the [host script](host-script.md).

## What never goes in it

- `On screen:`, `Beats:`, `Ready:`, B-roll lists, "say this while fixing it"
- minute timestamps or time estimates of any kind
- pacing or camera notes
- passwords, populated `.env` files, `.jwt` files, identity `.json` files

## The structure that works

1. **A short opening:** what the reader ends up with, what it assumes they already know, what they need (machines,
   versions), and which shells the commands run in.
2. **Numbered sections whose headers state the why, not the action.** "Users type a URL, so the operating system has
   to trust it", not "Get a certificate". Each section gets a fenced command block and only the explanation that is
   not obvious from the commands.
3. **The bringup is part of it.** Episodes are recorded building from an empty directory, so `git clone`, downloads
   and `docker compose up` are steps, not prerequisites to skip.
4. **A reset section:** one `reset.sh` that puts the demo back so the reader can run it again, and a full teardown.
5. **`## Troubleshooting` at the end:** symptom in bold, then cause, then fix. One entry per failure mode actually hit
   while building the episode. Where one client error has several causes, name all of them.

## Shell tags

Tag every command block with the shell it runs in: **[ubuntu]**, **[pwsh]**, **[macos]**, **[brave]**. Say once,
near the top, which tags the episode uses and that on one Linux machine it is all one shell. Inside a block, use
`# comment` lines to explain individual commands instead of breaking the block apart with prose.

## Scripts and configuration

- Every value that depends on the reader's machine goes in `default.env`, which is checked in. The reader copies it
  to `.env`, which is gitignored, and every script sources `.env`. Names that belong to the demo itself (realm,
  users, service names) can stay in the scripts.
- Pin versions in `default.env`: OpenZiti, tunnelers, the IdP, anything downloaded.
- Scripts are safe to rerun. Patch from a saved original instead of patching twice; `|| true` on deletes.
- Scripts run as `bash x.sh`, so they need no exec bit.

## Claims

Every sentence that says something works has been seen working, on the versions the README pins. A claim that only
comes from reading code or docs gets tested before the episode ships (see
[demo-infra.md](demo-infra.md#proving-claims-before-the-show)).

## Prose

No filler. Cut hedges, throat-clearing and editorializing adjectives. Every sentence carries information the reader
did not have. Wrap markdown at 120 characters.
