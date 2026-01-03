# Error Handling Framework Module
# Provides centralized error handling and custom exception types for Spotify CLI live features

using namespace System.Management.Automation

# Custom exception types for Spotify CLI live features
class SpotifyLiveFeatureException : System.Exception {
    [string] $ErrorCode
    [hashtable] $Context
    
    SpotifyLiveFeatureException([string]$message) : base($message) {
        $this.ErrorCode = "GENERAL_ERROR"
        $this.Context = @{}
    }
    
    SpotifyLiveFeatureException([string]$message, [string]$errorCode) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = @{}
    }
    
    SpotifyLiveFeatureException([string]$message, [string]$errorCode, [hashtable]$context) : base($message) {
        $this.ErrorCode = $errorCode
        $this.Context = $context
    }
    
    SpotifyLiveFeatureException([string]$message, [System.Exception]$innerException) : base($message, $innerException) {
        $this.ErrorCode = "GENERAL_ERROR"
        $this.Context = @{}
    }
}

# Live Display specific exceptions
class LiveDisplayException : SpotifyLiveFeatureException {
    LiveDisplayException([string]$message) : base($message, "LIVE_DISPLAY_ERROR") {}
    LiveDisplayException([string]$message, [hashtable]$context) : base($message, "LIVE_DISPLAY_ERROR", $context) {}
}

class DisplayEngineNotSupportedException : LiveDisplayException {
    DisplayEngineNotSupportedException([string]$engineType) : base("Display engine not supported: $engineType") {
        $this.ErrorCode = "DISPLAY_ENGINE_NOT_SUPPORTED"
    }
}

class TerminalCapabilityException : LiveDisplayException {
    TerminalCapabilityException([string]$capability) : base("Terminal capability not available: $capability") {
        $this.ErrorCode = "TERMINAL_CAPABILITY_MISSING"
    }
}

# Lyrics specific exceptions
class LyricsException : SpotifyLiveFeatureException {
    LyricsException([string]$message) : base($message, "LYRICS_ERROR") {}
    LyricsException([string]$message, [hashtable]$context) : base($message, "LYRICS_ERROR", $context) {}
}

class LyricsProviderException : LyricsException {
    [string] $ProviderName
    
    LyricsProviderException([string]$providerName, [string]$message) : base("Lyrics provider '$providerName' error: $message") {
        $this.ProviderName = $providerName
        $this.ErrorCode = "LYRICS_PROVIDER_ERROR"
    }
}

class LyricsCacheException : LyricsException {
    LyricsCacheException([string]$message) : base("Lyrics cache error: $message") {
        $this.ErrorCode = "LYRICS_CACHE_ERROR"
    }
}

# Statistics specific exceptions
class StatisticsException : SpotifyLiveFeatureException {
    StatisticsException([string]$message) : base($message, "STATISTICS_ERROR") {}
    StatisticsException([string]$message, [hashtable]$context) : base($message, "STATISTICS_ERROR", $context) {}
}

class DataCollectionException : StatisticsException {
    DataCollectionException([string]$message) : base("Data collection error: $message") {
        $this.ErrorCode = "DATA_COLLECTION_ERROR"
    }
}

class AnalyticsProcessingException : StatisticsException {
    AnalyticsProcessingException([string]$message) : base("Analytics processing error: $message") {
        $this.ErrorCode = "ANALYTICS_PROCESSING_ERROR"
    }
}

# API Client specific exceptions
class ApiClientException : SpotifyLiveFeatureException {
    [int] $StatusCode
    [string] $ResponseBody
    
    ApiClientException([string]$message) : base($message, "API_CLIENT_ERROR") {
        $this.StatusCode = 0
        $this.ResponseBody = ""
    }
    
    ApiClientException([string]$message, [int]$statusCode) : base($message, "API_CLIENT_ERROR") {
        $this.StatusCode = $statusCode
        $this.ResponseBody = ""
    }
    
    ApiClientException([string]$message, [int]$statusCode, [string]$responseBody) : base($message, "API_CLIENT_ERROR") {
        $this.StatusCode = $statusCode
        $this.ResponseBody = $responseBody
    }
}

class RateLimitException : ApiClientException {
    [int] $RetryAfterSeconds
    
