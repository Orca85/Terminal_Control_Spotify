# Task 1 Validation Script
# Validates that the core infrastructure and base classes have been successfully implemented

Write-Host "🎯 Task 1 Validation: Core Infrastructure and Base Classes" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

$validationResults = @{
    DirectoryStructure = $false
    BaseInterfaces = $false
    ConfigurationSystem = $false
    ErrorHandling = $false
    ModuleIntegration = $false
}

# 1. Validate Directory Structure
Write-Host "1. Validating Directory Structure..." -ForegroundColor Yellow

$requiredDirectories = @(
    "modules",
    "modules\Core",
    "modules\LiveDisplay", 
    "modules\Lyrics",
    "modules\Statistics"
)

$requiredFiles = @(
    "modules\Core\ErrorHandling.psm1",
    "modules\Core\ConfigurationManager.psm1",
    "modules\Core\ApiClientManager.psm1",
    "modules\LiveDisplay\LiveDisplayEngine.psm1",
    "modules\Lyrics\LyricsEngine.psm1",
    "modules\Statistics\StatisticsEngine.psm1",
    "modules\SpotifyLiveFeatures.psm1"
)

$allDirectoriesExist = $true
foreach ($dir in $requiredDirectories) {
    if (Test-Path $dir) {
        Write-Host "   ✅ Directory: $dir" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Missing Directory: $dir" -ForegroundColor Red
        $allDirectoriesExist = $false
    }
}

$allFilesExist = $true
foreach ($file in $requiredFiles) {
    if (Test-Path $file) {
        Write-Host "   ✅ Module: $file" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Missing Module: $file" -ForegroundColor Red
        $allFilesExist = $false
    }
}

$validationResults.DirectoryStructure = $allDirectoriesExist -and $allFilesExist
Write-Host ""

# 2. Validate Base Interfaces and Abstract Classes
Write-Host "2. Validating Base Interfaces and Abstract Classes..." -ForegroundColor Yellow

$interfaceValidation = @{
    LiveDisplayEngine = $false
    LyricsProvider = $false
    ErrorHandling = $false
    Configuration = $false
}

# Check LiveDisplay interfaces
$liveDisplayContent = Get-Content "modules\LiveDisplay\LiveDisplayEngine.psm1" -Raw
if ($liveDisplayContent -match "class IDisplayEngine" -and 
    $liveDisplayContent -match "class LiveDisplayEngineBase" -and
    $liveDisplayContent -match "class ConsoleDisplayEngine") {
    Write-Host "   ✅ Live Display Engine interfaces and base classes" -ForegroundColor Green
    $interfaceValidation.LiveDisplayEngine = $true
} else {
    Write-Host "   ❌ Live Display Engine interfaces missing" -ForegroundColor Red
}

# Check Lyrics interfaces
$lyricsContent = Get-Content "modules\Lyrics\LyricsEngine.psm1" -Raw
if ($lyricsContent -match "class ILyricsProvider" -and 
    $lyricsContent -match "class LyricsProviderBase" -and
    $lyricsContent -match "class LyricsEngine") {
    Write-Host "   ✅ Lyrics Engine interfaces and base classes" -ForegroundColor Green
    $interfaceValidation.LyricsProvider = $true
} else {
    Write-Host "   ❌ Lyrics Engine interfaces missing" -ForegroundColor Red
}

# Check Error Handling
$errorContent = Get-Content "modules\Core\ErrorHandling.psm1" -Raw
if ($errorContent -match "class SpotifyLiveFeatureException" -and 
    $errorContent -match "class ErrorHandler" -and
    $errorContent -match "class RetryHelper") {
    Write-Host "   ✅ Error Handling framework classes" -ForegroundColor Green
    $interfaceValidation.ErrorHandling = $true
} else {
    Write-Host "   ❌ Error Handling framework missing" -ForegroundColor Red
}

# Check Configuration
$configContent = Get-Content "modules\Core\ConfigurationManager.psm1" -Raw
if ($configContent -match "class ConfigurationSchema" -and 
    $configContent -match "class ConfigurationManager" -and
    $configContent -match "class ConfigurationFactory") {
    Write-Host "   ✅ Configuration Management system classes" -ForegroundColor Green
    $interfaceValidation.Configuration = $true
} else {
    Write-Host "   ❌ Configuration Management system missing" -ForegroundColor Red
}

$validationResults.BaseInterfaces = $interfaceValidation.Values -notcontains $false
Write-Host ""

# 3. Validate Configuration Management System
Write-Host "3. Validating Configuration Management System..." -ForegroundColor Yellow

