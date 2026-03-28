# InstallationCommands Module
# Functions for installing, repairing, and uninstalling Spotify CLI.

$script:ModuleName    = 'SpotifyCommands'
$script:DocumentsPath = [Environment]::GetFolderPath('MyDocuments')
$script:InstallPath   = Join-Path $script:DocumentsPath "PowerShell\Modules\$script:ModuleName"
$script:AppDataPath   = Join-Path $env:APPDATA "SpotifyCLI"

# All nested modules declared in SpotifyCommands.psd1
$script:NestedModules = @(
    'modules\SpotifyLiveFeatures.psm1',
    'modules\Core\ErrorHandling.psm1',
    'modules\Core\ApiClientManager.psm1',
    'modules\Core\LegacyApiClient.psm1',
    'modules\Core\StateManager.psm1',
    'modules\Core\LegacyConfigManager.psm1',
    'modules\Core\UIHelpers.psm1',
    'modules\Core\InteractiveMode.psm1',
    'modules\UI\SpotifyFormDisplay.psm1',
    'modules\Core\AppCommands.psm1',
    'modules\Core\PlaybackCommands.psm1',
    'modules\Core\SearchCommands.psm1',
    'modules\Core\PlaylistQueueCommands.psm1',
    'modules\Quiz\QuizCommands.psm1',
    'modules\UI\PeakDashboard.psm1',
    'modules\Core\SetlistCommands.psm1',
    'modules\Core\AliasManagement.psm1',
    'modules\Core\InstallationCommands.psm1'
)

