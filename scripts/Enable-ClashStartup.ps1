#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory)][string]$ExecutablePath)
$ErrorActionPreference = 'Stop'
$executable = Get-Item -LiteralPath $ExecutablePath -ErrorAction Stop
if ($executable.PSIsContainer -or $executable.Name -ne 'clash-verge.exe') { throw 'Select the installed clash-verge.exe.' }
$startup = [Environment]::GetFolderPath('Startup')
$linkPath = Join-Path $startup 'Clash Verge - unattended.lnk'
$shell = New-Object -ComObject WScript.Shell
if (Test-Path -LiteralPath $startup) {
    foreach ($existing in (Get-ChildItem -LiteralPath $startup -Filter '*.lnk' -File)) {
        $existingLink = $shell.CreateShortcut($existing.FullName)
        if ([string]::Equals($existingLink.TargetPath, $executable.FullName, [StringComparison]::OrdinalIgnoreCase)) {
            Write-Output "An existing startup shortcut already targets this app: $($existing.Name). Preserved."
            return
        }
    }
}
if (-not $PSCmdlet.ShouldProcess($linkPath, 'Create current-user login startup shortcut')) { return }
if (-not (Test-Path -LiteralPath $startup)) { New-Item -ItemType Directory -Path $startup -Force | Out-Null }
$link = $shell.CreateShortcut($linkPath)
$link.TargetPath = $executable.FullName
$link.WorkingDirectory = $executable.DirectoryName
$link.Arguments = ''
$link.WindowStyle = 7
$link.Description = 'Start the installed Clash Verge after Windows user login for unattended networking.'
$link.Save()
Write-Output "Startup registered: $linkPath"
Write-Output 'Keep Clash silent start enabled in the app. Retain your own working TUN/service/profile settings. Avoid duplicate native/task/folder startup entries.'
