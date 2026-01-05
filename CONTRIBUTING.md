# Contributing to Terminal Control Spotify

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to Terminal Control Spotify.

## Code of Conduct

Be respectful, constructive, and professional in all interactions. We're here to build great software together.

## Getting Started

### Prerequisites

- PowerShell 7.0 or later
- Spotify Premium account
- Spotify API credentials (Client ID and Secret)
- Git for version control
- Windows 10/11 (for full feature support)

### Development Setup

1. **Fork and clone the repository:**
 
   ```bash
   git clone https://github.com/YOUR_USERNAME/Terminal_Control_Spotify.git
   cd Terminal_Control_Spotify
   ```

2. **Set up Spotify API credentials:**

   ```powershell
   $env:SPOTIFY_CLIENT_ID = "your_client_id"
   $env:SPOTIFY_CLIENT_SECRET = "your_client_secret"
   ```

3. **Import the module:**

   ```powershell
   Import-Module .\SpotifyModule.psm1 -Force
   ```

4. **Test that it works:**

   ```powershell
   spotify --help
   ```

## Project Structure

```
Terminal_Control_Spotify/
├── SpotifyModule.psm1              # Main module orchestrator
├── modules/
│   ├── Core/                       # Core functionality
│   │   ├── ApiClientManager.psm1   # API client classes
│   │   ├── ErrorHandling.psm1      # Error handling
│   │   ├── LegacyApiClient.psm1    # API wrapper functions
│   │   ├── InteractiveMode.psm1    # Interactive navigation
│   │   ├── PlaybackCommands.psm1   # Playback control
│   │   ├── PlaylistQueueCommands.psm1 # Playlists & queue
│   │   ├── SearchCommands.psm1     # Search functionality
│   │   └── ...
│   ├── UI/                         # UI components
│   │   └── SpotifyFormDisplay.psm1 # Windows Form display
│   └── SpotifyLiveFeatures.psm1    # Live features
├── docs/                           # Documentation
├── tests/                          # Test files
└── README.md
```

## How to Contribute

### Reporting Bugs

1. **Check existing issues** to avoid duplicates
2. **Create a new issue** with:
   - Clear, descriptive title
   - Steps to reproduce
   - Expected vs actual behavior
   - PowerShell version (`$PSVersionTable.PSVersion`)
   - Error messages (if any)
   - Screenshots (if applicable)

### Suggesting Features

1. **Open an issue** with tag `enhancement`
2. **Describe the feature:**
   - What problem does it solve?
   - How should it work?
   - Any implementation ideas?
3. **Wait for feedback** before starting work

### Submitting Pull Requests

1. **Create a feature branch:**

   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes:**
   - Follow coding standards (see below)
   - Add comments for complex logic
   - Update documentation if needed

3. **Test your changes:**

   ```powershell
   Import-Module .\SpotifyModule.psm1 -Force
   # Test your feature thoroughly
   ```

4. **Commit your changes:**

   ```bash
   git add .
   git commit -m "Add feature: brief description"
   ```

5. **Push to your fork:**

   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create Pull Request:**
   - Clear title and description
   - Reference any related issues
   - Explain what changed and why

## Coding Standards

### PowerShell Style

#### Naming Conventions

```powershell
# Functions: Verb-Noun with PascalCase
function Get-CurrentTrack { }

# Variables: $camelCase
$currentTrack = "..."

# Script-scope: $script:camelCase
$script:isPlaying = $true

# Constants: $UPPER_CASE (if truly constant)
$API_BASE_URL = "https://api.spotify.com/v1"
```

#### Function Structure

```powershell
function Do-Something {
    <#
    .SYNOPSIS
    Brief description

    .DESCRIPTION
    Detailed description

    .PARAMETER Name
    Parameter description

    .EXAMPLE
    Do-Something -Name "test"
    #>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    try {
        # Implementation
    } catch {
        Write-Error "Error: $($_.Exception.Message)"
    }
}
```

#### Error Handling

```powershell
# Use generic catch blocks (not typed)
try {
    # Code
} catch {
    # Handle error
    Write-Verbose "Error: $($_.Exception.Message)"
}

# Don't use typed catch blocks (compatibility issues)
# ❌ catch [SpecificException]
# ✅ catch
```

#### Comments

```powershell
# Single-line comments for brief explanations

<#
Multi-line comments for:
- Complex logic
- Algorithm explanations
- Important notes
#>

# TODO: Future improvements
# FIXME: Known issues to fix
# NOTE: Important information
```

### Module Guidelines

#### Module Structure

```powershell
# Module header
# Brief description of module purpose

# Import dependencies (if needed)

# Functions
function Export-Function { }

# Export members
Export-ModuleMember -Function @(
    'Export-Function'
)
```

#### Function Export

