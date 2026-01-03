# Configuration Commands Module
# Provides runtime configuration commands for Spotify CLI live features

# Import required modules
$SimpleConfigManagerPath = Join-Path $PSScriptRoot "SimpleConfigurationManager.psm1"
if (Test-Path $SimpleConfigManagerPath) {
    Import-Module $SimpleConfigManagerPath -Force -Global
}

function Initialize-ConfigurationManager {
    <#
    .SYNOPSIS
    Initialize the configuration manager instance
    #>
    Initialize-SimpleConfigurationManager
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

function Get-LiveFeaturesConfig {
    <#
    .SYNOPSIS
    Get the current live features configuration
    .DESCRIPTION
    Retrieves the current configuration for all live features including display, lyrics, and statistics
    .PARAMETER Section
    Optional section name to retrieve only specific configuration section
    .PARAMETER Key
    Optional key name to retrieve only specific configuration value (requires Section)
    .EXAMPLE
    Get-LiveFeaturesConfig
    Gets the complete configuration
    .EXAMPLE
    Get-LiveFeaturesConfig -Section liveDisplay
    Gets only the live display configuration section
    .EXAMPLE
    Get-LiveFeaturesConfig -Section liveDisplay -Key refreshInterval
    Gets only the refresh interval value from live display section
    #>
    [CmdletBinding()]
    param(
        [string]$Section,
        [string]$Key
    )
    
    Initialize-ConfigurationManager
    
    try {
        if ($Key -and -not $Section) {
            Write-Error "Key parameter requires Section parameter"
            return
        }
        
        if ($Key) {
            # Get specific key value
            $value = Get-SimpleConfigurationValue -Section $Section -Key $Key
            if ($null -eq $value) {
                Write-Warning "Configuration key '$Section.$Key' not found"
                return
            }
            
            Write-Host "Configuration: $Section.$Key" -ForegroundColor Cyan
            Write-Host "Value: $value" -ForegroundColor White
            return $value
        }
        elseif ($Section) {
            # Get specific section
            $sectionConfig = Get-SimpleConfigurationSection -Section $Section
            if ($sectionConfig.Count -eq 0) {
                Write-Warning "Configuration section '$Section' not found"
                return
            }
            
            Write-Host "Configuration Section: $Section" -ForegroundColor Cyan
            Write-Host "=" * (20 + $Section.Length) -ForegroundColor Cyan
            
            foreach ($key in $sectionConfig.Keys | Sort-Object) {
                $value = $sectionConfig[$key]
                $displayValue = if ($value -is [bool]) { 
                    if ($value) { "true" } else { "false" }
                } else { 
                    $value 
                }
                Write-Host "  $key : $displayValue" -ForegroundColor White
            }
            
            return $sectionConfig
        }
        else {
            # Get complete configuration
            $config = Get-SimpleConfiguration
            
            Write-Host "Spotify CLI Live Features Configuration" -ForegroundColor Cyan
            Write-Host "=======================================" -ForegroundColor Cyan
            Write-Host ""
            
            foreach ($sectionName in $config.Keys | Sort-Object) {
                if ($sectionName -eq '_metadata') { continue }
                
                Write-Host "[$sectionName]" -ForegroundColor Yellow
                
                foreach ($key in $config[$sectionName].Keys | Sort-Object) {
                    $value = $config[$sectionName][$key]
                    $displayValue = if ($value -is [bool]) { 
                        if ($value) { "true" } else { "false" }
                    } else { 
                        $value 
                    }
                    Write-Host "  $key = $displayValue" -ForegroundColor White
                }
                Write-Host ""
            }
            
            # Show configuration info
            $info = Get-SimpleConfigurationInfo
            Write-Host "Configuration Info:" -ForegroundColor Gray
            Write-Host "  File: $($info.ConfigurationFile)" -ForegroundColor Gray
            Write-Host "  Loaded: $($info.IsLoaded)" -ForegroundColor Gray
            Write-Host "  Has Customizations: $($info.HasCustomizations)" -ForegroundColor Gray
            if ($info.LastModified) {
                Write-Host "  Last Modified: $($info.LastModified)" -ForegroundColor Gray
            }
            
            return $config
        }
    }
    catch {
        Write-Error "Failed to get configuration: $($_.Exception.Message)"
    }
}

function Set-LiveFeaturesConfig {
    <#
    .SYNOPSIS
    Set live features configuration values
    .DESCRIPTION
    Sets configuration values for live features with validation
    .PARAMETER Section
    Configuration section name
    .PARAMETER Key
    Configuration key name
    .PARAMETER Value
    Configuration value to set
    .PARAMETER SectionConfig
    Hashtable containing multiple key-value pairs for a section
    .EXAMPLE
    Set-LiveFeaturesConfig -Section liveDisplay -Key refreshInterval -Value 2000
    Sets the refresh interval to 2000ms
    .EXAMPLE
    Set-LiveFeaturesConfig -Section liveDisplay -SectionConfig @{refreshInterval=1500; displayMode="compact"}
    Sets multiple values in the liveDisplay section
    #>
    [CmdletBinding(DefaultParameterSetName = "SingleValue")]
    param(
        [Parameter(Mandatory, ParameterSetName = "SingleValue")]
        [Parameter(Mandatory, ParameterSetName = "SectionConfig")]
        [string]$Section,
        
        [Parameter(Mandatory, ParameterSetName = "SingleValue")]
        [string]$Key,
        
        [Parameter(Mandatory, ParameterSetName = "SingleValue")]
        $Value,
        
        [Parameter(Mandatory, ParameterSetName = "SectionConfig")]
        [hashtable]$SectionConfig
    )
    
    Initialize-ConfigurationManager
    
    try {
        if ($PSCmdlet.ParameterSetName -eq "SingleValue") {
            # Set single value
            Set-SimpleConfigurationValue -Section $Section -Key $Key -Value $Value
            Write-Host "✅ Configuration updated: $Section.$Key = $Value" -ForegroundColor Green
        }
        else {
            # Set section configuration
            foreach ($key in $SectionConfig.Keys) {
                Set-SimpleConfigurationValue -Section $Section -Key $key -Value $SectionConfig[$key]
            }
            Write-Host "✅ Configuration section updated: $Section" -ForegroundColor Green
            
            foreach ($key in $SectionConfig.Keys) {
                Write-Host "  $key = $($SectionConfig[$key])" -ForegroundColor White
            }
        }
    }
    catch {
        Write-Error "Failed to set configuration: $($_.Exception.Message)"
        
        # Show validation help if it's a validation error
        if ($_.Exception.Message -like "*Invalid value*") {
            Write-Host ""
            Write-Host "💡 Use 'Get-LiveFeaturesConfigSchema' to see valid values and ranges" -ForegroundColor Yellow
        }
    }
}

function Reset-LiveFeaturesConfig {
    <#
    .SYNOPSIS
    Reset live features configuration to defaults
    .DESCRIPTION
    Resets configuration to default values, either completely or for a specific section
    .PARAMETER Section
    Optional section name to reset only specific section
    .PARAMETER Force
    Skip confirmation prompt
    .EXAMPLE
    Reset-LiveFeaturesConfig
    Resets all configuration to defaults (with confirmation)
    .EXAMPLE
    Reset-LiveFeaturesConfig -Section liveDisplay -Force
    Resets only live display configuration without confirmation
    #>
    [CmdletBinding()]
    param(
        [string]$Section,
        [switch]$Force
    )
    
    Initialize-ConfigurationManager
    
    try {
        $confirmMessage = if ($Section) {
            "Reset configuration section '$Section' to defaults?"
        } else {
            "Reset ALL configuration to defaults?"
        }
        
        if (-not $Force) {
            $response = Read-Host "$confirmMessage (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "Configuration reset cancelled" -ForegroundColor Yellow
                return
            }
        }
        
        if ($Section) {
            Reset-SimpleConfiguration -Section $Section
            Write-Host "✅ Configuration section '$Section' reset to defaults" -ForegroundColor Green
        }
        else {
            Reset-SimpleConfiguration
            Write-Host "✅ All configuration reset to defaults" -ForegroundColor Green
        }
    }
    catch {
        Write-Error "Failed to reset configuration: $($_.Exception.Message)"
    }
}

