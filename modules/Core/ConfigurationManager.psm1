# Configuration Manager Module
# Provides centralized configuration management for Spotify CLI live features

# Configuration schema definition
class ConfigurationSchema {
    [hashtable] $Schema = @{
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
    
    [bool] ValidateValue([string]$section, [string]$key, $value) {
        if (-not $this.Schema.ContainsKey($section)) {
            return $false
        }
        
        $sectionSchema = $this.Schema[$section]
        if (-not $sectionSchema.ContainsKey($key)) {
            return $false
        }
        
        $keySchema = $sectionSchema[$key]
        
        switch ($keySchema.Type) {
            "int" {
                if ($value -isnot [int]) {
                    return $false
                }
                if ($keySchema.ContainsKey('Min') -and $value -lt $keySchema.Min) {
                    return $false
                }
                if ($keySchema.ContainsKey('Max') -and $value -gt $keySchema.Max) {
                    return $false
                }
                return $true
            }
            "bool" {
                return $value -is [bool]
            }
            "string" {
                if ($value -isnot [string]) {
                    return $false
                }
                if ($keySchema.ContainsKey('ValidValues') -and $value -notin $keySchema.ValidValues) {
                    return $false
                }
                return $true
            }
            default {
                return $true
            }
        }
    }
    
    [hashtable] GetDefaultConfiguration() {
        $config = @{}
        
        foreach ($section in $this.Schema.Keys) {
            $config[$section] = @{}
            foreach ($key in $this.Schema[$section].Keys) {
                $config[$section][$key] = $this.Schema[$section][$key].Default
            }
        }
        
        return $config
    }
    
    [string[]] GetValidationErrors([hashtable]$config) {
        $errors = @()
        
        foreach ($section in $config.Keys) {
            if (-not $this.Schema.ContainsKey($section)) {
                $errors += "Unknown configuration section: $section"
                continue
            }
            
            foreach ($key in $config[$section].Keys) {
                if (-not $this.Schema[$section].ContainsKey($key)) {
                    $errors += "Unknown configuration key: $section.$key"
                    continue
                }
                
                if (-not $this.ValidateValue($section, $key, $config[$section][$key])) {
                    $keySchema = $this.Schema[$section][$key]
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
}

# Configuration manager class
class ConfigurationManager {
    [string] $ConfigurationFile
    [string] $ConfigurationDirectory
    [ConfigurationSchema] $Schema
    [hashtable] $CurrentConfiguration
    [hashtable] $DefaultConfiguration
    [bool] $IsLoaded = $false
    
    ConfigurationManager([string]$configDir) {
        $this.ConfigurationDirectory = $configDir
        $this.ConfigurationFile = Join-Path $configDir "live_features_config.json"
        $this.Schema = [ConfigurationSchema]::new()
        $this.DefaultConfiguration = $this.Schema.GetDefaultConfiguration()
        $this.CurrentConfiguration = $this.DefaultConfiguration.Clone()
        
        $this.EnsureConfigurationDirectory()
    }
    
    [void] EnsureConfigurationDirectory() {
        if (-not (Test-Path $this.ConfigurationDirectory)) {
            New-Item -ItemType Directory -Path $this.ConfigurationDirectory -Force | Out-Null
        }
    }
    
    [void] LoadConfiguration() {
        try {
            if (Test-Path $this.ConfigurationFile) {
                $json = Get-Content -Path $this.ConfigurationFile -Raw -Encoding UTF8
                $loadedConfig = $json | ConvertFrom-Json
                
                # Convert PSCustomObject to hashtable
                $config = $this.ConvertToHashtable($loadedConfig)
                
                # Validate configuration
                $errors = $this.Schema.GetValidationErrors($config)
                if ($errors.Count -gt 0) {
                    Write-Warning "Configuration validation errors found:"
                    foreach ($error in $errors) {
                        Write-Warning "  $error"
                    }
                    Write-Warning "Using default configuration for invalid settings"
                }
                
                # Merge with defaults (defaults take precedence for invalid values)
                $this.CurrentConfiguration = $this.MergeConfigurations($this.DefaultConfiguration, $config)
            } else {
                # Create default configuration file
                $this.SaveConfiguration()
            }
            
            $this.IsLoaded = $true
        } catch {
            Write-Warning "Failed to load configuration: $($_.Exception.Message)"
            Write-Warning "Using default configuration"
            $this.CurrentConfiguration = $this.DefaultConfiguration.Clone()
            $this.IsLoaded = $true
        }
    }
    
    [hashtable] ConvertToHashtable([PSCustomObject]$obj) {
        $hashtable = @{}
        
        foreach ($property in $obj.PSObject.Properties) {
            if ($property.Value -is [PSCustomObject]) {
                $hashtable[$property.Name] = $this.ConvertToHashtable($property.Value)
            } else {
                $hashtable[$property.Name] = $property.Value
            }
        }
        
        return $hashtable
    }
    
    [hashtable] MergeConfigurations([hashtable]$default, [hashtable]$override) {
        $merged = $default.Clone()
        
        foreach ($section in $override.Keys) {
            if ($merged.ContainsKey($section)) {
                foreach ($key in $override[$section].Keys) {
                    if ($merged[$section].ContainsKey($key)) {
                        # Validate the override value
                        if ($this.Schema.ValidateValue($section, $key, $override[$section][$key])) {
                            $merged[$section][$key] = $override[$section][$key]
                        }
                    }
                }
            }
        }
        
        return $merged
    }
    
    [void] SaveConfiguration() {
        try {
            $json = $this.CurrentConfiguration | ConvertTo-Json -Depth 10
            Set-Content -Path $this.ConfigurationFile -Value $json -Encoding UTF8
        } catch {
            Write-Warning "Failed to save configuration: $($_.Exception.Message)"
        }
    }
    
    [hashtable] GetConfiguration() {
        if (-not $this.IsLoaded) {
            $this.LoadConfiguration()
        }
        return $this.CurrentConfiguration.Clone()
    }
    
    [hashtable] GetSection([string]$section) {
        $config = $this.GetConfiguration()
        if ($config.ContainsKey($section)) {
            return $config[$section].Clone()
        }
        return @{}
    }
    
    [$value] GetValue([string]$section, [string]$key) {
        $sectionConfig = $this.GetSection($section)
        if ($sectionConfig.ContainsKey($key)) {
            return $sectionConfig[$key]
        }
        
        # Return default value if not found
        if ($this.DefaultConfiguration.ContainsKey($section) -and 
            $this.DefaultConfiguration[$section].ContainsKey($key)) {
            return $this.DefaultConfiguration[$section][$key]
        }
        
        return $null
    }
    
    [void] SetValue([string]$section, [string]$key, $value) {
        if (-not $this.IsLoaded) {
            $this.LoadConfiguration()
        }
        
        # Validate the value
        if (-not $this.Schema.ValidateValue($section, $key, $value)) {
            throw [System.ArgumentException]::new("Invalid value for $section.$key")
        }
        
        # Ensure section exists
        if (-not $this.CurrentConfiguration.ContainsKey($section)) {
            $this.CurrentConfiguration[$section] = @{}
        }
        
        $this.CurrentConfiguration[$section][$key] = $value
        $this.SaveConfiguration()
    }
    
    [void] SetSection([string]$section, [hashtable]$sectionConfig) {
        if (-not $this.IsLoaded) {
            $this.LoadConfiguration()
        }
        
        # Validate all values in the section
        foreach ($key in $sectionConfig.Keys) {
            if (-not $this.Schema.ValidateValue($section, $key, $sectionConfig[$key])) {
                throw [System.ArgumentException]::new("Invalid value for $section.$key")
            }
        }
        
        $this.CurrentConfiguration[$section] = $sectionConfig.Clone()
        $this.SaveConfiguration()
    }
    
    [void] ResetToDefaults() {
        $this.CurrentConfiguration = $this.DefaultConfiguration.Clone()
        $this.SaveConfiguration()
    }
    
    [void] ResetSection([string]$section) {
        if ($this.DefaultConfiguration.ContainsKey($section)) {
            $this.CurrentConfiguration[$section] = $this.DefaultConfiguration[$section].Clone()
            $this.SaveConfiguration()
        }
    }
    
    [hashtable] GetConfigurationInfo() {
        return @{
            ConfigurationFile = $this.ConfigurationFile
            ConfigurationDirectory = $this.ConfigurationDirectory
            IsLoaded = $this.IsLoaded
            HasCustomizations = $this.HasCustomizations()
            LastModified = if (Test-Path $this.ConfigurationFile) { 
                (Get-Item $this.ConfigurationFile).LastWriteTime 
            } else { 
                $null 
            }
        }
    }
    
    [bool] HasCustomizations() {
        if (-not $this.IsLoaded) {
            return $false
        }
        
        # Compare current config with defaults
        return -not $this.ConfigurationsEqual($this.CurrentConfiguration, $this.DefaultConfiguration)
    }
    
    [bool] ConfigurationsEqual([hashtable]$config1, [hashtable]$config2) {
        if ($config1.Keys.Count -ne $config2.Keys.Count) {
            return $false
        }
        
        foreach ($section in $config1.Keys) {
            if (-not $config2.ContainsKey($section)) {
                return $false
            }
            
            $section1 = $config1[$section]
            $section2 = $config2[$section]
            
            if ($section1.Keys.Count -ne $section2.Keys.Count) {
                return $false
            }
            
            foreach ($key in $section1.Keys) {
                if (-not $section2.ContainsKey($key) -or $section1[$key] -ne $section2[$key]) {
                    return $false
                }
            }
        }
        
        return $true
    }
    
    [string] ExportConfiguration([string]$format) {
        $config = $this.GetConfiguration()
        
        switch ($format.ToLower()) {
            "json" {
                return $config | ConvertTo-Json -Depth 10
            }
            "yaml" {
                # Simple YAML export (basic implementation)
                $yaml = @()
                foreach ($section in $config.Keys) {
                    $yaml += "$section :"
                    foreach ($key in $config[$section].Keys) {
                        $value = $config[$section][$key]
                        if ($value -is [string]) {
                            $yaml += "  $key : `"$value`""
                        } else {
                            $yaml += "  $key : $value"
                        }
                    }
                    $yaml += ""
                }
                return $yaml -join "`n"
            }
            default {
                throw [System.ArgumentException]::new("Unsupported export format: $format")
            }
        }
    }
    
    [void] ImportConfiguration([string]$configData, [string]$format) {
        try {
            switch ($format.ToLower()) {
                "json" {
                    $importedConfig = $configData | ConvertFrom-Json
                    $config = $this.ConvertToHashtable($importedConfig)
                    
                    # Validate imported configuration
                    $errors = $this.Schema.GetValidationErrors($config)
                    if ($errors.Count -gt 0) {
                        throw [System.ArgumentException]::new("Invalid configuration: $($errors -join '; ')")
                    }
                    
                    $this.CurrentConfiguration = $this.MergeConfigurations($this.DefaultConfiguration, $config)
                    $this.SaveConfiguration()
                }
                default {
                    throw [System.ArgumentException]::new("Unsupported import format: $format")
                }
            }
        } catch {
            throw [System.InvalidOperationException]::new("Failed to import configuration: $($_.Exception.Message)")
        }
    }
    
    [void] MigrateConfiguration([string]$fromVersion, [string]$toVersion) {
        <#
        .SYNOPSIS
        Migrate configuration from one version to another
        .DESCRIPTION
        Handles configuration migration between different versions of the live features
        #>
        try {
            Write-Verbose "Migrating configuration from version $fromVersion to $toVersion"
            
            # Create backup before migration
            $backupFile = Join-Path $this.ConfigurationDirectory "config_backup_pre_migration_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
            $currentJson = $this.CurrentConfiguration | ConvertTo-Json -Depth 10
            Set-Content -Path $backupFile -Value $currentJson -Encoding UTF8
            Write-Verbose "Configuration backed up to: $backupFile"
            
            # Version-specific migration logic
            switch ("$fromVersion->$toVersion") {
                "1.0->1.1" {
                    # Example migration: Add new default values
                    if (-not $this.CurrentConfiguration.ContainsKey('apiClient')) {
                        $this.CurrentConfiguration['apiClient'] = $this.DefaultConfiguration['apiClient'].Clone()
                    }
                }
                "1.1->1.2" {
                    # Example migration: Rename or restructure settings
                    if ($this.CurrentConfiguration['liveDisplay'].ContainsKey('oldSetting')) {
                        $this.CurrentConfiguration['liveDisplay']['newSetting'] = $this.CurrentConfiguration['liveDisplay']['oldSetting']
                        $this.CurrentConfiguration['liveDisplay'].Remove('oldSetting')
                    }
                }
                default {
                    # Generic migration: merge with new defaults
                    $this.CurrentConfiguration = $this.MergeConfigurations($this.DefaultConfiguration, $this.CurrentConfiguration)
                }
            }
            
            # Add version metadata
            $this.CurrentConfiguration['_metadata'] = @{
                version = $toVersion
                migratedAt = [DateTimeOffset]::UtcNow.ToString('o')
                migratedFrom = $fromVersion
                backupFile = $backupFile
            }
            
            $this.SaveConfiguration()
            Write-Verbose "Configuration migration completed successfully"
        }
        catch {
            Write-Warning "Configuration migration failed: $($_.Exception.Message)"
            throw
        }
    }
    
    [string] GetConfigurationVersion() {
        <#
        .SYNOPSIS
        Get the current configuration version
        #>
        if ($this.CurrentConfiguration.ContainsKey('_metadata') -and 
            $this.CurrentConfiguration['_metadata'].ContainsKey('version')) {
            return $this.CurrentConfiguration['_metadata']['version']
        }
        return "1.0"  # Default version for configurations without metadata
    }
    
    [bool] RequiresMigration([string]$currentVersion) {
        <#
        .SYNOPSIS
        Check if configuration requires migration
        #>
        $configVersion = $this.GetConfigurationVersion()
        return $configVersion -ne $currentVersion
    }
}

# Configuration factory for creating managers
class ConfigurationFactory {
    static [ConfigurationManager] CreateManager([string]$configDir) {
        return [ConfigurationManager]::new($configDir)
    }
    
    static [ConfigurationManager] CreateDefaultManager() {
        $defaultDir = Join-Path $env:APPDATA "SpotifyCLI\LiveFeatures"
        return [ConfigurationManager]::new($defaultDir)
    }
}

# Export classes and functions
Export-ModuleMember -Function @() -Variable @()