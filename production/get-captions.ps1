# Downloads YouTube's captions for one video, a playlist, or a channel tab, filed by air date as <year>/<mm-dd>/.
#   pwsh production/get-captions.ps1 https://www.youtube.com/watch?v=zsG5_ZxuJdg
#   pwsh production/get-captions.ps1 https://www.youtube.com/@openziti/streams -OutDir D:\tmp\ziti-tv-captions
# Runs yt-dlp from the jauderho/yt-dlp image under wslc or docker, or a local yt-dlp if neither exists.
# Videos that already have a caption file in -OutDir are skipped, so a rerun only fetches what is missing.
# See captions.md for why it works this way.
param(
  [Parameter(Mandatory)][string]$Url,
  [string]$OutDir = 'captions',
  [ValidateSet('auto', 'wslc', 'docker', 'native')][string]$Runtime = 'auto',
  [string]$Image = 'jauderho/yt-dlp:latest',
  [string]$Langs = 'en',
  # Netscape-format cookies.txt, only needed where YouTube answers "Sign in to confirm you're not a bot".
  # $env:YT_COOKIES (the file's contents, e.g. from a CI secret) is used when this is not given.
  [string]$CookiesFile,
  [int]$SleepSeconds = 3
)
$ErrorActionPreference = 'Stop'

if (-not $CookiesFile -and $env:YT_COOKIES) {
  $CookiesFile = Join-Path ([IO.Path]::GetTempPath()) "yt-cookies-$PID.txt"
  Set-Content -Path $CookiesFile -Value $env:YT_COOKIES
}

if ($Runtime -eq 'auto') {
  $Runtime = foreach ($r in 'wslc', 'docker', 'yt-dlp') { if (Get-Command $r -ErrorAction SilentlyContinue) { $r; break } }
  if (-not $Runtime) { throw 'none of wslc, docker or yt-dlp is on PATH' }
  if ($Runtime -eq 'yt-dlp') { $Runtime = 'native' }
}
New-Item -ItemType Directory -Force $OutDir | Out-Null
$out = (Resolve-Path $OutDir).Path

function Invoke-YtDlp([string[]]$YtArgs) {
  if ($Runtime -eq 'native') {
    Push-Location $out
    try { yt-dlp @YtArgs } finally { Pop-Location }
    return
  }
  $mounts = @('-v', "${out}:/downloads", '-w', '/downloads')
  if ($CookiesFile) {
    $mounts += '-v', "$((Resolve-Path $CookiesFile).Path):/cookies.txt:ro"
    $YtArgs = @('--cookies', '/cookies.txt') + $YtArgs
  }
  & $Runtime run --rm @mounts $Image @YtArgs
}
$cookieArgs = if ($Runtime -eq 'native' -and $CookiesFile) { @('--cookies', (Resolve-Path $CookiesFile).Path) } else { @() }

# A live stream's upload_date can be the day the event was scheduled, so release_date (the air date) wins.
$year = '%(release_date>%Y,upload_date>%Y)s'
$day = '%(release_date>%m-%d,upload_date>%m-%d)s'

Write-Host "listing $Url ($Runtime)"
$ids = @(Invoke-YtDlp (@('--flat-playlist', '--print', 'id') + $cookieArgs + $Url) | Where-Object { $_ -match '^[\w-]{11}$' })
Write-Host "$($ids.Count) video(s)"

$got = @(); $skipped = @(); $missing = @()
foreach ($id in $ids) {
  if (Get-ChildItem $out -Recurse -File -Filter "$id.*" -ErrorAction SilentlyContinue) { $skipped += $id; continue }
  Invoke-YtDlp (@('--skip-download', '--write-subs', '--write-auto-subs', '--sub-langs', $Langs,
      '--sub-format', 'srt/vtt/best', '--no-progress', '-o', "$year/$day/%(id)s.%(ext)s") + $cookieArgs +
    "https://www.youtube.com/watch?v=$id")
  $file = Get-ChildItem $out -Recurse -File -Filter "$id.*" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($file) { $got += $file.FullName.Substring($out.Length + 1) } else { $missing += $id }
  Start-Sleep -Seconds $SleepSeconds
}

Write-Host "`ndownloaded $($got.Count), already present $($skipped.Count), no captions $($missing.Count)"
$got | ForEach-Object { Write-Host "  + $_" }
$missing | ForEach-Object { Write-Host "  - https://www.youtube.com/watch?v=$_" }
