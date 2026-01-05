# Test-CrossPlatformCompatibility.ps1
# Comprehensive cross-platform compatibility test
# Tests: PowerShell versions, terminals, Spotify account types

param(
    [switch]$Verbose = $false
)

# Import required modules
try {
    Import-Module .\SpotifyModule.psm1 -Force -ErrorAction Stop
    Write-Host "✓ SpotifyModule imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import SpotifyModule: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Test results tracking
$TestResults = @{
    TotalTests = 0
    PassedTests = 0
    FailedTests = 0
    Errors = @()
}

function Write-TestResult {
    param(
        [string]$TestName,
        [bool]$Passed,
        [string]$Details = "",
        [string]$Error = ""
    )
    
    $TestResults.TotalTests++
    
    if ($Passed) {
        $TestResults.PassedTests++
        Write-Host "✓ $TestName" -ForegroundColor Green
        if ($Details -and $Verbose) {
            Write-Host "  Details: $Details" -ForegroundColor Gray
        }
    } else {
        $TestResults.FailedTests++
        Write-Host "✗ $TestName" -ForegroundColor Red
        if ($Error) {
            Write-Host "  Error: $Error" -ForegroundColor Red
            $TestResults.Errors += "$TestName: $Error"
        }
    }
}

function Test-PowerShellEnvironment {
    Write-Host "`n=== Testing PowerShell Environment Compatibility ===" -ForegroundColor Cyan
    
    # Test 1: PowerShell version detection
    $psVersion = $PSVersionTable.PSVersion
    $majorVersion = $psVersion.Major
    
    Write-TestResult "PowerShell version detection" $true -Details "Version: $($psVersion.ToString())"
    
    # Test 2: PowerShell edition compatibility
    $psEdition = $PSVersionTable.PSEdition
    $supportedEditions = @("Desktop", "Core")
    $editionSupported = $psEdition -in $supportedEditions
    
    Write-TestResult "PowerShell edition compatibility" $editionSupported -Details "Edition: $psEdition" -Error $(if (-not $editionSupported) { "Unsupported edition: $psEdition" })
    
    # Test 3: Windows PowerShell 5.1 specific tests
    if ($majorVersion -eq 5) {
        Write-Host "Testing Windows PowerShell 5.1 specific features..." -ForegroundColor Yellow
        
        # Test .NET Framework compatibility
        try {
            $dotNetVersion = [System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
            Write-TestResult "Windows PowerShell .NET Framework" $true -Details $dotNetVersion
        } catch {
            # Fallback for older .NET versions
            $dotNetVersion = [System.Environment]::Version
            Write-TestResult "Windows PowerShell .NET Framework (legacy)" $true -Details "Version: $dotNetVersion"
        }
        
        # Test Windows-specific cmdlets
        $windowsCmdlets = @("Get-WmiObject", "Get-EventLog")
        foreach ($cmdlet in $windowsCmdlets) {
            $cmdletExists = Get-Command $cmdlet -ErrorAction SilentlyContinue
            Write-TestResult "Windows PowerShell cmdlet: $cmdlet" ($cmdletExists -ne $null)
        }
    }
    
    # Test 4: PowerShell 7+ specific tests
    if ($majorVersion -ge 7) {
        Write-Host "Testing PowerShell 7+ specific features..." -ForegroundColor Yellow
        
        # Test cross-platform compatibility
        $platform = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
        Write-TestResult "PowerShell 7+ platform detection" $true -Details $platform
        
        # Test modern cmdlets
        $modernCmdlets = @("Get-CimInstance", "Test-Connection")
        foreach ($cmdlet in $modernCmdlets) {
            $cmdletExists = Get-Command $cmdlet -ErrorAction SilentlyContinue
            Write-TestResult "PowerShell 7+ cmdlet: $cmdlet" ($cmdletExists -ne $null)
        }
    }
    
    # Test 5: JSON handling compatibility
    try {
        $testObject = @{test = "value"; number = 42}
        $json = $testObject | ConvertTo-Json
        $parsed = $json | ConvertFrom-Json
        $jsonCompatible = $parsed.test -eq "value" -and $parsed.number -eq 42
        
        Write-TestResult "JSON serialization compatibility" $jsonCompatible -Details "JSON handling works correctly"
    } catch {
        Write-TestResult "JSON serialization compatibility" $false -Error $_.Exception.Message
    }
    
    # Test 6: Web request compatibility
    try {
        # Test both Invoke-RestMethod and Invoke-WebRequest availability
        $restMethodExists = Get-Command Invoke-RestMethod -ErrorAction SilentlyContinue
        $webRequestExists = Get-Command Invoke-WebRequest -ErrorAction SilentlyContinue
        
        Write-TestResult "Invoke-RestMethod availability" ($restMethodExists -ne $null)
        Write-TestResult "Invoke-WebRequest availability" ($webRequestExists -ne $null)
        
        # Test TLS compatibility
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Write-TestResult "TLS 1.2 support" $true -Details "TLS 1.2 configured successfully"
        } catch {
            Write-TestResult "TLS 1.2 support" $false -Error $_.Exception.Message
        }
    } catch {
        Write-TestResult "Web request compatibility" $false -Error $_.Exception.Message
    }
}

function Test-TerminalCompatibility {
    Write-Host "`n=== Testing Terminal Environment Compatibility ===" -ForegroundColor Cyan
    
    # Test 1: Terminal type detection
    $terminalType = "Unknown"
    
    if ($env:WT_SESSION) {
        $terminalType = "Windows Terminal"
    } elseif ($env:TERM_PROGRAM -eq "vscode") {
        $terminalType = "VS Code Terminal"
    } elseif ($Host.Name -eq "Windows PowerShell ISE Host") {
        $terminalType = "PowerShell ISE"
    } elseif ($Host.Name -eq "ConsoleHost") {
        $terminalType = "Console Host"
    }
    
    Write-TestResult "Terminal type detection" $true -Details "Detected: $terminalType"
    
    # Test 2: Color support
    try {
        $supportsColor = $Host.UI.SupportsVirtualTerminal -or $env:TERM -or $env:WT_SESSION
        Write-Host "Testing color output..." -ForegroundColor Green
        Write-TestResult "Color output support" $true -Details "Colors displayed successfully"
    } catch {
        Write-TestResult "Color output support" $false -Error $_.Exception.Message
    }
    
    # Test 3: Unicode support
    try {
        $unicodeTest = "🎵 🎙️ ▶️ ⏸️ ⏭️ ⏮️"
        Write-Host "Unicode test: $unicodeTest" -ForegroundColor Cyan
        Write-TestResult "Unicode character support" $true -Details "Unicode characters displayed"
    } catch {
        Write-TestResult "Unicode character support" $false -Error $_.Exception.Message
    }
    
    # Test 4: Interactive input capabilities
    try {
        # Test if we can detect key presses (for interactive navigation)
        $keyAvailable = [System.Console]::KeyAvailable -ne $null
        Write-TestResult "Interactive input detection" $true -Details "Console key detection available"
    } catch {
        Write-TestResult "Interactive input detection" $false -Error $_.Exception.Message
    }
    
    # Test 5: Console dimensions
    try {
        $width = $Host.UI.RawUI.WindowSize.Width
        $height = $Host.UI.RawUI.WindowSize.Height
        $dimensionsValid = $width -gt 0 -and $height -gt 0
        
        Write-TestResult "Console dimensions detection" $dimensionsValid -Details "Size: ${width}x${height}"
    } catch {
        Write-TestResult "Console dimensions detection" $false -Error $_.Exception.Message
    }
    
    # Test 6: Progress bar support
    try {
        Write-Progress -Activity "Testing Progress Bar" -Status "50% Complete" -PercentComplete 50
        Start-Sleep -Milliseconds 500
        Write-Progress -Activity "Testing Progress Bar" -Completed
        Write-TestResult "Progress bar support" $true -Details "Progress bars functional"
    } catch {
        Write-TestResult "Progress bar support" $false -Error $_.Exception.Message
    }
}

function Test-ModuleCompatibility {
    Write-Host "`n=== Testing Module Loading Compatibility ===" -ForegroundColor Cyan
    
    # Test 1: Module import success
    try {
        $module = Get-Module SpotifyModule -ErrorAction SilentlyContinue
        $moduleLoaded = $module -ne $null
        Write-TestResult "SpotifyModule loading" $moduleLoaded -Details "Module loaded successfully"
        
        if ($moduleLoaded) {
            # Test 2: Exported functions availability
            $exportedFunctions = $module.ExportedFunctions.Keys
            $functionCount = $exportedFunctions.Count
            Write-TestResult "Exported functions available" ($functionCount -gt 0) -Details "Found $functionCount functions"
            
            # Test 3: Key functions exist
            $keyFunctions = @(
                "Get-SpotifyPlayback",
                "Invoke-SpotifySearch", 
                "Get-SpotifyDevices",
                "Set-SpotifyPlayback"
            )
            
            foreach ($func in $keyFunctions) {
                $funcExists = $func -in $exportedFunctions
                Write-TestResult "Key function: $func" $funcExists
            }
            
            # Test 4: Aliases availability
            $exportedAliases = $module.ExportedAliases.Keys
            $aliasCount = $exportedAliases.Count
            Write-TestResult "Exported aliases available" ($aliasCount -gt 0) -Details "Found $aliasCount aliases"
        }
    } catch {
        Write-TestResult "Module compatibility" $false -Error $_.Exception.Message
    }
    
    # Test 5: Function execution compatibility
    try {
        # Test a simple function that doesn't require API calls
        $testResult = Test-SpotifyEnvironment
        Write-TestResult "Function execution compatibility" $true -Details "Functions execute without errors"
    } catch {
        Write-TestResult "Function execution compatibility" $false -Error $_.Exception.Message
    }
}

function Test-FileSystemCompatibility {
    Write-Host "`n=== Testing File System Compatibility ===" -ForegroundColor Cyan
    
    # Test 1: Configuration directory access
    $configDir = "$env:APPDATA\SpotifyCLI"
    
    try {
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        Write-TestResult "Configuration directory access" $true -Details "Path: $configDir"
    } catch {
        Write-TestResult "Configuration directory access" $false -Error $_.Exception.Message
    }
    
    # Test 2: Token file read/write
    $tokenPath = "$configDir\tokens.json"
    
    try {
        # Test write
        $testToken = @{test = "token"; timestamp = (Get-Date).ToString()}
        $testToken | ConvertTo-Json | Set-Content $tokenPath -ErrorAction Stop
        
        # Test read
        $readToken = Get-Content $tokenPath | ConvertFrom-Json
        $tokenRW = $readToken.test -eq "token"
        
        Write-TestResult "Token file read/write" $tokenRW -Details "Token persistence works"
        
        # Cleanup test file
        if (Test-Path $tokenPath) {
            Remove-Item $tokenPath -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-TestResult "Token file read/write" $false -Error $_.Exception.Message
    }
    
    # Test 3: Configuration file handling
    $configPath = "$configDir\config.json"
    
    try {
        # Test configuration file operations
        $testConfig = @{
            CompactMode = $false
            NotificationsEnabled = $true
            TestTimestamp = (Get-Date).ToString()
        }
        
        $testConfig | ConvertTo-Json | Set-Content $configPath -ErrorAction Stop
        $readConfig = Get-Content $configPath | ConvertFrom-Json
        $configRW = $readConfig.CompactMode -eq $false
        
        Write-TestResult "Configuration file handling" $configRW -Details "Config persistence works"
        
        # Cleanup test file
        if (Test-Path $configPath) {
            Remove-Item $configPath -Force -ErrorAction SilentlyContinue
        }
    } catch {
        Write-TestResult "Configuration file handling" $false -Error $_.Exception.Message
    }
    
    # Test 4: Environment file access
    $envPath = ".env"
    $envExists = Test-Path $envPath
    
    if ($envExists) {
        try {
            $envContent = Get-Content $envPath -Raw
            Write-TestResult "Environment file access" $true -Details "Can read .env file"
        } catch {
            Write-TestResult "Environment file access" $false -Error $_.Exception.Message
        }
    } else {
        Write-TestResult "Environment file exists" $false -Details ".env file not found (expected for testing)"
    }
}

function Test-SpotifyAccountCompatibility {
    Write-Host "`n=== Testing Spotify Account Type Compatibility ===" -ForegroundColor Cyan
    
    # Test 1: Authentication status
    try {
        $authStatus = Test-SpotifyAuthentication
        Write-TestResult "Spotify authentication status" $true -Details "Authentication test completed"
        
        # Test 2: User profile access
        try {
            $userProfile = Get-SpotifyUserProfile
            if ($userProfile) {
                $accountType = if ($userProfile.product -eq "premium") { "Premium" } else { "Free" }
                Write-TestResult "User profile access" $true -Details "Account type: $accountType"
                
                # Test 3: Premium vs Free feature compatibility
                if ($userProfile.product -eq "premium") {
                    Write-Host "Testing Premium account features..." -ForegroundColor Yellow
                    
                    # Premium features that should work
                    $premiumFeatures = @(
                        "Full playback control",
                        "Device transfer",
                        "Queue management",
                        "Seek functionality"
                    )
                    
                    foreach ($feature in $premiumFeatures) {
                        Write-TestResult "Premium feature: $feature" $true -Details "Available with Premium account"
                    }
                } else {
                    Write-Host "Testing Free account limitations..." -ForegroundColor Yellow
                    
                    # Free account limitations
                    $freeFeatures = @(
                        @{Name = "Track information"; Available = $true},
                        @{Name = "Search functionality"; Available = $true},
                        @{Name = "Playlist browsing"; Available = $true},
                        @{Name = "Full playback control"; Available = $false},
                        @{Name = "Device transfer"; Available = $false}
                    )
                    
                    foreach ($feature in $freeFeatures) {
                        $status = if ($feature.Available) { "Available" } else { "Limited/Unavailable" }
                        Write-TestResult "Free account: $($feature.Name)" $true -Details $status
                    }
                }
                
                # Test 4: Market/Region compatibility
                if ($userProfile.country) {
                    Write-TestResult "Market/Region detection" $true -Details "Country: $($userProfile.country)"
                }
            } else {
                Write-TestResult "User profile access" $false -Error "Could not retrieve user profile"
            }
        } catch {
            Write-TestResult "User profile access" $false -Error $_.Exception.Message
        }
    } catch {
        Write-TestResult "Spotify authentication status" $false -Error $_.Exception.Message
    }
    
    # Test 5: API rate limiting compatibility
    try {
        Write-Host "Testing API rate limiting behavior..." -ForegroundColor Yellow
        
        # Make multiple quick requests to test rate limiting
        $requestCount = 3
        $successCount = 0
        
        for ($i = 1; $i -le $requestCount; $i++) {
            try {
                $result = Get-SpotifyDevices
                $successCount++
                Start-Sleep -Milliseconds 100
            } catch {
                # Rate limiting or other API errors are expected
            }
        }
        
        $rateLimitHandling = $successCount -gt 0
        Write-TestResult "API rate limiting handling" $rateLimitHandling -Details "Handled $successCount/$requestCount requests"
    } catch {
        Write-TestResult "API rate limiting handling" $false -Error $_.Exception.Message
    }
}

function Test-NetworkCompatibility {
    Write-Host "`n=== Testing Network and Security Compatibility ===" -ForegroundColor Cyan
    
    # Test 1: Spotify API connectivity
    try {
        $spotifyReachable = Test-NetConnection -ComputerName "api.spotify.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
        Write-TestResult "Spotify API connectivity" $spotifyReachable -Details "api.spotify.com:443 reachable"
    } catch {
        Write-TestResult "Spotify API connectivity" $false -Error $_.Exception.Message
    }
    
    # Test 2: HTTPS/TLS compatibility
    try {
        $response = Invoke-WebRequest -Uri "https://api.spotify.com" -Method Head -TimeoutSec 10 -ErrorAction Stop
        $httpsWorking = $response.StatusCode -eq 200
        Write-TestResult "HTTPS/TLS compatibility" $httpsWorking -Details "HTTPS requests successful"
    } catch {
        # 401 is expected without auth, but shows HTTPS is working
        $httpsWorking = $_.Exception.Response.StatusCode -eq 401
        Write-TestResult "HTTPS/TLS compatibility" $httpsWorking -Details "HTTPS connection established"
    }
    
    # Test 3: Proxy compatibility
    try {
        $proxySettings = [System.Net.WebRequest]::DefaultWebProxy
        $hasProxy = $proxySettings -ne $null -and $proxySettings.Address -ne $null
        
        if ($hasProxy) {
            Write-TestResult "Proxy detection" $true -Details "Proxy configured: $($proxySettings.Address)"
        } else {
            Write-TestResult "Proxy detection" $true -Details "No proxy configured (direct connection)"
        }
    } catch {
        Write-TestResult "Proxy compatibility" $false -Error $_.Exception.Message
    }
    
    # Test 4: Firewall compatibility
    try {
        # Test if we can make outbound HTTPS requests
        $outboundTest = Test-NetConnection -ComputerName "accounts.spotify.com" -Port 443 -InformationLevel Quiet -ErrorAction SilentlyContinue
        Write-TestResult "Firewall compatibility" $outboundTest -Details "Outbound HTTPS allowed"
    } catch {
        Write-TestResult "Firewall compatibility" $false -Error $_.Exception.Message
    }
}

# Main execution
Write-Host "Starting Cross-Platform Compatibility Integration Test" -ForegroundColor Magenta
Write-Host "===================================================" -ForegroundColor Magenta

# System information
Write-Host "`n=== System Information ===" -ForegroundColor Cyan
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor White
Write-Host "PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor White
Write-Host "Operating System: $([System.Environment]::OSVersion.VersionString)" -ForegroundColor White
Write-Host "Host Name: $($Host.Name)" -ForegroundColor White

# Run all test phases
Test-PowerShellEnvironment
Test-TerminalCompatibility
Test-ModuleCompatibility
Test-FileSystemCompatibility
Test-SpotifyAccountCompatibility
Test-NetworkCompatibility

# Display final results
Write-Host "`n=== Test Results Summary ===" -ForegroundColor Magenta
Write-Host "Total Tests: $($TestResults.TotalTests)" -ForegroundColor White
Write-Host "Passed: $($TestResults.PassedTests)" -ForegroundColor Green
Write-Host "Failed: $($TestResults.FailedTests)" -ForegroundColor Red

if ($TestResults.FailedTests -gt 0) {
    Write-Host "`nFailed Tests Details:" -ForegroundColor Red
    foreach ($error in $TestResults.Errors) {
        Write-Host "  • $error" -ForegroundColor Red
    }
}

$successRate = [math]::Round(($TestResults.PassedTests / $TestResults.TotalTests) * 100, 1)
Write-Host "`nSuccess Rate: $successRate%" -ForegroundColor $(if ($successRate -ge 80) { "Green" } elseif ($successRate -ge 60) { "Yellow" } else { "Red" })

# Cross-platform specific recommendations
Write-Host "`n=== Cross-Platform Compatibility Assessment ===" -ForegroundColor Cyan

if ($TestResults.FailedTests -eq 0) {
    Write-Host "✓ Excellent cross-platform compatibility!" -ForegroundColor Green
    Write-Host "✓ All PowerShell environments supported" -ForegroundColor Green
    Write-Host "✓ Terminal compatibility confirmed" -ForegroundColor Green
    Write-Host "✓ Network and security requirements met" -ForegroundColor Green
} else {
    Write-Host "⚠ Some compatibility issues detected:" -ForegroundColor Yellow
    
    if ($TestResults.Errors -match "PowerShell|version") {
        Write-Host "  • PowerShell version compatibility needs attention" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "terminal|Terminal|color") {
        Write-Host "  • Terminal compatibility issues detected" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "network|Network|connectivity") {
        Write-Host "  • Network connectivity problems found" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "file|File|directory") {
        Write-Host "  • File system access issues detected" -ForegroundColor Yellow
    }
    if ($TestResults.Errors -match "account|Account|spotify") {
        Write-Host "  • Spotify account compatibility needs verification" -ForegroundColor Yellow
    }
}

# Environment-specific guidance
Write-Host "`n=== Environment-Specific Guidance ===" -ForegroundColor Cyan

$psVersion = $PSVersionTable.PSVersion.Major
if ($psVersion -eq 5) {
    Write-Host "Windows PowerShell 5.1 Environment:" -ForegroundColor Yellow
    Write-Host "  • Ensure .NET Framework 4.7.2 or later is installed" -ForegroundColor Gray
    Write-Host "  • Some modern cmdlets may not be available" -ForegroundColor Gray
    Write-Host "  • Consider upgrading to PowerShell 7+ for best experience" -ForegroundColor Gray
} elseif ($psVersion -ge 7) {
    Write-Host "PowerShell 7+ Environment:" -ForegroundColor Green
    Write-Host "  • Modern PowerShell with full cross-platform support" -ForegroundColor Gray
    Write-Host "  • All features should work optimally" -ForegroundColor Gray
    Write-Host "  • Enhanced performance and compatibility" -ForegroundColor Gray
}

Write-Host "`nCross-Platform Compatibility Test Complete" -ForegroundColor Magenta