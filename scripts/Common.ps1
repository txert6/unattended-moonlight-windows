#Requires -Version 5.1
Set-StrictMode -Version 2.0

function Assert-Administrator {
    $principal = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Open PowerShell as Administrator for this operation.'
    }
}

function Write-Utf8File {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    [IO.File]::WriteAllText($Path, $Text, [Text.UTF8Encoding]::new($false))
}

function Invoke-CheckedNative {
    param([Parameter(Mandatory)][string]$FilePath, [string[]]$Arguments)
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Native command failed: $FilePath (exit $LASTEXITCODE)" }
}

function Test-TailscaleIPv4 {
    param([string]$Address)
    $parsed = $null
    if (-not [Net.IPAddress]::TryParse($Address, [ref]$parsed)) { return $false }
    if ($parsed.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { return $false }
    $bytes = $parsed.GetAddressBytes()
    return $bytes[0] -eq 100 -and $bytes[1] -ge 64 -and $bytes[1] -le 127
}

function Get-TailscaleIPv4 {
    $cli = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    if (-not (Test-Path -LiteralPath $cli)) { throw 'Install and authenticate Tailscale first.' }
    $raw = & $cli status --json
    if ($LASTEXITCODE -ne 0) { throw 'tailscale status failed.' }
    $status = $raw | ConvertFrom-Json
    if ($status.BackendState -ne 'Running') { throw 'Authenticate Tailscale and wait for Running before configuring Sunshine.' }
    $addresses = @($status.TailscaleIPs | Where-Object { Test-TailscaleIPv4 $_ })
    if ($addresses.Count -ne 1) { throw 'Unable to identify exactly one local Tailscale IPv4.' }
    return [string]$addresses[0]
}

function Merge-SunshineConfig {
    param([AllowEmptyString()][string]$Original, [System.Collections.IDictionary]$Settings)
    $remaining = @{}
    foreach ($key in $Settings.Keys) { $remaining[$key] = [string]$Settings[$key] }
    $lines = [Collections.Generic.List[string]]::new()
    foreach ($line in ($Original -split '\r?\n')) {
        if ($line -match '^\s*([A-Za-z0-9_]+)\s*=') {
            $key = $Matches[1]
            if ($Settings.Contains($key)) {
                if ($remaining.ContainsKey($key)) {
                    $lines.Add("$key = $($remaining[$key])")
                    $remaining.Remove($key)
                }
                continue
            }
        }
        $lines.Add($line)
    }
    foreach ($key in $Settings.Keys) {
        if ($remaining.ContainsKey($key)) { $lines.Add("$key = $($remaining[$key])") }
    }
    return (($lines -join "`r`n").TrimEnd() + "`r`n")
}

function Get-LocalStateDirectory {
    $directory = Join-Path $env:LOCALAPPDATA 'UnattendedMoonlightDeploy'
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,
        [Security.Principal.SecurityIdentifier]::new('S-1-5-18'),
        [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544'))) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $directory -AclObject $acl
    return $directory
}
