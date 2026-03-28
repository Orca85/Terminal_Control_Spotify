# AliasManagement Module
# Functions for listing, removing, and checking Spotify CLI aliases.

# All known Spotify CLI aliases (from psd1 AliasesToExport + SpotifyCommands.psm1)
$script:KnownSpotifyAliases = @{
    'plays-now'    = 'Show-SpotifyTrack'
    'music'        = 'Show-SpotifyTrack'
    'pn'           = 'Show-SpotifyTrack'
    'sp'           = 'Show-SpotifyTrack'
    'pl'           = 'playlists'
    'vol'          = 'volume'
    'sh'           = 'shuffle'
    'rep'          = 'repeat'
    'tr'           = 'transfer'
    'q'            = 'queue'
    'pq'           = 'play-queue'
    'spotify'      = 'Start-SpotifyApp'
    'help'         = 'Get-SpotifyHelp'
    'spotify-help' = 'Get-SpotifyHelp'
    'slw'          = 'Show-LyricsForm'
    'ShowLyrics'   = 'Show-LyricsForm'
    'quiz'         = 'Start-MusicQuiz'
    'peak'         = 'Show-PeakDashboard'
    'setlist'      = 'Invoke-SetlistCommand'
    'commands'     = 'Show-AllSpotifyCommands'
    'ss'           = 'Show-SpotifyForm'
    'ShowSpotify'  = 'Show-SpotifyForm'
}

function Get-SpotifyAliases {
    <#
    .SYNOPSIS
    List all Spotify CLI aliases and whether they are currently active
    .DESCRIPTION
    Returns a table of all defined Spotify CLI aliases, their target commands,
    and whether the alias is registered in the current session.
    .EXAMPLE
    Get-SpotifyAliases
    Get-SpotifyAliases | Where-Object Active -eq $false
    #>
    $results = @()
    foreach ($name in ($script:KnownSpotifyAliases.Keys | Sort-Object)) {
        $target  = $script:KnownSpotifyAliases[$name]
        $current = Get-Alias -Name $name -ErrorAction SilentlyContinue
        $active  = $null -ne $current
        $results += [PSCustomObject]@{
            Alias  = $name
            Target = $target
            Active = $active
        }
    }

    Write-Host ""
    Write-Host "Spotify CLI Aliases" -ForegroundColor Cyan
    Write-Host "───────────────────────────────────────" -ForegroundColor DarkGray
    foreach ($r in $results) {
        $status = if ($r.Active) { "✅" } else { "  " }
        $color  = if ($r.Active) { 'White' } else { 'DarkGray' }
        Write-Host ("  {0} {1,-14} → {2}" -f $status, $r.Alias, $r.Target) -ForegroundColor $color
    }
    $activeCount = ($results | Where-Object Active).Count
    Write-Host ""
    Write-Host "  $activeCount of $($results.Count) aliases active in this session" -ForegroundColor Gray
    Write-Host ""

    return $results
}

function Remove-SpotifyAlias {
    <#
    .SYNOPSIS
    Remove a Spotify CLI alias from the current session
    .PARAMETER Name
    The alias name to remove (must be a known Spotify CLI alias)
    .EXAMPLE
    Remove-SpotifyAlias -Name 'help'
    Remove-SpotifyAlias -Name 'sp'
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    if (-not $script:KnownSpotifyAliases.ContainsKey($Name)) {
        Write-Host "❌ '$Name' is not a known Spotify CLI alias" -ForegroundColor Red
        Write-Host "   Run Get-SpotifyAliases to see all available aliases" -ForegroundColor Gray
        return $false
    }

    $existing = Get-Alias -Name $Name -ErrorAction SilentlyContinue
    if (-not $existing) {
        Write-Host "⚠️  Alias '$Name' is not active in this session" -ForegroundColor Yellow
        return $false
    }

    if ($PSCmdlet.ShouldProcess("Alias:\$Name", "Remove alias")) {
        try {
            Remove-Item -Path "Alias:\$Name" -Force -ErrorAction Stop
            Write-Host "✅ Removed alias '$Name'" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "❌ Failed to remove '$Name': $($_.Exception.Message)" -ForegroundColor Red
            return $false
        }
    }
    return $false
}

function Test-AliasConflicts {
    <#
    .SYNOPSIS
    Check if any Spotify CLI aliases conflict with built-in PowerShell commands
    .DESCRIPTION
    Compares all known Spotify aliases against native PowerShell commands and
    reports conflicts with a severity level (Critical = core PS command, Warning = other).
    .EXAMPLE
    Test-AliasConflicts
    #>
    # Built-in PS aliases/cmdlets that are risky to override
    $criticalCommands = @('help', 'q', 'sort', 'where', 'select', 'measure', 'group', 'format', 'out', 'write', 'read')

    $conflicts = @()
    foreach ($name in $script:KnownSpotifyAliases.Keys) {
        # Check if a non-Spotify command/alias exists with this name
        $existing = Get-Command -Name $name -ErrorAction SilentlyContinue
        if ($existing) {
            # Skip if it already points to our Spotify target
            $spotifyTarget = $script:KnownSpotifyAliases[$name]
            if ($existing.CommandType -eq 'Alias' -and $existing.Definition -eq $spotifyTarget) {
                continue
            }
            if ($existing.Name -eq $spotifyTarget) {
                continue
            }

            $severity = if ($criticalCommands -contains $name.ToLower()) { 'Critical' } else { 'Warning' }
            $conflicts += [PSCustomObject]@{
                Alias       = $name
                SpotifyTarget = $spotifyTarget
                ConflictsWith = $existing.Name
                ConflictType  = $existing.CommandType
                Severity      = $severity
            }
        }
    }

    Write-Host ""
    if ($conflicts.Count -eq 0) {
        Write-Host "✅ No alias conflicts detected" -ForegroundColor Green
    } else {
        Write-Host "Alias Conflicts Found: $($conflicts.Count)" -ForegroundColor Yellow
        Write-Host "────────────────────────────────────────────────" -ForegroundColor DarkGray
        foreach ($c in ($conflicts | Sort-Object Severity)) {
            $color = if ($c.Severity -eq 'Critical') { 'Red' } else { 'Yellow' }
            Write-Host "  [$($c.Severity)] '$($c.Alias)' → Spotify: $($c.SpotifyTarget)" -ForegroundColor $color
            Write-Host "         Conflicts with: $($c.ConflictsWith) ($($c.ConflictType))" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  Use Remove-SpotifyAlias to remove specific aliases" -ForegroundColor Gray
    }
    Write-Host ""

    return $conflicts
}

Export-ModuleMember -Function 'Get-SpotifyAliases', 'Remove-SpotifyAlias', 'Test-AliasConflicts'