    RateLimitException([int]$retryAfter) : base("Rate limit exceeded", 429) {
        $this.RetryAfterSeconds = $retryAfter
        $this.ErrorCode = "RATE_LIMIT_EXCEEDED"
    }
}

class AuthenticationException : ApiClientException {
    AuthenticationException([string]$message) : base($message, 401) {
        $this.ErrorCode = "AUTHENTICATION_ERROR"
    }
}

# Configuration specific exceptions
class ConfigurationException : SpotifyLiveFeatureException {
    ConfigurationException([string]$message) : base($message, "CONFIGURATION_ERROR") {}
}

class ConfigurationValidationException : ConfigurationException {
    [string[]] $ValidationErrors
    
    ConfigurationValidationException([string[]]$errors) : base("Configuration validation failed") {
        $this.ValidationErrors = $errors
        $this.ErrorCode = "CONFIGURATION_VALIDATION_ERROR"
    }
}

# Error handler class for centralized error management
class ErrorHandler {
    [hashtable] $ErrorStrategies
    [bool] $LoggingEnabled = $true
    [string] $LogLevel = "Error"
    [GracefulDegradationManager] $DegradationManager
    
    ErrorHandler() {
        $this.InitializeErrorStrategies()
        $this.DegradationManager = [GracefulDegradationManager]::new()
    }
    
    [void] InitializeErrorStrategies() {
        $this.ErrorStrategies = @{
            "RATE_LIMIT_EXCEEDED" = @{
                Action = "Retry"
                RetryDelay = 60000
                MaxRetries = 3
                UserMessage = "Rate limit exceeded. Waiting before retry..."
            }
            "AUTHENTICATION_ERROR" = @{
                Action = "Reauth"
                UserMessage = "Authentication required. Please re-authenticate with Spotify."
                SuggestedAction = "Run authentication command"
            }
            "API_CLIENT_ERROR" = @{
                Action = "Retry"
                RetryDelay = 2000
                MaxRetries = 2
                UserMessage = "API request failed. Retrying..."
                FallbackToCachedData = $true
            }
            "DISPLAY_ENGINE_NOT_SUPPORTED" = @{
                Action = "Fallback"
                UserMessage = "Display engine not supported. Using fallback display mode."
                FallbackMode = "console"
            }
            "TERMINAL_CAPABILITY_MISSING" = @{
                Action = "Fallback"
                UserMessage = "Terminal capability missing. Using simplified display."
                FallbackMode = "simple"
            }
            "LYRICS_PROVIDER_ERROR" = @{
                Action = "Fallback"
                UserMessage = "Lyrics provider failed. Trying alternative provider..."
                FallbackAction = "NextProvider"
            }
            "LYRICS_CACHE_ERROR" = @{
                Action = "Continue"
                UserMessage = "Lyrics cache error. Fetching lyrics directly..."
                SkipCache = $true
            }
            "DATA_COLLECTION_ERROR" = @{
                Action = "Continue"
                UserMessage = "Data collection failed. Statistics may be incomplete."
                DisableFeature = "DataCollection"
            }
            "CONFIGURATION_ERROR" = @{
                Action = "UseDefaults"
                UserMessage = "Configuration error. Using default settings."
                ResetToDefaults = $true
            }
            "GENERAL_ERROR" = @{
                Action = "Log"
                UserMessage = "An unexpected error occurred."
                ShowDetails = $false
                FallbackToCachedData = $true
            }
            "NETWORK_ERROR" = @{
                Action = "Retry"
                RetryDelay = 5000
                MaxRetries = 3
                UserMessage = "Network connection failed. Retrying..."
                FallbackToCachedData = $true
                ExponentialBackoff = $true
            }
            "SERVICE_UNAVAILABLE" = @{
                Action = "Fallback"
                UserMessage = "Spotify service is temporarily unavailable. Using cached data..."
                FallbackToCachedData = $true
                DisableRealTimeFeatures = $true
            }
        }
    }
    
