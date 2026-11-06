#Requires -Version 5.1
[CmdletBinding()]
param([string]$ComputerTailscaleIP)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$report = [ordered]@{CheckedAt=(Get-Date).ToString('o');BootTime=(Get-CimInstance Win32_OperatingSystem).LastBootUpTime.ToString('o');ReadOnly=$true;Services=@();Tailscale=$null;Sunshine=$null;Firewall=@();Errors=@()}
try {
    $report.Services = @(Get-CimInstance Win32_Service -Filter "Name='Tailscale' OR Name='SunshineService' OR Name='clash_verge_service'" | Select-Object Name,State,StartMode,StartName)
    $cli = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
    $raw = & $cli status --json
    if ($LASTEXITCODE -ne 0) { throw 'tailscale status failed.' }
    $ts = $raw | ConvertFrom-Json
    $rawPreferences = & $cli debug prefs
    if ($LASTEXITCODE -ne 0) { throw 'tailscale preferences could not be read.' }
    $prefs = $rawPreferences | ConvertFrom-Json
    $expiryProperty = $ts.Self.PSObject.Properties['KeyExpiry']
    $expiry = if ($null -ne $expiryProperty) { $expiryProperty.Value } else { $null }
    $report.Tailscale = [ordered]@{BackendState=$ts.BackendState;Online=$ts.Self.Online;IPs=@($ts.TailscaleIPs);Unattended=$prefs.ForceDaemon;ShieldsUp=$prefs.ShieldsUp;KeyExpiry=$expiry;Health=@($ts.Health)}
    if (-not $ComputerTailscaleIP) { $ComputerTailscaleIP = Get-TailscaleIPv4 }
    if (-not (Test-TailscaleIPv4 $ComputerTailscaleIP)) { throw 'Invalid Tailscale IPv4.' }
    $localMatches = @(Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -eq $ComputerTailscaleIP)
    if ($localMatches.Count -eq 0) { throw 'Diagnostics only contact an IP assigned to this PC.' }
    $ports = @(Get-NetTCPConnection -State Listen | Where-Object { $_.LocalAddress -eq $ComputerTailscaleIP -and $_.LocalPort -in @(47984,47989,47990,48010) } | Select-Object LocalAddress,LocalPort)
    Add-Type -AssemblyName System.Net.Http
    $handler = [Net.Http.HttpClientHandler]::new()
    $handler.UseProxy = $false
    $client = [Net.Http.HttpClient]::new($handler)
    try {
        $client.Timeout = [timespan]::FromSeconds(5)
        $response = $client.GetAsync("http://${ComputerTailscaleIP}:47989/serverinfo").GetAwaiter().GetResult()
        [xml]$xml = $response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
        $serverStatus = [string]$xml.root.status_code
        $response.Dispose()
        $report.Sunshine = [ordered]@{IP=$ComputerTailscaleIP;TCPListeners=$ports;ServerInfoStatus=$serverStatus;Recovery=((& (Join-Path $env:SystemRoot 'System32\sc.exe') qfailure SunshineService) -join "`n")}
    } finally { $client.Dispose() }
    $report.Firewall = @(Get-NetFirewallProfile | Select-Object Name,Enabled)
} catch { $report.Errors += $_.Exception.Message }
$report | ConvertTo-Json -Depth 8
