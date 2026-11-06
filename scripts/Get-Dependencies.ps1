#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('windows','android','all')][string]$Platform = 'windows',
    [string]$DestinationDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'downloads'),
    [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $root 'config\dependencies.lock.json') -Raw | ConvertFrom-Json
$files = @($manifest.files | Where-Object { $Platform -eq 'all' -or $_.platform -eq $Platform })
if (-not $VerifyOnly) { New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
foreach ($file in $files) {
    if ($file.sha256 -notmatch '^[0-9A-Fa-f]{64}$') { throw "Missing locked SHA-256 for $($file.id)." }
    $path = Join-Path $DestinationDirectory $file.fileName
    if (-not (Test-Path -LiteralPath $path)) {
        if ($VerifyOnly) { throw "Missing dependency: $($file.fileName)" }
        if (-not $file.url.StartsWith('https://')) { throw 'Dependency URLs must use HTTPS.' }
        Invoke-WebRequest -Uri $file.url -OutFile $path -UseBasicParsing
    }
    if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.sha256) {
        throw "Checksum mismatch: $($file.fileName). File was not executed. Remove the failed download and retry from the official URL."
    }
    $signatureStatus = 'Not applicable to APK'
    if ($file.authenticodeRequired) {
        $signature = Get-AuthenticodeSignature -LiteralPath $path
        $signatureStatus = [string]$signature.Status
        if ($signature.Status -ne 'Valid') { throw "Invalid Authenticode signature: $($file.fileName)" }
    }
    [pscustomobject]@{Id=$file.id;Version=$file.version;File=$path;SHA256=$file.sha256;Signature=$signatureStatus}
}