    [hashtable] HandleError([System.Exception]$exception, [hashtable]$operationContext = @{}) {
        $errorCode = "GENERAL_ERROR"
        $context = @{}
        
        # Extract error code and context from custom exceptions
        if ($exception -is [SpotifyLiveFeatureException]) {
            $errorCode = $exception.ErrorCode
            $context = $exception.Context
        }
        
        # Determine error code from exception type and message
        $errorCode = $this.DetermineErrorCode($exception, $errorCode)
        
        # Get error strategy
        $strategy = $this.GetErrorStrategy($errorCode)
        
        # Handle graceful degradation if applicable
        $fallbackData = $null
        if ($strategy.ContainsKey('FallbackToCachedData') -and $strategy.FallbackToCachedData) {
            try {
                $fallbackData = $this.DegradationManager.HandleApiFailure($exception, $operationContext.Operation, $operationContext)
            } catch {
                # Fallback failed, continue with normal error handling
            }
        }
        
        # Log the error
        if ($this.LoggingEnabled) {
            $this.LogError($exception, $errorCode, $context)
        }
        
        # Create response
        $response = @{
            ErrorCode = $errorCode
            Exception = $exception
            Strategy = $strategy
            Context = $context
            OperationContext = $operationContext
            FallbackData = $fallbackData
            Timestamp = [DateTime]::UtcNow
            DegradationStatus = $this.DegradationManager.GetDegradationStatus()
        }
        
        return $response
    }
    
    [string] DetermineErrorCode([System.Exception]$exception, [string]$defaultCode) {
        $message = $exception.Message.ToLower()
        
        # Network-related errors
        if ($message -like "*network*" -or $message -like "*connection*" -or $message -like "*timeout*") {
            return "NETWORK_ERROR"
        }
        
        # Service unavailable
        if ($message -like "*service unavailable*" -or $message -like "*503*" -or $message -like "*502*" -or $message -like "*504*") {
            return "SERVICE_UNAVAILABLE"
        }
        
        # Rate limiting
        if ($message -like "*rate limit*" -or $message -like "*429*" -or $message -like "*too many requests*") {
            return "RATE_LIMIT_EXCEEDED"
        }
        
        # Authentication
        if ($message -like "*unauthorized*" -or $message -like "*401*" -or $message -like "*authentication*") {
            return "AUTHENTICATION_ERROR"
        }
        
        return $defaultCode
    }
    
    [hashtable] GetErrorStrategy([string]$errorCode) {
        if ($this.ErrorStrategies.ContainsKey($errorCode)) {
            return $this.ErrorStrategies[$errorCode].Clone()
        }
        
        return $this.ErrorStrategies["GENERAL_ERROR"].Clone()
    }
    
    [void] LogError([System.Exception]$exception, [string]$errorCode, [hashtable]$context) {
        $logEntry = @{
            Timestamp = [DateTime]::UtcNow
            ErrorCode = $errorCode
            Message = $exception.Message
            StackTrace = $exception.StackTrace
            Context = $context
        }
        
        # In a real implementation, this would write to a log file
        # For now, we'll use Write-Warning for visibility
        if ($this.LogLevel -eq "Error" -or $this.LogLevel -eq "Debug") {
            Write-Warning "[$errorCode] $($exception.Message)"
            
            if ($this.LogLevel -eq "Debug" -and $context.Count -gt 0) {
                Write-Warning "Context: $($context | ConvertTo-Json -Compress)"
            }
        }
    }
    
    [void] ShowUserFriendlyError([hashtable]$errorResponse) {
        $strategy = $errorResponse.Strategy
        $exception = $errorResponse.Exception
        
        if ($strategy.ContainsKey('UserMessage')) {
            Write-Host $strategy.UserMessage -ForegroundColor Yellow
        }
        
        if ($strategy.ContainsKey('SuggestedAction')) {
            Write-Host "💡 Suggestion: $($strategy.SuggestedAction)" -ForegroundColor Cyan
        }
        
        # Show technical details in debug mode
        if ($this.LogLevel -eq "Debug") {
            Write-Host "Technical details: $($exception.Message)" -ForegroundColor Gray
        }
    }
    
    [bool] ShouldRetry([hashtable]$errorResponse, [int]$currentAttempt) {
        $strategy = $errorResponse.Strategy
        
        if ($strategy.Action -ne "Retry") {
            return $false
        }
        
        $maxRetries = $strategy.ContainsKey('MaxRetries') ? $strategy.MaxRetries : 1
        return $currentAttempt -lt $maxRetries
    }
    
