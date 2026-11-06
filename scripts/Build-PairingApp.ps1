#Requires -Version 5.1
[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) 'artifacts'))
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $root 'src\SunshinePairing'
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $env:SystemRoot 'Microsoft.NET\Framework\v4.0.30319\csc.exe' }
if (-not (Test-Path -LiteralPath $compiler)) { throw 'Install the Windows .NET Framework 4.x compiler/developer components first.' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$output = Join-Path $OutputDirectory 'SunshinePairing.exe'
$arguments = @(
    '/nologo','/target:winexe','/platform:anycpu','/optimize+','/debug-','/codepage:65001',
    ('/out:' + $output),('/win32manifest:' + (Join-Path $source 'app.manifest')),
    ('/win32icon:' + (Join-Path $source 'pairing.ico')),
    '/reference:System.dll','/reference:System.Core.dll','/reference:System.Drawing.dll',
    '/reference:System.Windows.Forms.dll','/reference:System.Web.Extensions.dll','/reference:System.Security.dll',
    (Join-Path $source 'PairingApp.cs')
)
& $compiler @arguments
if ($LASTEXITCODE -ne 0) { throw "Pairing tool compilation failed: $LASTEXITCODE" }
[pscustomobject]@{File=$output;SHA256=(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash}