function Export-LiveFeaturesConfig {
    <#
    .SYNOPSIS
    Export live features configuration to file or string
    .DESCRIPTION
    Exports the current configuration in JSON or YAML format
    .PARAMETER Path
    Output file path (optional, outputs to console if not specified)
    .PARAMETER Format
    Export format (json or yaml)
    .EXAMPLE
    Export-LiveFeaturesConfig
    Exports configuration to console in JSON format
    .EXAMPLE
    Export-LiveFeaturesConfig -Path "config_backup.json" -Format json
    Exports configuration to file in JSON format
    #>
    [CmdletBinding()]
    param(
        [string]$Path,
        [ValidateSet("json", "yaml")]
        [string]$Format = "json"
    )
    
    Initialize-ConfigurationManager
    
    try {
        $exportData = Export-SimpleConfiguration
        
        if ($Path) {
            # Export to file
            $exportData | Set-Content -Path $Path -Encoding UTF8
            Write-Host "✅ Configuration exported to: $Path" -ForegroundColor Green
        }
        else {
            # Output to console
            Write-Host "Current Configuration ($Format format):" -ForegroundColor Cyan
            Write-Host "=" * 40 -ForegroundColor Cyan
            Write-Host $exportData
        }
    }
    catch {
        Write-Error "Failed to export configuration: $($_.Exception.Message)"
    }
}

