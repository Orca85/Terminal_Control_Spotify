param(
    [Parameter(Position = 0, ValueFromRemainingArguments)]
    [string[]]$Artist
)

$artistName = ($Artist -join " ").Trim()

& "$PSScriptRoot\spotifyCLI.ps1" -Setlist $artistName
