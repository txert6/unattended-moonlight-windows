#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidatePattern('^v?[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?$')][string]$Version = 'v1.0.0',
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist')
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Split-Path -Parent $PSScriptRoot
$null = & (Join-Path $PSScriptRoot 'Test-Package.ps1')
$build = & (Join-Path $PSScriptRoot 'Build-PairingApp.ps1')
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$stage = Join-Path $tempRoot ('umw-package-' + [guid]::NewGuid().ToString('N'))
$packageName = 'unattended-moonlight-windows-' + $Version
$payload = Join-Path $stage $packageName
New-Item -ItemType Directory -Path $payload -Force | Out-Null
try {
    foreach ($directory in @('config','scripts','src','docs')) {
        Copy-Item -LiteralPath (Join-Path $root $directory) -Destination $payload -Recurse
    }
    foreach ($name in @('README.md','NOTICE.md','.gitignore')) {
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination $payload
    }
    New-Item -ItemType Directory -Path (Join-Path $payload 'bin') | Out-Null
    Copy-Item -LiteralPath $build.File -Destination (Join-Path $payload 'bin\SunshinePairing.exe')
    $fileManifest = foreach ($file in (Get-ChildItem -LiteralPath $payload -Recurse -File | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($payload.Length + 1).Replace('\','/')
        '{0}  {1}' -f (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant(), $relative
    }
    Write-Utf8File -Path (Join-Path $payload 'FILES.sha256') -Text (($fileManifest -join "`n") + "`n")
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    $archivePath = Join-Path $OutputDirectory ($packageName + '.zip')
    if (Test-Path -LiteralPath $archivePath) { throw 'Archive already exists; select a new output directory or version.' }
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [IO.Compression.ZipFile]::CreateFromDirectory($stage, $archivePath, [IO.Compression.CompressionLevel]::Optimal, $false)
    $hash = (Get-FileHash -LiteralPath $archivePath -Algorithm SHA256).Hash.ToLowerInvariant()
    $checksumPath = Join-Path $OutputDirectory ($packageName + '.sha256')
    Write-Utf8File -Path $checksumPath -Text ("$hash  $packageName.zip`n")
    [pscustomobject]@{Version=$Version;Archive=$archivePath;SHA256=$hash;ChecksumFile=$checksumPath;PackagedFiles=@($fileManifest).Count + 1}
} finally {
    $resolvedStage = [IO.Path]::GetFullPath($stage)
    $expectedPrefix = Join-Path $tempRoot 'umw-package-'
    if (-not $resolvedStage.StartsWith($expectedPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw 'Refusing cleanup outside the dedicated temporary package directory.'
    }
    if (Test-Path -LiteralPath $resolvedStage) { Remove-Item -LiteralPath $resolvedStage -Recurse -Force }
}
