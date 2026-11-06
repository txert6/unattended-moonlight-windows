#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param([string]$DownloadDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'downloads'))
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$null = & (Join-Path $PSScriptRoot 'Get-Dependencies.ps1') -Platform windows -DestinationDirectory $DownloadDirectory -VerifyOnly
$stateDirectory = $null
foreach ($entry in @(
    @{Service='Tailscale';File='tailscale-setup-1.104.5-amd64.msi'},
    @{Service='SunshineService';File='Sunshine-Windows-AMD64-installer.msi'}
)) {
    if (Get-Service -Name $entry.Service -ErrorAction SilentlyContinue) {
        Write-Output "Already installed: $($entry.Service). Existing installation preserved."
        continue
    }
    if (-not $PSCmdlet.ShouldProcess($entry.Service, 'Install verified official Windows MSI without reboot')) { continue }
    Assert-Administrator
    if (-not $stateDirectory) { $stateDirectory = Get-LocalStateDirectory }
    $installer = Join-Path $DownloadDirectory $entry.File
    $log = Join-Path $stateDirectory ($entry.Service + '-install.log')
    $arguments = '/i "' + $installer + '" /qn /norestart /L*v "' + $log + '"'
    $process = Start-Process -FilePath (Join-Path $env:SystemRoot 'System32\msiexec.exe') -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    if ($process.ExitCode -notin @(0,3010)) { throw "MSI failed ($($process.ExitCode)); see $log" }
    if ($process.ExitCode -eq 3010) { Write-Warning 'Installer requests a reboot. Save work and reboot manually when ready.' }
}
Write-Output 'Next: authenticate Tailscale with your own account, then run Configure-Host.ps1. No account credentials were created or imported.'
