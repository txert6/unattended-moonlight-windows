#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$root = Split-Path -Parent $PSScriptRoot
$files = @()
foreach ($directory in @('config','scripts','src','docs')) {
    $files += @(Get-ChildItem -LiteralPath (Join-Path $root $directory) -Recurse -File)
}
foreach ($name in @('README.md','NOTICE.md','.gitignore')) { $files += Get-Item -LiteralPath (Join-Path $root $name) }
$failures = [Collections.Generic.List[string]]::new()
$sourceFiles = @($files | Where-Object Extension -in @('.ps1','.cs','.md','.json','.txt','.example','.manifest'))
foreach ($file in $files) {
    if ($file.Extension -in @('.dpapi','.pem','.key','.pfx','.p12','.msi','.apk','.log') -or
        $file.Name -in @('sunshine_state.json','credentials.txt','credentials.json','verge.yaml','profiles.yaml','.env')) {
        $failures.Add("Forbidden public-package file: $($file.Name)")
    }
}
foreach ($file in $sourceFiles) {
    $text = [IO.File]::ReadAllText($file.FullName)
    foreach ($pattern in @(
        '-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----',
        'gh[pousr]_[A-Za-z0-9]{30,}',
        'github_pat_[A-Za-z0-9_]{30,}',
        'tskey-(?:auth|api)-[A-Za-z0-9-]{16,}',
        '(?:ss|vmess|vless|trojan)://[A-Za-z0-9]'
    )) {
        if ($text -match $pattern) { $failures.Add("Potential secret/subscription in $($file.Name)") }
    }
    if ($file.Extension -eq '.ps1') {
        $tokens = $null; $errors = $null
        [Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors) | Out-Null
        if (@($errors).Count -ne 0) { $failures.Add("PowerShell parse error in $($file.Name)") }
    }
    if ($file.Extension -eq '.json') { try { $null = $text | ConvertFrom-Json } catch { $failures.Add("JSON parse error in $($file.Name)") } }
}
$manifest = Get-Content -LiteralPath (Join-Path $root 'config\dependencies.lock.json') -Raw | ConvertFrom-Json
foreach ($entry in $manifest.files) {
    if ($entry.sha256 -notmatch '^[A-Fa-f0-9]{64}$' -or -not $entry.url.StartsWith('https://')) {
        $failures.Add("Invalid locked dependency: $($entry.id)")
    }
}
$original = "# keep this comment`r`nunknown_option = keep-me`r`nencoder = old`r`nencoder = duplicate`r`n"
$settings = [ordered]@{encoder='nvenc';upnp='disabled'}
$merged = Merge-SunshineConfig -Original $original -Settings $settings
if ($merged -notmatch 'unknown_option = keep-me' -or $merged -notmatch '# keep this comment' -or
    @([regex]::Matches($merged, '(?m)^encoder\s*=')).Count -ne 1 -or
    $merged -ne (Merge-SunshineConfig -Original $merged -Settings $settings)) {
    $failures.Add('Configuration merge did not preserve unknown fields or was not idempotent.')
}
foreach ($invalid in @('127.0.0.1','192.0.2.1','100.63.255.255','100.128.0.1','example.com','100.64.0.1/10')) {
    if (Test-TailscaleIPv4 $invalid) { $failures.Add('Address validator accepted a non-Tailscale host input.') }
}
foreach ($valid in @('100.64.0.1','100.127.255.254')) {
    if (-not (Test-TailscaleIPv4 $valid)) { $failures.Add('Address validator rejected a valid Tailscale IPv4.') }
}
if ($failures.Count -gt 0) { throw ($failures -join "`n") }
[pscustomobject]@{Passed=$true;PublicFiles=$files.Count;PowerShellFiles=@($files | Where-Object Extension -eq '.ps1').Count;DependencyEntries=$manifest.files.Count;ConfigPreservationAndIdempotence=$true;InputBoundaries=$true;SecretPatternScan=$true}
