#!/usr/bin/env pwsh
<#
.SYNOPSIS
Spotify CLI Diagnostic Runner

.DESCRIPTION
Convenient script to run Spotify CLI diagnostics and system validation

.PARAMETER Full
Run complete diagnostic suite (system, API, server, config)

.PARAMETER System
Run only system diagnostics

.PARAMETER Api
Run only API connectivity tests

.PARAMETER Config
Run only configuration validation

.PARAMETER Server
Run only local server tests

.PARAMETER Export
Export diagnostic results to file

.PARAMETER Detailed
Show detailed diagnostic information

.EXAMPLE
.\Run-SpotifyDiagnostics.ps1
Run basic system diagnostics

.EXAMPLE
.\Run-SpotifyDiagnostics.ps1 -Full -Export
Run complete diagnostics and export report

.EXAMPLE
.\Run-SpotifyDiagnostics.ps1 -Api
Test only Spotify API connectivity
#>

[CmdletBinding()]
param(
    [switch]$Full,
    [switch]$System,
    [switch]$Api,
    [switch]$Config,
    [switch]$Server,
    [switch]$Export,
    [switch]$Detailed
)

# Import the diagnostic module
try {
    Import-Module ".\SpotifyDiagnostics.psm1" -Force -ErrorAction Stop
    Write-Host "✅ Diagnostic module loaded successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to load diagnostic module: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Make sure SpotifyDiagnostics.psm1 is in the current directory" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Determine what to run based on parameters
if ($Full) {
    # Run complete diagnostic suite
    Write-Host "🚀 Running Complete Spotify CLI Diagnostic Suite..." -ForegroundColor Cyan
    Write-Host ""
    $results = Invoke-SpotifyFullDiagnostics -ExportReport:$Export -Detailed:$Detailed
} elseif ($System) {
    # Run only system diagnostics
    Write-Host "🖥️ Running System Diagnostics..." -ForegroundColor Cyan
    Write-Host ""
    $results = Test-SpotifySystemDiagnostics -Detailed:$Detailed -ExportReport:$Export
} elseif ($Api) {
    # Run only API connectivity tests
    Write-Host "🌐 Running API Connectivity Tests..." -ForegroundColor Cyan
    Write-Host ""
    $results = Test-SpotifyApiConnectivity
} elseif ($Config) {
    # Run only configuration validation
    Write-Host "⚙️ Running Configuration Validation..." -ForegroundColor Cyan
    Write-Host ""
    $results = Test-SpotifyConfiguration
} elseif ($Server) {
    # Run only local server tests
    Write-Host "🖥️ Running Local Server Tests..." -ForegroundColor Cyan
    Write-Host ""
    $results = Test-SpotifyLocalServer
} else {
    # Default: run system diagnostics
    Write-Host "🖥️ Running Basic System Diagnostics..." -ForegroundColor Cyan
    Write-Host "💡 Use -Full for complete diagnostics or -Api/-Config/-Server for specific tests" -ForegroundColor Gray
    Write-Host ""
    $results = Test-SpotifySystemDiagnostics -Detailed:$Detailed -ExportReport:$Export
}

Write-Host ""
Write-Host "🏁 Diagnostic run completed!" -ForegroundColor Green

# Show quick summary for non-full runs
if (-not $Full -and $results.Issues) {
    Write-Host ""
    Write-Host "⚠️ Quick Summary:" -ForegroundColor Yellow
    Write-Host "Issues found: $($results.Issues.Count)" -ForegroundColor Yellow
    if ($results.Recommendations) {
        Write-Host "Recommendations: $($results.Recommendations.Count)" -ForegroundColor Cyan
    }
    Write-Host ""
    Write-Host "💡 Run with -Full for comprehensive analysis" -ForegroundColor Gray
}