    [int] GetRetryDelay([hashtable]$errorResponse, [int]$attempt) {
        $strategy = $errorResponse.Strategy
        $baseDelay = $strategy.ContainsKey('RetryDelay') ? $strategy.RetryDelay : 1000
        
        # Exponential backoff
        return $baseDelay * [Math]::Pow(2, $attempt - 1)
    }
    
    [void] SetLoggingLevel([string]$level) {
        if ($level -in @("Error", "Warning", "Info", "Debug")) {
            $this.LogLevel = $level
        }
    }
    
    [void] EnableLogging([bool]$enabled) {
        $this.LoggingEnabled = $enabled
    }
    
    [void] AddCustomErrorStrategy([string]$errorCode, [hashtable]$strategy) {
        $this.ErrorStrategies[$errorCode] = $strategy
    }
    
    [void] RegisterCachedDataSource([string]$sourceType, [object]$dataSource) {
        $this.DegradationManager.RegisterCachedDataSource($sourceType, $dataSource)
    }
    
    [void] RecordApiSuccess() {
        $this.DegradationManager.RecordApiSuccess()
    }
    
    [bool] IsOfflineMode() {
        return $this.DegradationManager.OfflineMode
    }
    
    [bool] ShouldUseCachedData() {
        return $this.DegradationManager.ShouldUseCachedData()
    }
    
    [bool] IsFeatureEnabled([string]$featureName) {
        return $this.DegradationManager.IsFeatureEnabled($featureName)
    }
    
    [hashtable] GetDegradationStatus() {
        return $this.DegradationManager.GetDegradationStatus()
    }
    
    [hashtable] GetErrorStatistics() {
        # In a real implementation, this would return statistics from logged errors
        return @{
            TotalErrors = 0
            ErrorsByCode = @{}
            MostCommonError = "None"
            LastError = $null
            DegradationStatus = $this.GetDegradationStatus()
        }
    }
}

# Retry helper class
class RetryHelper {
    static [object] ExecuteWithRetry([scriptblock]$operation, [ErrorHandler]$errorHandler, [int]$maxAttempts = 3, [hashtable]$operationContext = @{}) {
        $attempt = 1
        $lastErrorResponse = $null
        
        while ($attempt -le $maxAttempts) {
            try {
                $result = $operation.Invoke()
                
                # Record success if we had previous failures
                if ($attempt -gt 1) {
                    $errorHandler.RecordApiSuccess()
                }
                
                return $result
            } catch {
                $lastErrorResponse = $errorHandler.HandleError($_, $operationContext)
                
                # Check if we have fallback data
                if ($lastErrorResponse.FallbackData -ne $null) {
                    Write-Verbose "Using fallback data for operation"
                    return $lastErrorResponse.FallbackData
                }
                
                if ($errorHandler.ShouldRetry($lastErrorResponse, $attempt) -and $attempt -lt $maxAttempts) {
                    $delay = $errorHandler.GetRetryDelay($lastErrorResponse, $attempt)
                    
                    # Apply exponential backoff if specified in strategy
                    if ($lastErrorResponse.Strategy.ContainsKey('ExponentialBackoff') -and $lastErrorResponse.Strategy.ExponentialBackoff) {
                        $delay = $delay * [Math]::Pow(2, $attempt - 1)
                    }
                    
                    Write-Verbose "Retrying operation in $delay ms (attempt $($attempt + 1)/$maxAttempts)"
                    Start-Sleep -Milliseconds $delay
                    $attempt++
                } else {
                    $errorHandler.ShowUserFriendlyError($lastErrorResponse)
                    
                    # Check if we should return fallback data instead of throwing
                    if ($lastErrorResponse.Strategy.ContainsKey('FallbackToCachedData') -and $lastErrorResponse.Strategy.FallbackToCachedData) {
                        # Try one more time to get cached data
                        try {
                            $fallbackData = $errorHandler.DegradationManager.GetCachedData($operationContext.CacheSource, $operationContext.CacheKey)
                            if ($fallbackData -ne $null) {
                                Write-Host "📋 Returning cached data as final fallback" -ForegroundColor Yellow
                                return $fallbackData
                            }
                        } catch {
                            # Ignore fallback errors
                        }
                    }
                    
                    throw
                }
            }
        }
        
        # Final attempt to use cached data before giving up
        if ($lastErrorResponse -and $lastErrorResponse.Strategy.ContainsKey('FallbackToCachedData') -and $lastErrorResponse.Strategy.FallbackToCachedData) {
            try {
                $fallbackData = $errorHandler.DegradationManager.GetCachedData($operationContext.CacheSource, $operationContext.CacheKey)
                if ($fallbackData -ne $null) {
                    Write-Host "📋 Maximum retries exceeded. Using cached data." -ForegroundColor Yellow
                    return $fallbackData
                }
            } catch {
                # Ignore fallback errors
            }
        }
        
        throw [System.InvalidOperationException]::new("Maximum retry attempts exceeded and no fallback data available")
    }
    
