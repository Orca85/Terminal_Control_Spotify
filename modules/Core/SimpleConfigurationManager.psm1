# Simple Configuration Manager Module
# Provides configuration management without PowerShell classes for better compatibility

# Configuration schema as hashtable
$script:ConfigurationSchema = @{
    liveDisplay = @{
        refreshInterval = @{ Type = "int"; Min = 500; Max = 5000; Default = 1000 }
        displayMode = @{ Type = "string"; ValidValues = @("detailed", "compact", "minimal"); Default = "detailed" }
        sidecarPosition = @{ Type = "string"; ValidValues = @("left", "right", "top", "bottom"); Default = "right" }
        sidecarWidth = @{ Type = "int"; Min = 20; Max = 100; Default = 40 }
        showAlbumArt = @{ Type = "bool"; Default = $true }
        colorScheme = @{ Type = "string"; ValidValues = @("auto", "light", "dark"); Default = "auto" }
        useAnsiEscapes = @{ Type = "bool"; Default = $true }
    }
    lyrics = @{
        preferredProvider = @{ Type = "string"; ValidValues = @("genius", "musixmatch", "mock"); Default = "mock" }
        cacheEnabled = @{ Type = "bool"; Default = $true }
        syncHighlighting = @{ Type = "bool"; Default = $true }
        scrollSpeed = @{ Type = "int"; Min = 1; Max = 10; Default = 3 }
        cacheDirectory = @{ Type = "string"; Default = "" }
        maxCacheAgeDays = @{ Type = "int"; Min = 1; Max = 365; Default = 30 }
        geniusApiKey = @{ Type = "string"; Default = "" }
    }
    statistics = @{
        trackingEnabled = @{ Type = "bool"; Default = $true }
        retentionDays = @{ Type = "int"; Min = 30; Max = 1095; Default = 365 }
        exportFormat = @{ Type = "string"; ValidValues = @("json", "csv"); Default = "json" }
        defaultPeriod = @{ Type = "string"; ValidValues = @("day", "week", "month", "year"); Default = "month" }
        dataDirectory = @{ Type = "string"; Default = "" }
        autoCleanup = @{ Type = "bool"; Default = $true }
    }
    apiClient = @{
        maxRequestsPerMinute = @{ Type = "int"; Min = 10; Max = 100; Default = 60 }
        timeoutMs = @{ Type = "int"; Min = 5000; Max = 30000; Default = 10000 }
        retryAttempts = @{ Type = "int"; Min = 1; Max = 5; Default = 3 }
        cacheEnabled = @{ Type = "bool"; Default = $true }
        cacheDurationMs = @{ Type = "int"; Min = 1000; Max = 300000; Default = 60000 }
    }
}

# Global configuration state
$script:ConfigurationDirectory = $null
$script:ConfigurationFile = $null
$script:CurrentConfiguration = $null
$script:IsLoaded = $false

function Initialize-SimpleConfigurationManager {
    <#
    .SYNOPSIS
    Initialize the simple configuration manager
    #>
    param(
        [string]$ConfigDir = (Join-Path $env:APPDATA "SpotifyCLI\LiveFeatures")
    )
    
    $script:ConfigurationDirectory = $ConfigDir
    $script:ConfigurationFile = Join-Path $ConfigDir "live_features_config.json"
    
    # Ensure directory exists
    if (-not (Test-Path $script:ConfigurationDirectory)) {
        New-Item -ItemType Directory -Path $script:ConfigurationDirectory -Force | Out-Null
    }
    
    # Load configuration
    Load-SimpleConfiguration
}

function Get-DefaultConfiguration {
    <#
    .SYNOPSIS
    Get the default configuration
    #>
    $config = @{}
    
    foreach ($section in $script:ConfigurationSchema.Keys) {
        $config[$section] = @{}
        foreach ($key in $script:ConfigurationSchema[$section].Keys) {
            $config[$section][$key] = $script:ConfigurationSchema[$section][$key].Default
        }
    }
    
    return $config
}

function Test-ConfigurationValue {
    <#
    .SYNOPSIS
    Validate a configuration value
    #>
    param(
        [string]$Section,
        [string]$Key,
        $Value
    )
    
    if (-not $script:ConfigurationSchema.ContainsKey($Section)) {
        return $false
    }
    
    $sectionSchema = $script:ConfigurationSchema[$Section]
    if (-not $sectionSchema.ContainsKey($Key)) {
        return $false
    }
    
    $keySchema = $sectionSchema[$Key]
    
    switch ($keySchema.Type) {
        "int" {
            if ($Value -isnot [int]) {
                try {
                    $Value = [int]$Value
                } catch {
                    return $false
                }
            }
            if ($keySchema.ContainsKey('Min') -and $Value -lt $keySchema.Min) {
                return $false
            }
            if ($keySchema.ContainsKey('Max') -and $Value -gt $keySchema.Max) {
                return $false
            }
            return $true
        }
        "bool" {
            if ($Value -isnot [bool]) {
                if ($Value -eq "true" -or $Value -eq "True" -or $Value -eq $true) {
                    return $true
                }
                if ($Value -eq "false" -or $Value -eq "False" -or $Value -eq $false) {
                    return $true
                }
                return $false
            }
            return $true
        }
        "string" {
            if ($Value -isnot [string]) {
                $Value = [string]$Value
            }
            if ($keySchema.ContainsKey('ValidValues') -and $Value -notin $keySchema.ValidValues) {
                return $false
            }
            return $true
        }
        default {
            return $true
        }
    }
}

