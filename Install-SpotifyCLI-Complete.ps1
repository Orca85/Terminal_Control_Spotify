<#
.SYNOPSIS
Komplett installationsskript for Spotify CLI med verifiering mot README.md.

.DESCRIPTION
Detta skript:
1. Parsear README.md for att extrahera alla dokumenterade funktioner och alias
2. Analyserar modulfilerna for att hitta alla exporterade funktioner
3. Rensar tidigare installationer
4. Installerar till Documents\PowerShell\Modules\SpotifyCommands
5. Skapar ett komplett modulmanifest (.psd1)
6. Uppdaterar PowerShell-profilen
7. Skapar alla alias med -Force -Option AllScope
8. Verifierar installationen och genererar rapport

.PARAMETER SkipCleanup
Hoppa over rensning av tidigare installationer.

.PARAMETER Force
Kor utan bekraftelse.

.PARAMETER WhatIf
Visa vad som skulle goras utan att gora det.

.EXAMPLE
.\Install-SpotifyCLI-Complete.ps1
# Interaktiv installation med bekraftelser

.EXAMPLE
.\Install-SpotifyCLI-Complete.ps1 -Force
# Automatisk installation utan bekraftelser
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$SkipCleanup,
    [switch]$Force
)

# ============================================================================
# KONFIGURATION
# ============================================================================

$script:ProjectRoot = $PSScriptRoot
$script:ModuleName = "SpotifyCommands"
$script:ModuleVersion = "3.1.0"
$script:DocumentsPath = [Environment]::GetFolderPath('MyDocuments')
$script:InstallPath = Join-Path $DocumentsPath "PowerShell\Modules\$ModuleName"
$script:Timestamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$script:LogPath = Join-Path $DocumentsPath "PowerShell\SpotifyCLI-Installation-$Timestamp.log"

# Sakerstall att loggmappen finns
$logDir = Split-Path $script:LogPath -Parent
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# ============================================================================
# LOGGFUNKTION
# ============================================================================

function Write-InstallLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "HEADER")]
        [string]$Level = "INFO"
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"

    # Skriv till loggfil
    Add-Content -Path $script:LogPath -Value $logEntry -ErrorAction SilentlyContinue

    # Skriv till konsol med farg
    $color = switch ($Level) {
        "INFO"    { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
        "HEADER"  { "Cyan" }
        default   { "Gray" }
    }

    if ($Level -eq "HEADER") {
        Write-Host ""
        Write-Host $Message -ForegroundColor $color
    } else {
        Write-Host $logEntry -ForegroundColor $color
    }
}

# ============================================================================
# STEG 1: PARSA README.MD
# ============================================================================

function Get-ReadmeFunctions {
    Write-InstallLog "=== STEG 1: PARSAR README.MD ===" "HEADER"

    $readmePath = Join-Path $script:ProjectRoot "README.md"

    if (-not (Test-Path $readmePath)) {
        Write-InstallLog "README.md hittades inte. Anvander fallback-lista." "WARNING"
        return Get-FallbackFunctions
    }

    # Ladda parsern
    $parserPath = Join-Path $script:ProjectRoot "Parse-ReadmeForFunctions.ps1"
    if (Test-Path $parserPath) {
        . $parserPath
        $result = Parse-ReadmeForFunctions -IncludeFallback
        Write-InstallLog "Parsade $($result.TotalFunctions) funktioner och $($result.TotalAliases) alias fran README.md" "SUCCESS"
        return $result
    }

    Write-InstallLog "Parser hittades inte. Anvander fallback." "WARNING"
    return Get-FallbackFunctions
}