    static [object] ExecuteWithGracefulDegradation([scriptblock]$operation, [ErrorHandler]$errorHandler, [hashtable]$fallbackOptions) {
        try {
            $result = $operation.Invoke()
            $errorHandler.RecordApiSuccess()
            return $result
        } catch {
            return $errorHandler.DegradationManager.HandleApiFailure($_, $fallbackOptions.Operation, $fallbackOptions)
        }
    }
}

# Graceful degradation manager
class GracefulDegradationManager {
    [hashtable] $CachedDataSources = @{}
    [hashtable] $FeatureStates = @{}
    [bool] $OfflineMode = $false
    [DateTime] $LastSuccessfulApiCall = [DateTime]::MinValue
    [int] $ConsecutiveFailures = 0
    [int] $MaxConsecutiveFailures = 5
    
    GracefulDegradationManager() {
        $this.InitializeFeatureStates()
    }
    
    [void] InitializeFeatureStates() {
        $this.FeatureStates = @{
            "LiveDisplay" = @{ Enabled = $true; LastWorking = [DateTime]::UtcNow }
            "LyricsDisplay" = @{ Enabled = $true; LastWorking = [DateTime]::UtcNow }
            "Statistics" = @{ Enabled = $true; LastWorking = [DateTime]::UtcNow }
            "RealTimeUpdates" = @{ Enabled = $true; LastWorking = [DateTime]::UtcNow }
        }
    }
    
    [void] RegisterCachedDataSource([string]$sourceType, [object]$dataSource) {
        $this.CachedDataSources[$sourceType] = $dataSource
    }
    
    [object] GetCachedData([string]$sourceType, [string]$key) {
        if ($this.CachedDataSources.ContainsKey($sourceType)) {
            $source = $this.CachedDataSources[$sourceType]
            
            # Try to get cached data based on source type
            switch ($sourceType) {
                "ApiClient" {
                    if ($source -is [EnhancedSpotifyApiClient]) {
                        return $source.GetCachedData($key)
                    }
                }
                "LyricsCache" {
                    return $source.GetCachedLyrics($key)
                }
                "StatisticsCache" {
                    return $source.GetCachedStatistics($key)
                }
            }
        }
        
        return $null
    }
    
    [void] RecordApiSuccess() {
        $this.LastSuccessfulApiCall = [DateTime]::UtcNow
        $this.ConsecutiveFailures = 0
        
        if ($this.OfflineMode) {
            $this.OfflineMode = $false
            Write-Host "🌐 Connection restored. Returning to online mode." -ForegroundColor Green
        }
    }
    
    [void] RecordApiFailure() {
        $this.ConsecutiveFailures++
        
        if ($this.ConsecutiveFailures -ge $this.MaxConsecutiveFailures -and -not $this.OfflineMode) {
            $this.OfflineMode = $true
            Write-Host "📴 Multiple API failures detected. Switching to offline mode with cached data." -ForegroundColor Yellow
        }
    }
    
    [bool] ShouldUseCachedData() {
        return $this.OfflineMode -or 
               $this.ConsecutiveFailures -gt 2 -or 
               ([DateTime]::UtcNow - $this.LastSuccessfulApiCall).TotalMinutes -gt 10
    }
    