$configFeatures = @{
    Schema = $false
    DefaultValues = $false
    Validation = $false
    Persistence = $false
}

if ($configContent -match "liveDisplay" -and $configContent -match "refreshInterval" -and
    $configContent -match "lyrics" -and $configContent -match "preferredProvider" -and
    $configContent -match "statistics" -and $configContent -match "trackingEnabled" -and
    $configContent -match "apiClient" -and $configContent -match "maxRequestsPerMinute") {
    Write-Host "   ✅ Configuration schema with all required sections" -ForegroundColor Green
    $configFeatures.Schema = $true
} else {
    Write-Host "   ❌ Configuration schema incomplete" -ForegroundColor Red
}

if ($configContent -match "GetDefaultConfiguration" -and
    $configContent -match "Default.*=") {
    Write-Host "   ✅ Default configuration values" -ForegroundColor Green
    $configFeatures.DefaultValues = $true
} else {
    Write-Host "   ❌ Default configuration values missing" -ForegroundColor Red
}

if ($configContent -match "ValidateValue" -and
    $configContent -match "GetValidationErrors") {
    Write-Host "   ✅ Configuration validation system" -ForegroundColor Green
    $configFeatures.Validation = $true
} else {
    Write-Host "   ❌ Configuration validation system missing" -ForegroundColor Red
}

if ($configContent -match "SaveConfiguration" -and
    $configContent -match "LoadConfiguration" -and
    $configContent -match "ConvertTo-Json") {
    Write-Host "   ✅ Configuration persistence (JSON)" -ForegroundColor Green
    $configFeatures.Persistence = $true
} else {
    Write-Host "   ❌ Configuration persistence missing" -ForegroundColor Red
}

$validationResults.ConfigurationSystem = $configFeatures.Values -notcontains $false
Write-Host ""

# 4. Validate Error Handling Framework
Write-Host "4. Validating Error Handling Framework..." -ForegroundColor Yellow

$errorFeatures = @{
    CustomExceptions = $false
    ErrorStrategies = $false
    RetryLogic = $false
    UserFriendlyMessages = $false
}

if ($errorContent -match "LiveDisplayException" -and
    $errorContent -match "LyricsException" -and
    $errorContent -match "StatisticsException" -and
    $errorContent -match "ApiClientException") {
    Write-Host "   ✅ Custom exception types for all engines" -ForegroundColor Green
    $errorFeatures.CustomExceptions = $true
} else {
    Write-Host "   ❌ Custom exception types incomplete" -ForegroundColor Red
}

if ($errorContent -match "ErrorStrategies" -and
    $errorContent -match "RATE_LIMIT_EXCEEDED" -and
    $errorContent -match "AUTHENTICATION_ERROR") {
    Write-Host "   ✅ Error handling strategies" -ForegroundColor Green
    $errorFeatures.ErrorStrategies = $true
} else {
    Write-Host "   ❌ Error handling strategies missing" -ForegroundColor Red
}

if ($errorContent -match "RetryHelper" -and
    $errorContent -match "ExecuteWithRetry" -and
    $errorContent -match "ShouldRetry") {
    Write-Host "   ✅ Retry logic framework" -ForegroundColor Green
    $errorFeatures.RetryLogic = $true
} else {
    Write-Host "   ❌ Retry logic framework missing" -ForegroundColor Red
}

if ($errorContent -match "ShowUserFriendlyError" -and
    $errorContent -match "UserMessage") {
    Write-Host "   ✅ User-friendly error messages" -ForegroundColor Green
    $errorFeatures.UserFriendlyMessages = $true
} else {
    Write-Host "   ❌ User-friendly error messages missing" -ForegroundColor Red
}

$validationResults.ErrorHandling = $errorFeatures.Values -notcontains $false
Write-Host ""

# 5. Validate Module Integration
Write-Host "5. Validating Module Integration..." -ForegroundColor Yellow

$mainModuleContent = Get-Content "modules\SpotifyLiveFeatures.psm1" -Raw

$integrationFeatures = @{
    MainManager = $false
    SubModuleLoading = $false
    PublicFunctions = $false
    ExportedMembers = $false
}

if ($mainModuleContent -match "class SpotifyLiveFeaturesManager" -and
    $mainModuleContent -match "Initialize\(\)" -and
    $mainModuleContent -match "GetFeatureStatus\(\)") {
    Write-Host "   ✅ Main features manager class" -ForegroundColor Green
    $integrationFeatures.MainManager = $true
} else {
    Write-Host "   ❌ Main features manager class missing" -ForegroundColor Red
}

