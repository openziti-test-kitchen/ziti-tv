# Captions

YouTube transcribes every Ziti TV stream on its own. The captions are useful after the show: to fix the walkthrough
from what was actually said, to quote the episode in the YouTube description and the socials, and to feed an assistant
the episode without making it watch an hour of video.

[get-captions.ps1](get-captions.ps1) downloads them, filed by air date the same way the episodes are:

```powershell
# one episode
pwsh production/get-captions.ps1 https://www.youtube.com/watch?v=VMg5y1V1eDs
# every stream the channel has done; rerun later to fetch only what is new
pwsh production/get-captions.ps1 https://www.youtube.com/@openziti/streams -OutDir D:\tmp\ziti-tv-captions
```

```text
captions/
  2026/
    05-22/zsG5_ZxuJdg.en.srt
    10-23/VMg5y1V1eDs.en.srt
```

The [captions workflow](../.github/workflows/captions.yml) runs the same script from the Actions tab and attaches the
`captions/` folder to the run as an artifact.

## What YouTube gives you

- **Auto-captions.** YouTube runs speech recognition on every English video. For a stream they appear on the archived
  video some hours after it ends, not at the end of the stream. Until then the script lists the video under "no
  captions". Rerun it later.
- **Accuracy.** Good on plain speech, bad on product names: "OpenZiti" comes out as "open zitty" and similar. Fix
  names before quoting a transcript anywhere.
- **Where to see them.** Viewers: the video description, then **Show transcript**. Studio is also where corrected
  captions get published back.

## Download from YouTube Studio

The channel owner can download them by hand with no tools, no API and no quota. This is the path that worked for the
Oct 23 episode:

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

## Why yt-dlp in a container

There are three ways to get the files, and only one works without setup:

| Way | Verdict |
| --- | --- |
| `curl` the `timedtext` URL from the watch page | Dead. The URL needs a proof-of-origin token now, and without one YouTube returns an empty body. |
| YouTube Data API, `captions.download` | Works for the channel owner only, needs an OAuth token with the `youtube.force-ssl` scope, and costs 200 of the project's 10,000 daily quota units per file. |
| yt-dlp | Works for any public video, with no account and no quota. |

The Data API's easy path is a trap. The token from the
[OAuth 2.0 Playground](https://developers.google.com/oauthplayground) works, but the Playground's built-in OAuth
client is shared by everyone who uses it, so its YouTube quota is usually spent: `403 quotaExceeded` on the first
call. Using the API means creating a Google Cloud project with its own OAuth client. A Google Workspace account adds
no quota. It only lets the OAuth consent screen be **Internal**, which skips Google's app review.

yt-dlp needs a JavaScript runtime (deno) to solve YouTube's player challenges, so a plain install is not enough. The
`jauderho/yt-dlp` image has deno in it and tracks yt-dlp releases. There is no official image. The script runs it
with `wslc` when it exists, then `docker`, then a local `yt-dlp`. `wslc run` takes the same flags as `docker run`,
including Windows paths in `-v`.

## How the script files them

- **Air date, not upload date.** For a scheduled stream, `upload_date` can be the day the event was created, days
  before the show. The script uses `release_date`, the day it went live, and falls back to `upload_date`. Both are
  UTC, which is the same day for an 11 AM ET show.
- **Video ID as the name.** Titles change and contain characters Windows will not take in a file name. The ID does
  not change. `yt-dlp --flat-playlist --print "%(id)s %(title)s" <url>` maps IDs to titles.
- **Manual captions win.** When someone has uploaded corrected captions, those come down instead of the automatic
  ones.
- **Reruns are cheap.** A video with a caption file already in the output folder is skipped without a request.

## In Actions

GitHub's runners are datacenter IPs, and YouTube sometimes answers them with "Sign in to confirm you're not a bot".
When that happens, export a Netscape-format `cookies.txt` from a browser signed in to a throwaway Google account and
store its contents as the repository secret `YT_COOKIES`. The script uses `$env:YT_COOKIES` when it is set. Do not
use the account that owns the channel: YouTube can flag accounts whose cookies are used from many IPs.

The workflow appears in the Actions tab only after `captions.yml` is on `main`.
