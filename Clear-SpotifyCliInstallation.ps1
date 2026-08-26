function Clear-SpotifyCliInstallation {
    <#
    .SYNOPSIS
    Remove all SpotifyCLI installations from this machine.

    .DESCRIPTION
    Removes SpotifyCLI module directories, cleans up PowerShell profile imports,
    and optionally clears cached data from AppData. Backs up credentials and
    config before removing anything.

    .PARAMETER BackupPath
    Path to store the backup. Defaults to Documents\PowerShell\SpotifyCLI-Backup\<timestamp>.

    .PARAMETER Force
    Skip confirmation prompts.

    .PARAMETER WhatIf
    Preview what would be removed without making any changes.

    .EXAMPLE
    Clear-SpotifyCliInstallation -WhatIf

    .EXAMPLE
    Clear-SpotifyCliInstallation -Force
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [string]$BackupPath,
        [switch]$Force
    )

    $timestamp     = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')

    if (-not $BackupPath) {
        $BackupPath = Join-Path $documentsPath "PowerShell\SpotifyCLI-Backup\$timestamp"
    }

    $logPath = Join-Path $documentsPath "PowerShell\SpotifyCLI-Cleanup.log"

    $modulePaths = @(
        Join-Path $documentsPath "PowerShell\Modules\SpotifyCLI"
        Join-Path $documentsPath "WindowsPowerShell\Modules\SpotifyCLI"
    )

    $profilePaths = @(
        $PROFILE.CurrentUserCurrentHost
        $PROFILE.CurrentUserAllHosts
        Join-Path $documentsPath "PowerShell\Microsoft.PowerShell_profile.ps1"
        Join-Path $documentsPath "PowerShell\profile.ps1"
        Join-Path $documentsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        Join-Path $documentsPath "WindowsPowerShell\profile.ps1"
    ) | Select-Object -Unique | Where-Object { $_ }

    $cachePaths = @(
        Join-Path $env:APPDATA "SpotifyCLI"
    )

    function Write-Log {
        param([string]$Message, [string]$Level = "INFO")
        $entry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $logPath -Value $entry -ErrorAction SilentlyContinue
        $color = switch ($Level) {
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR"   { "Red" }
            default   { "White" }
        }
        Write-Host $entry -ForegroundColor $color
    }

    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  SpotifyCLI - Uninstaller" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""

    # --- Step 1: Backup ---
    Write-Host "[1/4] Backing up user data..." -ForegroundColor Yellow

    $filesToBackup = @()
    foreach ($modulePath in $modulePaths) {
        if (Test-Path $modulePath) {
            $filesToBackup += Get-ChildItem -Path $modulePath -Filter ".env*" -Recurse -ErrorAction SilentlyContinue
            $filesToBackup += Get-ChildItem -Path $modulePath -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
        }
    }

    $appDataConfig = Join-Path $env:APPDATA "SpotifyCLI"
    if (Test-Path $appDataConfig) {
        $filesToBackup += Get-ChildItem -Path $appDataConfig -Filter "*.json" -ErrorAction SilentlyContinue
    }

    if ($filesToBackup.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($BackupPath, "Create backup")) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
            foreach ($file in $filesToBackup) {
                $dest = Join-Path $BackupPath $file.Name
                Copy-Item -Path $file.FullName -Destination $dest -Force
                Write-Log "Backed up: $($file.FullName) -> $dest" "SUCCESS"
            }
        }
        Write-Host "   Backup saved to: $BackupPath" -ForegroundColor Green
    } else {
        Write-Host "   No user data found to back up." -ForegroundColor Gray
    }

    # --- Step 2: Remove module directories ---
    Write-Host ""
    Write-Host "[2/4] Removing module directories..." -ForegroundColor Yellow

    $removedModules = @()
    foreach ($modulePath in $modulePaths) {
        if (Test-Path $modulePath) {
            if ($PSCmdlet.ShouldProcess($modulePath, "Remove module directory")) {
                try {
                    $moduleName = Split-Path $modulePath -Leaf
                    if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue) {
                        Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
                    }
                    Remove-Item -Path $modulePath -Recurse -Force
                    $removedModules += $modulePath
                    Write-Log "Removed: $modulePath" "SUCCESS"
                    Write-Host "   Removed: $modulePath" -ForegroundColor Green
                } catch {
                    Write-Log "Could not remove: $modulePath — $_" "ERROR"
                    Write-Host "   Error: Could not remove $modulePath" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "   Not found: $modulePath" -ForegroundColor Gray
        }
    }

    if ($removedModules.Count -eq 0) {
        Write-Host "   No module directories found." -ForegroundColor Gray
    }

    # --- Step 3: Clean PowerShell profiles ---
    Write-Host ""
    Write-Host "[3/4] Cleaning PowerShell profiles..." -ForegroundColor Yellow

    $patternsToRemove = @(
        '(?m)^.*Import-Module\s+.*SpotifyCLI.*$'
        '(?m)^.*SpotifyCLI.*$'
        '(?m)^#\s*Spotify\s*CLI.*$'
        '(?m)^.*Set-Alias.*spotify.*$'
        '(?m)^.*plays-now.*$'
        '(?m)^.*Start-SpotifyCLI.*$'
    )

    foreach ($profilePath in $profilePaths) {
        if (Test-Path $profilePath) {
            if ($PSCmdlet.ShouldProcess($profilePath, "Clean Spotify references")) {
                try {
                    $content  = Get-Content $profilePath -Raw -ErrorAction Stop
                    $modified = $false

                    foreach ($pattern in $patternsToRemove) {
                        $new = $content -replace $pattern, ''
                        if ($new -ne $content) { $content = $new; $modified = $true }
                    }

                    $content = ($content -replace '(\r?\n){3,}', "`n`n").Trim()

                    if ($modified) {
                        Set-Content -Path $profilePath -Value $content -Encoding UTF8
                        Write-Log "Cleaned: $profilePath" "SUCCESS"
                        Write-Host "   Cleaned: $profilePath" -ForegroundColor Green
                    } else {
                        Write-Host "   No changes needed: $profilePath" -ForegroundColor Gray
                    }
                } catch {
                    Write-Log "Could not clean profile: $profilePath — $_" "ERROR"
                    Write-Host "   Error: $profilePath" -ForegroundColor Red
                }
            }
        }
    }

    # --- Step 4: Clear cache ---
    Write-Host ""
    Write-Host "[4/4] Clearing cache..." -ForegroundColor Yellow

    foreach ($cachePath in $cachePaths) {
        if (Test-Path $cachePath) {
            if ($PSCmdlet.ShouldProcess($cachePath, "Remove cache directory")) {
                try {
                    Remove-Item -Path $cachePath -Recurse -Force
                    Write-Log "Cleared cache: $cachePath" "SUCCESS"
                    Write-Host "   Cleared: $cachePath" -ForegroundColor Green
                } catch {
                    Write-Log "Could not clear cache: $cachePath — $_" "WARNING"
                    Write-Host "   Warning: Could not fully clear $cachePath" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "   Not found: $cachePath" -ForegroundColor Gray
        }
    }

    # --- Bonus: Remove session aliases ---
    Write-Host ""
    Write-Host "[Bonus] Removing session aliases..." -ForegroundColor Yellow

    $spotifyAliases = @('slw','ShowLyrics','plays-now','music','pn','sp','vol','sh','rep','tr','pl','q','spotify','help','spotify-help','peak','quiz','setlist','commands')
    $removedAliases = @()
    foreach ($alias in $spotifyAliases) {
        if (Get-Alias -Name $alias -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess($alias, "Remove alias")) {
                Remove-Item -Path "Alias:\$alias" -Force -ErrorAction SilentlyContinue
                $removedAliases += $alias
            }
        }
    }

    if ($removedAliases.Count -gt 0) {
        Write-Host "   Removed aliases: $($removedAliases -join ', ')" -ForegroundColor Green
    } else {
        Write-Host "   No active SpotifyCLI aliases found." -ForegroundColor Gray
    }

    # --- Summary ---
    Write-Host ""
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host "  Uninstall complete" -ForegroundColor Cyan
    Write-Host "==========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Backup:          $BackupPath" -ForegroundColor White
    Write-Host "  Log:             $logPath" -ForegroundColor White
    Write-Host "  Modules removed: $($removedModules.Count)" -ForegroundColor White
    Write-Host "  Aliases removed: $($removedAliases.Count)" -ForegroundColor White
    Write-Host ""
    Write-Host "  To reinstall: Install-Module SpotifyCLI" -ForegroundColor Yellow
    Write-Host ""

    Write-Log "Uninstall complete. Modules: $($removedModules.Count), Aliases: $($removedAliases.Count)" "SUCCESS"

    return [PSCustomObject]@{
        Success        = $true
        BackupPath     = $BackupPath
        LogPath        = $logPath
        RemovedModules = $removedModules
        RemovedAliases = $removedAliases
        BackedUpFiles  = $filesToBackup.FullName
        Timestamp      = $timestamp
    }
}

function Get-SpotifyCliInstallationStatus {
    <#
    .SYNOPSIS
    Show the current SpotifyCLI installation status.
    #>
    [CmdletBinding()]
    param()

    $documentsPath = [Environment]::GetFolderPath('MyDocuments')

    $locations = @(
        @{ Path = Join-Path $documentsPath "PowerShell\Modules\SpotifyCLI";       Name = "PS7 SpotifyCLI" }
        @{ Path = Join-Path $documentsPath "WindowsPowerShell\Modules\SpotifyCLI"; Name = "PS5 SpotifyCLI" }
        @{ Path = Join-Path $env:APPDATA "SpotifyCLI";                             Name = "AppData Config" }
    )

    Write-Host ""
    Write-Host "SpotifyCLI — Installation Status" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""

    foreach ($loc in $locations) {
        $exists = Test-Path $loc.Path
        $status = if ($exists) { "[FOUND]  " } else { "[MISSING]" }
        $color  = if ($exists) { "Yellow" } else { "Gray" }
        Write-Host "  $status $($loc.Name)" -ForegroundColor $color
        if ($exists) {
            $files = Get-ChildItem -Path $loc.Path -Recurse -File -ErrorAction SilentlyContinue
            Write-Host "           $($loc.Path) ($($files.Count) files)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "PowerShell profiles:" -ForegroundColor Cyan

    @($PROFILE.CurrentUserCurrentHost, $PROFILE.CurrentUserAllHosts) | Select-Object -Unique | ForEach-Object {
        if (Test-Path $_) {
            $content     = Get-Content $_ -Raw -ErrorAction SilentlyContinue
            $hasSpotify  = $content -match 'SpotifyCLI'
            $status      = if ($hasSpotify) { "[HAS SPOTIFY-REF]" } else { "[CLEAN]" }
            $color       = if ($hasSpotify) { "Yellow" } else { "Green" }
            Write-Host "  $status $_" -ForegroundColor $color
        } else {
            Write-Host "  [NOT FOUND] $_" -ForegroundColor Gray
        }
    }

    Write-Host ""
    Write-Host "Loaded modules:" -ForegroundColor Cyan
    $loaded = Get-Module | Where-Object { $_.Name -like "*Spotify*" }
    if ($loaded) {
        $loaded | ForEach-Object { Write-Host "  [LOADED] $($_.Name) v$($_.Version)" -ForegroundColor Yellow }
    } else {
        Write-Host "  No SpotifyCLI modules currently loaded." -ForegroundColor Gray
    }
    Write-Host ""
}

# Run interactively when executed directly
if ($MyInvocation.InvocationName -notmatch '^\.' -and $MyInvocation.Line -notmatch 'Import-Module') {
    Get-SpotifyCliInstallationStatus

    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  1. Remove all SpotifyCLI installations" -ForegroundColor White
    Write-Host "  2. Preview removal (WhatIf)" -ForegroundColor White
    Write-Host "  3. Cancel" -ForegroundColor White
    Write-Host ""
    $response = Read-Host "Choose (1-3)"

    switch ($response) {
        '1' { Clear-SpotifyCliInstallation }
        '2' { Clear-SpotifyCliInstallation -WhatIf }
        default { Write-Host "Cancelled." -ForegroundColor Yellow }
    }
}
