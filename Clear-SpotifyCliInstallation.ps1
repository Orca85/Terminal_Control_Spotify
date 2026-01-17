function Clear-SpotifyCliInstallation {
    <#
    .SYNOPSIS
    Rensar alla tidigare Spotify CLI-installationer.

    .DESCRIPTION
    Tar bort alla tidigare versioner av Spotify CLI fran:
    - Documents\PowerShell\Modules\SpotifyCLI
    - Documents\PowerShell\Modules\SpotifyCommands
    - Documents\WindowsPowerShell\Modules\SpotifyCLI
    - Documents\WindowsPowerShell\Modules\SpotifyCommands
    - PowerShell-profilen (import-statements)

    Skapar backup av .env och annan anvandardata innan rensning.

    .PARAMETER BackupPath
    Skvag till backup-mapp. Standard: Documents\PowerShell\SpotifyCLI-Backup

    .PARAMETER Force
    Hoppa over bekraftelse.

    .PARAMETER WhatIf
    Visa vad som skulle goras utan att gora det.

    .EXAMPLE
    Clear-SpotifyCliInstallation -WhatIf
    # Visar vad som skulle rensas

    .EXAMPLE
    Clear-SpotifyCliInstallation -Force
    # Rensar allt utan bekraftelse
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter()]
        [string]$BackupPath,

        [Parameter()]
        [switch]$Force
    )

    # Konfigurera sokvagar
    $timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $documentsPath = [Environment]::GetFolderPath('MyDocuments')

    if (-not $BackupPath) {
        $BackupPath = Join-Path $documentsPath "PowerShell\SpotifyCLI-Backup\$timestamp"
    }

    $logPath = Join-Path $documentsPath "PowerShell\SpotifyCLI-Cleanup.log"

    # Modulsokvagar att rensa
    $modulePaths = @(
        Join-Path $documentsPath "PowerShell\Modules\SpotifyCLI"
        Join-Path $documentsPath "PowerShell\Modules\SpotifyCommands"
        Join-Path $documentsPath "WindowsPowerShell\Modules\SpotifyCLI"
        Join-Path $documentsPath "WindowsPowerShell\Modules\SpotifyCommands"
    )

    # Profilsokvagar
    $profilePaths = @(
        $PROFILE.CurrentUserCurrentHost
        $PROFILE.CurrentUserAllHosts
        Join-Path $documentsPath "PowerShell\Microsoft.PowerShell_profile.ps1"
        Join-Path $documentsPath "PowerShell\profile.ps1"
        Join-Path $documentsPath "WindowsPowerShell\Microsoft.PowerShell_profile.ps1"
        Join-Path $documentsPath "WindowsPowerShell\profile.ps1"
    ) | Select-Object -Unique | Where-Object { $_ }

    # Cache och config att rensa
    $cachePaths = @(
        Join-Path $env:APPDATA "SpotifyCLI"
        Join-Path $documentsPath "PowerShell\SpotifyCLI-Cache"
    )

    # Loggfunktion
    function Write-CleanupLog {
        param([string]$Message, [string]$Level = "INFO")
        $logEntry = "[$timestamp] [$Level] $Message"
        Add-Content -Path $logPath -Value $logEntry -ErrorAction SilentlyContinue

        $color = switch ($Level) {
            "INFO" { "White" }
            "SUCCESS" { "Green" }
            "WARNING" { "Yellow" }
            "ERROR" { "Red" }
            default { "Gray" }
        }
        Write-Host $logEntry -ForegroundColor $color
    }

    # Initiera logg
    $logDir = Split-Path $logPath -Parent
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  SPOTIFY CLI - RENSNING AV TIDIGARE INSTALLATIONER" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-CleanupLog "Startar rensning av Spotify CLI-installationer"

    # =========================================================================
    # STEG 1: Skapa backup
    # =========================================================================
    Write-Host "[1/4] Skapar backup av anvandardata..." -ForegroundColor Yellow

    $filesToBackup = @()

    # Hitta .env-filer
    foreach ($modulePath in $modulePaths) {
        if (Test-Path $modulePath) {
            $envFiles = Get-ChildItem -Path $modulePath -Filter ".env*" -Recurse -ErrorAction SilentlyContinue
            $filesToBackup += $envFiles

            # Hitta config-filer
            $configFiles = Get-ChildItem -Path $modulePath -Filter "*.json" -Recurse -ErrorAction SilentlyContinue
            $filesToBackup += $configFiles
        }
    }

    # Kolla aven i AppData
    $appDataEnv = Join-Path $env:APPDATA "SpotifyCLI\.env"
    if (Test-Path $appDataEnv) {
        $filesToBackup += Get-Item $appDataEnv
    }

    # Projektkatalogen
    $projectEnv = Join-Path $PSScriptRoot ".env"
    if (Test-Path $projectEnv) {
        $filesToBackup += Get-Item $projectEnv
    }

    if ($filesToBackup.Count -gt 0) {
        if ($PSCmdlet.ShouldProcess($BackupPath, "Skapa backup-katalog")) {
            New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null

            foreach ($file in $filesToBackup) {
                $destPath = Join-Path $BackupPath $file.Name
                Copy-Item -Path $file.FullName -Destination $destPath -Force
                Write-CleanupLog "Backup skapad: $($file.FullName) -> $destPath" "SUCCESS"
            }
        }
        Write-Host "   Backup skapad i: $BackupPath" -ForegroundColor Green
    } else {
        Write-Host "   Ingen anvandardata att backa upp" -ForegroundColor Gray
        Write-CleanupLog "Ingen anvandardata hittades for backup" "INFO"
    }

    # =========================================================================
    # STEG 2: Rensa modulkataloger
    # =========================================================================
    Write-Host ""
    Write-Host "[2/4] Rensar modulkataloger..." -ForegroundColor Yellow

    $removedModules = @()
    foreach ($modulePath in $modulePaths) {
        if (Test-Path $modulePath) {
            if ($PSCmdlet.ShouldProcess($modulePath, "Ta bort modulkatalog")) {
                try {
                    # Forst, avladda modulen om den ar laddad
                    $moduleName = Split-Path $modulePath -Leaf
                    if (Get-Module -Name $moduleName -ErrorAction SilentlyContinue) {
                        Remove-Module -Name $moduleName -Force -ErrorAction SilentlyContinue
                        Write-CleanupLog "Avladdade modul: $moduleName" "INFO"
                    }

                    Remove-Item -Path $modulePath -Recurse -Force
                    $removedModules += $modulePath
                    Write-CleanupLog "Borttagen: $modulePath" "SUCCESS"
                    Write-Host "   Borttagen: $modulePath" -ForegroundColor Green
                } catch {
                    Write-CleanupLog "Kunde inte ta bort: $modulePath - $_" "ERROR"
                    Write-Host "   FEL: Kunde inte ta bort $modulePath" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "   Finns ej: $modulePath" -ForegroundColor Gray
        }
    }

    if ($removedModules.Count -eq 0) {
        Write-Host "   Inga modulkataloger att rensa" -ForegroundColor Gray
    }

    # =========================================================================
    # STEG 3: Rensa PowerShell-profil
    # =========================================================================
    Write-Host ""
    Write-Host "[3/4] Rensar PowerShell-profiler..." -ForegroundColor Yellow

    # Monster att ta bort fran profilen
    $patternsToRemove = @(
        '(?m)^.*Import-Module\s+.*Spotify.*$'
        '(?m)^.*SpotifyCLI.*$'
        '(?m)^.*SpotifyCommands.*$'
        '(?m)^#\s*Spotify\s*CLI.*$'
        '(?m)^.*Set-Alias.*spotify.*$'
        '(?m)^.*spotify-help.*$'
        '(?m)^.*plays-now.*$'
    )

    foreach ($profilePath in $profilePaths) {
        if (Test-Path $profilePath) {
            if ($PSCmdlet.ShouldProcess($profilePath, "Rensa Spotify-relaterade rader")) {
                try {
                    $content = Get-Content $profilePath -Raw -ErrorAction Stop
                    $originalLength = $content.Length
                    $modified = $false

                    foreach ($pattern in $patternsToRemove) {
                        $newContent = $content -replace $pattern, ''
                        if ($newContent -ne $content) {
                            $content = $newContent
                            $modified = $true
                        }
                    }

                    # Ta bort tomma rader (fler an 2 i rad)
                    $content = $content -replace '(\r?\n){3,}', "`n`n"
                    $content = $content.Trim()

                    if ($modified) {
                        Set-Content -Path $profilePath -Value $content -Encoding UTF8
                        Write-CleanupLog "Rensad profil: $profilePath" "SUCCESS"
                        Write-Host "   Rensad: $profilePath" -ForegroundColor Green
                    } else {
                        Write-Host "   Inga andringar: $profilePath" -ForegroundColor Gray
                    }
                } catch {
                    Write-CleanupLog "Kunde inte rensa profil: $profilePath - $_" "ERROR"
                    Write-Host "   FEL: $profilePath - $_" -ForegroundColor Red
                }
            }
        }
    }

    # =========================================================================
    # STEG 4: Rensa cache och temporara filer
    # =========================================================================
    Write-Host ""
    Write-Host "[4/4] Rensar cache och temporara filer..." -ForegroundColor Yellow

    foreach ($cachePath in $cachePaths) {
        if (Test-Path $cachePath) {
            if ($PSCmdlet.ShouldProcess($cachePath, "Ta bort cache-katalog")) {
                try {
                    # Behall .env-filer (redan backade)
                    $itemsToRemove = Get-ChildItem -Path $cachePath -Recurse |
                        Where-Object { $_.Name -notlike ".env*" }

                    foreach ($item in $itemsToRemove) {
                        Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
                    }

                    # Om mappen ar tom (forutom .env), ta bort hela
                    $remaining = Get-ChildItem -Path $cachePath -Recurse -ErrorAction SilentlyContinue
                    if ($remaining.Count -eq 0 -or ($remaining.Count -eq 1 -and $remaining[0].Name -like ".env*")) {
                        # Behall mappen om .env finns
                    } else {
                        Write-CleanupLog "Rensad cache: $cachePath" "SUCCESS"
                    }
                    Write-Host "   Rensad: $cachePath" -ForegroundColor Green
                } catch {
                    Write-CleanupLog "Kunde inte rensa cache: $cachePath - $_" "WARNING"
                    Write-Host "   Varning: Kunde inte helt rensa $cachePath" -ForegroundColor Yellow
                }
            }
        } else {
            Write-Host "   Finns ej: $cachePath" -ForegroundColor Gray
        }
    }

    # =========================================================================
    # STEG 5: Rensa alias (i aktuell session)
    # =========================================================================
    Write-Host ""
    Write-Host "[Bonus] Rensar Spotify-alias i aktuell session..." -ForegroundColor Yellow

    $spotifyAliases = @(
        'ss', 'slw', 'ShowSpotify', 'ShowLyrics',
        'plays-now', 'music', 'pn', 'sp',
        'vol', 'sh', 'rep', 'tr', 'pl', 'q',
        'spotify', 'help', 'spotify-help'
    )

    $removedAliases = @()
    foreach ($alias in $spotifyAliases) {
        if (Get-Alias -Name $alias -ErrorAction SilentlyContinue) {
            if ($PSCmdlet.ShouldProcess($alias, "Ta bort alias")) {
                Remove-Item -Path "Alias:\$alias" -Force -ErrorAction SilentlyContinue
                $removedAliases += $alias
            }
        }
    }

    if ($removedAliases.Count -gt 0) {
        Write-Host "   Borttagna alias: $($removedAliases -join ', ')" -ForegroundColor Green
        Write-CleanupLog "Borttagna alias fran session: $($removedAliases -join ', ')" "SUCCESS"
    } else {
        Write-Host "   Inga aktiva Spotify-alias att rensa" -ForegroundColor Gray
    }

    # =========================================================================
    # SAMMANFATTNING
    # =========================================================================
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  RENSNING SLUTFORD" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Backup:           $BackupPath" -ForegroundColor White
    Write-Host "  Loggfil:          $logPath" -ForegroundColor White
    Write-Host "  Borttagna moduler: $($removedModules.Count)" -ForegroundColor White
    Write-Host "  Borttagna alias:   $($removedAliases.Count)" -ForegroundColor White
    Write-Host ""
    Write-Host "  Nasta steg: Kor installationsskriptet for att installera" -ForegroundColor Yellow
    Write-Host "              Spotify CLI pa nytt." -ForegroundColor Yellow
    Write-Host ""

    Write-CleanupLog "Rensning slutford. Borttagna moduler: $($removedModules.Count), Alias: $($removedAliases.Count)" "SUCCESS"

    # Returnera resultat
    return [PSCustomObject]@{
        Success = $true
        BackupPath = $BackupPath
        LogPath = $logPath
        RemovedModules = $removedModules
        RemovedAliases = $removedAliases
        BackedUpFiles = $filesToBackup.FullName
        Timestamp = $timestamp
    }
}

function Get-SpotifyCliInstallationStatus {
    <#
    .SYNOPSIS
    Visar status for Spotify CLI-installationer.

    .DESCRIPTION
    Kontrollerar vilka Spotify CLI-installationer som finns och deras status.

    .EXAMPLE
    Get-SpotifyCliInstallationStatus
    #>
    [CmdletBinding()]
    param()

    $documentsPath = [Environment]::GetFolderPath('MyDocuments')

    $locations = @(
        @{ Path = Join-Path $documentsPath "PowerShell\Modules\SpotifyCLI"; Name = "PS7 SpotifyCLI" }
        @{ Path = Join-Path $documentsPath "PowerShell\Modules\SpotifyCommands"; Name = "PS7 SpotifyCommands" }
        @{ Path = Join-Path $documentsPath "WindowsPowerShell\Modules\SpotifyCLI"; Name = "PS5 SpotifyCLI" }
        @{ Path = Join-Path $documentsPath "WindowsPowerShell\Modules\SpotifyCommands"; Name = "PS5 SpotifyCommands" }
        @{ Path = Join-Path $env:APPDATA "SpotifyCLI"; Name = "AppData Config" }
    )

    Write-Host ""
    Write-Host "SPOTIFY CLI - INSTALLATIONSSTATUS" -ForegroundColor Cyan
    Write-Host "==================================" -ForegroundColor Cyan
    Write-Host ""

    foreach ($loc in $locations) {
        $exists = Test-Path $loc.Path
        $status = if ($exists) { "[FINNS]" } else { "[SAKNAS]" }
        $color = if ($exists) { "Yellow" } else { "Gray" }

        Write-Host "  $status $($loc.Name)" -ForegroundColor $color
        if ($exists) {
            Write-Host "          $($loc.Path)" -ForegroundColor DarkGray
            $files = Get-ChildItem -Path $loc.Path -Recurse -File -ErrorAction SilentlyContinue
            Write-Host "          $($files.Count) filer" -ForegroundColor DarkGray
        }
    }

    # Kolla profiler
    Write-Host ""
    Write-Host "PowerShell-profiler:" -ForegroundColor Cyan

    $profiles = @($PROFILE.CurrentUserCurrentHost, $PROFILE.CurrentUserAllHosts) | Select-Object -Unique
    foreach ($prof in $profiles) {
        if (Test-Path $prof) {
            $content = Get-Content $prof -Raw -ErrorAction SilentlyContinue
            $hasSpotify = $content -match 'Spotify'
            $status = if ($hasSpotify) { "[SPOTIFY-REF]" } else { "[RENT]" }
            $color = if ($hasSpotify) { "Yellow" } else { "Green" }
            Write-Host "  $status $prof" -ForegroundColor $color
        } else {
            Write-Host "  [FINNS EJ] $prof" -ForegroundColor Gray
        }
    }

    # Kolla laddade moduler
    Write-Host ""
    Write-Host "Laddade Spotify-moduler:" -ForegroundColor Cyan
    $loadedModules = Get-Module | Where-Object { $_.Name -like "*Spotify*" }
    if ($loadedModules) {
        foreach ($mod in $loadedModules) {
            Write-Host "  [LADDAD] $($mod.Name) v$($mod.Version)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  Inga Spotify-moduler laddade" -ForegroundColor Gray
    }

    Write-Host ""
}

function Restore-SpotifyCliBackup {
    <#
    .SYNOPSIS
    Aterstaller Spotify CLI-data fran backup.

    .DESCRIPTION
    Aterstaller .env och konfigurationsfiler fran en tidigare backup.

    .PARAMETER BackupPath
    Sokvag till backup-mappen.

    .EXAMPLE
    Restore-SpotifyCliBackup -BackupPath "C:\Users\user\Documents\PowerShell\SpotifyCLI-Backup\2026-01-17_143000"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$BackupPath
    )

    if (-not (Test-Path $BackupPath)) {
        Write-Host "Backup-mappen finns inte: $BackupPath" -ForegroundColor Red
        return
    }

    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $targetPath = Join-Path $documentsPath "PowerShell\Modules\SpotifyCommands"

    Write-Host ""
    Write-Host "ATERSTALLER FRAN BACKUP" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Kalla:  $BackupPath" -ForegroundColor White
    Write-Host "  Mal:    $targetPath" -ForegroundColor White
    Write-Host ""

    $backupFiles = Get-ChildItem -Path $BackupPath -File -ErrorAction SilentlyContinue
    if ($backupFiles.Count -eq 0) {
        Write-Host "Inga filer att aterst alla." -ForegroundColor Yellow
        return
    }

    # Skapa malkatalog om den inte finns
    if (-not (Test-Path $targetPath)) {
        New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    }

    foreach ($file in $backupFiles) {
        try {
            $destPath = Join-Path $targetPath $file.Name
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            Write-Host "  Aterstallde: $($file.Name)" -ForegroundColor Green
        } catch {
            Write-Host "  FEL: Kunde inte aterst alla $($file.Name) - $_" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Aterst allning slutford." -ForegroundColor Green
}

function Get-SpotifyCliBackups {
    <#
    .SYNOPSIS
    Listar alla tillgangliga Spotify CLI-backups.

    .EXAMPLE
    Get-SpotifyCliBackups
    #>
    [CmdletBinding()]
    param()

    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    $backupRoot = Join-Path $documentsPath "PowerShell\SpotifyCLI-Backup"

    if (-not (Test-Path $backupRoot)) {
        Write-Host "Inga backups hittades." -ForegroundColor Yellow
        return
    }

    $backups = Get-ChildItem -Path $backupRoot -Directory | Sort-Object Name -Descending

    if ($backups.Count -eq 0) {
        Write-Host "Inga backups hittades." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "TILLGANGLIGA BACKUPS" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    Write-Host ""

    foreach ($backup in $backups) {
        $files = Get-ChildItem -Path $backup.FullName -File -ErrorAction SilentlyContinue
        $fileCount = $files.Count
        $timestamp = $backup.Name

        Write-Host "  [$timestamp] - $fileCount filer" -ForegroundColor White
        Write-Host "    $($backup.FullName)" -ForegroundColor DarkGray
    }

    Write-Host ""
    Write-Host "  Aterstall med: Restore-SpotifyCliBackup -BackupPath '<sokvag>'" -ForegroundColor Yellow
    Write-Host ""
}

function Export-SpotifyCliCleanupReport {
    <#
    .SYNOPSIS
    Exporterar rensningsrapport till en fil.

    .PARAMETER CleanupResult
    Resultat fran Clear-SpotifyCliInstallation.

    .PARAMETER OutputPath
    Sokvag for rapporten. Standard: Documents\PowerShell\SpotifyCLI-Cleanup-Report.md

    .EXAMPLE
    $result = Clear-SpotifyCliInstallation -WhatIf
    Export-SpotifyCliCleanupReport -CleanupResult $result
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$CleanupResult,

        [Parameter()]
        [string]$OutputPath
    )

    $documentsPath = [Environment]::GetFolderPath('MyDocuments')
    if (-not $OutputPath) {
        $OutputPath = Join-Path $documentsPath "PowerShell\SpotifyCLI-Cleanup-Report.md"
    }

    # Bygg rapporten stegvis for att undvika here-string problem
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Spotify CLI Cleanup Report")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("**Timestamp:** $($CleanupResult.Timestamp)")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Summary")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("| Metric | Value |")
    [void]$sb.AppendLine("|--------|-------|")
    [void]$sb.AppendLine("| Success | $($CleanupResult.Success) |")
    [void]$sb.AppendLine("| Removed Modules | $($CleanupResult.RemovedModules.Count) |")
    [void]$sb.AppendLine("| Removed Aliases | $($CleanupResult.RemovedAliases.Count) |")
    [void]$sb.AppendLine("| Backed Up Files | $(($CleanupResult.BackedUpFiles | Measure-Object).Count) |")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Backup Location")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("``$($CleanupResult.BackupPath)``")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Log File")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("``$($CleanupResult.LogPath)``")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Removed Module Paths")
    [void]$sb.AppendLine("")

    if ($CleanupResult.RemovedModules -and $CleanupResult.RemovedModules.Count -gt 0) {
        foreach ($module in $CleanupResult.RemovedModules) {
            [void]$sb.AppendLine("- ``$module``")
        }
    } else {
        [void]$sb.AppendLine("- *No modules removed*")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Backed Up Files")
    [void]$sb.AppendLine("")

    if ($CleanupResult.BackedUpFiles -and ($CleanupResult.BackedUpFiles | Measure-Object).Count -gt 0) {
        foreach ($file in $CleanupResult.BackedUpFiles) {
            [void]$sb.AppendLine("- ``$file``")
        }
    } else {
        [void]$sb.AppendLine("- *No files backed up*")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Removed Aliases")
    [void]$sb.AppendLine("")

    if ($CleanupResult.RemovedAliases -and $CleanupResult.RemovedAliases.Count -gt 0) {
        [void]$sb.AppendLine(($CleanupResult.RemovedAliases -join ", "))
    } else {
        [void]$sb.AppendLine("*No aliases removed*")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("*Generated by Clear-SpotifyCliInstallation*")

    $report = $sb.ToString()
    Set-Content -Path $OutputPath -Value $report -Encoding UTF8
    Write-Host "Rapport sparad: $OutputPath" -ForegroundColor Green
}

# Om skriptet kors direkt
if ($MyInvocation.InvocationName -notmatch '^\.' -and $MyInvocation.Line -notmatch 'Import-Module') {
    # Visa status forst
    Get-SpotifyCliInstallationStatus

    Write-Host ""
    Write-Host "Alternativ:" -ForegroundColor Cyan
    Write-Host "  1. Rensa alla tidigare installationer" -ForegroundColor White
    Write-Host "  2. Visa tillgangliga backups" -ForegroundColor White
    Write-Host "  3. Forhandsgranska rensning (WhatIf)" -ForegroundColor White
    Write-Host "  4. Avbryt" -ForegroundColor White
    Write-Host ""
    $response = Read-Host "Valj alternativ (1-4)"

    switch ($response) {
        '1' {
            $result = Clear-SpotifyCliInstallation
            if ($result.Success) {
                Write-Host ""
                $exportResponse = Read-Host "Vill du exportera en rapport? (j/n)"
                if ($exportResponse -match '^[jJyY]') {
                    Export-SpotifyCliCleanupReport -CleanupResult $result
                }
            }
        }
        '2' {
            Get-SpotifyCliBackups
        }
        '3' {
            Clear-SpotifyCliInstallation -WhatIf
        }
        default {
            Write-Host "Avbrutet." -ForegroundColor Yellow
        }
    }
}
