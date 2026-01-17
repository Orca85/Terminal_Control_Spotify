# Fix Set-Alias warnings by adding -ErrorAction SilentlyContinue
$files = @(
    'C:\Users\tommy\Documents\PowerShell\Modules\SpotifyCommands\SpotifyModule.psm1',
    'C:\Users\tommy\Documents\PowerShell\Modules\SpotifyCommands\SpotifyCommands.psm1',
    'C:\Users\tommy\Documents\PowerShell\Modules\SpotifyCommands\modules\UI\SpotifyFormDisplay.psm1'
)

foreach ($file in $files) {
    if (Test-Path $file) {
        $content = Get-Content $file -Raw

        # Add -ErrorAction SilentlyContinue to Set-Alias commands that don't have it
        $patterns = @(
            @{ Find = 'Set-Alias -Name (\w+) -Value ([\w-]+) -Force\r?\n'; Replace = 'Set-Alias -Name $1 -Value $2 -Force -ErrorAction SilentlyContinue' + "`n" }
            @{ Find = 'Set-Alias -Name (\w+) -Value ([\w-]+) -Force -Scope Global\r?\n'; Replace = 'Set-Alias -Name $1 -Value $2 -Force -Scope Global -ErrorAction SilentlyContinue' + "`n" }
            @{ Find = 'Set-Alias -Name (\w+) -Value ([\w-]+)\r?\n'; Replace = 'Set-Alias -Name $1 -Value $2 -ErrorAction SilentlyContinue' + "`n" }
        )

        foreach ($p in $patterns) {
            $content = $content -replace $p.Find, $p.Replace
        }

        Set-Content $file -Value $content -NoNewline
        Write-Host "Fixed: $file" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Done! Restart PowerShell to see the changes." -ForegroundColor Cyan
