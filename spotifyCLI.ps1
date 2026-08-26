<#
.SYNOPSIS
Spotify CLI for PowerShell — thin launcher wrapper.

.DESCRIPTION
Loads the SpotifyCLI module and calls Start-SpotifyCLI.
For PSGallery users: Install-Module SpotifyCLI, then call Start-SpotifyCLI directly.

.PARAMETER Sidecar
Launch in sidecar/split window mode if supported by the terminal.

.PARAMETER NewWindow
Force launch in a new window instead of split window.

.PARAMETER SplitDirection
Direction for split window (right, down, left, up). Windows Terminal only.

.PARAMETER Live
Launch directly into live display mode with real-time track updates.

.PARAMETER LiveMode
Display mode for live view: detailed (default), compact, or minimal.

.PARAMETER Setlist
Launch directly into setlist lookup for the given artist.

.PARAMETER Quiz
Launch directly into the music quiz with the given number of rounds.

.EXAMPLE
.\spotifyCLI.ps1
.\spotifyCLI.ps1 -Live -LiveMode compact
.\spotifyCLI.ps1 -Sidecar -SplitDirection down
.\spotifyCLI.ps1 -Setlist "Metallica"
.\spotifyCLI.ps1 -Quiz 10
#>

[CmdletBinding()]
param(
    [switch]$Sidecar,
    [switch]$NewWindow,
    [switch]$Live,
    [ValidateSet("right", "down", "left", "up")]
    [string]$SplitDirection = "right",
    [ValidateSet("detailed", "compact", "minimal")]
    [string]$LiveMode = "detailed",
    [string]$Setlist = "",
    [int]$Quiz = 0
)

$manifestPath = Join-Path $PSScriptRoot "SpotifyCLI.psd1"
if (-not (Test-Path $manifestPath)) {
    Write-Error "SpotifyCLI.psd1 not found in $PSScriptRoot. Run from the project root directory."
    exit 1
}

Import-Module $manifestPath -Force -ErrorAction Stop

Start-SpotifyCLI @PSBoundParameters
