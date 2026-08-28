#Requires -Modules PowerShellGet
<#
.SYNOPSIS
    Builds and publishes SpotifyCLI to PowerShell Gallery.

.DESCRIPTION
    Copies the module files into a clean build directory and runs Publish-Module.
    Run this script from the project root.

.PARAMETER ApiKey
    Your NuGet/PSGallery API key. Get it from https://www.powershellgallery.com/account/apikeys

.PARAMETER WhatIf
    Validates the module without actually publishing.

.EXAMPLE
    .\Publish-SpotifyCLI.ps1 -ApiKey "your-api-key-here"
    .\Publish-SpotifyCLI.ps1 -WhatIf
#>
param(
    [string]$ApiKey,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$ModuleName  = 'SpotifyCLI'
$BuildDir    = Join-Path $env:TEMP "SpotifyCLIBuild\$ModuleName"

Write-Host "== SpotifyCLI Publisher ==" -ForegroundColor Cyan
Write-Host ""

# --- Read version from manifest ---
$ManifestPath = Join-Path $ProjectRoot "$ModuleName.psd1"
$manifest = Import-PowerShellDataFile $ManifestPath
$version = $manifest.ModuleVersion
Write-Host "Module : $ModuleName v$version" -ForegroundColor Green

# --- Clean and create build directory ---
if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force
}
New-Item -ItemType Directory -Path $BuildDir -Force | Out-Null
Write-Host "Build  : $BuildDir" -ForegroundColor Gray

# --- Copy module files ---
Write-Host "Copying files..." -ForegroundColor Gray

Copy-Item (Join-Path $ProjectRoot "$ModuleName.psd1") $BuildDir
Copy-Item (Join-Path $ProjectRoot "$ModuleName.psm1") $BuildDir
Copy-Item (Join-Path $ProjectRoot "modules") $BuildDir -Recurse
Copy-Item (Join-Path $ProjectRoot "README.md") $BuildDir

Write-Host "  $ModuleName.psd1" -ForegroundColor DarkGray
Write-Host "  $ModuleName.psm1" -ForegroundColor DarkGray
Write-Host "  modules\ ($(Get-ChildItem "$ProjectRoot\modules" -Recurse -Filter '*.psm1' | Measure-Object | Select-Object -ExpandProperty Count) psm1 files)" -ForegroundColor DarkGray
Write-Host "  README.md" -ForegroundColor DarkGray

# --- Validate manifest ---
Write-Host ""
Write-Host "Validating manifest..." -ForegroundColor Gray
$result = Test-ModuleManifest (Join-Path $BuildDir "$ModuleName.psd1") -ErrorAction Stop
Write-Host "  OK — $($result.Name) v$($result.Version)" -ForegroundColor Green

# --- WhatIf mode: stop here ---
if ($WhatIf) {
    Write-Host ""
    Write-Host "WhatIf: validation passed. Run without -WhatIf to publish." -ForegroundColor Yellow
    return
}

# --- Require API key ---
if (-not $ApiKey) {
    $ApiKey = Read-Host "Enter your PSGallery API key"
}
if (-not $ApiKey) {
    Write-Error "No API key provided. Get one at https://www.powershellgallery.com/account/apikeys"
}

# --- Publish ---
Write-Host ""
Write-Host "Publishing to PSGallery..." -ForegroundColor Cyan
Publish-Module -Path $BuildDir -NuGetApiKey $ApiKey -Repository PSGallery -Verbose

Write-Host ""
Write-Host "Done! SpotifyCLI v$version published to PSGallery." -ForegroundColor Green
Write-Host "https://www.powershellgallery.com/packages/SpotifyCLI" -ForegroundColor Cyan
