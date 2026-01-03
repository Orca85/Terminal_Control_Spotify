# Legacy Configuration Manager Module
# Handles the simple configuration system for the main Spotify CLI module.

# --- Private Module State ---

# These variables are needed by the config functions.
$script:AppDataDir = Join-Path $env:APPDATA "SpotifyCLI"
$script:ConfigFile = Join-Path $script:AppDataDir "config.json"

$script:DefaultConfig = @{
    PreferredDevice = $null
    CompactMode = $false
    NotificationsEnabled = $false
    AutoRefreshInterval = 0
    LoggingEnabled = $false
    HistoryEnabled = $true
    MaxHistoryEntries = 100
    LogLevel = "Info"
    MaxLogSizeMB = 10
    LogRetentionDays = 30
    Colors = @{
        Playing = "Green"
        Paused = "Yellow"
        Track = "Cyan"
        Artist = "Yellow"
        Album = "Green"
        Progress = "Magenta"
    }
    Aliases = @{
        'spotify' = 'Start-SpotifyApp'
        'plays-now' = 'Show-SpotifyTrack'
        'music' = 'Show-SpotifyTrack'
        'pn' = 'Show-SpotifyTrack'
        'sp' = 'Show-SpotifyTrack'
        'vol' = 'volume'
        'sh' = 'shuffle'
        'rep' = 'repeat'
        'tr' = 'transfer'
        'q' = 'queue'
        'pl' = 'playlists'
        'help' = 'Get-SpotifyHelp'
    }
}


# --- Public Functions ---

function Get-SpotifyConfig {
    if (-not (Test-Path $script:ConfigFile)) {
        return $script:DefaultConfig.Clone()
    }
    try {
        $json = Get-Content -Path $script:ConfigFile -Raw -ErrorAction Stop
        $config = ($json | ConvertFrom-Json)
        $result = $script:DefaultConfig.Clone()
        $config.PSObject.Properties | ForEach-Object {
            if ($_.Name -eq "Colors" -and $_.Value) {
                $result.Colors = @{}
                $_.Value.PSObject.Properties | ForEach-Object {
                    $result.Colors[$_.Name] = $_.Value
                }
            } elseif ($_.Name -eq "Aliases" -and $_.Value) {
                $result.Aliases = @{}
                $_.Value.PSObject.Properties | ForEach-Object {
                    $result.Aliases[$_.Name] = $_.Value
                }
            } else {
                $result[$_.Name] = $_.Value
            }
        }
        return $result
    } catch {
        return $script:DefaultConfig.Clone()
    }
}

function Set-SpotifyConfig {
    param([hashtable]$Config)
    try {
        if (-not (Test-Path $script:AppDataDir)) {
            New-Item -ItemType Directory -Path $script:AppDataDir | Out-Null
        }
        ($Config | ConvertTo-Json -Depth 5) | Set-Content -Path $script:ConfigFile -Encoding UTF8
        return $true
    } catch {
        return $false
    }
}


# --- Module Exports ---

Export-ModuleMember -Function @(
    'Get-SpotifyConfig',
    'Set-SpotifyConfig'
)