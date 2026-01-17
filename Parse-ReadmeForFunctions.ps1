function Parse-ReadmeForFunctions {
    <#
    .SYNOPSIS
    Parsar README.md för att extrahera alla dokumenterade funktioner och alias.

    .DESCRIPTION
    Läser README.md och extraherar alla funktioner och alias från markdown-tabeller.
    Returnerar en strukturerad lista som kan användas för installationsverifiering.

    .PARAMETER ReadmePath
    Sökväg till README.md. Standard är README.md i samma mapp.

    .PARAMETER IncludeFallback
    Inkludera fallback-lista med kritiska funktioner om parsning misslyckas.

    .OUTPUTS
    PSCustomObject med egenskaper:
    - Functions: Array av funktionsobjekt med Function, Aliases, Description, Section
    - TotalFunctions: Antal unika funktioner
    - TotalAliases: Antal alias
    - ParsedSections: Vilka sektioner som parsades
    - Success: Boolean om parsningen lyckades

    .EXAMPLE
    $result = Parse-ReadmeForFunctions
    $result.Functions | Format-Table Function, Aliases
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$ReadmePath = (Join-Path $PSScriptRoot "README.md"),

        [Parameter()]
        [switch]$IncludeFallback
    )

    # Fallback-lista med kritiska funktioner
    $fallbackFunctions = @(
        @{ Function = 'Show-SpotifyForm'; Aliases = @('ShowSpotify', 'ss'); Description = 'Windows Form display'; Section = 'Fallback' }
        @{ Function = 'Show-SpotifyLyricsForm'; Aliases = @('ShowLyrics', 'slw'); Description = 'Lyrics window'; Section = 'Fallback' }
        @{ Function = 'Show-SpotifyTrack'; Aliases = @('plays-now', 'music', 'pn', 'sp'); Description = 'Show current track'; Section = 'Fallback' }
        @{ Function = 'play'; Aliases = @(); Description = 'Resume playback'; Section = 'Fallback' }
        @{ Function = 'pause'; Aliases = @(); Description = 'Pause playback'; Section = 'Fallback' }
        @{ Function = 'next'; Aliases = @(); Description = 'Next track'; Section = 'Fallback' }
        @{ Function = 'previous'; Aliases = @(); Description = 'Previous track'; Section = 'Fallback' }
        @{ Function = 'volume'; Aliases = @('vol'); Description = 'Set volume'; Section = 'Fallback' }
        @{ Function = 'shuffle'; Aliases = @('sh'); Description = 'Toggle shuffle'; Section = 'Fallback' }
        @{ Function = 'repeat'; Aliases = @('rep'); Description = 'Set repeat mode'; Section = 'Fallback' }
        @{ Function = 'devices'; Aliases = @(); Description = 'List devices'; Section = 'Fallback' }
        @{ Function = 'transfer'; Aliases = @('tr'); Description = 'Transfer playback'; Section = 'Fallback' }
        @{ Function = 'search'; Aliases = @(); Description = 'Search Spotify'; Section = 'Fallback' }
        @{ Function = 'playlists'; Aliases = @('pl'); Description = 'Show playlists'; Section = 'Fallback' }
        @{ Function = 'queue'; Aliases = @('q'); Description = 'Show/manage queue'; Section = 'Fallback' }
        @{ Function = 'Start-SpotifyApp'; Aliases = @('spotify'); Description = 'Launch Spotify'; Section = 'Fallback' }
        @{ Function = 'Get-SpotifyHelp'; Aliases = @('help', 'spotify-help'); Description = 'Show help'; Section = 'Fallback' }
        @{ Function = 'Invoke-SpotifyApi'; Aliases = @(); Description = 'Core API function'; Section = 'Fallback' }
        @{ Function = 'Initialize-SpotifyLiveFeatures'; Aliases = @(); Description = 'Initialize live features'; Section = 'Fallback' }
        @{ Function = 'Get-SpotifyLyrics'; Aliases = @(); Description = 'Get lyrics'; Section = 'Fallback' }
    )

    $result = [PSCustomObject]@{
        Functions = @()
        TotalFunctions = 0
        TotalAliases = 0
        ParsedSections = @()
        Success = $false
        Errors = @()
    }

    # Kontrollera att README.md finns
    if (-not (Test-Path $ReadmePath)) {
        $result.Errors += "README.md hittades inte: $ReadmePath"
        if ($IncludeFallback) {
            Write-Warning "README.md hittades inte. Använder fallback-lista med $($fallbackFunctions.Count) kritiska funktioner."
            $result.Functions = $fallbackFunctions
            $result.TotalFunctions = $fallbackFunctions.Count
            $result.TotalAliases = ($fallbackFunctions | ForEach-Object { $_.Aliases.Count } | Measure-Object -Sum).Sum
            $result.ParsedSections = @('Fallback')
        }
        return $result
    }

    try {
        $readmeContent = Get-Content $ReadmePath -Raw -Encoding UTF8
        $lines = Get-Content $ReadmePath -Encoding UTF8

        $parsedFunctions = @()
        $currentSection = "Unknown"
        $inTable = $false
        $tableFormat = $null  # 'with-aliases' eller 'no-aliases'

        foreach ($line in $lines) {
            # Detektera sektionsrubriker
            if ($line -match '^#{2,4}\s+(.+)$') {
                $currentSection = $Matches[1].Trim()
                $inTable = $false
                $tableFormat = $null
                continue
            }

            # Detektera tabellhuvud
            if ($line -match '^\|\s*Function\s*\|') {
                $inTable = $true

                # Bestäm tabellformat baserat på kolumner
                if ($line -match '^\|\s*Function\s*\|\s*Aliases\s*\|') {
                    $tableFormat = 'with-aliases'
                } else {
                    $tableFormat = 'no-aliases'
                }

                if ($currentSection -notin $result.ParsedSections) {
                    $result.ParsedSections += $currentSection
                }
                continue
            }

            # Hoppa över separator-rader (|---|---|)
            if ($line -match '^\|[\s\-:]+\|') {
                continue
            }

            # Parsa tabellrader
            if ($inTable -and $line -match '^\|') {
                # Dela upp raden i kolumner
                $columns = $line -split '\|' | Where-Object { $_.Trim() -ne '' } | ForEach-Object { $_.Trim() }

                if ($columns.Count -ge 2) {
                    $functionName = $null
                    $aliases = @()
                    $description = ""

                    # Extrahera funktionsnamn från första kolumnen (ta bort backticks)
                    if ($columns[0] -match '`([^`]+)`') {
                        $functionName = $Matches[1]
                    } elseif ($columns[0] -notmatch '^\s*-\s*$' -and $columns[0] -notmatch 'Interactive Mode') {
                        # Funktionsnamn utan backticks (hoppa över "-" och "Interactive Mode")
                        $functionName = $columns[0].Trim()
                    }

                    if ($functionName) {
                        if ($tableFormat -eq 'with-aliases') {
                            # Format: | Function | Aliases | Description | Example |
                            if ($columns.Count -ge 3) {
                                # Extrahera alias (kan vara kommaseparerade i backticks, eller "-")
                                $aliasColumn = $columns[1]
                                if ($aliasColumn -notmatch '^\s*-\s*$') {
                                    # Hitta alla alias i backticks
                                    $aliasMatches = [regex]::Matches($aliasColumn, '`([^`]+)`')
                                    foreach ($match in $aliasMatches) {
                                        $aliases += $match.Groups[1].Value
                                    }
                                }
                                $description = $columns[2]
                            }
                        } else {
                            # Format: | Function | Description | Example |
                            if ($columns.Count -ge 2) {
                                $description = $columns[1]
                            }
                        }

                        $parsedFunctions += @{
                            Function = $functionName
                            Aliases = $aliases
                            Description = $description
                            Section = $currentSection
                        }
                    }
                }
            }

            # Avsluta tabell vid tom rad eller ny sektion
            if ($inTable -and ($line -match '^\s*$' -or $line -match '^---')) {
                $inTable = $false
                $tableFormat = $null
            }
        }

        # Parsa även funktioner som listas utanför tabeller (i "Advanced Features" sektionen)
        $advancedFunctionPatterns = @(
            @{ Pattern = 'Start-SpotifyCliInSidecar'; Description = 'Open CLI in split window' }
            @{ Pattern = 'Start-SpotifyCliInNewWindow'; Description = 'Open CLI in new window' }
            @{ Pattern = 'Test-SplitWindowSupport'; Description = 'Check split window support' }
            @{ Pattern = 'Show-TerminalCapabilities'; Description = 'Display terminal capabilities' }
            @{ Pattern = 'Test-NotificationSupport'; Description = 'Test notification system' }
            @{ Pattern = 'Install-SpotifyCliDependencies'; Description = 'Install required modules' }
            @{ Pattern = 'Repair-SpotifyCliInstallation'; Description = 'Fix installation issues' }
            @{ Pattern = 'Uninstall-SpotifyCli'; Description = 'Remove CLI completely' }
            @{ Pattern = 'Test-SpotifyAuth'; Description = 'Check authentication status' }
            @{ Pattern = 'Get-SpotifyCliTroubleshootingGuide'; Description = 'Cross-platform troubleshooting' }
        )

        foreach ($advFunc in $advancedFunctionPatterns) {
            if ($readmeContent -match $advFunc.Pattern) {
                # Kontrollera att funktionen inte redan finns
                $exists = $parsedFunctions | Where-Object { $_.Function -eq $advFunc.Pattern }
                if (-not $exists) {
                    $parsedFunctions += @{
                        Function = $advFunc.Pattern
                        Aliases = @()
                        Description = $advFunc.Description
                        Section = 'Advanced Features'
                    }
                    if ('Advanced Features' -notin $result.ParsedSections) {
                        $result.ParsedSections += 'Advanced Features'
                    }
                }
            }
        }

        # Lägg till lyrics-alias som dokumenteras i README
        $lyricsFunc = $parsedFunctions | Where-Object { $_.Function -eq 'Get-SpotifyLyrics' }
        if ($lyricsFunc -and $readmeContent -match 'slw.*Show Lyrics Window|ShowLyrics') {
            # Lägg till Show-SpotifyLyricsForm om den inte finns
            $lyricsFormExists = $parsedFunctions | Where-Object { $_.Function -eq 'Show-SpotifyLyricsForm' }
            if (-not $lyricsFormExists) {
                $parsedFunctions += @{
                    Function = 'Show-SpotifyLyricsForm'
                    Aliases = @('ShowLyrics', 'slw')
                    Description = 'Windows Form with live synchronized lyrics'
                    Section = 'Lyrics Engine'
                }
            }
        }

        $result.Functions = $parsedFunctions
        $result.TotalFunctions = $parsedFunctions.Count
        $result.TotalAliases = ($parsedFunctions | ForEach-Object { $_.Aliases.Count } | Measure-Object -Sum).Sum
        $result.Success = $parsedFunctions.Count -gt 0

        # Varning om färre än 90 funktioner hittades
        if ($parsedFunctions.Count -lt 90) {
            $result.Errors += "Varning: Endast $($parsedFunctions.Count) funktioner hittades (förväntat ~98). Parsningen kan vara ofullständig."
        }

    } catch {
        $result.Errors += "Fel vid parsning: $_"
        if ($IncludeFallback) {
            Write-Warning "Parsning misslyckades. Använder fallback-lista."
            $result.Functions = $fallbackFunctions
            $result.TotalFunctions = $fallbackFunctions.Count
            $result.TotalAliases = ($fallbackFunctions | ForEach-Object { $_.Aliases.Count } | Measure-Object -Sum).Sum
            $result.ParsedSections = @('Fallback')
        }
    }

    return $result
}