function Get-FallbackFunctions {
    return [PSCustomObject]@{
        Functions = @(
            @{ Function = 'Show-SpotifyForm'; Aliases = @('ShowSpotify', 'ss'); Description = 'Windows Form display' }
            @{ Function = 'Show-SpotifyLyricsForm'; Aliases = @('ShowLyrics', 'slw'); Description = 'Lyrics window' }
            @{ Function = 'Show-SpotifyTrack'; Aliases = @('plays-now', 'music', 'pn', 'sp'); Description = 'Show current track' }
            @{ Function = 'play'; Aliases = @(); Description = 'Resume playback' }
            @{ Function = 'pause'; Aliases = @(); Description = 'Pause playback' }
            @{ Function = 'next'; Aliases = @(); Description = 'Next track' }
            @{ Function = 'previous'; Aliases = @(); Description = 'Previous track' }
            @{ Function = 'volume'; Aliases = @('vol'); Description = 'Set volume' }
            @{ Function = 'shuffle'; Aliases = @('sh'); Description = 'Toggle shuffle' }
            @{ Function = 'repeat'; Aliases = @('rep'); Description = 'Set repeat mode' }
            @{ Function = 'devices'; Aliases = @(); Description = 'List devices' }
            @{ Function = 'transfer'; Aliases = @('tr'); Description = 'Transfer playback' }
            @{ Function = 'search'; Aliases = @(); Description = 'Search Spotify' }
            @{ Function = 'playlists'; Aliases = @('pl'); Description = 'Show playlists' }
            @{ Function = 'queue'; Aliases = @('q'); Description = 'Show/manage queue' }
            @{ Function = 'Start-SpotifyApp'; Aliases = @('spotify'); Description = 'Launch Spotify' }
            @{ Function = 'Get-SpotifyHelp'; Aliases = @('help', 'spotify-help'); Description = 'Show help' }
            @{ Function = 'Invoke-SpotifyApi'; Aliases = @(); Description = 'Core API function' }
        )
        TotalFunctions = 18
        TotalAliases = 15
        Success = $true
    }
}

# ============================================================================
# STEG 2: ANALYSERA MODULER
# ============================================================================

