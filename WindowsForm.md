Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- SKAPA FÖNSTRET ---

$form = New-Object System.Windows.Forms.Form
$form.Text = "Spotify Info"
$form.Size = New-Object System.Drawing.Size(350, 160)
$form.StartPosition = "CenterScreen" # Dyker upp i mitten nu för test
$form.TopMost = $true                # Ligger alltid överst
$form.FormBorderStyle = "FixedToolWindow" # Tunn ram, inget "maximera"
$form.BackColor = "#191414" # Spotify Dark Background

# --- LAYOUT (Labels) ---

# Låttitel (Spotify Green)

$lblSong = New-Object System.Windows.Forms.Label
$lblSong.Location = New-Object System.Drawing.Point(15, 10)
$lblSong.Size = New-Object System.Drawing.Size(310, 35)
$lblSong.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$lblSong.ForeColor = "#1DB954"       # Spotify Green
$lblSong.Text = "Bohemian Rhapsody"
$form.Controls.Add($lblSong)

# Artist (Vit)

$lblArtist = New-Object System.Windows.Forms.Label
$lblArtist.Location = New-Object System.Drawing.Point(15, 45)
$lblArtist.Size = New-Object System.Drawing.Size(310, 25)
$lblArtist.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
$lblArtist.ForeColor = "White"
$lblArtist.Text = "Queen"
$form.Controls.Add($lblArtist)

# Tid (Ljusgrå)

$lblTime = New-Object System.Windows.Forms.Label
$lblTime.Location = New-Object System.Drawing.Point(15, 75)
$lblTime.Size = New-Object System.Drawing.Size(310, 20)
$lblTime.Font = New-Object System.Drawing.Font("Consolas", 10) # Monospace för snygga siffror
$lblTime.ForeColor = "#B3B3B3"
$lblTime.Text = "00:00 / 05:55"
$form.Controls.Add($lblTime)

# Nästa låt (Mörkare grå)

$lblNext = New-Object System.Windows.Forms.Label
$lblNext.Location = New-Object System.Drawing.Point(15, 100)
$lblNext.Size = New-Object System.Drawing.Size(310, 20)
$lblNext.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
$lblNext.ForeColor = "#535353"
$lblNext.Text = "Up Next: Don't Stop Me Now"
$form.Controls.Add($lblNext)

# --- SIMULATOR (Bara för demo) ---

$script:seconds = 0
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000
$timer.Add_Tick({
$script:seconds++
    # Formatera sekunder till MM:SS
    $ts = [TimeSpan]::FromSeconds($script:seconds)
$timeString = "{0:mm}:{0:ss}" -f $ts
    $lblTime.Text = "$timeString / 05:55"

    # Byt låt på låtsas efter 5 sekunder för effekt
    if($script:seconds -eq 5) {
        $lblSong.Text = "Don't Stop Me Now"
        $lblNext.Text = "Up Next: We Will Rock You"
        $lblTime.ForeColor = "#1DB954" # Byt färg för att visa att något händer
    }

})

$timer.Start()
$form.ShowDialog()