function Get-ConfigurationValidationErrors {
    <#
    .SYNOPSIS
    Get validation errors for a configuration
    #>
    param([hashtable]$Config)
    
    $errors = @()
    
    foreach ($section in $Config.Keys) {
        if ($section -eq '_metadata') { continue }  # Skip metadata
        
        if (-not $script:ConfigurationSchema.ContainsKey($section)) {
            $errors += "Unknown configuration section: $section"
            continue
        }
        
        foreach ($key in $Config[$section].Keys) {
            if (-not $script:ConfigurationSchema[$section].ContainsKey($key)) {
                $errors += "Unknown configuration key: $section.$key"
                continue
            }
            
            if (-not (Test-ConfigurationValue -Section $section -Key $key -Value $Config[$section][$key])) {
                $keySchema = $script:ConfigurationSchema[$section][$key]
                $errors += "Invalid value for $section.$key : Expected $($keySchema.Type)"
                
                if ($keySchema.ContainsKey('ValidValues')) {
                    $errors += "  Valid values: $($keySchema.ValidValues -join ', ')"
                }
                if ($keySchema.ContainsKey('Min') -and $keySchema.ContainsKey('Max')) {
                    $errors += "  Valid range: $($keySchema.Min) - $($keySchema.Max)"
                }
            }
        }
    }
    
    return $errors
}

function Load-SimpleConfiguration {
    <#
    .SYNOPSIS
    Load configuration from file
    #>
    try {
        if (Test-Path $script:ConfigurationFile) {
            $json = Get-Content -Path $script:ConfigurationFile -Raw -Encoding UTF8
            $loadedConfig = $json | ConvertFrom-Json
            
            # Convert PSCustomObject to hashtable
            $config = ConvertTo-Hashtable -InputObject $loadedConfig
            
            # Validate configuration
            $errors = Get-ConfigurationValidationErrors -Config $config
            if ($errors.Count -gt 0) {
                Write-Warning "Configuration validation errors found:"
                foreach ($error in $errors) {
                    Write-Warning "  $error"
                }
                Write-Warning "Using default configuration for invalid settings"
            }
            
            # Merge with defaults
            $script:CurrentConfiguration = Merge-Configurations -Default (Get-DefaultConfiguration) -Override $config
        } else {
            # Create default configuration file
            $script:CurrentConfiguration = Get-DefaultConfiguration
            Save-SimpleConfiguration
        }
        
        $script:IsLoaded = $true
    } catch {
        Write-Warning "Failed to load configuration: $($_.Exception.Message)"
        Write-Warning "Using default configuration"
        $script:CurrentConfiguration = Get-DefaultConfiguration
        $script:IsLoaded = $true
    }
}

function ConvertTo-Hashtable {
    <#
    .SYNOPSIS
    Convert PSCustomObject to hashtable recursively
    #>
    param($InputObject)
    
    if ($InputObject -is [PSCustomObject]) {
        $hashtable = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            if ($property.Value -is [PSCustomObject]) {
                $hashtable[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            } else {
                $hashtable[$property.Name] = $property.Value
            }
        }
        return $hashtable
    } else {
        return $InputObject
    }
}

function Merge-Configurations {
    <#
    .SYNOPSIS
    Merge two configurations
    #>
    param(
        [hashtable]$Default,
        [hashtable]$Override
    )
    
    $merged = $Default.Clone()
    
    foreach ($section in $Override.Keys) {
        if ($section -eq '_metadata') {
            $merged[$section] = $Override[$section]
            continue
        }
        
        if ($merged.ContainsKey($section)) {
            foreach ($key in $Override[$section].Keys) {
                if ($merged[$section].ContainsKey($key)) {
                    # Validate the override value
                    if (Test-ConfigurationValue -Section $section -Key $key -Value $Override[$section][$key]) {
                        $merged[$section][$key] = $Override[$section][$key]
                    }
                }
            }
        }
    }
    
    return $merged
}

