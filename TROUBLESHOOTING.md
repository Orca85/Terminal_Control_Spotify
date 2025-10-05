# Spotify CLI - Troubleshooting Guide

This guide provides detailed troubleshooting information for common issues with the Spotify CLI Enhanced Edition.

## 🔍 Quick Diagnostics

Before diving into specific issues, try these quick diagnostic steps:

1. **Check Configuration**: `Get-SpotifyConfig`
2. **Test Connection**: Use `/help` to verify CLI is working
3. **View Logs**: Enable logging and check `logs` command
4. **Check Spotify Status**: Verify Spotify is running and playing music

## 🔐 Authentication Issues

### "Authentication Setup Error"

**Symptoms**: Cannot start local authentication server
**Causes**:

- PowerShell not running as Administrator
- Port 8888 already in use
- Windows Firewall blocking connection

**Solutions**:

1. Run PowerShell as Administrator
2. Check if port 8888 is in use: `netstat -an | findstr :8888`
3. Temporarily disable Windows Firewall for testing
4. Try a different port by modifying the script

### "Authentication State Mismatch"

**Symptoms**: Security error during OAuth flow
**Causes**:

- Browser session interference
- Network proxy issues
- Timing issues

**Solutions**:

1. Clear browser cache and cookies for Spotify
2. Try authentication in incognito/private mode
3. Restart the authentication process
4. Check for proxy or VPN interference

### "Token Requires Additional Permissions"

**Symptoms**: Re-authentication prompt for enhanced features
**Causes**:

- Upgrading from basic to enhanced version
- New features require additional scopes

**Solutions**:

1. Complete the re-authentication process
2. Ensure all required scopes are granted
3. Delete token file if corrupted: `Remove-Item "$env:APPDATA\SpotifyCLI\tokens.json"`

## 🎵 Playback Issues

### "No Active Device"

**Symptoms**: Cannot control playback, no device found
**Causes**:

- No Spotify device is currently active
- Device is offline or disconnected

**Solutions**:

1. Open Spotify on any device (phone, computer, smart speaker)
2. Start playing any song to activate the device
3. Use `/devices` command to list available devices
4. Use `/transfer <device_id>` to switch to a specific device
5. Ensure device is connected to the same network

### "Spotify Premium Required"

**Symptoms**: Playback control commands fail
**Causes**:

- Free Spotify account limitations
- Specific features require Premium

**Solutions**:

1. Upgrade to Spotify Premium for full functionality
2. Use read-only features available with Free accounts:
   - View current track (`/spotify`)
   - Browse playlists (`/playlists`)
   - Search music (`/search`)
   - View liked songs (`/liked`)

### "No Playback Found"

**Symptoms**: Current track commands show no music playing
**Causes**:

- No music currently playing on any device
- Playback is paused or stopped

**Solutions**:

1. Start playing music on any Spotify device
2. Use `/devices` to check device status
3. Use `/play` to resume if paused
4. Check if Spotify app is running and logged in

## 🌐 Network and API Issues

### "Rate Limit Exceeded"

**Symptoms**: Temporary API failures, "too many requests" errors
**Causes**:

- Making too many API calls too quickly
- Spotify API rate limiting

**Solutions**:

1. Wait 30-60 seconds before retrying
2. Reduce frequency of commands
3. Disable auto-refresh if enabled
4. The CLI automatically handles rate limiting with delays

### "Service Unavailable" / "Server Error"

**Symptoms**: HTTP 502, 503, 504 errors
**Causes**:

- Spotify API temporary outage
- Network connectivity issues

**Solutions**:

1. Check Spotify's status page: https://status.spotify.com/
2. Wait a few minutes and retry
3. Test internet connection
4. Try different network if available

### "Network Error" / "Connection Timeout"

**Symptoms**: Cannot connect to Spotify servers
**Causes**:

- Internet connection issues
- Firewall blocking connections
- DNS resolution problems

**Solutions**:

1. Test internet connection: `Test-NetConnection google.com`
2. Check Windows Firewall settings
3. Try different DNS servers (8.8.8.8, 1.1.1.1)
4. Disable VPN temporarily for testing
5. Check corporate firewall/proxy settings

## 🔔 Notification Issues

### Notifications Not Appearing

**Symptoms**: No toast notifications for track changes
**Causes**:

- Notifications disabled in configuration
- Windows notification system issues
- Missing BurntToast module

**Solutions**:

1. Enable notifications: `notifications on`
2. Test notification system: `notifications test`
3. Install BurntToast module: `Install-Module BurntToast -Force`
4. Check Windows notification settings
5. Ensure Windows 10+ for full toast support