$script:ProfilePaths = @(
    $PROFILE.CurrentUserCurrentHost
    $PROFILE.CurrentUserAllHosts
    (Join-Path $script:DocumentsPath "PowerShell\Microsoft.PowerShell_profile.ps1")
    (Join-Path $script:DocumentsPath "PowerShell\profile.ps1")
    (Join-Path $script:DocumentsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1")
    (Join-Path $script:DocumentsPath "WindowsPowerShell\profile.ps1")
) | Select-Object -Unique | Where-Object { $_ }


function Install-SpotifyCliDependencies {
    <#
    .SYNOPSIS
    Verify that all Spotify CLI dependencies are present
    .DESCRIPTION
    Checks that all required .psm1 module files exist in the installation directory,
    that PowerShell 5.0+ is available, and that the .env credential file is configured.
    Reports any missing items.
    .EXAMPLE
    Install-SpotifyCliDependencies
    #>
    $result = [PSCustomObject]@{
        Success  = $true
        Missing  = @()
        Present  = @()
        Errors   = @()
    }

    Write-Host ""
    Write-Host "Checking Spotify CLI dependencies..." -ForegroundColor Cyan
    Write-Host ""

    # Check PowerShell version
    $psVersion = $PSVersionTable.PSVersion
    if ($psVersion.Major -lt 5) {
        $msg = "PowerShell 5.0+ required (found $($psVersion.Major).$($psVersion.Minor))"
        $result.Missing  += $msg
        $result.Errors   += $msg
        $result.Success   = $false
        Write-Host "  ❌ $msg" -ForegroundColor Red
    } else {
        Write-Host "  ✅ PowerShell $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Green
        $result.Present += "PowerShell $($psVersion.Major).$($psVersion.Minor)"
    }

    # Check installation directory
    if (-not (Test-Path $script:InstallPath)) {
        $msg = "Installation directory not found: $script:InstallPath"
        $result.Missing  += $msg
        $result.Errors   += $msg
        $result.Success   = $false
        Write-Host "  ❌ $msg" -ForegroundColor Red
        Write-Host "     Run .\Install-SpotifyCLI-Complete.ps1 to install" -ForegroundColor Gray
    } else {
        Write-Host "  ✅ Installation directory: $script:InstallPath" -ForegroundColor Green
        $result.Present += "Installation directory"

        # Check each nested module
        foreach ($rel in $script:NestedModules) {
            $full = Join-Path $script:InstallPath $rel
            if (Test-Path $full) {
                $result.Present += $rel
            } else {
                $result.Missing  += $rel
                $result.Success   = $false
                Write-Host "  ❌ Missing module: $rel" -ForegroundColor Red
            }
        }
        $presentCount = ($result.Present | Where-Object { $_ -like 'modules\*' }).Count
        if ($presentCount -gt 0) {
            Write-Host "  ✅ $presentCount/$($script:NestedModules.Count) nested modules present" -ForegroundColor Green
        }
    }

    # Check .env file (look in both install path and current directory)
    $envPaths = @(
        (Join-Path $script:InstallPath ".env")
        (Join-Path $PSScriptRoot ".env")
        (Join-Path (Get-Location) ".env")
    )
    $envFound = $envPaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($envFound) {
        $envContent = Get-Content $envFound -Raw -ErrorAction SilentlyContinue
        $hasClientId     = $envContent -match 'SPOTIFY_CLIENT_ID=\S+'
        $hasClientSecret = $envContent -match 'SPOTIFY_CLIENT_SECRET=\S+'
        if ($hasClientId -and $hasClientSecret) {
            Write-Host "  ✅ .env file with credentials found" -ForegroundColor Green
            $result.Present += ".env credentials"
        } else {
            $msg = ".env found but missing SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET"
            $result.Missing += $msg
            $result.Success  = $false
            Write-Host "  ❌ $msg" -ForegroundColor Red
        }
    } else {
        $msg = ".env file not found — credentials required"
        $result.Missing += $msg
        $result.Success  = $false
        Write-Host "  ❌ $msg" -ForegroundColor Red
        Write-Host "     Copy .env.example to .env and add your Spotify credentials" -ForegroundColor Gray
    }

    Write-Host ""
    if ($result.Success) {
        Write-Host "✅ All dependencies satisfied" -ForegroundColor Green
    } else {
        Write-Host "⚠️  $($result.Missing.Count) issue(s) found — run .\Install-SpotifyCLI-Complete.ps1 to fix" -ForegroundColor Yellow
    }
    Write-Host ""

    return $result
}


function Repair-SpotifyCliInstallation {
    <#
    .SYNOPSIS
    Attempt to repair the Spotify CLI installation
    .DESCRIPTION
    Backs up config and tokens, re-imports all modules, verifies authentication,
    and restores missing PowerShell profile entries.
    .EXAMPLE
    Repair-SpotifyCliInstallation
    #>
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $backupDir = Join-Path $env:TEMP "SpotifyCLI_Repair_$timestamp"
    $result = [PSCustomObject]@{
        Success       = $false
        BackupPath    = $backupDir
        RepairedItems = @()
        Errors        = @()
    }

    Write-Host ""
    Write-Host "Repairing Spotify CLI installation..." -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Backup config and tokens
    try {
        New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
        $configFile = Join-Path $script:AppDataPath "config.json"
        $tokenFile  = Join-Path $script:AppDataPath "tokens.json"
        foreach ($f in @($configFile, $tokenFile)) {
            if (Test-Path $f) {
                Copy-Item $f -Destination $backupDir -ErrorAction SilentlyContinue
            }
        }
        Write-Host "  ✅ Backup created: $backupDir" -ForegroundColor Green
        $result.RepairedItems += "Backup created"
    } catch {
        $result.Errors += "Backup failed: $_"
        Write-Host "  ⚠️  Backup failed: $_" -ForegroundColor Yellow
    }

    # Step 2: Re-import all modules
    Write-Host "  Reloading modules..." -ForegroundColor Gray
    $moduleReloaded = $false
    try {
        $manifestPath = Join-Path $script:InstallPath "SpotifyCommands.psd1"
        if (Test-Path $manifestPath) {
            Remove-Module -Name $script:ModuleName -Force -ErrorAction SilentlyContinue
            Import-Module $manifestPath -Force -DisableNameChecking -ErrorAction Stop
            $moduleReloaded = $true
            Write-Host "  ✅ Module reloaded" -ForegroundColor Green
            $result.RepairedItems += "Module reloaded"
        } else {
            $result.Errors += "Manifest not found at $manifestPath"
            Write-Host "  ❌ Manifest not found — run .\Install-SpotifyCLI-Complete.ps1" -ForegroundColor Red
        }
    } catch {
        $result.Errors += "Module reload failed: $_"
        Write-Host "  ❌ Module reload failed: $_" -ForegroundColor Red
    }

    # Step 3: Verify authentication
    Write-Host "  Checking authentication..." -ForegroundColor Gray
    try {
        $authResult = Test-SpotifyAuth
        if ($authResult.IsAuthenticated) {
            Write-Host "  ✅ Authentication valid" -ForegroundColor Green
            $result.RepairedItems += "Authentication verified"
        } else {
            Write-Host "  ⚠️  Not authenticated — run .\spotifyCLI.ps1 to re-authenticate" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  ⚠️  Could not verify authentication" -ForegroundColor Yellow
    }

    # Step 4: Check profile entries
    Write-Host "  Checking PowerShell profile..." -ForegroundColor Gray
    $importStatement = "Import-Module $script:ModuleName"
    $profileFixed = $false
    foreach ($profilePath in $script:ProfilePaths) {
        if (-not (Test-Path $profilePath)) { continue }
        $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -notmatch [regex]::Escape($script:ModuleName)) {
            try {
                Add-Content -Path $profilePath -Value "`n$importStatement" -ErrorAction Stop
                Write-Host "  ✅ Added import to $profilePath" -ForegroundColor Green
                $result.RepairedItems += "Profile entry added: $profilePath"
                $profileFixed = $true
            } catch {
                $result.Errors += "Profile update failed for $profilePath`: $_"
            }
        }
    }
    if (-not $profileFixed) {
        Write-Host "  ✅ Profile entries OK" -ForegroundColor Green
    }

    $result.Success = $result.Errors.Count -eq 0
    Write-Host ""
    if ($result.Success) {
        Write-Host "✅ Repair complete. $($result.RepairedItems.Count) items repaired." -ForegroundColor Green
    } else {
        Write-Host "⚠️  Repair finished with $($result.Errors.Count) error(s)." -ForegroundColor Yellow
        foreach ($e in $result.Errors) { Write-Host "   - $e" -ForegroundColor Red }
    }
    Write-Host ""

    return $result
}


function Uninstall-SpotifyCli {
    <#
    .SYNOPSIS
    Remove the Spotify CLI installation
    .DESCRIPTION
    Unloads the module from the current session, removes PowerShell profile entries,
    clears session aliases, removes the installation directory, and optionally removes
    cached data and config.
    .PARAMETER KeepConfig
    Keep .env, config.json and tokens.json (backed up to Documents folder)
    .PARAMETER Force
    Skip the confirmation prompt
    .EXAMPLE
    Uninstall-SpotifyCli -WhatIf
    Uninstall-SpotifyCli -KeepConfig
    Uninstall-SpotifyCli -Force
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [switch]$KeepConfig,
        [switch]$Force
    )

    if ($Force) {
        $ConfirmPreference = 'None'
    }

    if (-not $PSCmdlet.ShouldProcess("Spotify CLI", "Uninstall")) {
        return
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $result = [PSCustomObject]@{
        Success      = $false
        BackupPath   = $null
        RemovedItems = @()
    }

    Write-Host ""
    Write-Host "Uninstalling Spotify CLI..." -ForegroundColor Cyan
    Write-Host ""

    # Step 1: Back up config if -KeepConfig
    if ($KeepConfig) {
        $backupDir = Join-Path $script:DocumentsPath "SpotifyCLI_Backup_$timestamp"
        try {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            foreach ($f in @("config.json", "tokens.json")) {
                $src = Join-Path $script:AppDataPath $f
                if (Test-Path $src) {
                    Copy-Item $src -Destination $backupDir -ErrorAction SilentlyContinue
                }
            }
            $envSrc = Join-Path $script:InstallPath ".env"
            if (Test-Path $envSrc) {
                Copy-Item $envSrc -Destination $backupDir -ErrorAction SilentlyContinue
            }
            $result.BackupPath = $backupDir
            Write-Host "  ✅ Config backed up to: $backupDir" -ForegroundColor Green
        } catch {
            Write-Host "  ⚠️  Backup failed: $_" -ForegroundColor Yellow
        }
    }

    # Step 2: Unload module from session
    try {
        Remove-Module -Name $script:ModuleName -Force -ErrorAction SilentlyContinue
        Write-Host "  ✅ Module unloaded from session" -ForegroundColor Green
        $result.RemovedItems += "Session module"
    } catch {
        Write-Host "  ⚠️  Could not unload module: $_" -ForegroundColor Yellow
    }

    # Step 3: Remove profile entries
    $importPattern = "(?m)^[^\r\n]*Import-Module[^\r\n]*$script:ModuleName[^\r\n]*$"
    foreach ($profilePath in $script:ProfilePaths) {
        if (-not (Test-Path $profilePath)) { continue }
        try {
            $content = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
            if ($content -and $content -match $importPattern) {
                $cleaned = [regex]::Replace($content, $importPattern, '')
                Set-Content -Path $profilePath -Value $cleaned -ErrorAction Stop
                Write-Host "  ✅ Removed profile entry from $profilePath" -ForegroundColor Green
                $result.RemovedItems += "Profile entry: $profilePath"
            }
        } catch {
            Write-Host "  ⚠️  Could not update profile $profilePath`: $_" -ForegroundColor Yellow
        }
    }

    # Step 4: Remove session aliases
    $allAliases = @('plays-now','music','pn','sp','pl','vol','sh','rep','tr','q','pq',
                    'spotify','help','spotify-help','slw','ShowLyrics','quiz','peak',
                    'setlist','commands','ss','ShowSpotify')
    $removedAliases = 0
    foreach ($alias in $allAliases) {
        if (Get-Alias -Name $alias -ErrorAction SilentlyContinue) {
            Remove-Item -Path "Alias:\$alias" -Force -ErrorAction SilentlyContinue
            $removedAliases++
        }
    }
    if ($removedAliases -gt 0) {
        Write-Host "  ✅ Removed $removedAliases session aliases" -ForegroundColor Green
        $result.RemovedItems += "$removedAliases aliases"
    }

    # Step 5: Remove installation directory
    if (Test-Path $script:InstallPath) {
        try {
            Remove-Item -Path $script:InstallPath -Recurse -Force -ErrorAction Stop
            Write-Host "  ✅ Removed installation directory: $script:InstallPath" -ForegroundColor Green
            $result.RemovedItems += "Installation directory"
        } catch {
            Write-Host "  ❌ Could not remove installation directory: $_" -ForegroundColor Red
        }
    }

    # Step 6: Remove cache/appdata (unless -KeepConfig)
    if (-not $KeepConfig -and (Test-Path $script:AppDataPath)) {
        try {
            Remove-Item -Path $script:AppDataPath -Recurse -Force -ErrorAction Stop
            Write-Host "  ✅ Removed app data: $script:AppDataPath" -ForegroundColor Green
            $result.RemovedItems += "App data"
        } catch {
            Write-Host "  ⚠️  Could not remove app data: $_" -ForegroundColor Yellow
        }
    }

    $result.Success = $true
    Write-Host ""
    Write-Host "✅ Spotify CLI uninstalled. $($result.RemovedItems.Count) items removed." -ForegroundColor Green
    if ($result.BackupPath) {
        Write-Host "   Config saved to: $result.BackupPath" -ForegroundColor Gray
    }
    Write-Host ""

    return $result
}

Export-ModuleMember -Function 'Install-SpotifyCliDependencies', 'Repair-SpotifyCliInstallation', 'Uninstall-SpotifyCli'
