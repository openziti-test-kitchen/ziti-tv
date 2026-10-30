# Captions

YouTube transcribes every Ziti TV stream on its own. The captions are useful after the show: to fix the walkthrough
from what was actually said, to quote the episode in the YouTube description and the socials, and to feed an assistant
the episode without making it watch an hour of video.

## What YouTube gives you

- **Auto-captions.** YouTube runs speech recognition on every English video. For a stream they appear on the archived
  video some hours after it ends, not at the end of the stream. Until then Studio shows no **Automatic subtitles**
  row. Come back later.
- **Accuracy.** Good on plain speech, bad on product names: "OpenZiti" comes out as "open zitty" and similar. Fix
  names before quoting a transcript anywhere.
- **Where to see them.** Viewers: the video description, then **Show transcript**. Studio is also where corrected
  captions get published back.

## Download from YouTube Studio

Captions come down by hand from Studio, signed in as the channel owner. No tools, no API and no quota:

1. Open `https://studio.youtube.com/video/<video id>/translations`. The video ID is the part after `/live/` or `v=` in
   the episode's URL, for example `VMg5y1V1eDs`.
2. Click the pencil next to **Video language**. A dialog opens.
3. On the **Automatic subtitles** row, click the three dots, then **Download**.
4. Pick **.srt**. Every player and editor reads it. `.vtt` holds nothing more for an auto-caption track, and `.sbv` is
   YouTube's own format.
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

## Why not automate it

| Way | Verdict |
| --- | --- |
| `curl` the `timedtext` URL from the watch page | Dead. The URL needs a proof-of-origin token now, and without one YouTube returns an empty body. |
| YouTube Data API, `captions.download` | Works for the channel owner only, needs an OAuth token with the `youtube.force-ssl` scope, and costs 200 of the project's 10,000 daily quota units per file. |
| Scrapers such as yt-dlp | Not used. They work around YouTube's player checks rather than through a supported interface. |

The Data API's easy path is a trap. The token from the
[OAuth 2.0 Playground](https://developers.google.com/oauthplayground) works, but the Playground's built-in OAuth
client is shared by everyone who uses it, so its YouTube quota is usually spent: `403 quotaExceeded` on the first
call. Using the API means creating a Google Cloud project with its own OAuth client. One episode a week does not
justify that, so the Studio download is the process.
