param(
    [Parameter(Position = 0)]
    [int]$Rounds = 5
)

& "$PSScriptRoot\spotifyCLI.ps1" -Quiz $Rounds
