# Renders a markdown file to a dark, standalone HTML page with a copy button on every code block, and opens it.
# Use it for the host script and the socials: read on one screen, copy commands and posts with one click.
#   pwsh production/render-html.ps1 live-stream/2026/10-23/script-join-with-a-url.md
# The HTML goes to $env:TEMP\ziti-tv\<name>.html, outside the repo. Rerun after every edit to the markdown.
param(
  [Parameter(Mandatory)][string]$Md,
  [string]$Out = (Join-Path ([IO.Path]::GetTempPath()) "ziti-tv\$([IO.Path]::GetFileNameWithoutExtension($Md)).html"),
  [switch]$NoOpen
)
$body = (ConvertFrom-Markdown -Path $Md).Html
$title = [IO.Path]::GetFileNameWithoutExtension($Md)
$html = @"
<!doctype html><html><head><meta charset="utf-8"><title>$title</title>
<style>
body{background:#0d1117;color:#e6edf3;font:17px/1.55 -apple-system,Segoe UI,sans-serif;max-width:1000px;margin:2em auto;
  padding:0 1em}
h1{color:#ffd54a}h2{color:#7ee787;border-top:1px solid #30363d;padding-top:1em;margin-top:2em}h3{color:#79c0ff}
a{color:#58a6ff}code{background:#161b22;padding:.1em .35em;border-radius:4px;font-size:.92em}
pre{position:relative;background:#161b22;border:1px solid #30363d;border-radius:8px;padding:1em;overflow-x:auto;
  white-space:pre-wrap}
pre code{background:none;padding:0;font-size:15px}
button.copy{position:absolute;top:.5em;right:.5em;background:#238636;color:#fff;border:0;border-radius:6px;
  padding:.3em .8em;cursor:pointer;font-size:13px}
button.copy.done{background:#8957e5}
table{border-collapse:collapse}td,th{border:1px solid #30363d;padding:.35em .7em}
strong{color:#ffa657}blockquote{border-left:4px solid #30363d;margin:0;padding-left:1em;color:#9da7b3}
</style></head><body>
$body
<script>
document.querySelectorAll('pre').forEach(p=>{const b=document.createElement('button');b.className='copy';
b.textContent='copy';b.onclick=()=>{navigator.clipboard.writeText(p.querySelector('code').innerText.replace(/\n$/,''));
b.textContent='copied';b.classList.add('done');setTimeout(()=>{b.textContent='copy';b.classList.remove('done')},1200)};
p.appendChild(b)});
</script></body></html>
"@
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
Set-Content -Path $Out -Value $html -Encoding utf8
$Out
if (-not $NoOpen) { Start-Process $Out }
