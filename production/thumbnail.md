# Thumbnail

Every Ziti TV thumbnail follows one house style, and the series is the brand. Codex's image generation reproduces it
well when it gets the recent thumbnails as references and an exact text spec. The Oct 23, 2026 thumbnail was made this
way in three passes: a first draft, then two targeted edits.

## The house style

- 1280 x 720.
- A dark background with a vintage blue-grey CRT television on the left, its `NETFOUNDRY` panel and dial on the right
  side of the set.
- The small **ZITI TV / OPENZITI TELEVISION** logo inside the screen, top right, fully inside the bezel.
- Ziggy, the yellow cylinder mascot with big round eyes, inside the screen, acting out the topic.
- A loud, stylized title stacked on the right. Series episodes reuse the series wordmark, such as **OPENZITI
  APPETIZER**.
- The date in big yellow sans-serif, bottom left: `October 23, 2026`.

References live in the `openziti/branding` repo under `ziti-tv/`: the last few `<mon>-<dd>-<year>.jpg` files and
`thumbs/` for older ones.

## 1. Stage the references

Codex reads images from its working directory, so copy the references into a new, empty one:

```powershell
$work = "D:\tmp\ziti-tv-thumb\$(Get-Date -Format yyyy-MM-dd)"
New-Item -ItemType Directory -Force "$work\refs" | Out-Null
$brand = 'D:\git\github\openziti\branding\ziti-tv'
Get-ChildItem $brand -File | Where-Object Extension -in '.jpg', '.webp', '.png' |
  Sort-Object LastWriteTime | Select-Object -Last 4 | Copy-Item -Destination "$work\refs"
Get-ChildItem "$brand\thumbs" | Sort-Object Name | Select-Object -Last 6 | Copy-Item -Destination "$work\refs"
```

## 2. Write the prompt

Save as `$work\prompt.txt` and fill in the four `<...>` values. Keep the title short: if it cannot be read at 320
pixels wide, it is too long.

```text
You are making one image with your image generation tool. Save the final image as a PNG in the current directory as
ziti-tv-<yyyy-mm-dd>.png. If the tool saves elsewhere, copy the file here. Do not edit anything in refs\.

Reference images are in refs\. The four newest are the most recent Ziti TV episode thumbnails and set the house
style: a dark background, a vintage blue-grey CRT television on the left with a "NETFOUNDRY" panel and a dial on its
right side, a small "ZITI TV / OPENZITI TELEVISION" logo inside the screen fully inside the bezel, the yellow
cylinder mascot ("Ziggy", big round eyes, wide smile) inside the screen acting out the topic, a bold stylized title
stacked on the right, and the date in large yellow sans-serif at the bottom left. The rest are older thumbnails, for
extra style context only.

1280x720, the thumbnail for this episode:
- Episode: "<one sentence on what the episode does>"
- Follow the house style exactly: same TV, same layout, same logo placement, same date treatment.
- Date text, exact: "<Month D, YYYY>"
- Title on the right, exact words, stacked and stylized like the references: "<title>"
  with a smaller line above it: "<kicker>"
- Inside the TV screen: <what Ziggy is doing>
- Fun, cartoony, high contrast, readable at small thumbnail size. Spell all text exactly as given.

If text comes out misspelled, regenerate until it is correct (up to 3 tries, keep the best). At the end, list the
files you saved and their dimensions.
```

## 3. Run codex

From PowerShell. Pipe the prompt in on stdin: `codex.cmd` truncates arguments that contain newlines. The work
directory is not a git repository, so `--skip-git-repo-check` is required.

```powershell
Set-Location $work
Get-Content prompt.txt -Raw | & "$env:APPDATA\npm\codex.cmd" exec --skip-git-repo-check --sandbox workspace-write `
  -C $work -o out.md - *> run.log
Get-Content out.md
```

## 4. Check it, then fix one thing at a time

Codex says it checked the spelling. Check it yourself anyway. On Oct 23 the first edit introduced
`OPENZITI TELLEVISION` while it said all text was correct. Zoom into the small logo text:

```powershell
Add-Type -AssemblyName System.Drawing
$img = [System.Drawing.Image]::FromFile("$work\ziti-tv-<yyyy-mm-dd>.png")
$crop = New-Object System.Drawing.Bitmap 600, 160
$g = [System.Drawing.Graphics]::FromImage($crop); $g.InterpolationMode = 'HighQualityBicubic'
# source rectangle: x, y, width, height of the region to inspect
$g.DrawImage($img, (New-Object System.Drawing.Rectangle 0,0,600,160), (New-Object System.Drawing.Rectangle 370,170,150,40), 'Pixel')
$crop.Save("$work\zoom.png"); $g.Dispose(); $crop.Dispose(); $img.Dispose()
```

For a fix, pass the image with `-i` and ask for exactly one or two changes. Save to a new name, `-v2`, `-v3`, and
never overwrite the previous version:

```powershell
@'
Edit the attached image and save the result as ziti-tv-<yyyy-mm-dd>-v2.png in the current directory. Do not overwrite
any existing file. Keep everything else identical, 1280x720.

One change only: <the change>.

Zoom in and check the spelling of every piece of text after editing. List the saved file and its dimensions.
'@ | & "$env:APPDATA\npm\codex.cmd" exec --skip-git-repo-check --sandbox workspace-write `
  -C $work -i "$work\ziti-tv-<yyyy-mm-dd>.png" -o out-v2.md - *> run-v2.log
```

## 5. Ship it

Save as JPEG into the branding repo, next to the others. Use a new file name if one exists already:

```powershell
Add-Type -AssemblyName System.Drawing
$dst = 'D:\git\github\openziti\branding\ziti-tv\<mon>-<dd>-<yyyy>.jpg'
if (Test-Path $dst) { throw "exists: $dst" }
$img = [System.Drawing.Image]::FromFile("$work\ziti-tv-<yyyy-mm-dd>-v3.png")
$img.Save($dst, [System.Drawing.Imaging.ImageFormat]::Jpeg); $img.Dispose()
```

The same file goes on the YouTube event and on every social post.
