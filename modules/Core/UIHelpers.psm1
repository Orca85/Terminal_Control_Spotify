# UIHelpers Module
# Contains helper functions for formatting output, showing progress, and managing colors.

function Format-Time {
    param([int]$ms)
    $totalSec = [int][Math]::Round($ms / 1000.0)
    $m = [Math]::Floor($totalSec / 60)
    $s = $totalSec % 60
    "{0}:{1:D2}" -f $m, $s
}

function Show-ProgressBar {
    param([int]$Current, [int]$Total, [int]$Width = 30)
    if ($Total -le 0) { return "[$("░" * $Width)] 0%" }
    $percentage = [Math]::Round(($Current / $Total) * 100)
    $filled = [Math]::Round(($Current / $Total) * $Width)
    $empty = $Width - $filled
    if ($filled -gt $Width) { $filled = $Width; $empty = 0 }
    if ($filled -lt 0) { $filled = 0; $empty = $Width }
    $bar = "█" * $filled + "░" * $empty
    return "[$bar] $percentage%"
}

function Get-StatusColor {
    param([bool]$IsPlaying)
    $config = Get-SpotifyConfig
    if ($IsPlaying) {
        return $config.Colors.Playing
    } else {
        return $config.Colors.Paused
    }
}

function Get-TrackColor {
    $config = Get-SpotifyConfig
    return $config.Colors.Track
}

function Get-ArtistColor {
    $config = Get-SpotifyConfig
    return $config.Colors.Artist
}

function Get-AlbumColor {
    $config = Get-SpotifyConfig
    return $config.Colors.Album
}

function Get-ProgressColor {
    $config = Get-SpotifyConfig
    return $config.Colors.Progress
}

Export-ModuleMember -Function @(
    'Format-Time',
    'Show-ProgressBar',
    'Get-StatusColor',
    'Get-TrackColor',
    'Get-ArtistColor',
    'Get-AlbumColor',
    'Get-ProgressColor'
)