function Import-LiveFeaturesConfig {
    <#
    .SYNOPSIS
    Import live features configuration from file or string
    .DESCRIPTION
    Imports configuration from JSON format with validation
    .PARAMETER Path
    Input file path
    .PARAMETER ConfigData
    Configuration data as string
    .PARAMETER Format
    Import format (json)
    .PARAMETER Force
    Skip confirmation prompt
    .EXAMPLE
    Import-LiveFeaturesConfig -Path "config_backup.json"
    Imports configuration from JSON file
    .EXAMPLE
    Import-LiveFeaturesConfig -ConfigData $jsonString -Format json -Force
    Imports configuration from JSON string without confirmation
    #>
    [CmdletBinding(DefaultParameterSetName = "FromFile")]
    param(
        [Parameter(Mandatory, ParameterSetName = "FromFile")]
        [string]$Path,
        
        [Parameter(Mandatory, ParameterSetName = "FromString")]
        [string]$ConfigData,
        
        [ValidateSet("json")]
        [string]$Format = "json",
        
        [switch]$Force
    )
    
    Initialize-ConfigurationManager
    
    try {
        if ($PSCmdlet.ParameterSetName -eq "FromFile") {
            if (-not (Test-Path $Path)) {
                Write-Error "Configuration file not found: $Path"
                return
            }
            $ConfigData = Get-Content -Path $Path -Raw -Encoding UTF8
        }
        
        if (-not $Force) {
            Write-Host "This will replace your current configuration." -ForegroundColor Yellow
            $response = Read-Host "Continue? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "Configuration import cancelled" -ForegroundColor Yellow
                return
            }
        }
        
        # For now, we'll implement a simple JSON import
        if ($Format -eq "json") {
            $importedConfig = $ConfigData | ConvertFrom-Json
            $config = ConvertTo-Hashtable -InputObject $importedConfig
            
            # Validate imported configuration
            $errors = Get-ConfigurationValidationErrors -Config $config
            if ($errors.Count -gt 0) {
                throw "Invalid configuration: $($errors -join '; ')"
            }
            
            # Apply the configuration
            foreach ($section in $config.Keys) {
                if ($section -eq '_metadata') { continue }
                foreach ($key in $config[$section].Keys) {
                    Set-SimpleConfigurationValue -Section $section -Key $key -Value $config[$section][$key]
                }
            }
        } else {
            throw "Unsupported import format: $Format"
        }
        Write-Host "✅ Configuration imported successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to import configuration: $($_.Exception.Message)"
    }
}