```powershell
# Explicitly export public functions
Export-ModuleMember -Function @(
    'Public-Function1',
    'Public-Function2'
)

# Don't export internal helpers
# Prefix with _ or keep private
function _InternalHelper { }
```

### API Integration

#### API Calls

```powershell
# Always use Invoke-SpotifyApi wrapper
$result = Invoke-SpotifyApi -Method GET -Path "/me/player"

# Don't make direct HTTP calls
# ❌ Invoke-RestMethod -Uri "..."
```

#### Error Handling

```powershell
# Handle API errors gracefully
try {
    Invoke-SpotifyApi -Method POST -Path "/me/player/play"
} catch {
    Write-Host "❌ Could not start playback" -ForegroundColor Red
    Write-Verbose $_.Exception.Message
}
```

#### Rate Limiting

```powershell
# Be mindful of API rate limits
# Avoid tight loops with API calls
# Use reasonable update intervals (min 1 second)
```

### UI Guidelines

#### Console Output

```powershell
# Use color for better UX
Write-Host "✅ Success" -ForegroundColor Green
Write-Host "❌ Error" -ForegroundColor Red
Write-Host "⚠️ Warning" -ForegroundColor Yellow
Write-Host "ℹ️ Info" -ForegroundColor Cyan

# Use emojis for visual clarity
# 🎵 Music
# 📁 Playlists
# 🎙️ Podcasts
# ⏯️ Playback
```

#### Progress Indicators

```powershell
# Show progress for long operations
Write-Host "🔄 Loading..." -ForegroundColor Cyan

# Clear indicators when done
Write-Host "✅ Complete!" -ForegroundColor Green
```

### Windows Forms

#### Form Creation

```powershell
# Use Segoe UI fonts for consistency
$label.Font = New-Object System.Drawing.Font("Segoe UI", 12)

# Use Segoe UI Emoji for emoji support
$label.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 12)

# Follow Spotify color scheme
$spotifyGreen = [System.Drawing.ColorTranslator]::FromHtml("#1DB954")
$spotifyDark = [System.Drawing.ColorTranslator]::FromHtml("#191414")
```

#### Event Handlers

```powershell
# Use .GetNewClosure() for scriptblocks that need outer scope
$timer.Add_Tick({
    # Access outer scope variables
    $label.Text = $outerVariable
}.GetNewClosure())

# Store function references before scriptblock
$apiFunc = Get-Command Invoke-SpotifyApi
$button.Add_Click({
    & $apiFunc -Method POST -Path "/endpoint"
})
```

## Testing

### Manual Testing

1. Import module: `Import-Module .\SpotifyModule.psm1 -Force`
2. Test your feature thoroughly
3. Test edge cases
4. Test error scenarios
5. Test with different Spotify states (playing, paused, no device)

### Test Checklist

- [ ] Feature works as expected
- [ ] Handles errors gracefully
- [ ] Works with and without active Spotify playback
- [ ] Doesn't break existing functionality
- [ ] Follows coding standards
- [ ] Documentation updated (if needed)

## Documentation

### When to Update Docs

Update documentation when:

- Adding new features
- Changing existing behavior
- Fixing bugs that affect usage
- Adding new commands or aliases

### Documentation Files

- **README.md** - Overview and quick start
- **docs/FEATURES.md** - Complete feature list
- **docs/WINDOWS-FORM-GUIDE.md** - Windows Form documentation
- **docs/INTERACTIVE-MODE.md** - Interactive mode documentation
- **CHANGELOG.md** - All changes
- **Code comments** - Complex logic explanation

### Documentation Style

- Clear, concise language
- Include code examples
- Use screenshots where helpful
- List prerequisites and requirements
- Provide troubleshooting tips

## Git Workflow

### Branch Naming

- `feature/feature-name` - New features
- `fix/bug-description` - Bug fixes
- `docs/what-changed` - Documentation updates
- `refactor/component-name` - Code refactoring

### Commit Messages

```
Type: Brief description (50 chars or less)

More detailed explanation if needed (wrap at 72 chars).
Explain what changed and why, not how.

Fixes #123
```

Types:

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `style:` - Formatting, no code change
- `refactor:` - Code restructuring
- `test:` - Adding tests
- `chore:` - Maintenance

### Before Submitting PR

- [ ] Code follows style guidelines
- [ ] All tests pass
- [ ] Documentation updated
- [ ] Commit messages are clear
- [ ] No unnecessary files included
- [ ] Branch is up to date with main

## Getting Help

- **Issues** - Ask questions by opening an issue
- **Discussions** - General discussions and ideas
- **Documentation** - Check existing docs first

## Recognition

Contributors will be recognized in:

- README.md contributors section
- Release notes
- Git history

Thank you for contributing! 🎵
