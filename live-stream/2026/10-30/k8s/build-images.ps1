<#
.SYNOPSIS
  Builds the zab and demo-http-server images with ko (no Docker daemon needed) and imports them
  into the k3s node's containerd.

.EXAMPLE
  ./build-images.ps1 -Repo D:\git\github\openziti-test-kitchen\ziti-access-bridge -SshHost clintfips
#>
param(
    [Parameter(Mandatory)] [string] $Repo,
    [string] $SshHost = 'clintfips',
    [string] $Tag = 'dev',
    [string] $Base = 'gcr.io/distroless/static-debian12:nonroot',
    [string[]] $Packages = @('./cmd/zab', './demo/cmd/demo-http-server'),
    [string] $OutDir = (Join-Path $PSScriptRoot 'out')
)
$ErrorActionPreference = 'Stop'

if (-not (Get-Command ko -ErrorAction SilentlyContinue)) {
    throw 'ko not found. go install github.com/google/ko@latest'
}
New-Item -ItemType Directory -Force $OutDir | Out-Null
$tarball = Join-Path $OutDir 'zab-images.tar'

# An empty docker config keeps ko away from a credsStore helper that may not exist.
$env:DOCKER_CONFIG = Join-Path $OutDir 'dockercfg'
New-Item -ItemType Directory -Force $env:DOCKER_CONFIG | Out-Null
# Any name but ko.local: ko.local means "load into a Docker daemon".
$env:KO_DOCKER_REPO = 'zab.local'
$env:KO_DEFAULTBASEIMAGE = $Base
$env:CGO_ENABLED = '0'

Push-Location $Repo
try {
    ko build --push=false --base-import-paths --platform linux/amd64 --tags $Tag `
        --tarball $tarball @Packages
    if ($LASTEXITCODE) { throw "ko build failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}

scp $tarball "${SshHost}:/tmp/zab-images.tar"
if ($LASTEXITCODE) { throw 'scp failed' }
ssh $SshHost 'sudo k3s ctr -n k8s.io images import /tmp/zab-images.tar && sudo k3s ctr -n k8s.io images ls -q | grep zab.local'
if ($LASTEXITCODE) { throw 'image import failed' }