if ($mainModuleContent -match "SubModules.*=.*@\(" -and
    $mainModuleContent -match "ErrorHandling\.psm1" -and
    $mainModuleContent -match "ConfigurationManager\.psm1") {
    Write-Host "   ✅ Sub-module loading system" -ForegroundColor Green
    $integrationFeatures.SubModuleLoading = $true
} else {
    Write-Host "   ❌ Sub-module loading system missing" -ForegroundColor Red
}

if ($mainModuleContent -match "function Initialize-SpotifyLiveFeatures" -and
    $mainModuleContent -match "function Get-SpotifyLiveFeaturesStatus" -and
    $mainModuleContent -match "function Start-SpotifyLiveDisplay") {
    Write-Host "   ✅ Public API functions" -ForegroundColor Green
    $integrationFeatures.PublicFunctions = $true
} else {
    Write-Host "   ❌ Public API functions missing" -ForegroundColor Red
}

if ($mainModuleContent -match "Export-ModuleMember.*-Function") {
    Write-Host "   ✅ Module member exports" -ForegroundColor Green
    $integrationFeatures.ExportedMembers = $true
} else {
    Write-Host "   ❌ Module member exports missing" -ForegroundColor Red
}

$validationResults.ModuleIntegration = $integrationFeatures.Values -notcontains $false
Write-Host ""

# 6. Validate Requirements Coverage
Write-Host "6. Validating Requirements Coverage..." -ForegroundColor Yellow

Write-Host "   Requirements 4.1 (Multiple display modes):" -ForegroundColor Cyan
if ($liveDisplayContent -match "displayMode" -and $liveDisplayContent -match "detailed" -and $liveDisplayContent -match "compact" -and $liveDisplayContent -match "minimal") {
    Write-Host "     ✅ Multiple display modes supported" -ForegroundColor Green
} else {
    Write-Host "     ❌ Display modes not fully implemented" -ForegroundColor Red
}

Write-Host "   Requirements 5.1 (API rate limiting and caching):" -ForegroundColor Cyan
$apiContent = Get-Content "modules\Core\ApiClientManager.psm1" -Raw
if ($apiContent -match "class RateLimiter" -and $apiContent -match "class CacheManager") {
    Write-Host "     ✅ Rate limiting and caching implemented" -ForegroundColor Green
} else {
    Write-Host "     ❌ Rate limiting and caching missing" -ForegroundColor Red
}

Write-Host ""

# Final Results
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "🎯 Task 1 Validation Results" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host ""

$totalComponents = $validationResults.Count
$passedComponents = ($validationResults.Values | Where-Object { $_ -eq $true }).Count

Write-Host "Component Validation Results:" -ForegroundColor White
foreach ($component in $validationResults.Keys) {
    $status = if ($validationResults[$component]) { "✅ PASSED" } else { "❌ FAILED" }
    $color = if ($validationResults[$component]) { "Green" } else { "Red" }
    Write-Host "  $component : $status" -ForegroundColor $color
}

Write-Host ""
Write-Host "Overall Results:" -ForegroundColor White
Write-Host "  Total Components: $totalComponents" -ForegroundColor White
Write-Host "  Passed: $passedComponents" -ForegroundColor Green
Write-Host "  Failed: $($totalComponents - $passedComponents)" -ForegroundColor Red

Write-Host ""
if ($passedComponents -eq $totalComponents) {
    Write-Host "🎉 Task 1 - COMPLETED SUCCESSFULLY!" -ForegroundColor Green
    Write-Host "✅ All core infrastructure and base classes have been implemented" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 What was accomplished:" -ForegroundColor Cyan
    Write-Host "  • Created directory structure for LiveDisplay, Lyrics, and Statistics modules" -ForegroundColor White
    Write-Host "  • Defined base interfaces and abstract classes for all engines" -ForegroundColor White
    Write-Host "  • Implemented comprehensive configuration management system" -ForegroundColor White
    Write-Host "  • Set up error handling framework with custom exception types" -ForegroundColor White
    Write-Host "  • Created main integration module with public API" -ForegroundColor White
    Write-Host ""
    Write-Host "🚀 Ready to proceed to Task 2: Live Display Engine foundation" -ForegroundColor Cyan
    exit 0
} else {
    Write-Host "⚠️ Task 1 - PARTIALLY COMPLETED" -ForegroundColor Yellow
    Write-Host "Some components need attention before proceeding to the next task." -ForegroundColor Yellow
    exit 1
}