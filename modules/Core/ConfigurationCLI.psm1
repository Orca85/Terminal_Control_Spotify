# Configuration CLI Module
# Provides user-friendly command-line interface for configuration management

# Import required modules
$ConfigCommandsPath = Join-Path $PSScriptRoot "ConfigurationCommands.psm1"
if (Test-Path $ConfigCommandsPath) {
    Import-Module $ConfigCommandsPath -Force -Global
}

function Invoke-ConfigurationCommand {
    <#
    .SYNOPSIS
    Main configuration command dispatcher
    .DESCRIPTION
    Provides a unified interface for all configuration operations
    .PARAMETER Command
    Configuration command to execute
    .PARAMETER Arguments
    Arguments for the command
    .EXAMPLE
    Invoke-ConfigurationCommand -Command "show"
    Shows current configuration
    .EXAMPLE
    Invoke-ConfigurationCommand -Command "set" -Arguments "liveDisplay.refreshInterval=2000"
    Sets refresh interval to 2000ms
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("show", "set", "reset", "schema", "export", "import", "backup", "restore", "test", "update", "info", "help")]
        [string]$Command,
        
        [string[]]$Arguments = @()
    )
    
    try {
        switch ($Command.ToLower()) {
            "show" {
                if ($Arguments.Count -eq 0) {
                    Get-LiveFeaturesConfig
                }
                elseif ($Arguments.Count -eq 1) {
                    $parts = $Arguments[0] -split '\.'
                    if ($parts.Count -eq 1) {
                        Get-LiveFeaturesConfig -Section $parts[0]
                    }
                    elseif ($parts.Count -eq 2) {
                        Get-LiveFeaturesConfig -Section $parts[0] -Key $parts[1]
                    }
                    else {
                        Write-Error "Invalid argument format. Use 'section' or 'section.key'"
                    }
                }
                else {
                    Write-Error "Too many arguments for 'show' command"
                }
            }
            
            "set" {
                if ($Arguments.Count -eq 0) {
                    Write-Error "Missing arguments for 'set' command. Use 'section.key=value' format"
                    return
                }
                
                foreach ($arg in $Arguments) {
                    if ($arg -match '^([^.]+)\.([^=]+)=(.+)$') {
                        $section = $matches[1]
                        $key = $matches[2]
                        $valueStr = $matches[3]
                        
                        # Parse value based on type
                        $value = ConvertTo-ConfigValue -ValueString $valueStr
                        
                        Set-LiveFeaturesConfig -Section $section -Key $key -Value $value
                    }
                    else {
                        Write-Error "Invalid argument format: '$arg'. Use 'section.key=value' format"
                    }
                }
            }
            
            "reset" {
                if ($Arguments.Count -eq 0) {
                    Reset-LiveFeaturesConfig
                }
                elseif ($Arguments.Count -eq 1) {
                    Reset-LiveFeaturesConfig -Section $Arguments[0]
                }
                else {
                    Write-Error "Too many arguments for 'reset' command"
                }
            }
            
            "schema" {
                if ($Arguments.Count -eq 0) {
                    Get-LiveFeaturesConfigSchema
                }
                elseif ($Arguments.Count -eq 1) {
                    Get-LiveFeaturesConfigSchema -Section $Arguments[0]
                }
                else {
                    Write-Error "Too many arguments for 'schema' command"
                }
            }
            
            "export" {
                if ($Arguments.Count -eq 0) {
                    Export-LiveFeaturesConfig
                }
                elseif ($Arguments.Count -eq 1) {
                    Export-LiveFeaturesConfig -Path $Arguments[0]
                }
                elseif ($Arguments.Count -eq 2) {
                    Export-LiveFeaturesConfig -Path $Arguments[0] -Format $Arguments[1]
                }
                else {
                    Write-Error "Too many arguments for 'export' command"
                }
            }
            
            "import" {
                if ($Arguments.Count -eq 1) {
                    Import-LiveFeaturesConfig -Path $Arguments[0]
                }
                elseif ($Arguments.Count -eq 2) {
                    Import-LiveFeaturesConfig -Path $Arguments[0] -Format $Arguments[1]
                }
                else {
                    Write-Error "Invalid arguments for 'import' command. Provide file path and optional format"
                }
            }
            
            "backup" {
                if ($Arguments.Count -eq 0) {
                    Backup-LiveFeaturesConfig
                }
                elseif ($Arguments.Count -eq 1) {
                    Backup-LiveFeaturesConfig -Path $Arguments[0]
                }
                else {
                    Write-Error "Too many arguments for 'backup' command"
                }
            }
            
            "restore" {
                if ($Arguments.Count -eq 1) {
                    Restore-LiveFeaturesConfig -Path $Arguments[0]
                }
                else {
                    Write-Error "Invalid arguments for 'restore' command. Provide backup file path"
                }
            }
            
            "test" {
                Test-LiveFeaturesConfig
            }
            
            "update" {
                if ($Arguments.Count -eq 0) {
                    Update-LiveFeaturesConfig
                }
                else {
                    $force = $Arguments -contains "-Force" -or $Arguments -contains "--force"
                    $version = $Arguments | Where-Object { $_ -notlike "-*" } | Select-Object -First 1
                    
                    if ($version) {
                        Update-LiveFeaturesConfig -CurrentVersion $version -Force:$force
                    }
                    else {
                        Update-LiveFeaturesConfig -Force:$force
                    }
                }
            }
            
            "info" {
                Get-LiveFeaturesConfigInfo
            }
            
            "help" {
                Show-ConfigurationHelp
            }
        }
    }
    catch {
        Write-Error "Configuration command failed: $($_.Exception.Message)"
    }
}