function Get-LiveFeaturesConfigSchema {
    <#
    .SYNOPSIS
    Get the configuration schema information
    .DESCRIPTION
    Shows the available configuration sections, keys, valid values, and ranges
    .PARAMETER Section
    Optional section name to show only specific section schema
    .EXAMPLE
    Get-LiveFeaturesConfigSchema
    Shows complete configuration schema
    .EXAMPLE
    Get-LiveFeaturesConfigSchema -Section liveDisplay
    Shows only live display section schema
    #>
    [CmdletBinding()]
    param(
        [string]$Section
    )
    
    Initialize-ConfigurationManager
    
    # Get the schema from the simple configuration manager
    $schema = Get-ConfigurationSchema
    
    if ($Section) {
        if (-not $schema.ContainsKey($Section)) {
            Write-Warning "Configuration section '$Section' not found"
            return
        }
        
        Write-Host "Configuration Schema: $Section" -ForegroundColor Cyan
        Write-Host "=" * (22 + $Section.Length) -ForegroundColor Cyan
        Write-Host ""
        
        $sectionSchema = $schema[$Section]
        foreach ($key in $sectionSchema.Keys | Sort-Object) {
            $keySchema = $sectionSchema[$key]
            Write-Host "  $key" -ForegroundColor Yellow
            Write-Host "    Type: $($keySchema.Type)" -ForegroundColor White
            Write-Host "    Default: $($keySchema.Default)" -ForegroundColor White
            
            if ($keySchema.ContainsKey('ValidValues')) {
                Write-Host "    Valid Values: $($keySchema.ValidValues -join ', ')" -ForegroundColor White
            }
            if ($keySchema.ContainsKey('Min') -and $keySchema.ContainsKey('Max')) {
                Write-Host "    Range: $($keySchema.Min) - $($keySchema.Max)" -ForegroundColor White
            }
            Write-Host ""
        }
    }
    else {
        Write-Host "Live Features Configuration Schema" -ForegroundColor Cyan
        Write-Host "==================================" -ForegroundColor Cyan
        Write-Host ""
        
        foreach ($sectionName in $schema.Keys | Sort-Object) {
            Write-Host "[$sectionName]" -ForegroundColor Yellow
            
            $sectionSchema = $schema[$sectionName]
            foreach ($key in $sectionSchema.Keys | Sort-Object) {
                $keySchema = $sectionSchema[$key]
                Write-Host "  $key ($($keySchema.Type))" -ForegroundColor White
                
                $details = @()
                $details += "default: $($keySchema.Default)"
                
                if ($keySchema.ContainsKey('ValidValues')) {
                    $details += "values: $($keySchema.ValidValues -join '|')"
                }
                if ($keySchema.ContainsKey('Min') -and $keySchema.ContainsKey('Max')) {
                    $details += "range: $($keySchema.Min)-$($keySchema.Max)"
                }
                
                Write-Host "    $($details -join ', ')" -ForegroundColor Gray
            }
            Write-Host ""
        }
    }
}