    [void] DisableFeature([string]$featureName, [string]$reason) {
        if ($this.FeatureStates.ContainsKey($featureName)) {
            $this.FeatureStates[$featureName].Enabled = $false
            $this.FeatureStates[$featureName].DisabledReason = $reason
            $this.FeatureStates[$featureName].DisabledAt = [DateTime]::UtcNow
            
            Write-Warning "Feature '$featureName' disabled: $reason"
        }
    }
    
    [void] EnableFeature([string]$featureName) {
        if ($this.FeatureStates.ContainsKey($featureName)) {
            $this.FeatureStates[$featureName].Enabled = $true
            $this.FeatureStates[$featureName].LastWorking = [DateTime]::UtcNow
            
            if ($this.FeatureStates[$featureName].ContainsKey('DisabledReason')) {
                $this.FeatureStates[$featureName].Remove('DisabledReason')
                $this.FeatureStates[$featureName].Remove('DisabledAt')
            }
            
            Write-Host "✅ Feature '$featureName' re-enabled." -ForegroundColor Green
        }
    }
    
    [bool] IsFeatureEnabled([string]$featureName) {
        if ($this.FeatureStates.ContainsKey($featureName)) {
            return $this.FeatureStates[$featureName].Enabled
        }
        return $true
    }
    
    [hashtable] GetDegradationStatus() {
        return @{
            OfflineMode = $this.OfflineMode
            ConsecutiveFailures = $this.ConsecutiveFailures
            LastSuccessfulApiCall = $this.LastSuccessfulApiCall
            FeatureStates = $this.FeatureStates.Clone()
            ShouldUseCachedData = $this.ShouldUseCachedData()
        }
    }
    
    [object] HandleApiFailure([System.Exception]$exception, [string]$operation, [hashtable]$fallbackOptions = @{}) {
        $this.RecordApiFailure()
        
        # Try to get cached data if available
        if ($fallbackOptions.ContainsKey('CacheKey') -and $fallbackOptions.ContainsKey('CacheSource')) {
            $cachedData = $this.GetCachedData($fallbackOptions.CacheSource, $fallbackOptions.CacheKey)
            
            if ($cachedData -ne $null) {
                Write-Host "📋 Using cached data for $operation" -ForegroundColor Cyan
                return $cachedData
            }
        }
        
        # Disable real-time features if in offline mode
        if ($this.OfflineMode) {
            $this.DisableFeature("RealTimeUpdates", "API unavailable")
        }
        
        # Return fallback data if provided
        if ($fallbackOptions.ContainsKey('FallbackData')) {
            return $fallbackOptions.FallbackData
        }
        
        # Re-throw the exception if no fallback is available
        throw $exception
    }
}

# Error context builder
class ErrorContextBuilder {
    [hashtable] $Context = @{}
    
    [ErrorContextBuilder] AddTrackInfo([hashtable]$trackData) {
        if ($trackData) {
            $this.Context["TrackId"] = $trackData.id
            $this.Context["TrackName"] = $trackData.name
            $this.Context["ArtistName"] = ($trackData.artists | ForEach-Object { $_.name }) -join ", "
        }
        return $this
    }
    
    [ErrorContextBuilder] AddApiInfo([string]$endpoint, [string]$method, [int]$statusCode) {
        $this.Context["ApiEndpoint"] = $endpoint
        $this.Context["HttpMethod"] = $method
        $this.Context["StatusCode"] = $statusCode
        return $this
    }
    
    [ErrorContextBuilder] AddUserAction([string]$action, [hashtable]$parameters) {
        $this.Context["UserAction"] = $action
        $this.Context["ActionParameters"] = $parameters
        return $this
    }
    
    [ErrorContextBuilder] AddSystemInfo([string]$component, [string]$version) {
        $this.Context["Component"] = $component
        $this.Context["Version"] = $version
        $this.Context["PowerShellVersion"] = $PSVersionTable.PSVersion.ToString()
        $this.Context["OperatingSystem"] = [System.Environment]::OSVersion.ToString()
        return $this
    }
    
    [ErrorContextBuilder] AddCustomData([string]$key, $value) {
        $this.Context[$key] = $value
        return $this
    }
    
    [hashtable] Build() {
        return $this.Context.Clone()
    }
    
    [void] Clear() {
        $this.Context.Clear()
    }
}

# Global error handler instance
$script:GlobalErrorHandler = [ErrorHandler]::new()

