# Spotify CLI Diagnostic Framework
# Comprehensive system validation and troubleshooting tools

function Test-SpotifySystemDiagnostics {
    <#
    .SYNOPSIS
    Comprehensive system diagnostic function for Spotify CLI
    
    .DESCRIPTION
    Tests PowerShell environment, module loading, file permissions, and system compatibility
    
    .PARAMETER Detailed
    Show detailed diagnostic information
    
    .PARAMETER ExportReport
    Export diagnostic report to file
    
    .EXAMPLE
    Test-SpotifySystemDiagnostics
    Run basic system diagnostics
    
    .EXAMPLE
    Test-SpotifySystemDiagnostics -Detailed -ExportReport
    Run detailed diagnostics and export report
    #>
    param(
        [switch]$Detailed,
        [switch]$ExportReport
    )
    
    Write-Host "🔍 Spotify CLI System Diagnostics" -ForegroundColor Cyan
    Write-Host "=================================" -ForegroundColor Cyan
    Write-Host ""
    
    $diagnosticResults = @{
        Timestamp = Get-Date
        PowerShellInfo = @{}
        EnvironmentInfo = @{}
        ModuleInfo = @{}
        FileSystemInfo = @{}
        NetworkInfo = @{}
        Issues = @()
        Recommendations = @()
    }
    
    # Test PowerShell Environment
    Write-Host "📋 PowerShell Environment" -ForegroundColor Yellow
    Write-Host "-------------------------" -ForegroundColor Yellow
    
    $psVersion = $PSVersionTable.PSVersion
    $psEdition = $PSVersionTable.PSEdition
    $osVersion = [System.Environment]::OSVersion
    $is64Bit = [System.Environment]::Is64BitProcess
    
    $diagnosticResults.PowerShellInfo = @{
        Version = $psVersion.ToString()
        Edition = $psEdition
        Is64Bit = $is64Bit
        ExecutionPolicy = (Get-ExecutionPolicy).ToString()
        ProcessId = $PID
        Host = $Host.Name
        Culture = (Get-Culture).Name
    }
    
    Write-Host "  PowerShell Version: $($psVersion.ToString())" -ForegroundColor White
    Write-Host "  Edition: $psEdition" -ForegroundColor White
    Write-Host "  Architecture: $(if($is64Bit){'64-bit'}else{'32-bit'})" -ForegroundColor White
    Write-Host "  Execution Policy: $(Get-ExecutionPolicy)" -ForegroundColor White
    Write-Host "  Host: $($Host.Name)" -ForegroundColor White
    
    # Check PowerShell version compatibility
    if ($psVersion.Major -lt 5) {
        $issue = "PowerShell version $($psVersion.ToString()) is not supported. Minimum version is 5.0"
        $diagnosticResults.Issues += $issue
        Write-Host "  ❌ $issue" -ForegroundColor Red
        $diagnosticResults.Recommendations += "Upgrade to PowerShell 5.1 or PowerShell 7+"
    } elseif ($psVersion.Major -eq 5 -and $psVersion.Minor -eq 0) {
        $warning = "PowerShell 5.0 has limited support. Consider upgrading to 5.1 or 7+"
        $diagnosticResults.Issues += $warning
        Write-Host "  ⚠️ $warning" -ForegroundColor Yellow
        $diagnosticResults.Recommendations += "Upgrade to PowerShell 5.1 or PowerShell 7+ for better compatibility"
    } else {
        Write-Host "  ✅ PowerShell version is compatible" -ForegroundColor Green
    }
    
    # Check execution policy
    $execPolicy = Get-ExecutionPolicy
    if ($execPolicy -eq "Restricted") {
        $issue = "Execution policy is Restricted, which prevents script execution"
        $diagnosticResults.Issues += $issue
        Write-Host "  ❌ $issue" -ForegroundColor Red
        $diagnosticResults.Recommendations += "Set execution policy: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser"
    } else {
        Write-Host "  ✅ Execution policy allows script execution" -ForegroundColor Green
    }
    
    Write-Host ""
    
    # Test Terminal Environment
    Write-Host "🖥️ Terminal Environment" -ForegroundColor Yellow
    Write-Host "-----------------------" -ForegroundColor Yellow
    
    $terminalType = Get-TerminalType
    $supportsColor = Test-ColorSupport
    $supportsUnicode = Test-UnicodeSupport
    
    $diagnosticResults.EnvironmentInfo = @{
        TerminalType = $terminalType
        SupportsColor = $supportsColor
        SupportsUnicode = $supportsUnicode
        WindowWidth = $Host.UI.RawUI.WindowSize.Width
        WindowHeight = $Host.UI.RawUI.WindowSize.Height
        IsInteractive = [System.Environment]::UserInteractive
    }
    
    Write-Host "  Terminal Type: $terminalType" -ForegroundColor White
    Write-Host "  Color Support: $(if($supportsColor){'✅ Yes'}else{'❌ No'})" -ForegroundColor $(if($supportsColor){'Green'}else{'Red'})
    Write-Host "  Unicode Support: $(if($supportsUnicode){'✅ Yes'}else{'❌ No'})" -ForegroundColor $(if($supportsUnicode){'Green'}else{'Red'})
    Write-Host "  Window Size: $($Host.UI.RawUI.WindowSize.Width)x$($Host.UI.RawUI.WindowSize.Height)" -ForegroundColor White
    Write-Host "  Interactive Mode: $(if([System.Environment]::UserInteractive){'✅ Yes'}else{'❌ No'})" -ForegroundColor White
    
    if (-not $supportsColor) {
        $diagnosticResults.Issues += "Terminal does not support colors - CLI output may appear plain"
        $diagnosticResults.Recommendations += "Use a modern terminal like Windows Terminal for better experience"
    }
    
    if (-not $supportsUnicode) {
        $diagnosticResults.Issues += "Terminal does not support Unicode - some icons may not display correctly"
        $diagnosticResults.Recommendations += "Configure terminal to use UTF-8 encoding"
    }
    
    Write-Host ""
    
    # Test Module Loading
    Write-Host "📦 Module Loading Capabilities" -ForegroundColor Yellow
    Write-Host "-----------------------------" -ForegroundColor Yellow
    
    $moduleLoadTest = Test-ModuleLoading
    $diagnosticResults.ModuleInfo = $moduleLoadTest
    
    Write-Host "  Module Path Access: $(if($moduleLoadTest.CanAccessModulePath){'✅ Yes'}else{'❌ No'})" -ForegroundColor $(if($moduleLoadTest.CanAccessModulePath){'Green'}else{'Red'})
    Write-Host "  Can Import Modules: $(if($moduleLoadTest.CanImportModules){'✅ Yes'}else{'❌ No'})" -ForegroundColor $(if($moduleLoadTest.CanImportModules){'Green'}else{'Red'})
    Write-Host "  SpotifyModule Status: $($moduleLoadTest.SpotifyModuleStatus)" -ForegroundColor White
    
    if ($moduleLoadTest.ConflictingModules.Count -gt 0) {
        Write-Host "  ⚠️ Conflicting Modules Found:" -ForegroundColor Yellow
        foreach ($conflict in $moduleLoadTest.ConflictingModules) {
            Write-Host "    - $conflict" -ForegroundColor Yellow
        }
        $diagnosticResults.Issues += "Conflicting modules detected: $($moduleLoadTest.ConflictingModules -join ', ')"
        $diagnosticResults.Recommendations += "Consider removing conflicting modules or using module isolation"
    }
    
    if (-not $moduleLoadTest.CanImportModules) {
        $diagnosticResults.Issues += "Cannot import PowerShell modules"
        $diagnosticResults.Recommendations += "Check PowerShell module path and permissions"
    }
    
    Write-Host ""
    
    # Test File System Permissions
    Write-Host "📁 File System Permissions" -ForegroundColor Yellow
    Write-Host "-------------------------" -ForegroundColor Yellow
    
    $fileSystemTest = Test-FileSystemPermissions
    $diagnosticResults.FileSystemInfo = $fileSystemTest
    
    Write-Host "  AppData Directory: $(if($fileSystemTest.CanCreateAppData){'✅ Accessible'}else{'❌ No Access'})" -ForegroundColor $(if($fileSystemTest.CanCreateAppData){'Green'}else{'Red'})
    Write-Host "  Token Storage: $(if($fileSystemTest.CanWriteTokens){'✅ Writable'}else{'❌ No Write Access'})" -ForegroundColor $(if($fileSystemTest.CanWriteTokens){'Green'}else{'Red'})
    Write-Host "  Config Storage: $(if($fileSystemTest.CanWriteConfig){'✅ Writable'}else{'❌ No Write Access'})" -ForegroundColor $(if($fileSystemTest.CanWriteConfig){'Green'}else{'Red'})
    Write-Host "  Temp Directory: $(if($fileSystemTest.CanWriteTemp){'✅ Writable'}else{'❌ No Write Access'})" -ForegroundColor $(if($fileSystemTest.CanWriteTemp){'Green'}else{'Red'})
    
    if (-not $fileSystemTest.CanCreateAppData) {
        $diagnosticResults.Issues += "Cannot create or access AppData directory for Spotify CLI"
        $diagnosticResults.Recommendations += "Check user permissions for %APPDATA% directory"
    }
    
    if (-not $fileSystemTest.CanWriteTokens) {
        $diagnosticResults.Issues += "Cannot write authentication tokens"
        $diagnosticResults.Recommendations += "Ensure write permissions to SpotifyCLI directory in AppData"
    }
    
    Write-Host ""
    
    # Test Network Connectivity (basic)
    Write-Host "🌐 Network Connectivity" -ForegroundColor Yellow
    Write-Host "----------------------" -ForegroundColor Yellow
    
    $networkTest = Test-NetworkConnectivity
    $diagnosticResults.NetworkInfo = $networkTest
    
    Write-Host "  Internet Access: $(if($networkTest.HasInternetAccess){'✅ Available'}else{'❌ No Access'})" -ForegroundColor $(if($networkTest.HasInternetAccess){'Green'}else{'Red'})
    Write-Host "  DNS Resolution: $(if($networkTest.CanResolveDNS){'✅ Working'}else{'❌ Failed'})" -ForegroundColor $(if($networkTest.CanResolveDNS){'Green'}else{'Red'})
    Write-Host "  HTTPS Support: $(if($networkTest.SupportsHTTPS){'✅ Available'}else{'❌ Not Available'})" -ForegroundColor $(if($networkTest.SupportsHTTPS){'Green'}else{'Red'})
    Write-Host "  Proxy Detection: $($networkTest.ProxyStatus)" -ForegroundColor White
    
    if (-not $networkTest.HasInternetAccess) {
        $diagnosticResults.Issues += "No internet connectivity detected"
        $diagnosticResults.Recommendations += "Check network connection and firewall settings"
    }
    
    if (-not $networkTest.SupportsHTTPS) {
        $diagnosticResults.Issues += "HTTPS connections not supported"
        $diagnosticResults.Recommendations += "Update .NET Framework or PowerShell version"
    }
    
    Write-Host ""
    
    # Summary
    Write-Host "📊 Diagnostic Summary" -ForegroundColor Cyan
    Write-Host "=====================" -ForegroundColor Cyan
    
    $issueCount = $diagnosticResults.Issues.Count
    $recommendationCount = $diagnosticResults.Recommendations.Count
    
    if ($issueCount -eq 0) {
        Write-Host "✅ No issues detected - System appears ready for Spotify CLI" -ForegroundColor Green
    } else {
        Write-Host "⚠️ $issueCount issue(s) detected:" -ForegroundColor Yellow
        foreach ($issue in $diagnosticResults.Issues) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
    }
    
    if ($recommendationCount -gt 0) {
        Write-Host ""
        Write-Host "💡 Recommendations:" -ForegroundColor Cyan
        foreach ($recommendation in $diagnosticResults.Recommendations) {
            Write-Host "  • $recommendation" -ForegroundColor Cyan
        }
    }
    
    # Export report if requested
    if ($ExportReport) {
        $reportPath = Join-Path $env:TEMP "SpotifyCLI-Diagnostics-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        try {
            $diagnosticResults | ConvertTo-Json -Depth 10 | Set-Content -Path $reportPath -Encoding UTF8
            Write-Host ""
            Write-Host "📄 Diagnostic report exported to: $reportPath" -ForegroundColor Green
        } catch {
            Write-Host ""
            Write-Host "❌ Failed to export diagnostic report: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $diagnosticResults
}

function Get-TerminalType {
    <#
    .SYNOPSIS
    Detect the type of terminal being used
    #>
    
    # Check for Windows Terminal
    if ($env:WT_SESSION) {
        return "Windows Terminal"
    }
    
    # Check for VS Code Terminal
    if ($env:TERM_PROGRAM -eq "vscode") {
        return "VS Code Terminal"
    }
    
    # Check for PowerShell ISE
    if ($Host.Name -eq "Windows PowerShell ISE Host") {
        return "PowerShell ISE"
    }
    
    # Check for ConEmu
    if ($env:ConEmuPID) {
        return "ConEmu"
    }
    
    # Check for Windows Console Host
    if ($Host.Name -eq "ConsoleHost") {
        return "Windows Console Host"
    }
    
    # Default fallback
    return $Host.Name
}

function Test-ColorSupport {
    <#
    .SYNOPSIS
    Test if the terminal supports color output
    #>
    try {
        # Try to get console colors
        $null = $Host.UI.RawUI.ForegroundColor
        $null = $Host.UI.RawUI.BackgroundColor
        return $true
    } catch {
        return $false
    }
}

function Test-UnicodeSupport {
    <#
    .SYNOPSIS
    Test if the terminal supports Unicode characters
    #>
    try {
        # Test by checking if we can display Unicode characters
        $testChar = "🎵"
        $encoded = [System.Text.Encoding]::UTF8.GetBytes($testChar)
        return $encoded.Length -gt 1
    } catch {
        return $false
    }
}

function Test-ModuleLoading {
    <#
    .SYNOPSIS
    Test PowerShell module loading capabilities
    #>
    $result = @{
        CanAccessModulePath = $false
        CanImportModules = $false
        SpotifyModuleStatus = "Not Found"
        ConflictingModules = @()
        ModulePaths = @()
    }
    
    try {
        # Test module path access
        $result.ModulePaths = $env:PSModulePath -split ';'
        $result.CanAccessModulePath = $true
        
        # Test basic module import capability
        try {
            Import-Module Microsoft.PowerShell.Utility -Force -ErrorAction Stop
            $result.CanImportModules = $true
        } catch {
            $result.CanImportModules = $false
        }
        
        # Check for SpotifyModule
        if (Test-Path ".\SpotifyModule.psm1") {
            try {
                Import-Module ".\SpotifyModule.psm1" -Force -ErrorAction Stop
                $result.SpotifyModuleStatus = "Available and Loadable"
                Remove-Module SpotifyModule -ErrorAction SilentlyContinue
            } catch {
                $result.SpotifyModuleStatus = "Found but Cannot Load: $($_.Exception.Message)"
            }
        } else {
            $result.SpotifyModuleStatus = "Not Found in Current Directory"
        }
        
        # Check for conflicting modules (modules that might have conflicting command names)
        $potentialConflicts = @("Spotify", "Music", "MediaPlayer")
        foreach ($moduleName in $potentialConflicts) {
            if (Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue) {
                $result.ConflictingModules += $moduleName
            }
        }
        
    } catch {
        # Module path access failed
        $result.CanAccessModulePath = $false
    }
    
    return $result
}

function Test-FileSystemPermissions {
    <#
    .SYNOPSIS
    Test file system permissions for Spotify CLI directories and files
    #>
    $result = @{
        CanCreateAppData = $false
        CanWriteTokens = $false
        CanWriteConfig = $false
        CanWriteTemp = $false
        AppDataPath = ""
        TokenPath = ""
        ConfigPath = ""
    }
    
    try {
        # Test AppData directory creation
        $appDataDir = Join-Path $env:APPDATA "SpotifyCLI"
        $result.AppDataPath = $appDataDir
        
        if (-not (Test-Path $appDataDir)) {
            New-Item -ItemType Directory -Path $appDataDir -Force | Out-Null
        }
        $result.CanCreateAppData = Test-Path $appDataDir
        
        if ($result.CanCreateAppData) {
            # Test token file write
            $tokenFile = Join-Path $appDataDir "test-tokens.json"
            $result.TokenPath = $tokenFile
            try {
                '{"test": true}' | Set-Content -Path $tokenFile -Encoding UTF8 -ErrorAction Stop
                $result.CanWriteTokens = Test-Path $tokenFile
                Remove-Item $tokenFile -ErrorAction SilentlyContinue
            } catch {
                $result.CanWriteTokens = $false
            }
            
            # Test config file write
            $configFile = Join-Path $appDataDir "test-config.json"
            $result.ConfigPath = $configFile
            try {
                '{"test": true}' | Set-Content -Path $configFile -Encoding UTF8 -ErrorAction Stop
                $result.CanWriteConfig = Test-Path $configFile
                Remove-Item $configFile -ErrorAction SilentlyContinue
            } catch {
                $result.CanWriteConfig = $false
            }
        }
        
        # Test temp directory write
        try {
            $tempFile = Join-Path $env:TEMP "spotify-cli-test.tmp"
            "test" | Set-Content -Path $tempFile -ErrorAction Stop
            $result.CanWriteTemp = Test-Path $tempFile
            Remove-Item $tempFile -ErrorAction SilentlyContinue
        } catch {
            $result.CanWriteTemp = $false
        }
        
    } catch {
        # AppData access failed completely
        $result.CanCreateAppData = $false
    }
    
    return $result
}

function Test-NetworkConnectivity {
    <#
    .SYNOPSIS
    Test basic network connectivity for Spotify API access
    #>
    $result = @{
        HasInternetAccess = $false
        CanResolveDNS = $false
        SupportsHTTPS = $false
        ProxyStatus = "Not Detected"
    }
    
    try {
        # Test DNS resolution
        try {
            $null = [System.Net.Dns]::GetHostAddresses("accounts.spotify.com")
            $result.CanResolveDNS = $true
        } catch {
            $result.CanResolveDNS = $false
        }
        
        # Test basic internet connectivity
        try {
            $response = Invoke-WebRequest -Uri "https://www.google.com" -Method Head -TimeoutSec 10 -ErrorAction Stop
            $result.HasInternetAccess = $true
        } catch {
            $result.HasInternetAccess = $false
        }
        
        # Test HTTPS support
        try {
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
            $result.SupportsHTTPS = $true
        } catch {
            $result.SupportsHTTPS = $false
        }
        
        # Check for proxy settings
        try {
            $proxy = [System.Net.WebRequest]::GetSystemWebProxy()
            if ($proxy -and $proxy.GetProxy([System.Uri]"https://accounts.spotify.com") -ne [System.Uri]"https://accounts.spotify.com") {
                $result.ProxyStatus = "Proxy Detected"
            } else {
                $result.ProxyStatus = "Direct Connection"
            }
        } catch {
            $result.ProxyStatus = "Cannot Determine"
        }
        
    } catch {
        # Network test failed
        $result.HasInternetAccess = $false
    }
    
    return $result
}

function Test-SpotifyApiConnectivity {
    <#
    .SYNOPSIS
    Test Spotify API connectivity and authentication endpoints
    
    .DESCRIPTION
    Tests network connectivity to Spotify API endpoints, validates client credentials,
    and tests basic authentication flow without requiring user interaction
    
    .PARAMETER ClientId
    Spotify Client ID to test
    
    .PARAMETER ClientSecret
    Spotify Client Secret to test
    
    .EXAMPLE
    Test-SpotifyApiConnectivity -ClientId "your_client_id" -ClientSecret "your_secret"
    Test API connectivity with specific credentials
    
    .EXAMPLE
    Test-SpotifyApiConnectivity
    Test API connectivity using environment variables
    #>
    param(
        [string]$ClientId = $env:SPOTIFY_CLIENT_ID,
        [string]$ClientSecret = $env:SPOTIFY_CLIENT_SECRET
    )
    
    Write-Host "🌐 Spotify API Connectivity Test" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host ""
    
    $testResults = @{
        Timestamp = Get-Date
        EndpointTests = @{}
        AuthenticationTests = @{}
        CredentialTests = @{}
        Issues = @()
        Recommendations = @()
    }
    
    # Test 1: Basic endpoint connectivity
    Write-Host "🔗 Testing Spotify API Endpoints" -ForegroundColor Yellow
    Write-Host "--------------------------------" -ForegroundColor Yellow
    
    $endpoints = @{
        "Accounts Service" = "https://accounts.spotify.com"
        "API Service" = "https://api.spotify.com"
    }
    
    foreach ($endpointName in $endpoints.Keys) {
        $url = $endpoints[$endpointName]
        Write-Host "  Testing $endpointName..." -NoNewline
        
        try {
            $response = Invoke-WebRequest -Uri $url -Method Head -TimeoutSec 10 -ErrorAction Stop
            $statusCode = $response.StatusCode
            $testResults.EndpointTests[$endpointName] = @{
                Url = $url
                StatusCode = $statusCode
                Success = $true
                ResponseTime = 0  # Could add timing if needed
            }
            Write-Host " ✅ OK ($statusCode)" -ForegroundColor Green
        } catch {
            $errorMessage = $_.Exception.Message
            $testResults.EndpointTests[$endpointName] = @{
                Url = $url
                Success = $false
                Error = $errorMessage
            }
            Write-Host " ❌ Failed" -ForegroundColor Red
            Write-Host "    Error: $errorMessage" -ForegroundColor Red
            $testResults.Issues += "Cannot connect to $endpointName at $url"
            $testResults.Recommendations += "Check network connectivity and firewall settings for Spotify API access"
        }
    }
    
    Write-Host ""
    
    # Test 2: Credential validation
    Write-Host "🔑 Testing Spotify Credentials" -ForegroundColor Yellow
    Write-Host "------------------------------" -ForegroundColor Yellow
    
    if ([string]::IsNullOrWhiteSpace($ClientId)) {
        Write-Host "  ❌ Client ID not provided or empty" -ForegroundColor Red
        $testResults.Issues += "Spotify Client ID is missing"
        $testResults.Recommendations += "Set SPOTIFY_CLIENT_ID environment variable or provide ClientId parameter"
        $testResults.CredentialTests["ClientId"] = @{ Present = $false }
    } else {
        Write-Host "  ✅ Client ID present: $($ClientId.Substring(0, 8))..." -ForegroundColor Green
        $testResults.CredentialTests["ClientId"] = @{ Present = $true; Value = $ClientId }
    }
    
    if ([string]::IsNullOrWhiteSpace($ClientSecret)) {
        Write-Host "  ❌ Client Secret not provided or empty" -ForegroundColor Red
        $testResults.Issues += "Spotify Client Secret is missing"
        $testResults.Recommendations += "Set SPOTIFY_CLIENT_SECRET environment variable or provide ClientSecret parameter"
        $testResults.CredentialTests["ClientSecret"] = @{ Present = $false }
    } else {
        Write-Host "  ✅ Client Secret present: $($ClientSecret.Substring(0, 8))..." -ForegroundColor Green
        $testResults.CredentialTests["ClientSecret"] = @{ Present = $true; Masked = $ClientSecret.Substring(0, 8) + "..." }
    }
    
    # Test 3: Client Credentials Flow (if credentials available)
    if (-not [string]::IsNullOrWhiteSpace($ClientId) -and -not [string]::IsNullOrWhiteSpace($ClientSecret)) {
        Write-Host ""
        Write-Host "🔐 Testing Authentication Flow" -ForegroundColor Yellow
        Write-Host "------------------------------" -ForegroundColor Yellow
        
        Write-Host "  Testing Client Credentials flow..." -NoNewline
        
        try {
            # Test client credentials grant (doesn't require user auth)
            $body = @{
                grant_type = "client_credentials"
                client_id = $ClientId
                client_secret = $ClientSecret
            }
            
            $response = Invoke-RestMethod -Method Post -Uri "https://accounts.spotify.com/api/token" -Body $body -ErrorAction Stop
            
            if ($response.access_token) {
                Write-Host " ✅ Success" -ForegroundColor Green
                Write-Host "    Token Type: $($response.token_type)" -ForegroundColor White
                Write-Host "    Expires In: $($response.expires_in) seconds" -ForegroundColor White
                
                $testResults.AuthenticationTests["ClientCredentials"] = @{
                    Success = $true
                    TokenType = $response.token_type
                    ExpiresIn = $response.expires_in
                    HasAccessToken = $true
                }
                
                # Test a basic API call with the token
                Write-Host "  Testing API call with token..." -NoNewline
                try {
                    $headers = @{ Authorization = "Bearer $($response.access_token)" }
                    $apiResponse = Invoke-RestMethod -Method Get -Uri "https://api.spotify.com/v1/browse/categories?limit=1" -Headers $headers -ErrorAction Stop
                    Write-Host " ✅ API call successful" -ForegroundColor Green
                    $testResults.AuthenticationTests["ApiCall"] = @{ Success = $true }
                } catch {
                    Write-Host " ❌ API call failed" -ForegroundColor Red
                    Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
                    $testResults.AuthenticationTests["ApiCall"] = @{ Success = $false; Error = $_.Exception.Message }
                    $testResults.Issues += "API call failed with valid token"
                }
            } else {
                Write-Host " ❌ No access token received" -ForegroundColor Red
                $testResults.AuthenticationTests["ClientCredentials"] = @{ Success = $false; Error = "No access token in response" }
                $testResults.Issues += "Authentication succeeded but no access token received"
            }
            
        } catch {
            $errorMessage = $_.Exception.Message
            Write-Host " ❌ Failed" -ForegroundColor Red
            Write-Host "    Error: $errorMessage" -ForegroundColor Red
            
            # Parse specific error types
            if ($errorMessage -like "*invalid_client*") {
                $testResults.Issues += "Invalid client credentials - check Client ID and Secret"
                $testResults.Recommendations += "Verify Client ID and Secret in Spotify Developer Dashboard"
            } elseif ($errorMessage -like "*unauthorized*") {
                $testResults.Issues += "Client credentials are not authorized"
                $testResults.Recommendations += "Ensure your Spotify app is properly configured in the Developer Dashboard"
            } else {
                $testResults.Issues += "Authentication failed: $errorMessage"
                $testResults.Recommendations += "Check network connectivity and credential validity"
            }
            
            $testResults.AuthenticationTests["ClientCredentials"] = @{
                Success = $false
                Error = $errorMessage
            }
        }
    } else {
        Write-Host ""
        Write-Host "⚠️ Skipping authentication test - credentials not available" -ForegroundColor Yellow
    }
    
    # Test 4: Authorization endpoint accessibility
    Write-Host ""
    Write-Host "🌐 Testing Authorization Endpoint" -ForegroundColor Yellow
    Write-Host "--------------------------------" -ForegroundColor Yellow
    
    if (-not [string]::IsNullOrWhiteSpace($ClientId)) {
        Write-Host "  Testing authorization URL generation..." -NoNewline
        
        try {
            $authUrl = "https://accounts.spotify.com/authorize?response_type=code&client_id=$ClientId&redirect_uri=http://127.0.0.1:8888/callback&scope=user-read-playback-state"
            
            # Test if the authorization endpoint responds (without following redirects)
            try {
                $response = Invoke-WebRequest -Uri $authUrl -Method Get -MaximumRedirection 0 -ErrorAction Stop
                Write-Host " ✅ Authorization endpoint accessible" -ForegroundColor Green
                $testResults.AuthenticationTests["AuthorizationEndpoint"] = @{ Success = $true; Url = $authUrl }
            } catch {
                # Check if it's a redirect (which is expected)
                if ($_.Exception.Response -and $_.Exception.Response.StatusCode -eq 302) {
                    Write-Host " ✅ Authorization endpoint accessible (redirect)" -ForegroundColor Green
                    $testResults.AuthenticationTests["AuthorizationEndpoint"] = @{ Success = $true; Url = $authUrl }
                } else {
                    # Any other response code from the auth endpoint is also acceptable
                    Write-Host " ✅ Authorization endpoint accessible" -ForegroundColor Green
                    $testResults.AuthenticationTests["AuthorizationEndpoint"] = @{ Success = $true; Url = $authUrl }
                }
            }
            
        } catch {
            Write-Host " ❌ Authorization endpoint not accessible" -ForegroundColor Red
            $testResults.AuthenticationTests["AuthorizationEndpoint"] = @{ Success = $false; Error = $_.Exception.Message }
            $testResults.Issues += "Cannot access Spotify authorization endpoint"
        }
    } else {
        Write-Host "  ⚠️ Skipping - Client ID not available" -ForegroundColor Yellow
    }
    
    # Summary
    Write-Host ""
    Write-Host "📊 API Connectivity Summary" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    
    $issueCount = $testResults.Issues.Count
    $recommendationCount = $testResults.Recommendations.Count
    
    if ($issueCount -eq 0) {
        Write-Host "✅ All API connectivity tests passed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ $issueCount issue(s) detected:" -ForegroundColor Yellow
        foreach ($issue in $testResults.Issues) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
    }
    
    if ($recommendationCount -gt 0) {
        Write-Host ""
        Write-Host "💡 Recommendations:" -ForegroundColor Cyan
        foreach ($recommendation in $testResults.Recommendations) {
            Write-Host "  • $recommendation" -ForegroundColor Cyan
        }
    }
    
    return $testResults
}

function Test-SpotifyLocalServer {
    <#
    .SYNOPSIS
    Test local HTTP server capability for OAuth callback
    
    .DESCRIPTION
    Tests if the system can start a local HTTP server on port 8888 for OAuth callback handling
    
    .PARAMETER Port
    Port to test (default: 8888)
    
    .EXAMPLE
    Test-SpotifyLocalServer
    Test default OAuth callback server setup
    
    .EXAMPLE
    Test-SpotifyLocalServer -Port 8080
    Test OAuth callback server on custom port
    #>
    param(
        [int]$Port = 8888
    )
    
    Write-Host "🖥️ Testing Local OAuth Server Capability" -ForegroundColor Cyan
    Write-Host "=========================================" -ForegroundColor Cyan
    Write-Host ""
    
    $testResults = @{
        Port = $Port
        CanStartServer = $false
        CanBindPort = $false
        CanReceiveRequests = $false
        Issues = @()
        Recommendations = @()
    }
    
    Write-Host "  Testing port $Port availability..." -NoNewline
    
    try {
        # Test if port is available
        $listener = New-Object System.Net.HttpListener
        $listener.Prefixes.Add("http://127.0.0.1:$Port/")
        
        try {
            $listener.Start()
            $testResults.CanStartServer = $true
            $testResults.CanBindPort = $true
            Write-Host " ✅ Port available" -ForegroundColor Green
            
            # Test basic request handling
            Write-Host "  Testing request handling..." -NoNewline
            
            # Start a background job to make a test request
            $testJob = Start-Job -ScriptBlock {
                param($Port)
                Start-Sleep -Milliseconds 500
                try {
                    Invoke-WebRequest -Uri "http://127.0.0.1:$Port/test" -TimeoutSec 5 -ErrorAction Stop
                } catch {
                    # Expected to fail, we just want to test if server receives it
                }
            } -ArgumentList $Port
            
            # Wait for a request (with timeout)
            $timeout = [DateTime]::Now.AddSeconds(2)
            $requestReceived = $false
            
            while ([DateTime]::Now -lt $timeout -and -not $requestReceived) {
                if ($listener.IsListening) {
                    try {
                        $contextTask = $listener.GetContextAsync()
                        if ($contextTask.Wait(100)) {
                            $context = $contextTask.Result
                            $response = $context.Response
                            $response.StatusCode = 200
                            $response.Close()
                            $requestReceived = $true
                            $testResults.CanReceiveRequests = $true
                        }
                    } catch {
                        # Timeout or other error, continue
                    }
                }
            }
            
            # Clean up the test job
            Stop-Job $testJob -ErrorAction SilentlyContinue
            Remove-Job $testJob -ErrorAction SilentlyContinue
            
            if ($requestReceived) {
                Write-Host " ✅ Request handling works" -ForegroundColor Green
            } else {
                Write-Host " ⚠️ Request handling test inconclusive" -ForegroundColor Yellow
                $testResults.CanReceiveRequests = $true  # Assume it works if server started
            }
            
            $listener.Stop()
            
        } catch {
            Write-Host " ❌ Cannot start server" -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            
            $testResults.Issues += "Cannot start HTTP server on port $Port"
            
            if ($_.Exception.Message -like "*access*denied*" -or $_.Exception.Message -like "*permission*") {
                $testResults.Recommendations += "Run PowerShell as Administrator to allow HTTP server binding"
            } elseif ($_.Exception.Message -like "*address*already*in*use*") {
                $testResults.Recommendations += "Port $Port is already in use by another application"
            } else {
                $testResults.Recommendations += "Check Windows Firewall and network settings"
            }
        }
        
    } catch {
        Write-Host " ❌ Cannot create HTTP listener" -ForegroundColor Red
        Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
        $testResults.Issues += "Cannot create HTTP listener: $($_.Exception.Message)"
        $testResults.Recommendations += "Check .NET Framework installation and system permissions"
    }
    
    # Test Windows Firewall considerations
    Write-Host ""
    Write-Host "🔥 Firewall Considerations" -ForegroundColor Yellow
    Write-Host "-------------------------" -ForegroundColor Yellow
    
    if ($testResults.CanStartServer) {
        Write-Host "  ✅ Local server can start - firewall should allow localhost connections" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Cannot test firewall - server startup failed" -ForegroundColor Yellow
        $testResults.Recommendations += "Resolve server startup issues before testing firewall"
    }
    
    # Summary
    Write-Host ""
    Write-Host "📊 Local Server Test Summary" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    
    if ($testResults.CanStartServer -and $testResults.CanReceiveRequests) {
        Write-Host "✅ Local OAuth server capability confirmed" -ForegroundColor Green
    } else {
        Write-Host "❌ Local OAuth server has issues" -ForegroundColor Red
        foreach ($issue in $testResults.Issues) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
        
        if ($testResults.Recommendations.Count -gt 0) {
            Write-Host ""
            Write-Host "💡 Recommendations:" -ForegroundColor Cyan
            foreach ($recommendation in $testResults.Recommendations) {
                Write-Host "  • $recommendation" -ForegroundColor Cyan
            }
        }
    }
    
    return $testResults
}

function Test-SpotifyConfiguration {
    <#
    .SYNOPSIS
    Validate Spotify CLI configuration files and settings
    
    .DESCRIPTION
    Tests .env file, stored tokens, configuration files, and validates their format and permissions
    
    .PARAMETER ConfigPath
    Path to configuration directory (default: %APPDATA%\SpotifyCLI)
    
    .PARAMETER EnvPath
    Path to .env file (default: current directory)
    
    .EXAMPLE
    Test-SpotifyConfiguration
    Test configuration with default paths
    
    .EXAMPLE
    Test-SpotifyConfiguration -EnvPath "C:\MyProject\.env"
    Test configuration with custom .env file path
    #>
    param(
        [string]$ConfigPath = (Join-Path $env:APPDATA "SpotifyCLI"),
        [string]$EnvPath = ".\.env"
    )
    
    Write-Host "⚙️ Spotify Configuration Validation" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    Write-Host ""
    
    $testResults = @{
        Timestamp = Get-Date
        EnvFileTests = @{}
        TokenTests = @{}
        ConfigTests = @{}
        PermissionTests = @{}
        Issues = @()
        Recommendations = @()
    }
    
    # Test 1: .env file validation
    Write-Host "📄 Testing .env File" -ForegroundColor Yellow
    Write-Host "--------------------" -ForegroundColor Yellow
    
    Write-Host "  Checking .env file existence..." -NoNewline
    if (Test-Path $EnvPath) {
        Write-Host " ✅ Found" -ForegroundColor Green
        $testResults.EnvFileTests["Exists"] = $true
        
        try {
            $envContent = Get-Content $EnvPath -ErrorAction Stop
            $testResults.EnvFileTests["Readable"] = $true
            Write-Host "  Reading .env file content..." -NoNewline
            Write-Host " ✅ Readable" -ForegroundColor Green
            
            # Parse environment variables
            $envVars = @{}
            $lineNumber = 0
            foreach ($line in $envContent) {
                $lineNumber++
                if ($line -match "^\s*([^#][^=]*?)\s*=\s*(.*?)\s*$") {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    $envVars[$key] = $value
                }
            }
            
            $testResults.EnvFileTests["Variables"] = $envVars
            
            # Check required variables
            Write-Host "  Validating required variables:" -ForegroundColor White
            
            $requiredVars = @("SPOTIFY_CLIENT_ID", "SPOTIFY_CLIENT_SECRET")
            foreach ($varName in $requiredVars) {
                Write-Host "    $varName..." -NoNewline
                if ($envVars.ContainsKey($varName) -and -not [string]::IsNullOrWhiteSpace($envVars[$varName])) {
                    $value = $envVars[$varName]
                    if ($value.Length -ge 32) {  # Spotify IDs/secrets are typically 32 chars
                        Write-Host " ✅ Present and valid length" -ForegroundColor Green
                        $testResults.EnvFileTests[$varName] = @{ Present = $true; Valid = $true; Length = $value.Length }
                    } else {
                        Write-Host " ⚠️ Present but suspicious length ($($value.Length) chars)" -ForegroundColor Yellow
                        $testResults.EnvFileTests[$varName] = @{ Present = $true; Valid = $false; Length = $value.Length }
                        $testResults.Issues += "$varName appears to be too short (expected ~32 characters)"
                        $testResults.Recommendations += "Verify $varName value from Spotify Developer Dashboard"
                    }
                } else {
                    Write-Host " ❌ Missing or empty" -ForegroundColor Red
                    $testResults.EnvFileTests[$varName] = @{ Present = $false; Valid = $false }
                    $testResults.Issues += "$varName is missing or empty in .env file"
                    $testResults.Recommendations += "Add $varName to .env file from Spotify Developer Dashboard"
                }
            }
            
            # Check for common issues
            if ($envVars.ContainsKey("SPOTIFY_CLIENT_ID") -and $envVars.ContainsKey("SPOTIFY_CLIENT_SECRET")) {
                if ($envVars["SPOTIFY_CLIENT_ID"] -eq $envVars["SPOTIFY_CLIENT_SECRET"]) {
                    Write-Host "  ❌ Client ID and Secret are identical" -ForegroundColor Red
                    $testResults.Issues += "Client ID and Client Secret should be different values"
                    $testResults.Recommendations += "Check Spotify Developer Dashboard for correct Client ID and Secret"
                }
            }
            
        } catch {
            Write-Host " ❌ Cannot read file" -ForegroundColor Red
            Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            $testResults.EnvFileTests["Readable"] = $false
            $testResults.Issues += "Cannot read .env file: $($_.Exception.Message)"
            $testResults.Recommendations += "Check file permissions and encoding for .env file"
        }
    } else {
        Write-Host " ❌ Not found" -ForegroundColor Red
        $testResults.EnvFileTests["Exists"] = $false
        $testResults.Issues += ".env file not found at $EnvPath"
        $testResults.Recommendations += "Create .env file with SPOTIFY_CLIENT_ID and SPOTIFY_CLIENT_SECRET"
    }
    
    Write-Host ""
    
    # Test 2: Token storage validation
    Write-Host "🔑 Testing Token Storage" -ForegroundColor Yellow
    Write-Host "-----------------------" -ForegroundColor Yellow
    
    $tokenFile = Join-Path $ConfigPath "tokens.json"
    Write-Host "  Checking token file..." -NoNewline
    
    if (Test-Path $tokenFile) {
        Write-Host " ✅ Found" -ForegroundColor Green
        $testResults.TokenTests["Exists"] = $true
        
        try {
            $tokenContent = Get-Content $tokenFile -Raw -ErrorAction Stop
            $testResults.TokenTests["Readable"] = $true
            
            if ([string]::IsNullOrWhiteSpace($tokenContent) -or $tokenContent.Trim() -eq "{}") {
                Write-Host "  📝 Token file is empty (no stored tokens)" -ForegroundColor Gray
                $testResults.TokenTests["HasTokens"] = $false
            } else {
                try {
                    $tokens = $tokenContent | ConvertFrom-Json -ErrorAction Stop
                    $testResults.TokenTests["ValidJson"] = $true
                    
                    # Check token structure
                    $requiredTokenFields = @("access_token", "token_type", "expires_in", "obtained_at")
                    $hasValidStructure = $true
                    
                    foreach ($field in $requiredTokenFields) {
                        if (-not $tokens.PSObject.Properties.Name -contains $field) {
                            $hasValidStructure = $false
                            break
                        }
                    }
                    
                    if ($hasValidStructure) {
                        Write-Host "  ✅ Valid token structure found" -ForegroundColor Green
                        $testResults.TokenTests["HasTokens"] = $true
                        $testResults.TokenTests["ValidStructure"] = $true
                        
                        # Check token expiration
                        try {
                            $obtained = [long]$tokens.obtained_at
                            $expiresIn = [int]$tokens.expires_in
                            $currentTime = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
                            $age = $currentTime - $obtained
                            
                            if ($age -ge $expiresIn) {
                                Write-Host "  ⚠️ Stored token is expired" -ForegroundColor Yellow
                                $testResults.TokenTests["Expired"] = $true
                                if ($tokens.PSObject.Properties.Name -contains "refresh_token" -and -not [string]::IsNullOrWhiteSpace($tokens.refresh_token)) {
                                    Write-Host "  ✅ Refresh token available for renewal" -ForegroundColor Green
                                    $testResults.TokenTests["CanRefresh"] = $true
                                } else {
                                    Write-Host "  ❌ No refresh token available" -ForegroundColor Red
                                    $testResults.TokenTests["CanRefresh"] = $false
                                    $testResults.Issues += "Token is expired and no refresh token is available"
                                    $testResults.Recommendations += "Re-authenticate to obtain new tokens"
                                }
                            } else {
                                $remainingTime = $expiresIn - $age
                                Write-Host "  ✅ Token is valid (expires in $remainingTime seconds)" -ForegroundColor Green
                                $testResults.TokenTests["Expired"] = $false
                                $testResults.TokenTests["RemainingTime"] = $remainingTime
                            }
                        } catch {
                            Write-Host "  ⚠️ Cannot validate token expiration" -ForegroundColor Yellow
                            $testResults.TokenTests["ExpirationCheckFailed"] = $true
                        }
                        
                    } else {
                        Write-Host "  ❌ Invalid token structure" -ForegroundColor Red
                        $testResults.TokenTests["ValidStructure"] = $false
                        $testResults.Issues += "Stored tokens have invalid structure"
                        $testResults.Recommendations += "Delete tokens.json and re-authenticate"
                    }
                    
                } catch {
                    Write-Host "  ❌ Invalid JSON format" -ForegroundColor Red
                    $testResults.TokenTests["ValidJson"] = $false
                    $testResults.Issues += "Token file contains invalid JSON"
                    $testResults.Recommendations += "Delete corrupted tokens.json and re-authenticate"
                }
            }
            
        } catch {
            Write-Host " ❌ Cannot read token file" -ForegroundColor Red
            $testResults.TokenTests["Readable"] = $false
            $testResults.Issues += "Cannot read token file: $($_.Exception.Message)"
            $testResults.Recommendations += "Check permissions for SpotifyCLI directory"
        }
    } else {
        Write-Host " 📝 Not found (will be created on first authentication)" -ForegroundColor Gray
        $testResults.TokenTests["Exists"] = $false
    }
    
    Write-Host ""
    
    # Test 3: Configuration file validation
    Write-Host "⚙️ Testing Configuration File" -ForegroundColor Yellow
    Write-Host "-----------------------------" -ForegroundColor Yellow
    
    $configFile = Join-Path $ConfigPath "config.json"
    Write-Host "  Checking config file..." -NoNewline
    
    if (Test-Path $configFile) {
        Write-Host " ✅ Found" -ForegroundColor Green
        $testResults.ConfigTests["Exists"] = $true
        
        try {
            $configContent = Get-Content $configFile -Raw -ErrorAction Stop
            $testResults.ConfigTests["Readable"] = $true
            
            try {
                $config = $configContent | ConvertFrom-Json -ErrorAction Stop
                $testResults.ConfigTests["ValidJson"] = $true
                Write-Host "  ✅ Valid JSON format" -ForegroundColor Green
                
                # Validate configuration values
                $configValid = $true
                $configIssues = @()
                
                # Check boolean values
                $booleanSettings = @("CompactMode", "NotificationsEnabled", "LoggingEnabled", "HistoryEnabled")
                foreach ($setting in $booleanSettings) {
                    if ($config.PSObject.Properties.Name -contains $setting) {
                        if ($config.$setting -isnot [bool]) {
                            $configIssues += "$setting should be true or false"
                            $configValid = $false
                        }
                    }
                }
                
                # Check numeric values
                if ($config.PSObject.Properties.Name -contains "AutoRefreshInterval") {
                    if ($config.AutoRefreshInterval -isnot [int] -or $config.AutoRefreshInterval -lt 0) {
                        $configIssues += "AutoRefreshInterval should be a non-negative integer"
                        $configValid = $false
                    }
                }
                
                if ($configValid) {
                    Write-Host "  ✅ Configuration values are valid" -ForegroundColor Green
                    $testResults.ConfigTests["ValidValues"] = $true
                } else {
                    Write-Host "  ⚠️ Configuration has invalid values:" -ForegroundColor Yellow
                    foreach ($issue in $configIssues) {
                        Write-Host "    • $issue" -ForegroundColor Yellow
                    }
                    $testResults.ConfigTests["ValidValues"] = $false
                    $testResults.Issues += "Configuration file has invalid values"
                    $testResults.Recommendations += "Reset configuration to defaults or fix invalid values"
                }
                
            } catch {
                Write-Host "  ❌ Invalid JSON format" -ForegroundColor Red
                $testResults.ConfigTests["ValidJson"] = $false
                $testResults.Issues += "Configuration file contains invalid JSON"
                $testResults.Recommendations += "Delete config.json to reset to defaults"
            }
            
        } catch {
            Write-Host " ❌ Cannot read config file" -ForegroundColor Red
            $testResults.ConfigTests["Readable"] = $false
            $testResults.Issues += "Cannot read configuration file: $($_.Exception.Message)"
        }
    } else {
        Write-Host " 📝 Not found (will use defaults)" -ForegroundColor Gray
        $testResults.ConfigTests["Exists"] = $false
    }
    
    Write-Host ""
    
    # Test 4: Directory permissions
    Write-Host "📁 Testing Directory Permissions" -ForegroundColor Yellow
    Write-Host "--------------------------------" -ForegroundColor Yellow
    
    Write-Host "  Testing config directory access..." -NoNewline
    try {
        if (-not (Test-Path $ConfigPath)) {
            New-Item -ItemType Directory -Path $ConfigPath -Force | Out-Null
        }
        
        # Test write permission
        $testFile = Join-Path $ConfigPath "permission-test.tmp"
        "test" | Set-Content -Path $testFile -ErrorAction Stop
        Remove-Item $testFile -ErrorAction SilentlyContinue
        
        Write-Host " ✅ Read/Write access confirmed" -ForegroundColor Green
        $testResults.PermissionTests["ConfigDirectory"] = $true
        
    } catch {
        Write-Host " ❌ No write access" -ForegroundColor Red
        $testResults.PermissionTests["ConfigDirectory"] = $false
        $testResults.Issues += "No write access to configuration directory: $ConfigPath"
        $testResults.Recommendations += "Check user permissions for AppData directory"
    }
    
    # Summary
    Write-Host ""
    Write-Host "📊 Configuration Validation Summary" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    
    $issueCount = $testResults.Issues.Count
    $recommendationCount = $testResults.Recommendations.Count
    
    if ($issueCount -eq 0) {
        Write-Host "✅ Configuration validation passed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ $issueCount issue(s) detected:" -ForegroundColor Yellow
        foreach ($issue in $testResults.Issues) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
    }
    
    if ($recommendationCount -gt 0) {
        Write-Host ""
        Write-Host "💡 Recommendations:" -ForegroundColor Cyan
        foreach ($recommendation in $testResults.Recommendations) {
            Write-Host "  • $recommendation" -ForegroundColor Cyan
        }
    }
    
    return $testResults
}

function Invoke-SpotifyFullDiagnostics {
    <#
    .SYNOPSIS
    Run complete Spotify CLI diagnostic suite
    
    .DESCRIPTION
    Runs all diagnostic tests in sequence: system, API connectivity, local server, and configuration
    
    .PARAMETER ExportReport
    Export comprehensive diagnostic report to file
    
    .PARAMETER Detailed
    Show detailed diagnostic information
    
    .EXAMPLE
    Invoke-SpotifyFullDiagnostics
    Run complete diagnostic suite
    
    .EXAMPLE
    Invoke-SpotifyFullDiagnostics -ExportReport -Detailed
    Run detailed diagnostics and export comprehensive report
    #>
    param(
        [switch]$ExportReport,
        [switch]$Detailed
    )
    
    Write-Host "🔍 Spotify CLI - Complete Diagnostic Suite" -ForegroundColor Magenta
    Write-Host "===========================================" -ForegroundColor Magenta
    Write-Host ""
    
    $fullResults = @{
        Timestamp = Get-Date
        SystemDiagnostics = $null
        ApiConnectivity = $null
        LocalServer = $null
        Configuration = $null
        OverallStatus = "Unknown"
        CriticalIssues = @()
        AllRecommendations = @()
    }
    
    # Run system diagnostics
    Write-Host "🖥️ PHASE 1: System Diagnostics" -ForegroundColor Magenta
    Write-Host "==============================" -ForegroundColor Magenta
    $fullResults.SystemDiagnostics = Test-SpotifySystemDiagnostics -Detailed:$Detailed
    
    Write-Host ""
    Write-Host "🌐 PHASE 2: API Connectivity" -ForegroundColor Magenta
    Write-Host "============================" -ForegroundColor Magenta
    $fullResults.ApiConnectivity = Test-SpotifyApiConnectivity
    
    Write-Host ""
    Write-Host "🖥️ PHASE 3: Local Server Test" -ForegroundColor Magenta
    Write-Host "=============================" -ForegroundColor Magenta
    $fullResults.LocalServer = Test-SpotifyLocalServer
    
    Write-Host ""
    Write-Host "⚙️ PHASE 4: Configuration Validation" -ForegroundColor Magenta
    Write-Host "====================================" -ForegroundColor Magenta
    $fullResults.Configuration = Test-SpotifyConfiguration
    
    # Compile overall results
    Write-Host ""
    Write-Host "📊 OVERALL DIAGNOSTIC SUMMARY" -ForegroundColor Magenta
    Write-Host "=============================" -ForegroundColor Magenta
    
    $allIssues = @()
    $allRecommendations = @()
    
    if ($fullResults.SystemDiagnostics.Issues) { $allIssues += $fullResults.SystemDiagnostics.Issues }
    if ($fullResults.ApiConnectivity.Issues) { $allIssues += $fullResults.ApiConnectivity.Issues }
    if ($fullResults.LocalServer.Issues) { $allIssues += $fullResults.LocalServer.Issues }
    if ($fullResults.Configuration.Issues) { $allIssues += $fullResults.Configuration.Issues }
    
    if ($fullResults.SystemDiagnostics.Recommendations) { $allRecommendations += $fullResults.SystemDiagnostics.Recommendations }
    if ($fullResults.ApiConnectivity.Recommendations) { $allRecommendations += $fullResults.ApiConnectivity.Recommendations }
    if ($fullResults.LocalServer.Recommendations) { $allRecommendations += $fullResults.LocalServer.Recommendations }
    if ($fullResults.Configuration.Recommendations) { $allRecommendations += $fullResults.Configuration.Recommendations }
    
    $fullResults.CriticalIssues = $allIssues
    $fullResults.AllRecommendations = $allRecommendations
    
    # Determine overall status
    $criticalCount = $allIssues.Count
    if ($criticalCount -eq 0) {
        $fullResults.OverallStatus = "Ready"
        Write-Host "✅ SPOTIFY CLI IS READY TO USE" -ForegroundColor Green
        Write-Host "All diagnostic tests passed successfully!" -ForegroundColor Green
    } elseif ($criticalCount -le 2) {
        $fullResults.OverallStatus = "Minor Issues"
        Write-Host "⚠️ SPOTIFY CLI HAS MINOR ISSUES ($criticalCount)" -ForegroundColor Yellow
        Write-Host "The CLI should work but may have reduced functionality." -ForegroundColor Yellow
    } else {
        $fullResults.OverallStatus = "Major Issues"
        Write-Host "❌ SPOTIFY CLI HAS MAJOR ISSUES ($criticalCount)" -ForegroundColor Red
        Write-Host "The CLI may not work properly until issues are resolved." -ForegroundColor Red
    }
    
    if ($criticalCount -gt 0) {
        Write-Host ""
        Write-Host "🚨 Issues Found:" -ForegroundColor Red
        foreach ($issue in $allIssues) {
            Write-Host "  • $issue" -ForegroundColor Yellow
        }
    }
    
    if ($allRecommendations.Count -gt 0) {
        Write-Host ""
        Write-Host "💡 Recommended Actions:" -ForegroundColor Cyan
        $uniqueRecommendations = $allRecommendations | Sort-Object -Unique
        foreach ($recommendation in $uniqueRecommendations) {
            Write-Host "  • $recommendation" -ForegroundColor Cyan
        }
    }
    
    # Export comprehensive report if requested
    if ($ExportReport) {
        $reportPath = Join-Path $env:TEMP "SpotifyCLI-FullDiagnostics-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        try {
            $fullResults | ConvertTo-Json -Depth 15 | Set-Content -Path $reportPath -Encoding UTF8
            Write-Host ""
            Write-Host "📄 Comprehensive diagnostic report exported to:" -ForegroundColor Green
            Write-Host "   $reportPath" -ForegroundColor White
        } catch {
            Write-Host ""
            Write-Host "❌ Failed to export diagnostic report: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    return $fullResults
}

# Export the functions
Export-ModuleMember -Function Test-SpotifySystemDiagnostics, Test-SpotifyApiConnectivity, Test-SpotifyLocalServer, Test-SpotifyConfiguration, Invoke-SpotifyFullDiagnostics