function Backup-LiveFeaturesConfig {
    <#
    .SYNOPSIS
    Create a backup of the current configuration
    .DESCRIPTION
    Creates a timestamped backup of the current configuration
    .PARAMETER Path
    Optional backup directory path (defaults to config directory)
    .EXAMPLE
    Backup-LiveFeaturesConfig
    Creates backup in default location
    .EXAMPLE
    Backup-LiveFeaturesConfig -Path "C:\Backups"
    Creates backup in specified directory
    #>
    [CmdletBinding()]
    param(
        [string]$Path
    )
    
    Initialize-ConfigurationManager
    
    try {
        $info = Get-SimpleConfigurationInfo
        
        if (-not $Path) {
            $Path = $info.ConfigurationDirectory
        }
        
        if (-not (Test-Path $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFile = Join-Path $Path "live_features_config_backup_$timestamp.json"
        
        Export-LiveFeaturesConfig -Path $backupFile -Format json
        Write-Host "✅ Configuration backed up to: $backupFile" -ForegroundColor Green
        
        return $backupFile
    }
    catch {
        Write-Error "Failed to backup configuration: $($_.Exception.Message)"
    }
}

function Restore-LiveFeaturesConfig {
    <#
    .SYNOPSIS
    Restore configuration from a backup file
    .DESCRIPTION
    Restores configuration from a previously created backup file
    .PARAMETER Path
    Path to the backup file
    .PARAMETER Force
    Skip confirmation prompt
    .EXAMPLE
    Restore-LiveFeaturesConfig -Path "live_features_config_backup_20241106_143022.json"
    Restores configuration from backup file
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$Force
    )
    
    if (-not (Test-Path $Path)) {
        Write-Error "Backup file not found: $Path"
        return
    }
    
    try {
        Import-LiveFeaturesConfig -Path $Path -Force:$Force
        Write-Host "✅ Configuration restored from backup" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to restore configuration: $($_.Exception.Message)"
    }
}

function Test-LiveFeaturesConfig {
    <#
    .SYNOPSIS
    Validate the current configuration
    .DESCRIPTION
    Validates the current configuration against the schema and reports any issues
    .EXAMPLE
    Test-LiveFeaturesConfig
    Validates current configuration
    #>
    [CmdletBinding()]
    param()
    
    Initialize-ConfigurationManager
    
    try {
        $config = Get-SimpleConfiguration
        $errors = Get-ConfigurationValidationErrors -Config $config
        
        if ($errors.Count -eq 0) {
            Write-Host "✅ Configuration is valid" -ForegroundColor Green
            return $true
        }
        else {
            Write-Host "❌ Configuration validation failed:" -ForegroundColor Red
            foreach ($error in $errors) {
                Write-Host "  • $error" -ForegroundColor Yellow
            }
            return $false
        }
    }
    catch {
        Write-Error "Failed to validate configuration: $($_.Exception.Message)"
        return $false
    }
}

function Update-LiveFeaturesConfig {
    <#
    .SYNOPSIS
    Update configuration to the latest version
    .DESCRIPTION
    Migrates configuration from older versions to the current version
    .PARAMETER Force
    Skip confirmation prompt
    .PARAMETER CurrentVersion
    Current version of the live features (defaults to 1.2)
    .EXAMPLE
    Update-LiveFeaturesConfig
    Updates configuration to latest version with confirmation
    .EXAMPLE
    Update-LiveFeaturesConfig -Force -CurrentVersion "1.2"
    Updates configuration without confirmation
    #>
    [CmdletBinding()]
    param(
        [switch]$Force,
        [string]$CurrentVersion = "1.2"
    )
    
    Initialize-ConfigurationManager
    
    try {
        # For the simple configuration manager, we'll just ensure defaults are merged
        Write-Host "Updating configuration to latest version..." -ForegroundColor Yellow
        
        if (-not $Force) {
            Write-Host "This will merge your configuration with the latest defaults." -ForegroundColor Cyan
            $response = Read-Host "Continue? (y/N)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-Host "Configuration update cancelled" -ForegroundColor Yellow
                return
            }
        }
        
        # Create backup first
        $backupFile = Backup-LiveFeaturesConfig
        
        # Reload configuration to ensure latest defaults are applied
        Initialize-SimpleConfigurationManager
        
        Write-Host "✅ Configuration updated successfully" -ForegroundColor Green
        Write-Host "💡 Backup created: $backupFile" -ForegroundColor Cyan
    }
    catch {
        Write-Error "Failed to update configuration: $($_.Exception.Message)"
    }
}