### Notification Permission Denied

**Symptoms**: Notifications fail with permission errors
**Causes**:

- Windows notification permissions disabled
- PowerShell execution policy restrictions

**Solutions**:

1. Check Windows Settings > System > Notifications & actions
2. Enable notifications for PowerShell
3. Run as Administrator if needed
4. Use fallback console notifications

## 🔍 Search and Library Issues

### "Search Returns No Results"

**Symptoms**: Search command finds nothing
**Causes**:

- Misspelled search terms
- Regional content restrictions
- API connectivity issues

**Solutions**:

1. Check spelling and try different search terms
2. Use broader search terms (artist name only)
3. Try searching in the Spotify app to verify content exists
4. Check internet connection

### "Playlist Access Denied"

**Symptoms**: Cannot view or access playlists
**Causes**:

- Insufficient API scopes
- Private playlist restrictions
- Authentication issues

**Solutions**:

1. Re-authenticate to get required scopes
2. Check if playlists are set to private
3. Verify Spotify account has playlists
4. Try accessing public playlists first

## 📁 File and Configuration Issues

### "Configuration Not Saving"

**Symptoms**: Settings reset after restart
**Causes**:

- Write permission issues
- Corrupted configuration file
- Disk space issues

**Solutions**:

1. Check write permissions to `%APPDATA%\SpotifyCLI\`
2. Delete corrupted config: `Remove-Item "$env:APPDATA\SpotifyCLI\config.json"`
3. Run PowerShell as Administrator
4. Check available disk space

### "Log Files Growing Too Large"

**Symptoms**: Large log files consuming disk space
**Causes**:

- Debug logging enabled with high activity
- Log rotation not working

**Solutions**:

1. Adjust log settings: `Set-SpotifyConfig @{LogLevel="Warning"; MaxLogSizeMB=5}`
2. Manually clean logs: `Remove-Item "$env:APPDATA\SpotifyCLI\*.log"`
3. Disable logging if not needed: `Set-SpotifyConfig @{LoggingEnabled=$false}`

## 🛠️ Advanced Troubleshooting

### Enable Debug Logging

For detailed troubleshooting information:

```powershell
# Enable debug logging
Set-SpotifyConfig @{
    LoggingEnabled = $true
    LogLevel = "Debug"
}

# Reproduce the issue, then view logs
logs

# Or view log file directly
Get-Content "$env:APPDATA\SpotifyCLI\spotify-cli.log" -Tail 50
```

### Reset to Factory Defaults

If all else fails, reset the CLI:

```powershell
# Remove all data (will require re-authentication)
Remove-Item "$env:APPDATA\SpotifyCLI" -Recurse -Force

# Restart PowerShell and run CLI again
```

### Check PowerShell Version

Ensure compatible PowerShell version:

```powershell
$PSVersionTable.PSVersion
# Should be 5.1+ for Windows PowerShell or 7+ for PowerShell Core
```

### Verify Module Installation

Check if the module is properly installed:

```powershell
Get-Module SpotifyModule -ListAvailable
Import-Module .\SpotifyModule.psm1 -Force
```

## 📞 Getting Additional Help

If you're still experiencing issues:

1. **Check the README**: Review the main documentation
2. **Enable Debug Logging**: Capture detailed error information
3. **Test with Minimal Setup**: Try basic commands first
4. **Check Spotify Status**: Verify Spotify services are operational
5. **Community Support**: Search for similar issues online

### Information to Gather for Support

When seeking help, provide:

- PowerShell version (`$PSVersionTable.PSVersion`)
- Windows version (`Get-ComputerInfo | Select WindowsProductName, WindowsVersion`)
- Error messages (exact text)
- Debug logs (if enabled)
- Steps to reproduce the issue
- Spotify account type (Free/Premium)

## 🔄 Common Command Patterns

### Safe Testing Commands

Start with these low-impact commands:

```powershell
Get-SpotifyHelp          # Show help
Show-SpotifyTrack        # Show current track
devices                  # List devices
Get-SpotifyConfig        # View configuration
search "test"            # Test search functionality
```

### Recovery Commands

If the CLI becomes unresponsive:

```powershell
# Force stop auto-refresh
Ctrl+C

# Reset configuration
Set-SpotifyConfig $DefaultConfig

# Clear and restart
Clear-Host
```

This troubleshooting guide covers the most common issues. For specific error messages not covered here, enable debug logging and examine the detailed error information provided.