function ConvertTo-ConfigValue {
    <#
    .SYNOPSIS
    Convert string value to appropriate type for configuration
    #>
    param([string]$ValueString)
    
    # Try to parse as boolean
    if ($ValueString -eq "true" -or $ValueString -eq "True" -or $ValueString -eq "TRUE") {
        return $true
    }
    if ($ValueString -eq "false" -or $ValueString -eq "False" -or $ValueString -eq "FALSE") {
        return $false
    }
    
    # Try to parse as integer
    if ($ValueString -match '^\d+$') {
        return [int]$ValueString
    }
    
    # Return as string
    return $ValueString
}

function Show-ConfigurationHelp {
    <#
    .SYNOPSIS
    Show help for configuration commands
    #>
    Write-Host "Live Features Configuration Commands" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  config <command> [arguments...]" -ForegroundColor White
    Write-Host "  Invoke-ConfigurationCommand -Command <command> -Arguments <args>" -ForegroundColor White
    Write-Host ""
    
    Write-Host "COMMANDS:" -ForegroundColor Yellow
    Write-Host ""
    
    $commands = @(
        @{ Name = "show"; Description = "Display configuration"; Examples = @("show", "show liveDisplay", "show liveDisplay.refreshInterval") },
        @{ Name = "set"; Description = "Set configuration values"; Examples = @("set liveDisplay.refreshInterval=2000", "set lyrics.cacheEnabled=false") },
        @{ Name = "reset"; Description = "Reset to defaults"; Examples = @("reset", "reset liveDisplay") },
        @{ Name = "schema"; Description = "Show valid settings"; Examples = @("schema", "schema liveDisplay") },
        @{ Name = "export"; Description = "Export configuration"; Examples = @("export", "export backup.json") },
        @{ Name = "import"; Description = "Import configuration"; Examples = @("import backup.json") },
        @{ Name = "backup"; Description = "Create backup"; Examples = @("backup", "backup C:\Backups") },
        @{ Name = "restore"; Description = "Restore from backup"; Examples = @("restore backup_file.json") },
        @{ Name = "test"; Description = "Validate configuration"; Examples = @("test") },
        @{ Name = "update"; Description = "Migrate to latest version"; Examples = @("update", "update 1.2") },
        @{ Name = "info"; Description = "Show system information"; Examples = @("info") },
        @{ Name = "help"; Description = "Show this help"; Examples = @("help") }
    )
    
    foreach ($cmd in $commands) {
        Write-Host "  $($cmd.Name)" -ForegroundColor Green -NoNewline
        Write-Host " - $($cmd.Description)" -ForegroundColor White
        
        foreach ($example in $cmd.Examples) {
            Write-Host "    config $example" -ForegroundColor Gray
        }
        Write-Host ""
    }
    
    Write-Host "CONFIGURATION SECTIONS:" -ForegroundColor Yellow
    Write-Host "  liveDisplay  - Real-time display settings" -ForegroundColor White
    Write-Host "  lyrics       - Lyrics fetching and display" -ForegroundColor White
    Write-Host "  statistics   - Data collection and analytics" -ForegroundColor White
    Write-Host "  apiClient    - API client configuration" -ForegroundColor White
    Write-Host ""
    
    Write-Host "EXAMPLES:" -ForegroundColor Yellow
    Write-Host "  config show                              # Show all configuration" -ForegroundColor Gray
    Write-Host "  config set liveDisplay.refreshInterval=1500  # Set refresh to 1.5 seconds" -ForegroundColor Gray
    Write-Host "  config set lyrics.preferredProvider=genius   # Use Genius for lyrics" -ForegroundColor Gray
    Write-Host "  config reset liveDisplay                 # Reset display settings" -ForegroundColor Gray
    Write-Host "  config backup                            # Create configuration backup" -ForegroundColor Gray
    Write-Host "  config schema liveDisplay                # Show display settings schema" -ForegroundColor Gray
}

function config {
    <#
    .SYNOPSIS
    Convenient wrapper for configuration commands
    .DESCRIPTION
    Provides a simple 'config' command for managing live features configuration
    .PARAMETER Command
    Configuration command
    .PARAMETER Arguments
    Command arguments
    .EXAMPLE
    config show
    Shows current configuration
    .EXAMPLE
    config set liveDisplay.refreshInterval=2000
    Sets refresh interval
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Command = "show",
        
        [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
        [string[]]$Arguments = @()
    )
    
    if (-not $Command -or $Command -eq "") {
        $Command = "show"
    }
    
    # Validate command
    $validCommands = @("show", "set", "reset", "schema", "export", "import", "backup", "restore", "test", "update", "info", "help")
    if ($Command -notin $validCommands) {
        Write-Error "Invalid command: '$Command'. Use 'config help' to see available commands."
        return
    }
    
    Invoke-ConfigurationCommand -Command $Command -Arguments $Arguments
}

# Export functions
Export-ModuleMember -Function @(
    'Invoke-ConfigurationCommand',
    'config',
    'Show-ConfigurationHelp'
)