function Get-LiveFeaturesConfigInfo {
    <#
    .SYNOPSIS
    Get detailed information about the configuration system
    .DESCRIPTION
    Shows configuration file location, version, and other metadata
    .EXAMPLE
    Get-LiveFeaturesConfigInfo
    Shows configuration system information
    #>
    [CmdletBinding()]
    param()
    
    Initialize-ConfigurationManager
    
    try {
        $info = Get-SimpleConfigurationInfo
        
        Write-Host "Live Features Configuration Information" -ForegroundColor Cyan
        Write-Host "======================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Configuration File:" -ForegroundColor Yellow
        Write-Host "  Path: $($info.ConfigurationFile)" -ForegroundColor White
        Write-Host "  Directory: $($info.ConfigurationDirectory)" -ForegroundColor White
        Write-Host "  Exists: $(Test-Path $info.ConfigurationFile)" -ForegroundColor White
        
        if ($info.LastModified) {
            Write-Host "  Last Modified: $($info.LastModified)" -ForegroundColor White
        }
        
        Write-Host ""
        Write-Host "Configuration Status:" -ForegroundColor Yellow
        Write-Host "  Loaded: $($info.IsLoaded)" -ForegroundColor White
        Write-Host "  Has Customizations: $($info.HasCustomizations)" -ForegroundColor White
        
        # Show metadata if available
        $config = Get-SimpleConfiguration
        if ($config.ContainsKey('_metadata')) {
            Write-Host ""
            Write-Host "Migration History:" -ForegroundColor Yellow
            $metadata = $config['_metadata']
            
            if ($metadata.ContainsKey('migratedFrom')) {
                Write-Host "  Migrated From: $($metadata['migratedFrom'])" -ForegroundColor White
            }
            if ($metadata.ContainsKey('migratedAt')) {
                Write-Host "  Migration Date: $($metadata['migratedAt'])" -ForegroundColor White
            }
            if ($metadata.ContainsKey('backupFile')) {
                Write-Host "  Backup File: $($metadata['backupFile'])" -ForegroundColor White
            }
        }
        
        Write-Host ""
        Write-Host "Available Commands:" -ForegroundColor Yellow
        Write-Host "  config                    - View configuration" -ForegroundColor White
        Write-Host "  config-set                - Modify settings" -ForegroundColor White
        Write-Host "  config-reset              - Reset to defaults" -ForegroundColor White
        Write-Host "  config-schema             - View valid settings" -ForegroundColor White
        Write-Host "  Get-LiveFeaturesConfig    - Full configuration view" -ForegroundColor White
        Write-Host "  Set-LiveFeaturesConfig    - Modify configuration" -ForegroundColor White
        Write-Host "  Export-LiveFeaturesConfig - Export/backup config" -ForegroundColor White
        Write-Host "  Import-LiveFeaturesConfig - Import/restore config" -ForegroundColor White
        
        return $info
    }
    catch {
        Write-Error "Failed to get configuration info: $($_.Exception.Message)"
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Get-LiveFeaturesConfig',
    'Set-LiveFeaturesConfig', 
    'Reset-LiveFeaturesConfig',
    'Export-LiveFeaturesConfig',
    'Import-LiveFeaturesConfig',
    'Get-LiveFeaturesConfigSchema',
    'Backup-LiveFeaturesConfig',
    'Restore-LiveFeaturesConfig',
    'Test-LiveFeaturesConfig',
    'Update-LiveFeaturesConfig',
    'Get-LiveFeaturesConfigInfo'
)