function Save-SimpleConfiguration {
    <#
    .SYNOPSIS
    Save configuration to file
    #>
    try {
        $json = $script:CurrentConfiguration | ConvertTo-Json -Depth 10
        Set-Content -Path $script:ConfigurationFile -Value $json -Encoding UTF8
    } catch {
        Write-Warning "Failed to save configuration: $($_.Exception.Message)"
    }
}

function Get-SimpleConfiguration {
    <#
    .SYNOPSIS
    Get the current configuration
    #>
    if (-not $script:IsLoaded) {
        Initialize-SimpleConfigurationManager
    }
    return $script:CurrentConfiguration.Clone()
}

function Get-SimpleConfigurationSection {
    <#
    .SYNOPSIS
    Get a specific configuration section
    #>
    param([string]$Section)
    
    $config = Get-SimpleConfiguration
    if ($config.ContainsKey($Section)) {
        return $config[$Section].Clone()
    }
    return @{}
}

function Get-SimpleConfigurationValue {
    <#
    .SYNOPSIS
    Get a specific configuration value
    #>
    param(
        [string]$Section,
        [string]$Key
    )
    
    $sectionConfig = Get-SimpleConfigurationSection -Section $Section
    if ($sectionConfig.ContainsKey($Key)) {
        return $sectionConfig[$Key]
    }
    
    # Return default value if not found
    $defaultConfig = Get-DefaultConfiguration
    if ($defaultConfig.ContainsKey($Section) -and $defaultConfig[$Section].ContainsKey($Key)) {
        return $defaultConfig[$Section][$Key]
    }
    
    return $null
}

function Set-SimpleConfigurationValue {
    <#
    .SYNOPSIS
    Set a specific configuration value
    #>
    param(
        [string]$Section,
        [string]$Key,
        $Value
    )
    
    if (-not $script:IsLoaded) {
        Initialize-SimpleConfigurationManager
    }
    
    # Validate the value
    if (-not (Test-ConfigurationValue -Section $Section -Key $Key -Value $Value)) {
        throw "Invalid value for $Section.$Key"
    }
    
    # Ensure section exists
    if (-not $script:CurrentConfiguration.ContainsKey($Section)) {
        $script:CurrentConfiguration[$Section] = @{}
    }
    
    $script:CurrentConfiguration[$Section][$Key] = $Value
    Save-SimpleConfiguration
}

function Reset-SimpleConfiguration {
    <#
    .SYNOPSIS
    Reset configuration to defaults
    #>
    param([string]$Section)
    
    if (-not $script:IsLoaded) {
        Initialize-SimpleConfigurationManager
    }
    
    $defaultConfig = Get-DefaultConfiguration
    
    if ($Section) {
        if ($defaultConfig.ContainsKey($Section)) {
            $script:CurrentConfiguration[$Section] = $defaultConfig[$Section].Clone()
            Save-SimpleConfiguration
        }
    } else {
        $script:CurrentConfiguration = $defaultConfig
        Save-SimpleConfiguration
    }
}

function Export-SimpleConfiguration {
    <#
    .SYNOPSIS
    Export configuration as JSON
    #>
    $config = Get-SimpleConfiguration
    return $config | ConvertTo-Json -Depth 10
}

function Get-SimpleConfigurationInfo {
    <#
    .SYNOPSIS
    Get configuration system information
    #>
    $defaultConfig = Get-DefaultConfiguration
    $hasCustomizations = $false
    
    if ($script:CurrentConfiguration) {
        # Simple comparison to detect customizations
        $currentJson = $script:CurrentConfiguration | ConvertTo-Json -Depth 10
        $defaultJson = $defaultConfig | ConvertTo-Json -Depth 10
        $hasCustomizations = $currentJson -ne $defaultJson
    }
    
    return @{
        ConfigurationFile = $script:ConfigurationFile
        ConfigurationDirectory = $script:ConfigurationDirectory
        IsLoaded = $script:IsLoaded
        HasCustomizations = $hasCustomizations
        LastModified = if ($script:ConfigurationFile -and (Test-Path $script:ConfigurationFile)) { 
            (Get-Item $script:ConfigurationFile).LastWriteTime 
        } else { 
            $null 
        }
    }
}

function Get-ConfigurationSchema {
    <#
    .SYNOPSIS
    Get the configuration schema
    #>
    return $script:ConfigurationSchema
}

# Export functions
Export-ModuleMember -Function @(
    'Initialize-SimpleConfigurationManager',
    'Get-SimpleConfiguration',
    'Get-SimpleConfigurationSection', 
    'Get-SimpleConfigurationValue',
    'Set-SimpleConfigurationValue',
    'Reset-SimpleConfiguration',
    'Export-SimpleConfiguration',
    'Get-SimpleConfigurationInfo',
    'Get-ConfigurationValidationErrors',
    'Get-DefaultConfiguration',
    'Get-ConfigurationSchema'
)