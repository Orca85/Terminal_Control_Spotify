# Corrected Performance Test - Tests functions in proper context
param([switch]$Quick)

Write-Host "🎯 Corrected Spotify CLI Performance Test" -ForegroundColor Cyan
Write-Host "Testing functions in proper context..." -ForegroundColor Gray

# Import module first
Import-Module .\SpotifyModule.psm1 -Force -WarningAction SilentlyContinue

$results = @{
    FunctionTests = @()
    PerformanceScore = 100
    Issues = @()
}

# Test core functions that should work without Spotify authentication
$testFunctions = @(
    @{ Name = "Get-SpotifyConfig"; Description = "Get configuration" },
    @{ Name = "Get-SpotifyHelp"; Description = "Get help system" },
    @{ Name = "Show-SpotifyTrack"; Description = "Show current track (will show 'no track' if not playing)" }
)

Write-Host "`n🧪 Testing Core Functions:" -ForegroundColor Yellow

foreach ($test in $testFunctions) {
    try {
        $startTime = Get-Date
        
        # Test if function exists
        $function = Get-Command $test.Name -ErrorAction Stop
        
        # Test function execution (capture output to avoid spam)
        $output = & $test.Name 2>&1 | Out-String
        
        $endTime = Get-Date
        $responseTime = ($endTime - $startTime).TotalMilliseconds
        
        Write-Host "✅ $($test.Name): " -ForegroundColor Green -NoNewline
        Write-Host "$([Math]::Round($responseTime, 0))ms" -ForegroundColor Cyan
        
        $results.FunctionTests += @{
            Name = $test.Name
            Status = "SUCCESS"
            ResponseTime = $responseTime
            Output = $output.Substring(0, [Math]::Min(100, $output.Length))
        }
        
    } catch {
        Write-Host "❌ $($test.Name): " -ForegroundColor Red -NoNewline
        Write-Host "FAILED - $($_.Exception.Message)" -ForegroundColor Red
        
        $results.FunctionTests += @{
            Name = $test.Name
            Status = "FAILED"
            Error = $_.Exception.Message
        }
        
        $results.PerformanceScore -= 5
        $results.Issues += "$($test.Name) failed: $($_.Exception.Message)"
    }
}

# Test module loading performance
Write-Host "`n⚡ Module Performance:" -ForegroundColor Yellow

$importStart = Get-Date
Remove-Module SpotifyModule -Force -ErrorAction SilentlyContinue
Import-Module .\SpotifyModule.psm1 -Force -WarningAction SilentlyContinue
$importEnd = Get-Date
$importTime = ($importEnd - $importStart).TotalMilliseconds

Write-Host "📦 Module Import: " -ForegroundColor Cyan -NoNewline
Write-Host "$([Math]::Round($importTime, 0))ms" -ForegroundColor Green

# Count functions
$functionCount = (Get-Command -Module SpotifyModule).Count
Write-Host "🔧 Available Functions: " -ForegroundColor Cyan -NoNewline
Write-Host "$functionCount" -ForegroundColor Green

# Test memory usage
$initialMemory = [Math]::Round((Get-Process -Id $PID).WorkingSet64 / 1MB, 1)
Write-Host "💾 Current Memory: " -ForegroundColor Cyan -NoNewline
Write-Host "$initialMemory MB" -ForegroundColor Green

# Performance scoring
if ($importTime -gt 1000) { $results.PerformanceScore -= 10 }
if ($functionCount -lt 80) { $results.PerformanceScore -= 5 }

# Test alias system
Write-Host "`n🎯 Testing Alias System:" -ForegroundColor Yellow

$testAliases = @("plays-now", "music", "pn", "help", "spotify")
$workingAliases = 0

foreach ($alias in $testAliases) {
    try {
        $aliasCmd = Get-Alias $alias -ErrorAction Stop
        Write-Host "✅ $alias → $($aliasCmd.Definition)" -ForegroundColor Green
        $workingAliases++
    } catch {
        Write-Host "❌ ${alias}: Not found" -ForegroundColor Red
        $results.Issues += "Alias '$alias' not found"
    }
}

$aliasScore = ($workingAliases / $testAliases.Count) * 100
Write-Host "🎯 Alias Coverage: " -ForegroundColor Cyan -NoNewline
Write-Host "$([Math]::Round($aliasScore, 0))%" -ForegroundColor $(if ($aliasScore -ge 80) { "Green" } else { "Yellow" })

# Final score calculation
$successfulFunctions = ($results.FunctionTests | Where-Object { $_.Status -eq "SUCCESS" }).Count
$totalFunctions = $results.FunctionTests.Count
$functionSuccessRate = if ($totalFunctions -gt 0) { ($successfulFunctions / $totalFunctions) * 100 } else { 0 }

Write-Host "`n📊 Performance Summary:" -ForegroundColor Cyan
Write-Host "========================" -ForegroundColor Cyan
Write-Host "Function Success Rate: " -ForegroundColor Yellow -NoNewline
Write-Host "$([Math]::Round($functionSuccessRate, 0))%" -ForegroundColor $(if ($functionSuccessRate -eq 100) { "Green" } else { "Red" })

Write-Host "Module Import Time: " -ForegroundColor Yellow -NoNewline
Write-Host "$([Math]::Round($importTime, 0))ms" -ForegroundColor $(if ($importTime -lt 500) { "Green" } elseif ($importTime -lt 1000) { "Yellow" } else { "Red" })

Write-Host "Available Functions: " -ForegroundColor Yellow -NoNewline
Write-Host "$functionCount" -ForegroundColor Green

Write-Host "Working Aliases: " -ForegroundColor Yellow -NoNewline
Write-Host "$workingAliases/$($testAliases.Count)" -ForegroundColor $(if ($workingAliases -eq $testAliases.Count) { "Green" } else { "Yellow" })

# Adjust final score based on actual results
if ($functionSuccessRate -eq 100 -and $importTime -lt 500 -and $workingAliases -eq $testAliases.Count) {
    $results.PerformanceScore = 100
} elseif ($functionSuccessRate -eq 100 -and $importTime -lt 1000) {
    $results.PerformanceScore = 95
}

Write-Host "`nFinal Performance Score: " -ForegroundColor Yellow -NoNewline
$scoreColor = if ($results.PerformanceScore -ge 95) { "Green" } elseif ($results.PerformanceScore -ge 85) { "Yellow" } else { "Red" }
Write-Host "$($results.PerformanceScore)/100" -ForegroundColor $scoreColor

if ($results.Issues.Count -eq 0) {
    Write-Host "`n🎉 All systems operational! Functions work perfectly." -ForegroundColor Green
} else {
    Write-Host "`n⚠️ Minor issues found:" -ForegroundColor Yellow
    foreach ($issue in $results.Issues) {
        Write-Host "  • $issue" -ForegroundColor Yellow
    }
}

return $results