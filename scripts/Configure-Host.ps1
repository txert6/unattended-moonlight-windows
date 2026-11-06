#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string[]]$TrustedClientIPs,
    [string]$ComputerTailscaleIP,
    [ValidatePattern('^[^\r\n=]{1,64}$')][string]$SunshineName = 'Remote-Streaming-PC',
    [ValidateSet('nvenc','amdvce','quicksync','software')][string]$Encoder = 'nvenc',
    [switch]$DisableSleepOnAC
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
if (-not $ComputerTailscaleIP) { $ComputerTailscaleIP = Get-TailscaleIPv4 }
if (-not (Test-TailscaleIPv4 $ComputerTailscaleIP)) { throw 'Host address must be a Tailscale IPv4 in 100.64.0.0/10.' }
foreach ($address in $TrustedClientIPs) {
    if (-not (Test-TailscaleIPv4 $address) -or $address -eq $ComputerTailscaleIP) {
        throw 'Each trusted client must be a different device Tailscale IPv4.'
    }
}
$localAddress = @(Get-NetIPAddress -AddressFamily IPv4 | Where-Object IPAddress -eq $ComputerTailscaleIP)
if ($localAddress.Count -ne 1) { throw 'The host Tailscale IP is not uniquely assigned to this PC.' }
foreach ($name in @('Tailscale','SunshineService')) { Get-Service -Name $name -ErrorAction Stop | Out-Null }
$installDirectory = Join-Path $env:ProgramFiles 'Sunshine'
$configurationPath = Join-Path $installDirectory 'config\sunshine.conf'
$settings = [ordered]@{
    address_family='ipv4';bind_address=$ComputerTailscaleIP;sunshine_name=$SunshineName;
    encoder=$Encoder;nvenc_preset='1';hevc_mode='0';av1_mode='0';origin_web_ui_allowed='lan';
    upnp='disabled';controller='disabled';gamepad_driver='vigembus';keyboard='enabled';mouse='enabled';
    locale='zh';dd_configuration_option='verify_only';dd_resolution_option='disabled';
    dd_refresh_rate_option='disabled';dd_hdr_option='auto';dd_config_revert_on_disconnect='enabled'
}
$original = if (Test-Path -LiteralPath $configurationPath) { [IO.File]::ReadAllText($configurationPath) } else { '' }
$newConfiguration = Merge-SunshineConfig -Original $original -Settings $settings
$plan = [pscustomobject]@{HostIP=$ComputerTailscaleIP;TrustedClientIPs=$TrustedClientIPs;Interface=$localAddress[0].InterfaceAlias;Encoder=$Encoder;DisableSleepOnAC=[bool]$DisableSleepOnAC;ConfigurationChanged=($original -ne $newConfiguration)}
if (-not $PSCmdlet.ShouldProcess(($plan | ConvertTo-Json -Compress), 'Configure services, Sunshine VPN binding and scoped streaming rules')) { return $plan }
Assert-Administrator
$stateDirectory = Get-LocalStateDirectory
if (Test-Path -LiteralPath $configurationPath) {
    Copy-Item -LiteralPath $configurationPath -Destination (Join-Path $stateDirectory ('sunshine-before-{0}.conf' -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
}
if ($original -ne $newConfiguration) {
    Stop-Service -Name SunshineService -ErrorAction Stop
    Write-Utf8File -Path $configurationPath -Text $newConfiguration
}
Set-Service -Name Tailscale -StartupType Automatic
Set-Service -Name SunshineService -StartupType Automatic
Start-Service -Name Tailscale
$tailscale = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
Invoke-CheckedNative -FilePath $tailscale -Arguments @('set','--unattended=true')
$sc = Join-Path $env:SystemRoot 'System32\sc.exe'
Invoke-CheckedNative -FilePath $sc -Arguments @('failure','SunshineService','reset=','86400','actions=','restart/15000/restart/30000/restart/60000')
Invoke-CheckedNative -FilePath $sc -Arguments @('failureflag','SunshineService','1')
foreach ($protocol in @('TCP','UDP')) {
    $parameters = @{
        Name="UnattendedMoonlight-Tailscale-$protocol";DisplayName="Sunshine Tailscale trusted $protocol";
        Direction='Inbound';Action='Allow';Enabled='True';Profile='Any';
        InterfaceAlias=$localAddress[0].InterfaceAlias;LocalAddress=$ComputerTailscaleIP;
        RemoteAddress=@($TrustedClientIPs | Select-Object -Unique);
        Program=(Join-Path $installDirectory 'sunshine.exe');Protocol=$protocol;
        LocalPort=$(if ($protocol -eq 'TCP') { @(47984,47989,48010) } else { @(47998,47999,48000) })
    }
    if (Get-NetFirewallRule -Name $parameters.Name -ErrorAction SilentlyContinue) { Set-NetFirewallRule @parameters | Out-Null }
    else { New-NetFirewallRule @parameters | Out-Null }
}
if ($DisableSleepOnAC) {
    $power = Join-Path $env:SystemRoot 'System32\powercfg.exe'
    Invoke-CheckedNative -FilePath $power -Arguments @('/change','standby-timeout-ac','0')
    Invoke-CheckedNative -FilePath $power -Arguments @('/change','hibernate-timeout-ac','0')
}
Start-Service -Name SunshineService
$plan | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $stateDirectory 'last-configuration.json') -Encoding UTF8
Write-Output "Host configured. Sunshine admin UI: https://${ComputerTailscaleIP}:47990/"
Write-Output 'Retain/create your own Sunshine admin credentials; pair each client once. Review node key expiry in the Tailscale console.'
Write-Output 'Global firewall enablement, broad existing rules, tailnet access policies and Windows login settings were not changed.'
