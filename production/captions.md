# Captions

YouTube transcribes every Ziti TV stream. Use the captions to fix the walkthrough and to quote the episode in the
description and the socials. They also let an assistant read the show without watching an hour of video.

## What YouTube gives you

- **Auto-captions.** YouTube runs speech recognition on every English video. For a stream they appear on the archived
  video some hours after it ends. Until then Studio shows no **Automatic subtitles** row.
- **Accuracy.** Good on plain speech, bad on product names: "OpenZiti" comes out as "open zitty" and similar. Fix
  names before quoting a transcript anywhere.
- **Where to see them.** Viewers: the video description, then **Show transcript**. Studio is also where corrected
  captions get published back.

## Download from YouTube Studio

Download the captions by hand from Studio, signed in as the channel owner:

1. Open `https://studio.youtube.com/video/<video id>/translations`. The video ID is the part after `/live/` or `v=` in
   the episode's URL, for example `VMg5y1V1eDs`.
2. Click the pencil next to **Video language**.
3. On the **Automatic subtitles** row, click the three dots, then **Download**.
4. Pick **.srt**. `.vtt` holds nothing more for an auto-caption track, and `.sbv` is YouTube's own format.
5. Save it as `live-stream/<year>/<mm-dd>/captions.srt` in the episode directory.

## Fixing the names

Speech recognition hears the show's vocabulary wrong the same way every week. Fix it into `captions.fixed.srt` next
to the original, changing text only: same cue numbers, same timings. Check with
`diff <(grep -- '-->' captions.srt) <(grep -- '-->' captions.fixed.srt)`, which prints nothing when the timings match.

| Heard | Meant |
| --- | --- |
| ZDTV, ZDV, ZDTB, CDTV | Ziti TV |
| ZD, Open ZD, open Ziti | ziti (the CLI), OpenZiti |
| ZD edge tunnel, Zdge tunnel, ZDH tunnel | `ziti-edge-tunnel` |
| ZD desktop edge | Ziti Desktop Edge |
| zdu | ZDEW |
| Zach, Zack | ZAC (the admin console) |
| IDP, IDPR | IdP, IdP root |
| external JT, JT serer, assigner | external JWT, `ext-jwt-signer`, a signer |
| O policy, off policy | auth policy |
| geeklo, keycloak | Keycloak |
| less encrypted | Let's Encrypt |
| cdawws, CD AWS | cdaws (the demo box) |
| the bender, demo dur | the bin dir, `$DEMO_DIR` |
| No hub, make dur, bash RC | `nohup`, `mkdir`, `.bashrc` |
| Clawed, Lad | Claude |

Words split across two cues, URLs, and hostnames need a cue-by-cue fix. Find them by searching the text for `.z`
and `dollar`.

To publish the fixed file, upload `captions.fixed.srt` on the same Studio page as a new English subtitle track.

## Other ways

The `timedtext` URL from the watch page returns an empty body without a proof-of-origin token. The YouTube Data API
needs a Google Cloud project with its own OAuth client, and each download costs 200 of its 10,000 daily quota units.
The OAuth Playground's shared client fails with `403 quotaExceeded`.
