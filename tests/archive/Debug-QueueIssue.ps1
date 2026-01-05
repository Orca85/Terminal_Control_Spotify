#!/usr/bin/env pwsh
<#
.SYNOPSIS
Debug the queue issue to see what's really happening
#>

# Import the module
Import-Module .\SpotifyModule.psm1 -Force

Write-Host "🔍 Debugging Queue Issue" -ForegroundColor Cyan
Write-Host ""

# Test 1: Check if we have a valid access token
Write-Host "1. Checking access token..." -ForegroundColor White
try {
    $token = Get-SpotifyAccessToken
    if ($token) {
        Write-Host "✅ Access token available: $($token.Substring(0,20))..." -ForegroundColor Green
    } else {
        Write-Host "❌ No access token available" -ForegroundColor Red
        Write-Host "💡 Run .\spotifyCLI.ps1 to authenticate" -ForegroundColor Yellow
        exit
    }
} catch {
    Write-Host "❌ Token check failed: $($_.Exception.Message)" -ForegroundColor Red
    exit
}

# Test 2: Check current playback state
Write-Host ""
Write-Host "2. Checking current playback state..." -ForegroundColor White
try {
    $currentTrack = Invoke-SpotifyApi -Method GET -Path "/me/player/currently-playing"
    if ($currentTrack) {
        Write-Host "✅ Playback active: $($currentTrack.item.name)" -ForegroundColor Green
        Write-Host "📱 Device: $($currentTrack.device.name)" -ForegroundColor Gray
    } else {
        Write-Host "⚠️ No active playback detected" -ForegroundColor Yellow
        Write-Host "💡 Start playing something in Spotify first" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Playback check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 3: Check available devices
Write-Host ""
Write-Host "3. Checking available devices..." -ForegroundColor White
try {
    $devicesResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/devices"
    if ($devicesResponse -and $devicesResponse.devices) {
        Write-Host "✅ Available devices:" -ForegroundColor Green
        foreach ($device in $devicesResponse.devices) {
            $status = if ($device.is_active) { "ACTIVE" } else { "inactive" }
            Write-Host "  • $($device.name) ($($device.type)) - $status" -ForegroundColor Gray
        }
    } else {
        Write-Host "❌ No devices found" -ForegroundColor Red
        Write-Host "💡 Make sure Spotify is running on at least one device" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Device check failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 4: Try to add a specific track to queue manually
Write-Host ""
Write-Host "4. Testing manual queue addition..." -ForegroundColor White

# First, do a search to get a track
Write-Host "Searching for test track..." -ForegroundColor Gray
try {
    $searchResults = Invoke-SpotifyApi -Method GET -Path "/search" -Query @{ 
        q = "test"
        type = "track"
        limit = "1"
    }
    
    if ($searchResults -and $searchResults.tracks -and $searchResults.tracks.items -and $searchResults.tracks.items.Count -gt 0) {
        $testTrack = $searchResults.tracks.items[0]
        Write-Host "✅ Found test track: $($testTrack.name) by $(($testTrack.artists | ForEach-Object { $_.name }) -join ', ')" -ForegroundColor Green
        
        # Now try to add it to queue
        Write-Host "Attempting to add to queue..." -ForegroundColor Gray
        try {
            $query = @{ uri = $testTrack.uri }
            Write-Host "Debug: URI = $($testTrack.uri)" -ForegroundColor Gray
            Write-Host "Debug: Query = $($query | ConvertTo-Json)" -ForegroundColor Gray
            
            $result = Invoke-SpotifyApi -Method POST -Path "/me/player/queue" -Query $query
            Write-Host "✅ Queue addition successful!" -ForegroundColor Green
            Write-Host "Debug: API Response = $($result | ConvertTo-Json)" -ForegroundColor Gray
            
            # Wait a moment and check the queue
            Start-Sleep -Seconds 2
            Write-Host "Checking queue to verify..." -ForegroundColor Gray
            
            $queueResponse = Invoke-SpotifyApi -Method GET -Path "/me/player/queue"
            if ($queueResponse -and $queueResponse.queue) {
                Write-Host "✅ Queue has $($queueResponse.queue.Count) tracks" -ForegroundColor Green
                
                # Look for our track in the queue
                $foundTrack = $queueResponse.queue | Where-Object { $_.id -eq $testTrack.id }
                if ($foundTrack) {
                    Write-Host "✅ Our track found in queue!" -ForegroundColor Green
                } else {
                    Write-Host "⚠️ Our track not found in queue (might be at the end)" -ForegroundColor Yellow
                }
            } else {
                Write-Host "⚠️ Could not retrieve queue for verification" -ForegroundColor Yellow
            }
            
        } catch {
            Write-Host "❌ Queue addition failed: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "Debug: Full error = $($_ | ConvertTo-Json)" -ForegroundColor Gray
            
            # Check specific error codes
            if ($_.Exception.Response) {
                $statusCode = [int]$_.Exception.Response.StatusCode
                Write-Host "Debug: HTTP Status Code = $statusCode" -ForegroundColor Gray
                
                switch ($statusCode) {
                    403 { Write-Host "💡 This requires Spotify Premium" -ForegroundColor Yellow }
                    404 { Write-Host "💡 No active device found" -ForegroundColor Yellow }
                    429 { Write-Host "💡 Rate limited - try again later" -ForegroundColor Yellow }
                }
            }
        }
        
    } else {
        Write-Host "❌ No tracks found in search" -ForegroundColor Red
    }
    
} catch {
    Write-Host "❌ Search failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔍 Debug completed. Check the results above to identify the issue." -ForegroundColor Cyan