# Helper functions for easy error handling
function New-SpotifyLiveFeatureException {
    param(
        [Parameter(Mandatory)]
        [string]$Message,
        
        [string]$ErrorCode = "GENERAL_ERROR",
        
        [hashtable]$Context = @{},
        
        [System.Exception]$InnerException
    )
    
    if ($InnerException) {
        return [SpotifyLiveFeatureException]::new($Message, $InnerException)
    } else {
        return [SpotifyLiveFeatureException]::new($Message, $ErrorCode, $Context)
    }
}

function Invoke-WithErrorHandling {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [ErrorHandler]$ErrorHandler = $script:GlobalErrorHandler,
        
        [int]$MaxRetries = 1,
        
        [hashtable]$OperationContext = @{},
        
        [switch]$ShowUserFriendlyErrors,
        
        [switch]$UseGracefulDegradation
    )
    
    try {
        if ($UseGracefulDegradation -and $OperationContext.Count -gt 0) {
            return [RetryHelper]::ExecuteWithGracefulDegradation($ScriptBlock, $ErrorHandler, $OperationContext)
        } elseif ($MaxRetries -gt 1) {
            return [RetryHelper]::ExecuteWithRetry($ScriptBlock, $ErrorHandler, $MaxRetries, $OperationContext)
        } else {
            $result = $ScriptBlock.Invoke()
            $ErrorHandler.RecordApiSuccess()
            return $result
        }
    } catch {
        $errorResponse = $ErrorHandler.HandleError($_, $OperationContext)
        
        if ($ShowUserFriendlyErrors) {
            $ErrorHandler.ShowUserFriendlyError($errorResponse)
        }
        
        # Return fallback data if available
        if ($errorResponse.FallbackData -ne $null) {
            return $errorResponse.FallbackData
        }
        
        throw
    }
}

function Get-ErrorContextBuilder {
    return [ErrorContextBuilder]::new()
}

function Get-GlobalErrorHandler {
    return $script:GlobalErrorHandler
}

function Set-ErrorHandlerLogging {
    param(
        [bool]$Enabled = $true,
        [ValidateSet("Error", "Warning", "Info", "Debug")]
        [string]$Level = "Error"
    )
    
    $script:GlobalErrorHandler.EnableLogging($Enabled)
    $script:GlobalErrorHandler.SetLoggingLevel($Level)
}

function Register-CachedDataSource {
    param(
        [Parameter(Mandatory)]
        [string]$SourceType,
        
        [Parameter(Mandatory)]
        [object]$DataSource,
        
        [ErrorHandler]$ErrorHandler = $script:GlobalErrorHandler
    )
    
    $ErrorHandler.RegisterCachedDataSource($SourceType, $DataSource)
}

function Test-OfflineMode {
    param(
        [ErrorHandler]$ErrorHandler = $script:GlobalErrorHandler
    )
    
    return $ErrorHandler.IsOfflineMode()
}

function Test-FeatureEnabled {
    param(
        [Parameter(Mandatory)]
        [string]$FeatureName,
        
        [ErrorHandler]$ErrorHandler = $script:GlobalErrorHandler
    )
    
    return $ErrorHandler.IsFeatureEnabled($FeatureName)
}

function Get-DegradationStatus {
    param(
        [ErrorHandler]$ErrorHandler = $script:GlobalErrorHandler
    )
    
    return $ErrorHandler.GetDegradationStatus()
}

function Invoke-WithGracefulDegradation {
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory)]
        [hashtable]$FallbackOptions,
        
        [ErrorHandler]$ErrorHandler = $script:GlobalErrorHandler
    )
    
    return [RetryHelper]::ExecuteWithGracefulDegradation($ScriptBlock, $ErrorHandler, $FallbackOptions)
}

# Export functions and classes
Export-ModuleMember -Function @(
    'New-SpotifyLiveFeatureException',
    'Invoke-WithErrorHandling',
    'Get-ErrorContextBuilder',
    'Get-GlobalErrorHandler',
    'Set-ErrorHandlerLogging',
    'Register-CachedDataSource',
    'Test-OfflineMode',
    'Test-FeatureEnabled',
    'Get-DegradationStatus',
    'Invoke-WithGracefulDegradation'
) -Variable @()