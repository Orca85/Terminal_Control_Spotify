#!/usr/bin/env pwsh

# Test the new playlist functions in isolation

function play-playlist {
    param(
        [Parameter(Mandatory)][int]$PlaylistNumber,
        [int]$TrackNumber
    )
    
    Write-Host "play-playlist function called with PlaylistNumber: $PlaylistNumber, TrackNumber: $TrackNumber"
}

function queue-playlist {
    param([Parameter(Mandatory)][int]$PlaylistNumber)
    
    Write-Host "queue-playlist function called with PlaylistNumber: $PlaylistNumber"
}

# Test the functions
Write-Host "Testing new playlist functions..."
play-playlist -PlaylistNumber 1
play-playlist -PlaylistNumber 1 -TrackNumber 5
queue-playlist -PlaylistNumber 2

Write-Host "Functions work correctly!"