function Get-ModuleExports {
    Write-InstallLog "=== STEG 2: ANALYSERAR MODULER ===" "HEADER"

    $exports = @{
        Functions = @()
        Aliases = @()
        Modules = @()
    }

    # Hitta alla .psm1-filer
    $moduleFiles = Get-ChildItem -Path $script:ProjectRoot -Filter "*.psm1" -Recurse |
        Where-Object { $_.FullName -notmatch 'tests|backup|old' }

    Write-InstallLog "Hittade $($moduleFiles.Count) modulfiler" "INFO"

    foreach ($file in $moduleFiles) {
        $relativePath = $file.FullName.Replace($script:ProjectRoot, '').TrimStart('\', '/')

        try {
            $content = Get-Content $file.FullName -Raw

            # Hitta Export-ModuleMember statements
            $exportMatches = [regex]::Matches($content, 'Export-ModuleMember\s+(-Function\s+([^\s-]+(?:,\s*[^\s-]+)*))?(?:\s+-Alias\s+([^\s]+(?:,\s*[^\s]+)*))?')

            foreach ($match in $exportMatches) {
                # Extrahera funktioner
                if ($match.Groups[2].Success) {
                    $funcs = $match.Groups[2].Value -split ',\s*' | ForEach-Object { $_.Trim().Trim("'", '"') }
                    $exports.Functions += $funcs
                }

                # Extrahera alias
                if ($match.Groups[3].Success) {
                    $aliases = $match.Groups[3].Value -split ',\s*' | ForEach-Object { $_.Trim().Trim("'", '"') }
                    $exports.Aliases += $aliases
                }
            }

            # Hitta aven Set-Alias statements
            $aliasMatches = [regex]::Matches($content, "Set-Alias\s+-Name\s+([^\s]+)")
            foreach ($match in $aliasMatches) {
                $exports.Aliases += $match.Groups[1].Value.Trim("'", '"')
            }

            # Hitta funktionsdefinitioner
            $funcMatches = [regex]::Matches($content, 'function\s+([A-Za-z][A-Za-z0-9-]+)')
            foreach ($match in $funcMatches) {
                $funcName = $match.Groups[1].Value
                if ($funcName -notin $exports.Functions) {
                    # Lagg till om funktionen ser ut att vara publik (inte startar med _)
                    if (-not $funcName.StartsWith('_')) {
                        $exports.Functions += $funcName
                    }
                }
            }

            $exports.Modules += $relativePath

        } catch {
            Write-InstallLog "Kunde inte parsa $relativePath : $_" "WARNING"
        }
    }

    # Ta bort dubbletter
    $exports.Functions = $exports.Functions | Select-Object -Unique | Sort-Object
    $exports.Aliases = $exports.Aliases | Select-Object -Unique | Sort-Object

    Write-InstallLog "Hittade $($exports.Functions.Count) funktioner och $($exports.Aliases.Count) alias i modulerna" "SUCCESS"

    return $exports
}

# ============================================================================
# STEG 3: RENSA TIDIGARE INSTALLATIONER
# ============================================================================

function Clear-PreviousInstallation {
    Write-InstallLog "=== STEG 3: RENSAR TIDIGARE INSTALLATIONER ===" "HEADER"

    if ($SkipCleanup) {
        Write-InstallLog "Hoppar over rensning (SkipCleanup)" "INFO"
        return
    }

    # Ladda rensningsskriptet
    $cleanupPath = Join-Path $script:ProjectRoot "Clear-SpotifyCliInstallation.ps1"
    if (Test-Path $cleanupPath) {
        . $cleanupPath

        if ($PSCmdlet.ShouldProcess("Tidigare installationer", "Rensa")) {
            $result = Clear-SpotifyCliInstallation -Force:$Force
            Write-InstallLog "Rensning slutford. Borttagna moduler: $($result.RemovedModules.Count)" "SUCCESS"
        }
    } else {
        # Manuell rensning om skriptet inte finns
        $pathsToClean = @(
            (Join-Path $script:DocumentsPath "PowerShell\Modules\SpotifyCLI"),
            (Join-Path $script:DocumentsPath "PowerShell\Modules\SpotifyCommands"),
            (Join-Path $script:DocumentsPath "WindowsPowerShell\Modules\SpotifyCLI"),
            (Join-Path $script:DocumentsPath "WindowsPowerShell\Modules\SpotifyCommands")
        )

        foreach ($path in $pathsToClean) {
            if (Test-Path $path) {
                if ($PSCmdlet.ShouldProcess($path, "Ta bort")) {
                    Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
                    Write-InstallLog "Borttagen: $path" "SUCCESS"
                }
            }
        }
    }
}

# ============================================================================
# STEG 4: KOPIERA FILER
# ============================================================================

function Copy-ModuleFiles {
    Write-InstallLog "=== STEG 4: KOPIERAR FILER ===" "HEADER"

    # Skapa installationskatalog
    if (-not (Test-Path $script:InstallPath)) {
        if ($PSCmdlet.ShouldProcess($script:InstallPath, "Skapa katalog")) {
            New-Item -ItemType Directory -Path $script:InstallPath -Force | Out-Null
            Write-InstallLog "Skapade katalog: $script:InstallPath" "SUCCESS"
        }
    }

    # Filer och mappar att kopiera
    $itemsToCopy = @(
        @{ Source = "SpotifyCommands.psm1"; Dest = "SpotifyCommands.psm1" }
        @{ Source = "SpotifyModule.psm1"; Dest = "SpotifyModule.psm1" }
        @{ Source = "modules"; Dest = "modules"; IsDirectory = $true }
        @{ Source = ".env.example"; Dest = ".env.example" }
        @{ Source = "README.md"; Dest = "README.md" }
    )

    # Kopiera .env om den finns (men inte over befintlig)
    $envSource = Join-Path $script:ProjectRoot ".env"
    $envDest = Join-Path $script:InstallPath ".env"
    if ((Test-Path $envSource) -and -not (Test-Path $envDest)) {
        $itemsToCopy += @{ Source = ".env"; Dest = ".env" }
    }

    $copiedCount = 0
    foreach ($item in $itemsToCopy) {
        $sourcePath = Join-Path $script:ProjectRoot $item.Source
        $destPath = Join-Path $script:InstallPath $item.Dest

        if (Test-Path $sourcePath) {
            if ($PSCmdlet.ShouldProcess($sourcePath, "Kopiera till $destPath")) {
                try {
                    if ($item.IsDirectory) {
                        # Kopiera katalog rekursivt
                        if (Test-Path $destPath) {
                            Remove-Item -Path $destPath -Recurse -Force
                        }
                        Copy-Item -Path $sourcePath -Destination $destPath -Recurse -Force
                    } else {
                        Copy-Item -Path $sourcePath -Destination $destPath -Force
                    }
                    $copiedCount++
                    Write-InstallLog "Kopierade: $($item.Source)" "SUCCESS"
                } catch {
                    Write-InstallLog "Kunde inte kopiera $($item.Source): $_" "ERROR"
                }
            }
        } else {
            Write-InstallLog "Saknas: $($item.Source)" "WARNING"
        }
    }

    Write-InstallLog "Kopierade $copiedCount objekt till $script:InstallPath" "INFO"
}

# ============================================================================
# STEG 5: SKAPA MODULMANIFEST
# ============================================================================

function New-ModuleManifest {
    param(
        [array]$Functions,
        [array]$Aliases
    )

    Write-InstallLog "=== STEG 5: SKAPAR MODULMANIFEST ===" "HEADER"

    $manifestPath = Join-Path $script:InstallPath "SpotifyCommands.psd1"

    # Generera GUID om det inte finns
    $existingManifest = Join-Path $script:ProjectRoot "SpotifyCommands.psd1"
    $guid = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    if (Test-Path $existingManifest) {
        try {
            $existing = Import-PowerShellDataFile $existingManifest
            if ($existing.GUID) {
                $guid = $existing.GUID
            }
        } catch { }
    }

    # Filtrera funktioner - ta bara de som ar giltiga PowerShell-funktionsnamn
    $validFunctions = $Functions | Where-Object {
        $_ -match '^[A-Za-z][A-Za-z0-9-]*$' -and
        $_ -notmatch '^(if|else|while|for|foreach|switch|try|catch|function|param)$'
    } | Sort-Object -Unique

    # Filtrera alias
    $validAliases = $Aliases | Where-Object { $_ -and $_.Length -gt 0 } | Sort-Object -Unique

    # Lista over nested modules
    $nestedModules = @(
        'modules\SpotifyLiveFeatures.psm1'
        'modules\Core\ErrorHandling.psm1'
        'modules\Core\ApiClientManager.psm1'
        'modules\Core\LegacyApiClient.psm1'
        'modules\Core\StateManager.psm1'
        'modules\Core\LegacyConfigManager.psm1'
        'modules\Core\UIHelpers.psm1'
        'modules\Core\InteractiveMode.psm1'
        'modules\UI\SpotifyFormDisplay.psm1'
        'modules\UI\LyricsFormDisplay.psm1'
        'modules\Core\AppCommands.psm1'
        'modules\Core\PlaybackCommands.psm1'
        'modules\Core\SearchCommands.psm1'
        'modules\Core\PlaylistQueueCommands.psm1'
        'modules\Lyrics\LyricsEngine.psm1'
    )

    # Verifiera vilka nested modules som faktiskt finns
    $validNestedModules = @()
    foreach ($nm in $nestedModules) {
        $nmPath = Join-Path $script:InstallPath $nm
        if (Test-Path $nmPath) {
            $validNestedModules += $nm
        }
    }

    $manifestContent = @"
@{
    RootModule = 'SpotifyCommands.psm1'
    ModuleVersion = '$script:ModuleVersion'
    GUID = '$guid'
    Author = 'Spotify CLI Community'
    CompanyName = 'Community'
    Copyright = '(c) 2026. All rights reserved.'
    Description = 'Comprehensive Spotify CLI with live display, synchronized lyrics, Windows Form UI, and interactive controls for PowerShell'
    PowerShellVersion = '5.1'

    # Nested modules som laddas automatiskt
    NestedModules = @(
        $(($validNestedModules | ForEach-Object { "        '$_'" }) -join ",`n")
    )

    # Funktioner som exporteras
    FunctionsToExport = @(
        $(($validFunctions | ForEach-Object { "        '$_'" }) -join ",`n")
    )

    # Alias som exporteras
    AliasesToExport = @(
        $(($validAliases | ForEach-Object { "        '$_'" }) -join ",`n")
    )

    # Metadata for PowerShell Gallery
    PrivateData = @{
        PSData = @{
            Tags = @('Spotify', 'Music', 'CLI', 'Playback', 'Lyrics', 'Windows', 'Audio', 'Streaming', 'LiveFeatures')
            LicenseUri = 'https://github.com/spotify-cli/enhanced/blob/main/LICENSE.txt'
            ProjectUri = 'https://github.com/spotify-cli/enhanced'
            ReleaseNotes = @'
v$script:ModuleVersion - Windows Form Display Edition
- NEW: Windows Form display (ss command) with live updates
- NEW: Lyrics Form with synchronized highlighting (slw command)
- Enhanced interactive mode with arrow key navigation
- Improved alias management with -Force -Option AllScope
- PowerShell Gallery ready
'@
        }
    }
}
"@

    if ($PSCmdlet.ShouldProcess($manifestPath, "Skapa modulmanifest")) {
        Set-Content -Path $manifestPath -Value $manifestContent -Encoding UTF8
        Write-InstallLog "Skapade manifest med $($validFunctions.Count) funktioner och $($validAliases.Count) alias" "SUCCESS"
    }

    return @{
        Functions = $validFunctions
        Aliases = $validAliases
    }
}

# ============================================================================
# STEG 6: UPPDATERA PROFIL
# ============================================================================

function Update-PowerShellProfile {
    Write-InstallLog "=== STEG 6: UPPDATERAR POWERSHELL-PROFIL ===" "HEADER"

    $profilePath = $PROFILE.CurrentUserCurrentHost

    # Skapa profil om den inte finns
    if (-not (Test-Path $profilePath)) {
        $profileDir = Split-Path $profilePath -Parent
        if (-not (Test-Path $profileDir)) {
            New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
        }
        New-Item -ItemType File -Path $profilePath -Force | Out-Null
        Write-InstallLog "Skapade ny profil: $profilePath" "INFO"
    }

    $profileContent = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
    if (-not $profileContent) { $profileContent = "" }

    # Ta bort gamla Spotify-relaterade rader
    $patterns = @(
        '(?m)^.*Import-Module\s+.*Spotify.*$'
        '(?m)^#\s*Spotify\s*CLI.*$'
        '(?m)^.*SpotifyCommands.*$'
        '(?m)^.*SpotifyCLI.*$'
    )

    foreach ($pattern in $patterns) {
        $profileContent = $profileContent -replace $pattern, ''
    }

    # Ta bort tomma rader
    $profileContent = $profileContent -replace '(\r?\n){3,}', "`n`n"
    $profileContent = $profileContent.Trim()

    # Lagg till import-statement
    $importStatement = @"

# Spotify CLI - Live Features Edition v$script:ModuleVersion
Import-Module SpotifyCommands -Force -ErrorAction SilentlyContinue
"@

    $newContent = $profileContent + "`n" + $importStatement

    if ($PSCmdlet.ShouldProcess($profilePath, "Uppdatera profil")) {
        Set-Content -Path $profilePath -Value $newContent.Trim() -Encoding UTF8
        Write-InstallLog "Uppdaterade profil: $profilePath" "SUCCESS"
    }
}

# ============================================================================
# STEG 7: SKAPA ALIAS
# ============================================================================

function Set-SpotifyAliases {
    param(
        [array]$AliasDefinitions
    )

    Write-InstallLog "=== STEG 7: SKAPAR ALIAS ===" "HEADER"

    # Mappa alias till funktioner baserat pa README och modulanalys
    $aliasMap = @{
        'ss' = 'Show-SpotifyForm'
        'ShowSpotify' = 'Show-SpotifyForm'
        'slw' = 'Show-SpotifyLyricsForm'
        'ShowLyrics' = 'Show-SpotifyLyricsForm'
        'plays-now' = 'Show-SpotifyTrack'
        'music' = 'Show-SpotifyTrack'
        'pn' = 'Show-SpotifyTrack'
        'sp' = 'Show-SpotifyTrack'
        'vol' = 'volume'
        'sh' = 'shuffle'
        'rep' = 'repeat'
        'tr' = 'transfer'
        'pl' = 'playlists'
        'q' = 'queue'
        'spotify' = 'Start-SpotifyApp'
        'help' = 'Get-SpotifyHelp'
        'spotify-help' = 'Get-SpotifyHelp'
    }

    $createdCount = 0
    $failedCount = 0

    foreach ($alias in $aliasMap.Keys) {
        $target = $aliasMap[$alias]

        if ($PSCmdlet.ShouldProcess($alias, "Skapa alias till $target")) {
            try {
                Set-Alias -Name $alias -Value $target -Scope Global -Force -Option AllScope -ErrorAction Stop
                $createdCount++
            } catch {
                # Om funktionen inte finns an, logga varning
                Write-InstallLog "Kunde inte skapa alias '$alias' -> '$target': $_" "WARNING"
                $failedCount++
            }
        }
    }

    Write-InstallLog "Skapade $createdCount alias ($failedCount misslyckades)" "SUCCESS"

    return $aliasMap
}

# ============================================================================
# STEG 8: VERIFIERA INSTALLATION
# ============================================================================

function Test-Installation {
    param(
        [PSCustomObject]$ReadmeResult,
        [hashtable]$ModuleExports,
        [hashtable]$ManifestResult
    )

    Write-InstallLog "=== STEG 8: VERIFIERAR INSTALLATION ===" "HEADER"

    $results = @{
        ModuleLoaded = $false
        FunctionsAvailable = @()
        FunctionsMissing = @()
        AliasesAvailable = @()
        AliasesMissing = @()
        CriticalTests = @()
    }

    # Testa modulimport
    try {
        Import-Module $script:InstallPath -Force -ErrorAction Stop
        $results.ModuleLoaded = $true
        Write-InstallLog "Modulen laddades korrekt" "SUCCESS"
    } catch {
        Write-InstallLog "Kunde inte ladda modulen: $_" "ERROR"
        return $results
    }

    # Hamta tillgangliga kommandon
    $availableCommands = Get-Command -Module SpotifyCommands -ErrorAction SilentlyContinue
    $availableFunctions = ($availableCommands | Where-Object CommandType -eq 'Function').Name
    $availableAliases = ($availableCommands | Where-Object CommandType -eq 'Alias').Name

    # Kolla aven globala alias vi skapade
    $globalAliases = @('ss', 'slw', 'plays-now', 'music', 'pn', 'sp', 'vol', 'sh', 'rep', 'tr', 'pl', 'q', 'spotify', 'help', 'spotify-help', 'ShowSpotify', 'ShowLyrics')
    foreach ($alias in $globalAliases) {
        $existing = Get-Alias -Name $alias -ErrorAction SilentlyContinue
        if ($existing -and $alias -notin $availableAliases) {
            $availableAliases += $alias
        }
    }

    # Testa forvaantade funktioner fran README
    $expectedFunctions = $ReadmeResult.Functions | ForEach-Object { $_.Function } | Select-Object -Unique

    foreach ($func in $expectedFunctions) {
        $cmd = Get-Command -Name $func -ErrorAction SilentlyContinue
        if ($cmd) {
            $results.FunctionsAvailable += $func
        } else {
            $results.FunctionsMissing += $func
        }
    }

    # Testa forvaantade alias fran README
    $expectedAliases = $ReadmeResult.Functions | ForEach-Object { $_.Aliases } | Where-Object { $_ } | Select-Object -Unique

    foreach ($alias in $expectedAliases) {
        $cmd = Get-Command -Name $alias -ErrorAction SilentlyContinue
        if ($cmd) {
            $results.AliasesAvailable += $alias
        } else {
            $results.AliasesMissing += $alias
        }
    }

    # Kritiska tester
    $criticalCommands = @('ss', 'slw', 'play', 'pause', 'plays-now', 'music', 'playlists', 'search')
    foreach ($cmd in $criticalCommands) {
        $exists = Get-Command -Name $cmd -ErrorAction SilentlyContinue
        $results.CriticalTests += @{
            Command = $cmd
            Available = [bool]$exists
        }
    }

    return $results
}

# ============================================================================
# STEG 9: GENERERA RAPPORT
# ============================================================================

function Write-InstallationReport {
    param(
        [hashtable]$Results,
        [PSCustomObject]$ReadmeResult
    )

    Write-InstallLog "=== INSTALLATIONSRAPPORT ===" "HEADER"

    $totalExpected = $ReadmeResult.TotalFunctions
    $totalAvailable = $Results.FunctionsAvailable.Count
    $successRate = if ($totalExpected -gt 0) { [math]::Round(($totalAvailable / $totalExpected) * 100, 1) } else { 0 }

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  SPOTIFY CLI INSTALLATION COMPLETE" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Installation Path:    $script:InstallPath" -ForegroundColor White
    Write-Host "  Module Version:       $script:ModuleVersion" -ForegroundColor White
    Write-Host "  Module Loaded:        $(if ($Results.ModuleLoaded) { 'Yes' } else { 'No' })" -ForegroundColor $(if ($Results.ModuleLoaded) { 'Green' } else { 'Red' })
    Write-Host ""
    Write-Host "  Functions Expected:   $totalExpected" -ForegroundColor White
    Write-Host "  Functions Available:  $totalAvailable" -ForegroundColor $(if ($totalAvailable -eq $totalExpected) { 'Green' } else { 'Yellow' })
    Write-Host "  Functions Missing:    $($Results.FunctionsMissing.Count)" -ForegroundColor $(if ($Results.FunctionsMissing.Count -eq 0) { 'Green' } else { 'Yellow' })
    Write-Host ""
    Write-Host "  Aliases Expected:     $($ReadmeResult.TotalAliases)" -ForegroundColor White
    Write-Host "  Aliases Available:    $($Results.AliasesAvailable.Count)" -ForegroundColor $(if ($Results.AliasesAvailable.Count -ge $ReadmeResult.TotalAliases) { 'Green' } else { 'Yellow' })
    Write-Host ""
    Write-Host "  Success Rate:         $successRate%" -ForegroundColor $(if ($successRate -ge 90) { 'Green' } elseif ($successRate -ge 70) { 'Yellow' } else { 'Red' })
    Write-Host ""

    # Kritiska tester
    Write-Host "  Critical Commands:" -ForegroundColor Cyan
    foreach ($test in $Results.CriticalTests) {
        $status = if ($test.Available) { "[OK]" } else { "[MISSING]" }
        $color = if ($test.Available) { "Green" } else { "Red" }
        Write-Host "    $status $($test.Command)" -ForegroundColor $color
    }

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan

    # Saknade funktioner
    if ($Results.FunctionsMissing.Count -gt 0 -and $Results.FunctionsMissing.Count -le 10) {
        Write-Host ""
        Write-Host "  Missing Functions:" -ForegroundColor Yellow
        foreach ($func in $Results.FunctionsMissing) {
            Write-Host "    - $func" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "  Next Steps:" -ForegroundColor Cyan
    Write-Host "    1. Restart PowerShell or run: . `$PROFILE" -ForegroundColor White
    Write-Host "    2. Test with: ss (Windows Form display)" -ForegroundColor White
    Write-Host "    3. Get help: help or Get-SpotifyHelp" -ForegroundColor White
    Write-Host ""
    Write-Host "  Log File: $script:LogPath" -ForegroundColor Gray
    Write-Host ""

    # Spara rapport till fil
    $reportPath = Join-Path $script:DocumentsPath "PowerShell\INSTALLATION-STATUS.md"

    # Bygg rapport stegvis for att undvika here-string problem
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("# Spotify CLI Installation Status")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Installation Summary")
    [void]$sb.AppendLine("- **Date:** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$sb.AppendLine("- **PowerShell Version:** $($PSVersionTable.PSVersion)")
    [void]$sb.AppendLine("- **Installation Path:** $script:InstallPath")
    [void]$sb.AppendLine("- **Module Version:** $script:ModuleVersion")
    [void]$sb.AppendLine("- **Success Rate:** $successRate%")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Function Verification")
    [void]$sb.AppendLine("- **Expected:** $totalExpected functions")
    [void]$sb.AppendLine("- **Available:** $totalAvailable functions")
    [void]$sb.AppendLine("- **Missing:** $($Results.FunctionsMissing.Count) functions")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Critical Commands")

    foreach ($test in $Results.CriticalTests) {
        $status = if ($test.Available) { "OK" } else { "MISSING" }
        [void]$sb.AppendLine("- [$status] ``$($test.Command)``")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Missing Functions")

    if ($Results.FunctionsMissing.Count -gt 0) {
        foreach ($func in $Results.FunctionsMissing) {
            [void]$sb.AppendLine("- ``$func``")
        }
    } else {
        [void]$sb.AppendLine("None - all functions available!")
    }

    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("## Quick Start")
    [void]$sb.AppendLine('```powershell')
    [void]$sb.AppendLine("# Reload profile")
    [void]$sb.AppendLine('. $PROFILE')
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# Test Windows Form display")
    [void]$sb.AppendLine("ss")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# Show current track")
    [void]$sb.AppendLine("plays-now")
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("# Get help")
    [void]$sb.AppendLine("help")
    [void]$sb.AppendLine('```')
    [void]$sb.AppendLine("")
    [void]$sb.AppendLine("---")
    [void]$sb.AppendLine("*Generated by Install-SpotifyCLI-Complete.ps1*")

    $reportContent = $sb.ToString()
    Set-Content -Path $reportPath -Value $reportContent -Encoding UTF8
    Write-InstallLog "Rapport sparad: $reportPath" "INFO"
}

# ============================================================================
# MAIN
# ============================================================================

function Start-Installation {
    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host "  SPOTIFY CLI - KOMPLETT INSTALLATION v$script:ModuleVersion" -ForegroundColor Cyan
    Write-Host "================================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-InstallLog "Startar installation fran $script:ProjectRoot" "INFO"
    Write-InstallLog "Malplats: $script:InstallPath" "INFO"

    # Bekraftelse om inte Force
    if (-not $Force -and -not $WhatIfPreference) {
        Write-Host "  Detta kommer att:" -ForegroundColor Yellow
        Write-Host "    - Rensa tidigare Spotify CLI-installationer" -ForegroundColor White
        Write-Host "    - Installera till $script:InstallPath" -ForegroundColor White
        Write-Host "    - Uppdatera din PowerShell-profil" -ForegroundColor White
        Write-Host ""
        $response = Read-Host "  Fortsatt? (j/n)"
        if ($response -notmatch '^[jJyY]') {
            Write-Host "  Avbrutet." -ForegroundColor Yellow
            return
        }
    }

    # Steg 1: Parsa README
    $readmeResult = Get-ReadmeFunctions

    # Steg 2: Analysera moduler
    $moduleExports = Get-ModuleExports

    # Steg 3: Rensa tidigare installationer
    Clear-PreviousInstallation

    # Steg 4: Kopiera filer
    Copy-ModuleFiles

    # Steg 5: Skapa manifest
    $allFunctions = @($readmeResult.Functions | ForEach-Object { $_.Function }) + $moduleExports.Functions | Select-Object -Unique
    $allAliases = @($readmeResult.Functions | ForEach-Object { $_.Aliases } | Where-Object { $_ }) + $moduleExports.Aliases | Select-Object -Unique
    $manifestResult = New-ModuleManifest -Functions $allFunctions -Aliases $allAliases

    # Steg 6: Uppdatera profil
    Update-PowerShellProfile

    # Steg 7: Skapa alias (efter att modulen ar pa plats)
    # Ladda modulen forst
    try {
        Import-Module $script:InstallPath -Force -ErrorAction Stop
    } catch {
        Write-InstallLog "Varning: Kunde inte ladda modulen for alias-skapande: $_" "WARNING"
    }
    $aliasMap = Set-SpotifyAliases -AliasDefinitions $allAliases

    # Steg 8: Verifiera
    $verificationResults = Test-Installation -ReadmeResult $readmeResult -ModuleExports $moduleExports -ManifestResult $manifestResult

    # Steg 9: Generera rapport
    Write-InstallationReport -Results $verificationResults -ReadmeResult $readmeResult

    Write-InstallLog "Installation slutford!" "SUCCESS"
}

# Kor installation
Start-Installation

# Rensa upp testfil om den finns
$testFile = Join-Path $script:ProjectRoot "test-parse.ps1"
if (Test-Path $testFile) {
    Remove-Item $testFile -Force -ErrorAction SilentlyContinue
}
