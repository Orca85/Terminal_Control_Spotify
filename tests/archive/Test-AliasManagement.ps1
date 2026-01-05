# Test Script for Spotify CLI Alias Management System
# Task 12.1 and 12.2 - Test alias creation, management, and conflict detection

Write-Host "🧪 Testing Spotify CLI Alias Management System" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""

# Import the Spotify module
try {
    Import-Module .\SpotifyModule.psm1 -Force
    Write-Host "✅ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 12.1: Test alias creation and management
Write-Host "📋 Task 12.1: Testing alias creation and management" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

# Test 1: Get current aliases
Write-Host ""
Write-Host "🔍 Test 1: Getting current aliases" -ForegroundColor Cyan
try {
    Get-SpotifyAliases
    Write-Host "✅ Get-SpotifyAliases executed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Get-SpotifyAliases failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue to alias creation test..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 2: Create a new alias
Write-Host ""
Write-Host "🔍 Test 2: Creating new alias 'music' → 'Show-SpotifyTrack'" -ForegroundColor Cyan
try {
    Set-SpotifyAlias -Alias 'music' -Command 'Show-SpotifyTrack'
    Write-Host "✅ Set-SpotifyAlias executed successfully" -ForegroundColor Green
    
    # Verify the alias was created
    Write-Host ""
    Write-Host "Verifying alias creation:" -ForegroundColor Gray
    Get-SpotifyAliases
    
    # Test if the alias function exists
    $aliasFunction = Get-Command -Name 'music' -ErrorAction SilentlyContinue
    if ($aliasFunction) {
        Write-Host "✅ Alias function 'music' created successfully" -ForegroundColor Green
        Write-Host "   Type: $($aliasFunction.CommandType)" -ForegroundColor Gray
        Write-Host "   Source: $($aliasFunction.Source)" -ForegroundColor Gray
    } else {
        Write-Host "❌ Alias function 'music' not found" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Set-SpotifyAlias failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue to alias testing..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 3: Test the created alias (if possible without Spotify API)
Write-Host ""
Write-Host "🔍 Test 3: Testing created alias functionality" -ForegroundColor Cyan
try {
    Write-Host "Attempting to call 'music' alias (may fail without Spotify auth):" -ForegroundColor Gray
    music
    Write-Host "✅ Alias 'music' executed (check output above for results)" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Alias 'music' execution failed (expected without Spotify auth): $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to continue to alias removal test..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 4: Create another alias for testing
Write-Host ""
Write-Host "🔍 Test 4: Creating additional test alias 'testplay' → 'play'" -ForegroundColor Cyan
try {
    Set-SpotifyAlias -Alias 'testplay' -Command 'play'
    Write-Host "✅ Additional alias created successfully" -ForegroundColor Green
    
    Write-Host ""
    Write-Host "Current aliases after addition:" -ForegroundColor Gray
    Get-SpotifyAliases
    
} catch {
    Write-Host "❌ Additional alias creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue to alias removal test..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 5: Remove an alias
Write-Host ""
Write-Host "🔍 Test 5: Removing alias 'music'" -ForegroundColor Cyan
try {
    Remove-SpotifyAlias -Alias 'music'
    Write-Host "✅ Remove-SpotifyAlias executed successfully" -ForegroundColor Green
    
    # Verify the alias was removed
    Write-Host ""
    Write-Host "Verifying alias removal:" -ForegroundColor Gray
    Get-SpotifyAliases
    
    # Test if the alias function still exists
    $aliasFunction = Get-Command -Name 'music' -ErrorAction SilentlyContinue
    if ($aliasFunction) {
        Write-Host "⚠️ Alias function 'music' still exists" -ForegroundColor Yellow
        Write-Host "   Type: $($aliasFunction.CommandType)" -ForegroundColor Gray
        Write-Host "   Source: $($aliasFunction.Source)" -ForegroundColor Gray
    } else {
        Write-Host "✅ Alias function 'music' successfully removed" -ForegroundColor Green
    }
    
} catch {
    Write-Host "❌ Remove-SpotifyAlias failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue to conflict detection tests..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 12.2: Test alias conflict detection
Write-Host ""
Write-Host "📋 Task 12.2: Testing alias conflict detection" -ForegroundColor Yellow
Write-Host "-" * 50 -ForegroundColor Gray

# Test 6: Run conflict detection on current aliases
Write-Host ""
Write-Host "🔍 Test 6: Testing conflict detection with current aliases" -ForegroundColor Cyan
try {
    Test-AliasConflicts
    Write-Host "✅ Test-AliasConflicts executed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Test-AliasConflicts failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue to conflict creation test..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 7: Create an alias that conflicts with PowerShell commands
Write-Host ""
Write-Host "🔍 Test 7: Creating alias that conflicts with PowerShell built-in" -ForegroundColor Cyan
Write-Host "Attempting to create alias 'ls' → 'Show-SpotifyTrack' (should conflict)" -ForegroundColor Gray

try {
    Set-SpotifyAlias -Alias 'ls' -Command 'Show-SpotifyTrack'
    Write-Host "⚠️ Conflicting alias created (this may cause issues)" -ForegroundColor Yellow
    
    # Check what 'ls' command points to now
    $lsCommand = Get-Command -Name 'ls' -ErrorAction SilentlyContinue
    if ($lsCommand) {
        Write-Host "Current 'ls' command details:" -ForegroundColor Gray
        Write-Host "   Name: $($lsCommand.Name)" -ForegroundColor Gray
        Write-Host "   Type: $($lsCommand.CommandType)" -ForegroundColor Gray
        Write-Host "   Source: $($lsCommand.Source)" -ForegroundColor Gray
    }
    
} catch {
    Write-Host "❌ Conflicting alias creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue to conflict detection after creation..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 8: Run conflict detection after creating conflicting alias
Write-Host ""
Write-Host "🔍 Test 8: Testing conflict detection after creating conflicting alias" -ForegroundColor Cyan
try {
    Test-AliasConflicts
    Write-Host "✅ Conflict detection completed" -ForegroundColor Green
} catch {
    Write-Host "❌ Conflict detection failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue to conflict prevention test..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 9: Test another common PowerShell command conflict
Write-Host ""
Write-Host "🔍 Test 9: Testing conflict with 'cd' command" -ForegroundColor Cyan
Write-Host "Attempting to create alias 'cd' → 'devices' (should conflict)" -ForegroundColor Gray

try {
    Set-SpotifyAlias -Alias 'cd' -Command 'devices'
    Write-Host "⚠️ Another conflicting alias created" -ForegroundColor Yellow
} catch {
    Write-Host "❌ Conflicting alias creation failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Run conflict detection again
Write-Host ""
Write-Host "Running conflict detection after multiple conflicts:" -ForegroundColor Gray
try {
    Test-AliasConflicts
} catch {
    Write-Host "❌ Final conflict detection failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "Press any key to continue to cleanup..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

# Test 10: Clean up test aliases
Write-Host ""
Write-Host "🔍 Test 10: Cleaning up test aliases" -ForegroundColor Cyan

$testAliases = @('testplay', 'ls', 'cd')
foreach ($alias in $testAliases) {
    try {
        Write-Host "Removing test alias: $alias" -ForegroundColor Gray
        Remove-SpotifyAlias -Alias $alias
        Write-Host "✅ Removed $alias" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Failed to remove $alias : $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "Final alias state:" -ForegroundColor Gray
try {
    Get-SpotifyAliases
} catch {
    Write-Host "❌ Failed to get final alias state: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎯 Alias Management Testing Complete!" -ForegroundColor Green
Write-Host "=" * 60 -ForegroundColor Gray
Write-Host ""
Write-Host "📊 Test Summary:" -ForegroundColor Cyan
Write-Host "✅ Task 12.1: Alias creation and management functions tested" -ForegroundColor Green
Write-Host "✅ Task 12.2: Conflict detection functionality tested" -ForegroundColor Green
Write-Host ""
Write-Host "💡 Key findings will be displayed above. Review the output to verify:" -ForegroundColor Yellow
Write-Host "   - Set-SpotifyAlias creates aliases correctly" -ForegroundColor White
Write-Host "   - Get-SpotifyAliases displays current aliases" -ForegroundColor White
Write-Host "   - Remove-SpotifyAlias removes aliases properly" -ForegroundColor White
Write-Host "   - Test-AliasConflicts detects PowerShell command conflicts" -ForegroundColor White
Write-Host "   - Conflict prevention works as expected" -ForegroundColor White
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")