function Show-ParsedFunctions {
    <#
    .SYNOPSIS
    Visar parsade funktioner i en formaterad tabell.

    .PARAMETER ParseResult
    Resultat från Parse-ReadmeForFunctions.

    .EXAMPLE
    $result = Parse-ReadmeForFunctions
    Show-ParsedFunctions -ParseResult $result
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$ParseResult
    )

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  README.md PARSING RESULTS                                 ║" -ForegroundColor Cyan
    Write-Host "╠════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "║  Totalt funktioner: $($ParseResult.TotalFunctions.ToString().PadRight(37))║" -ForegroundColor White
    Write-Host "║  Totalt alias: $($ParseResult.TotalAliases.ToString().PadRight(42))║" -ForegroundColor White
    Write-Host "║  Parsade sektioner: $($ParseResult.ParsedSections.Count.ToString().PadRight(37))║" -ForegroundColor White
    Write-Host "║  Status: $(if ($ParseResult.Success) { 'OK'.PadRight(48) } else { 'MISSLYCKADES'.PadRight(48) })║" -ForegroundColor $(if ($ParseResult.Success) { 'Green' } else { 'Red' })
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""

    if ($ParseResult.Errors.Count -gt 0) {
        Write-Host "Varningar/Fel:" -ForegroundColor Yellow
        foreach ($error in $ParseResult.Errors) {
            Write-Host "  - $error" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    Write-Host "Parsade sektioner:" -ForegroundColor Cyan
    foreach ($section in $ParseResult.ParsedSections) {
        $count = ($ParseResult.Functions | Where-Object { $_.Section -eq $section }).Count
        Write-Host "  - $section ($count funktioner)" -ForegroundColor Gray
    }
    Write-Host ""

    # Gruppera efter sektion
    $grouped = $ParseResult.Functions | Group-Object Section

    foreach ($group in $grouped) {
        Write-Host "── $($group.Name) ──" -ForegroundColor Yellow
        foreach ($func in $group.Group) {
            $aliasStr = if ($func.Aliases.Count -gt 0) { " → $($func.Aliases -join ', ')" } else { "" }
            Write-Host "  ✓ $($func.Function)$aliasStr" -ForegroundColor Green
        }
        Write-Host ""
    }
}

# Om skriptet körs direkt (inte importeras som modul), kör parsning och visa resultat
if ($MyInvocation.InvocationName -notmatch '^\.' -and $MyInvocation.Line -notmatch 'Import-Module') {
    Write-Host "Kör README.md-parsning..." -ForegroundColor Cyan
    $result = Parse-ReadmeForFunctions -IncludeFallback
    Show-ParsedFunctions -ParseResult $result

    # Returnera resultat för pipeline-användning
    $result
}
