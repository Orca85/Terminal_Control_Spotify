# StateManager Module
# Handles the session state for the Spotify CLI, such as search results and device lists.

# --- Private Module State ---

# Stores track/episode results from the 'search' command
$script:SessionTracks = @()

# Stores device results from the 'devices' command
$script:SessionDevices = @()

# Stores album results from the 'search-albums' command
$script:SessionAlbums = @()

# Stores playlist results from the 'playlists' command
$script:SessionPlaylists = @()


# --- Public Functions ---

# --- Track State Management ---

function Get-SessionTracks {
    return $script:SessionTracks
}

function Set-SessionTracks {
    param($Tracks)
    $script:SessionTracks = $Tracks
}

function Clear-SessionTracks {
    $script:SessionTracks = @()
}


# --- Device State Management ---

function Get-SessionDevices {
    return $script:SessionDevices
}

function Set-SessionDevices {
    param($Devices)
    $script:SessionDevices = $Devices
}


# --- Album State Management ---

function Get-SessionAlbums {
    return $script:SessionAlbums
}

function Set-SessionAlbums {
    param($Albums)
    $script:SessionAlbums = $Albums
}

# --- Playlist State Management ---

function Get-SessionPlaylists {
    return $script:SessionPlaylists
}

function Set-SessionPlaylists {
    param($Playlists)
    $script:SessionPlaylists = $Playlists
}


# --- Module Exports ---

Export-ModuleMember -Function @(
    'Get-SessionTracks',
    'Set-SessionTracks',
    'Clear-SessionTracks',
    'Get-SessionDevices',
    'Set-SessionDevices',
    'Get-SessionAlbums',
    'Set-SessionAlbums',
    'Get-SessionPlaylists',
    'Set-SessionPlaylists'
)