<#
.SYNOPSIS
    kat installer for Windows.

.DESCRIPTION
    Downloads a released kat build from GitHub, verifies its SHA256 checksum,
    installs it, and adds the install directory to the user PATH.

.EXAMPLE
    irm https://raw.githubusercontent.com/shellhaki/kat/main/install.ps1 | iex

.EXAMPLE
    .\install.ps1 -Version v1.2.3 -InstallDir C:\tools\kat
#>

[CmdletBinding()]
param(
    [string]$Version    = $env:KAT_VERSION,
    [string]$InstallDir = $env:KAT_INSTALL_DIR
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Repo   = 'shellhaki/kat'
$Binary = 'kat'

function Write-Info { param($Message) Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Warn { param($Message) Write-Host "warn: $Message" -ForegroundColor Yellow }

function Get-Platform {
    $arch = switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { 'amd64' }
        'ARM64' { 'arm64' }
        'x86'   { throw '32-bit Windows is not supported' }
        default { throw "unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)" }
    }
    return "windows_$arch"
}

function Get-LatestVersion {
    Write-Info 'resolving latest release'
    $headers = @{ 'User-Agent' = 'kat-installer' }
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -Headers $headers
    if (-not $release.tag_name) { throw "could not resolve the latest release of $Repo" }
    return $release.tag_name
}

function Test-Checksum {
    param([string]$ArchivePath, [string]$ChecksumsPath)

    $name = Split-Path $ArchivePath -Leaf
    $line = Select-String -Path $ChecksumsPath -Pattern "\s$([regex]::Escape($name))$" | Select-Object -First 1
    if (-not $line) {
        Write-Warn "no checksum entry for $name, skipping verification"
        return
    }

    $expected = ($line.Line -split '\s+')[0]
    $actual   = (Get-FileHash -Path $ArchivePath -Algorithm SHA256).Hash

    if ($expected -ne $actual) {
        throw "checksum mismatch for $name (expected $expected, got $actual)"
    }
    Write-Info 'checksum verified'
}

function Add-ToUserPath {
    param([string]$Directory)

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $entries  = @()
    if ($userPath) { $entries = $userPath -split ';' | Where-Object { $_ } }

    if ($entries -contains $Directory) { return }

    $updated = (@($entries) + $Directory) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $updated, 'User')
    $env:Path = "$env:Path;$Directory"

    Write-Info "added $Directory to your user PATH (restart your terminal to pick it up)"
}

# --- main ---------------------------------------------------------------

$platform = Get-Platform

if (-not $Version) { $Version = Get-LatestVersion }
if ($Version -notmatch '^v') { $Version = "v$Version" }

if (-not $InstallDir) { $InstallDir = Join-Path $env:LOCALAPPDATA "Programs\$Binary" }

$archive = "${Binary}_${Version}_${platform}.zip"
$baseUrl = "https://github.com/$Repo/releases/download/$Version"
$tmp     = Join-Path ([System.IO.Path]::GetTempPath()) ("kat-install-" + [Guid]::NewGuid().ToString('N'))

New-Item -ItemType Directory -Path $tmp -Force | Out-Null

try {
    $archivePath = Join-Path $tmp $archive

    Write-Info "downloading $Binary $Version ($platform)"
    try {
        Invoke-WebRequest -Uri "$baseUrl/$archive" -OutFile $archivePath -UseBasicParsing
    } catch {
        throw "download failed: $baseUrl/$archive"
    }

    $checksumsPath = Join-Path $tmp 'checksums.txt'
    try {
        Invoke-WebRequest -Uri "$baseUrl/checksums.txt" -OutFile $checksumsPath -UseBasicParsing
        Test-Checksum -ArchivePath $archivePath -ChecksumsPath $checksumsPath
    } catch [System.Net.WebException] {
        Write-Warn 'checksums.txt unavailable, skipping verification'
    }

    $extractDir = Join-Path $tmp 'extracted'
    Expand-Archive -Path $archivePath -DestinationPath $extractDir -Force

    $exe = Join-Path $extractDir "$Binary.exe"
    if (-not (Test-Path $exe)) { throw "archive did not contain $Binary.exe" }

    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
    Copy-Item -Path $exe -Destination (Join-Path $InstallDir "$Binary.exe") -Force

    Write-Info "installed $Binary $Version to $(Join-Path $InstallDir "$Binary.exe")"
    Add-ToUserPath -Directory $InstallDir
}
finally {
    Remove-Item -Path $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
