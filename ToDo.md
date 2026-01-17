**Situation**

Du utvecklar ett PowerShell-baserat Spotify CLI-projekt (v3.1.0) med omfattande funktionalitet inklusive live-display, synkroniserade lyrics, interaktiv navigering och Windows Form-gränssnitt. Projektet innehåller 98 funktioner och alias, och du behöver säkerställa att installationen fungerar felfritt i PowerShell 7+ miljöer (Windows Terminal och VS Code). Användare rapporterar specifika fel där alias och funktioner inte känns igen efter installation, vilket indikerar problem med modulimport, alias-hantering och beroenden. Installationen ska ske i användarens `Documents\PowerShell` mapp för optimal integration med PowerShell-profilen. **Projektet ska också förbereda för publicering på PowerShell Gallery för att möjliggöra professionell distribution via `Install-Module SpotifyCommands` och automatiska uppdateringar via `Update-Module`.**

**Task**
Skapa en robust installationsskript för Claude Code som:

1. **Läser och parsear README.md-filen först** för att extrahera alla dokumenterade alias och funktioner som ska finnas tillgängliga efter installation
2. Analyserar projektstrukturen grundligt för att identifiera alla moduler, funktioner och beroenden
3. Tar bort alla tidigare installationer av projektet fullständigt från både `Documents\PowerShell` och `Documents\WindowsPowerShell`
4. Installerar projektet korrekt i `Documents\PowerShell` mappen med alla nödvändiga komponenter
5. Säkerställer att alla alias och kortkommandon skriver över PowerShells standardalias
6. Verifierar att alla moduler är korrekt importerade och funktionella
7. Kopierar eller flyttar filer vid behov för att säkerställa korrekt funktionalitet
8. **Validerar installationen genom att testa varje funktion och alias som dokumenteras i README.md**
9. **Genererar en detaljerad rapport som jämför README.md-specifikationen mot faktisk installation**
10. Ger tydlig feedback om eventuella problem och deras lösningar
11. **Förbereder projektet för PowerShell Gallery-publicering genom att:**
    - Skapa en korrekt strukturerad modulmanifest (`.psd1`) som följer PowerShell Gallery-standarder
    - Validera att alla Gallery-krav är uppfyllda (metadata, versionshantering, licens, tags)
    - Generera en publiceringsguide med steg-för-steg-instruktioner för att publicera modulen
    - Säkerställa att modulstrukturen är kompatibel med `Install-Module` och `Update-Module`

**Objective**
Målet är att eliminera alla installationsfel och säkerställa att användare kan använda alla funktioner och alias (som `ss`, `slw`, `play`, `music`) omedelbart efter installation utan att stöta på "term not recognized"-fel. Installationen ska vara idiotsäker och hantera edge cases som befintliga alias-konflikter, modulimportfel och saknade beroenden. **Alla funktioner och alias som dokumenteras i README.md ska vara verifierade och funktionella efter installation, och eventuella avvikelser ska rapporteras tydligt.** **Dessutom ska projektet vara redo för professionell distribution via PowerShell Gallery, vilket möjliggör enkel installation med `Install-Module SpotifyCommands`, automatiska uppdateringar via `Update-Module`, och följer branschstandarder för PowerShell-moduler.**

**Knowledge**
Projektet innehåller följande komponenter som måste hanteras:

"""

# Spotify CLI for PowerShell - Live Features Edition v3.1.0

A comprehensive command-line interface for controlling Spotify playback directly from PowerShell with revolutionary **Live Features** including real-time display, synchronized lyrics, comprehensive analytics, interactive navigation, smart playlist management, and cross-platform compatibility.

**🎨 NEW: WINDOWS FORM DISPLAY** - Beautiful floating window with live playback info and full controls!

**🎮 NEW: ENHANCED INTERACTIVE MODE** - Navigate playlists, queue, and search with arrow keys!

**✅ FULLY TESTED AND VALIDATED** - Comprehensively tested with enhanced performance and expanded functionality.
"""

Typiska fel som måste åtgärdas:
"""
🐋  ~\..\amk-website  main ≡  ss
ss: The term 'ss' is not recognized as a name of a cmdlet, function, script file, or executable program.

🐋  ~\..\amk-website  main ≡  slw
slw: The term 'Show-SpotifyLyricsForm' is not recognized as a name of a cmdlet, function, script file, or executable program.

🐋  ~\..\amk-website  main ≡  play
🎵 No active playback found. Trying to start from your recent tracks...
❌ Could not start playback: The term 'Invoke-SpotifyApi' is not recognized as a name of a cmdlet, function, script file, or executable program.

🐋  ~\..\amk-website  main ≡  music
❌ An unexpected error occurred while getting the current track: The term 'Invoke-SpotifyApi' is not recognized as a name of a cmdlet, function, script file, or executable program.
"""

Viktiga funktioner och alias som måste fungera (kommer att verifieras mot README.md):

- `ss` / `ShowSpotify` - Windows Form display
- `slw` / `ShowLyrics` - Lyrics window
- `play`, `pause`, `next`, `previous` - Playback controls
- `music` / `plays-now` / `pn` / `sp` - Show current track
- `Invoke-SpotifyApi` - Core API function som andra funktioner är beroende av

Installationsalternativ som finns:

- `Install-SpotifyCLI-LiveFeatures.ps1` - Huvudinstallation med live features
- `Install-SpotifyCliDependencies.ps1` - Legacy installer
- `SpotifyModule.psm1` - Huvudmodulen som måste importeras

Systemkrav:

- PowerShell 7+ (Windows Terminal och VS Code)
- Spotify Premium-konto
- Spotify Developer App credentials (.env-fil)

Installationsplats:

- `$HOME\Documents\PowerShell` för PowerShell 7+ (primär målmiljö)

**PowerShell Gallery-krav:**
För att modulen ska kunna publiceras på PowerShell Gallery och installeras via `Install-Module SpotifyCommands` måste följande krav uppfyllas:

1. **Modulmanifest (`.psd1`)**:
   - ModuleVersion (semantisk versionshantering: 3.1.0)
   - GUID (unik identifierare för modulen)
   - Author och CompanyName
   - Copyright och LicenseUri
   - ProjectUri (GitHub eller annan kod-repository)
   - Description (tydlig beskrivning av modulens funktionalitet)
   - Tags (för sökbarhet: 'Spotify', 'Music', 'CLI', 'Playback', 'Lyrics')
   - ReleaseNotes (ändringslogg för varje version)
   - RequiredModules (om modulen har beroenden)
   - FunctionsToExport (lista över alla 98 funktioner)
   - AliasesToExport (lista över alla alias)

2. **Modulstruktur**:
   - Root-mapp med modulnamn: `SpotifyCommands/`
   - Modulmanifest: `SpotifyCommands.psd1`
   - Huvudmodul: `SpotifyCommands.psm1`
   - README.md (dokumentation)
   - LICENSE.txt (licensfil, t.ex. MIT)
   - Undermappar för organisering: `Public/`, `Private/`, `Data/`

3. **Publiceringsprocess**:
   - Registrera konto på PowerShell Gallery (<https://www.powershellgallery.com/>)
   - Generera API-nyckel från Gallery
   - Använd `Publish-Module` cmdlet med API-nyckel
   - Validera modulen med `Test-ModuleManifest` innan publicering

4. **Versionshantering**:
   - Följ semantisk versionshantering (MAJOR.MINOR.PATCH)
   - Uppdatera ModuleVersion i `.psd1` för varje release
   - Dokumentera ändringar i ReleaseNotes

**Instructions**
Du är en expert PowerShell-utvecklare och DevOps-ingenjör med specialisering på modulhantering, installationsautomatisering och PowerShell Gallery-publicering. Din uppgift är att skapa ett omfattande installationsskript som Claude Code kan köra för att säkerställa felfri installation av Spotify CLI-projektet, samt förbereda projektet för professionell distribution via PowerShell Gallery.

Skriptet ska:

1. **Extrahera och parsa README.md som ground truth**:
   - Läs README.md-filen rad för rad och identifiera alla tabeller med funktioner och alias
   - Parsa specifikt dessa sektioner: "🎨 Latest Features", "🌟 Live Features Commands", "🎵 Core Playback Functions", "🎛️ Advanced Controls", "🎨 UI Features", "📱 Device Management", "🔍 Search & Discovery", "📚 Playlist & Library Management", "🎯 Queue Management", "⚙️ System & Configuration", "🎯 Alias Management"
   - Extrahera alla funktionsnamn, alias och beskrivningar från markdown-tabellerna med regex-mönster som matchar `| Function | Aliases | Description |` format
   - Skapa en strukturerad lista (hashtable eller objekt) med alla förväntade kommandon: `@{Function='Show-SpotifyForm'; Aliases=@('ShowSpotify','ss'); Description='Windows Form display with controls'}`
   - Identifiera de 98 funktionerna som dokumenteras och skapa en fullständig referenslista genom att räkna alla unika funktioner och alias
   - Hantera edge case där README.md inte kan läsas: använd en fallback-lista med kritiska funktioner (`ss`, `slw`, `play`, `music`, `Invoke-SpotifyApi`, `Show-SpotifyTrack`, `Show-SpotifyForm`, `Show-SpotifyLyricsForm`)
   - Validera att parsningen lyckades genom att kontrollera att minst 90 funktioner hittades (om färre, varna användaren om potentiella parsingproblem)

2. **Utföra förinstallationsanalys**:
   - Identifiera alla `.psm1`, `.ps1` och konfigurationsfiler i projektet
   - Kartlägga alla funktioner, alias och beroenden i projektfilerna genom att parsa `Export-ModuleMember` statements
   - Kontrollera befintliga PowerShell-profiler (`$PROFILE`) och modulinstallationer i `Documents\PowerShell\Modules`
   - Dokumentera alla befintliga alias-konflikter med PowerShells standardalias genom att köra `Get-Alias` och jämföra
   - Verifiera att PowerShell 7+ används (kör `$PSVersionTable.PSVersion` och varna om version < 7)

3. **Rensa tidigare installationer**:
   - Ta bort alla tidigare versioner av Spotify CLI från `Documents\PowerShell\Modules\SpotifyCLI` och `Documents\PowerShell\Modules\SpotifyCommands`
   - Rensa även `Documents\WindowsPowerShell\Modules\SpotifyCLI` och `Documents\WindowsPowerShell\Modules\SpotifyCommands` om de finns (för att undvika konflikter)
   - Rensa Spotify CLI-relaterade alias och import-statements från PowerShell-profilen (`$PROFILE`)
   - Ta bort gamla konfigurationsfiler och cache från `Documents\PowerShell` mappen
   - Säkerhetskopiera användardata (som `.env`) innan rensning till en `.backup` mapp med timestamp
   - Logga alla rensningsoperationer till `Documents\PowerShell\SpotifyCLI-Cleanup.log`

4. **Installera projektet korrekt i Documents\PowerShell**:
   - Skapa `Documents\PowerShell\Modules\SpotifyCommands` katalog om den inte finns (använd Gallery-kompatibelt modulnamn)
   - Kopiera `SpotifyModule.psm1` och alla relaterade `.psm1` filer till modulkatalogen (döp om huvudmodul till `SpotifyCommands.psm1`)
   - Kopiera alla hjälpfiler, konfigurationsfiler (`.env.example`), och beroenden
   - Säkerställ att alla filer har korrekta behörigheter för läsning och körning
   - Konfigurera PowerShell-profilen (`$PROFILE`) för att automatiskt importera modulen vid start: `Import-Module SpotifyCommands -Force`
   - Skapa alla nödvändiga alias med `-Force` och `-Option AllScope` för att skriva över standardalias

5. **Skapa PowerShell Gallery-kompatibel modulmanifest**:
   - Generera en `SpotifyCommands.psd1` fil med alla nödvändiga metadata:

     ```powershell
     @{
         ModuleVersion = '3.1.0'
         GUID = '<generera ny GUID med [guid]::NewGuid()>'
         Author = '<extrahera från README.md eller använd standardvärde>'
         CompanyName = 'Community'
         Copyright = '(c) 2026. All rights reserved.'
         Description = 'Comprehensive command-line interface for Spotify with live features, synchronized lyrics, and interactive controls'
         PowerShellVersion = '7.0'
         RootModule = 'SpotifyCommands.psm1'
         FunctionsToExport = @('<lista alla 98 funktioner från README.md-parsning>')
         AliasesToExport = @('<lista alla alias från README.md-parsning>')
         PrivateData = @{
             PSData = @{
                 Tags = @('Spotify', 'Music', 'CLI', 'Playback', 'Lyrics', 'Windows', 'Audio', 'Streaming')
                 LicenseUri = 'https://github.com/<user>/<repo>/blob/main/LICENSE.txt'
                 ProjectUri = 'https://github.com/<user>/<repo>'
                 IconUri = 'https://github.com/<user>/<repo>/blob/main/icon.png'
                 ReleaseNotes = 'v3.1.0: Windows Form display, enhanced interactive mode, synchronized lyrics'
             }
         }
     }
     ```

   - Validera manifestet med `Test-ModuleManifest SpotifyCommands.psd1`
   - Säkerställ att alla funktioner i `FunctionsToExport` faktiskt existerar i modulen
   - Verifiera att alla alias i `AliasesToExport` är definierade

6. **Skapa LICENSE.txt för Gallery-kompatibilitet**:
   - Om LICENSE.txt inte finns, skapa en MIT-licens som standard:

     ```
     MIT License
     
     Copyright (c) 2026 [Author Name]
     
     Permission is hereby granted, free of charge, to any person obtaining a copy
     of this software and associated documentation files (the "Software"), to deal
     in the Software without restriction...
     ```

   - Varna användaren om de behöver uppdatera copyright-information

7. **Hantera alias-konflikter explicit**:
   - Använd `Set-Alias -Name <alias> -Value <function> -Scope Global -Force -Option AllScope` för varje alias från README.md
   - Dokumentera vilka standardalias som skrivs över i `Documents\PowerShell\SpotifyCLI-AliasOverrides.log`
   - Skapa en `Restore-DefaultAliases` funktion i profilen för att återställa standardalias om användaren vill
   - Verifiera att alla alias från README.md-listan är korrekt konfigurerade genom att köra `Get-Alias` för varje

8. **Verifiera modulimport**:
   - Testa att `Import-Module SpotifyCommands` fungerar utan fel
   - Kontrollera att `Invoke-SpotifyApi` och andra core-funktioner är tillgängliga genom `Get-Command`
   - Validera att alla 98 funktioner exporteras korrekt från modulen genom att jämföra `Get-Command -Module SpotifyCommands` mot README.md-listan
   - Verifiera att Windows Forms-komponenter kan laddas för `ss` och `slw` genom att testa `Add-Type -AssemblyName System.Windows.Forms`

9. **Testa kritiska funktioner mot README.md-specifikation**:
   - För varje funktion och alias i README.md-listan, kör `Get-Command <name>` och verifiera att den finns
   - Testa specifikt dessa kritiska kommandon: `ss`, `slw`, `play`, `music`, `Invoke-SpotifyApi`, `ShowSpotify`, `ShowLyrics`, `plays-now`, `pn`, `sp`
   - Verifiera att `Get-SpotifyHelp` kan köras och returnerar hjälptext
   - Testa att `Initialize-SpotifyLiveFeatures` kan köras utan fel (om modulen är korrekt laddad)
   - **Generera en detaljerad verifieringsrapport som visar:**
     - Totalt antal funktioner i README.md vs tillgängliga efter installation
     - Lista över alla funktioner som FINNS och fungerar (grön status)
     - Lista över alla funktioner som SAKNAS eller inte fungerar (röd status)
     - Specifika felmeddelanden för funktioner som misslyckades
     - Procentuell framgångsgrad (t.ex. "95/98 funktioner tillgängliga - 96.9% framgång")

10. **Validera PowerShell Gallery-beredskap**:
    - Kör `Test-ModuleManifest` och verifiera att inga fel returneras
    - Kontrollera att alla obligatoriska metadata-fält är ifyllda (Author, Description, ProjectUri, LicenseUri)
    - Verifiera att ModuleVersion följer semantisk versionshantering (X.Y.Z format)
    - Testa att modulen kan importeras med `Import-Module` utan fel
    - Simulera Gallery-installation genom att kopiera modulen till en temporär plats och importera därifrån
    - Generera en Gallery-beredskapsrapport:

      ```
      ╔════════════════════════════════════════════════════════════╗
      ║  POWERSHELL GALLERY READINESS REPORT                       ║
      ╠════════════════════════════════════════════════════════════╣
      ║  ✓ Module Manifest Valid                                   ║
      ║  ✓ All Metadata Fields Present                             ║
      ║  ✓ Semantic Versioning (3.1.0)                             ║
      ║  ✓ License File Present (MIT)                              ║
      ║  ✓ README.md Present                                       ║
      ║  ✓ 98/98 Functions Exported                                ║
      ║  ✓ 156/156 Aliases Exported                                ║
      ║  ✓ Module Imports Successfully                             ║
      ║                                                            ║
      ║  Status: READY FOR PUBLICATION                             ║
      ╚════════════════════════════════════════════════════════════╝
      ```

11. **Generera publiceringsguide**:
    - Skapa en `PUBLISHING-GUIDE.md` fil med steg-för-steg-instruktioner:

      ```markdown
      # PowerShell Gallery Publishing Guide for SpotifyCommands
      
      ## Prerequisites
      1. PowerShell Gallery account (https://www.powershellgallery.com/)
      2. API Key from Gallery (Profile → API Keys → Create)
      3. Module validated with Test-ModuleManifest
      
      ## Publishing Steps
      
      ### 1. First-Time Setup
      ```powershell
      # Register PowerShell Gallery (if not already registered)
      Register-PSRepository -Default
      
      # Set your API key (replace with your actual key)
      $apiKey = 'your-api-key-here'
      ```

      ### 2. Validate Module Before Publishing

      ```powershell
      # Test module manifest
      Test-ModuleManifest .\SpotifyCommands.psd1
      
      # Import module to verify functionality
      Import-Module .\SpotifyCommands.psd1 -Force
      
      # Verify all functions are available
      Get-Command -Module SpotifyCommands
      ```

      ### 3. Publish to Gallery

      ```powershell
      # Publish module (first time)
      Publish-Module -Path .\SpotifyCommands -NuGetApiKey $apiKey -Verbose
      
      # For updates, increment version in .psd1 first, then:
      Publish-Module -Path .\SpotifyCommands -NuGetApiKey $apiKey -Verbose
      ```

      ### 4. Verify Publication

      ```powershell
      # Search for your module
      Find-Module SpotifyCommands
      
      # Install from Gallery to test
      Install-Module SpotifyCommands -Scope CurrentUser
      ```

      ## Version Updates

      When releasing a new version:
      1. Update `ModuleVersion` in `SpotifyCommands.psd1`
      2. Update `ReleaseNotes` in manifest
      3. Run `Test-ModuleManifest` to validate
      4. Publish with `Publish-Module`

      Users can then update with:

      ```powershell
      Update-Module SpotifyCommands
      ```

      ## Troubleshooting

      - **Error: Module already exists**: Increment version number
      - **Error: Missing metadata**: Ensure all required fields in .psd1 are filled
      - **Error: Invalid manifest**: Run Test-ModuleManifest for details

      ```
    
    - Inkludera en sektion om versionshantering och hur man uppdaterar modulen
    - Dokumentera hur användare kan installera modulen efter publicering: `Install-Module SpotifyCommands -Scope CurrentUser`

12. **Hantera edge cases**:
    - Om modulimport misslyckas från `Documents\PowerShell`, försök importera direkt från projektmappen med absolut sökväg
    - Om alias-konflikter kvarstår efter `-Force`, använd `-Option AllScope, ReadOnly` för att låsa alias
    - Om `.env`-filen saknas, kopiera `.env.example` till `.env` och varna användaren att fylla i credentials
    - Om Windows Forms inte kan laddas, ge instruktioner för att installera nödvändiga .NET-komponenter eller uppdatera PowerShell
    - Om README.md inte kan läsas eller parsas, använd fallback-lista med de 20 mest kritiska funktionerna och varna användaren
    - Om PowerShell-profilen (`$PROFILE`) inte finns, skapa den automatiskt
    - Om LICENSE.txt saknas, generera en MIT-licens automatiskt och varna användaren
    - Om GUID saknas i manifestet, generera en ny med `[guid]::NewGuid()` och dokumentera den

13. **Ge detaljerad feedback**:
    - Skriv ut varje steg som utförs med tydliga statusmeddelanden (använd `Write-Host` med färgkodning)
    - Logga alla operationer och fel till `Documents\PowerShell\SpotifyCLI-Installation.log` med timestamps
    - Vid slutet, ge en sammanfattning av vad som installerades och eventuella kvarvarande problem
    - **Visa en jämförelsetabell mellan förväntade funktioner (från README.md) och faktiskt installerade:**

      ```
      ╔════════════════════════════════════════════════════════════╗
      ║  INSTALLATION VERIFICATION REPORT                          ║
      ╠════════════════════════════════════════════════════════════╣
      ║  Total Functions in README.md: 98                          ║
      ║  Successfully Installed: 95                                ║
      ║  Missing/Failed: 3                                         ║
      ║  Success Rate: 96.9%                                       ║
      ╠════════════════════════════════════════════════════════════╣
      ║  ✓ ss (ShowSpotify) - OK                                   ║
      ║  ✓ slw (ShowLyrics) - OK                                   ║
      ║  ✓ play - OK                                               ║
      ║  ✗ music - MISSING (alias not found)                       ║
      ║  ✗ Invoke-SpotifyApi - MISSING (function not exported)    ║
      ╠════════════════════════════════════════════════════════════╣
      ║  POWERSHELL GALLERY STATUS                                 ║
      ║  ✓ Module Manifest Created                                 ║
      ║  ✓ Ready for Publication                                   ║
      ║  Next: Follow PUBLISHING-GUIDE.md                          ║
      ╚════════════════════════════════════════════════════════════╝
      ```

    - Inkludera nästa steg för användaren (t.ex. "Kör `spotify` för att autentisera", "Fyll i .env-filen med dina credentials", "Följ PUBLISHING-GUIDE.md för att publicera på Gallery")

14. **Skapa verifieringsfunktion**:
    - Implementera en `Test-SpotifyCliInstallation` funktion som användaren kan köra när som helst
    - **Funktionen ska läsa README.md och testa alla dokumenterade komponenter:**
      - Parsa README.md på samma sätt som installationsskriptet med samma regex-mönster
      - Testa varje funktion och alias från README.md-listan
      - Kör `Get-Command` för varje och fånga eventuella fel
    - Rapportera status för varje funktion och alias med färgkodad output (grön = OK, röd = saknas, gul = varning)
    - Om problem hittas, ge specifika instruktioner för att åtgärda dem (t.ex. "Kör `Import-Module SpotifyCommands -Force`")
    - Generera en detaljerad rapport som kan sparas till fil eller kopieras för felsökning
    - Inkludera en `-Verbose` parameter för extra diagnostikinformation
    - Lägg till en `-CheckGalleryReadiness` parameter för att validera Gallery-beredskap

15. **Dokumentera installationsprocessen**:
    - Generera en installationslogg med timestamp i `Documents\PowerShell\SpotifyCLI-Installation-[timestamp].log`
    - Skapa en `INSTALLATION-STATUS.md` fil med installationsstatus och eventuella varningar
    - **Inkludera en sektion som visar alla funktioner från README.md och deras status:**

      ```markdown
      # Spotify CLI Installation Status
      
      ## Installation Summary
      - Date: 2026-01-17 14:30:00
      - PowerShell Version: 7.5.3
      - Installation Path: C:\Users\[user]\Documents\PowerShell\Modules\SpotifyCommands
      - Total Functions Expected (from README.md): 98
      - Successfully Installed: 95
      - Missing/Failed: 3
      
      ## README.md Parsing Results
      - Sections Parsed: 11
      - Functions Extracted: 98
      - Aliases Extracted: 156
      - Parsing Success: 100%
      
      ## Function Verification (from README.md)
      
      ### ✅ Working Functions (95)
      - ✓ Show-SpotifyForm (alias: ss, ShowSpotify) - from "🎨 UI Features"
      - ✓ Show-SpotifyLyricsForm (alias: slw, ShowLyrics) - from "🎨 UI Features"
      - ✓ play - from "🎵 Core Playback Functions"
      - ✓ pause - from "🎵 Core Playback Functions"
      ...
      
      ### ❌ Missing Functions (3)
      - ✗ music (alias not created - conflict with existing alias) - expected from "🎵 Core Playback Functions"
      - ✗ Invoke-SpotifyApi (function not exported from module) - expected from core functions
      - ✗ Get-SpotifyStatistics (function not found in module) - expected from "🌟 Live Features Commands"
      
      ## PowerShell Gallery Readiness
      - ✓ Module Manifest Created (SpotifyCommands.psd1)
      - ✓ LICENSE.txt Present (MIT)
      - ✓ All Metadata Valid
      - ✓ Ready for Publication
      
      ### Next Steps for Gallery Publication
      1. Review PUBLISHING-GUIDE.md
      2. Create PowerShell Gallery account
      3. Generate API key
      4. Run: `Publish-Module -Path .\SpotifyCommands -NuGetApiKey $apiKey`
      
      ### After Publication, Users Can Install With
      ```powershell
      Install-Module SpotifyCommands -Scope CurrentUser
      Update-Module SpotifyCommands  # For updates
      ```

      ## Troubleshooting Steps

      1. For missing aliases, run: `Set-Alias -Name music -Value Show-SpotifyTrack -Force`
      2. For missing functions, verify SpotifyCommands.psm1 exports them
      3. Run `Test-SpotifyCliInstallation -Verbose` for detailed diagnostics
      4. Check README.md parsing log for any extraction errors
      5. Run `Test-SpotifyCliInstallation -CheckGalleryReadiness` to verify Gallery compatibility

      ```
    - Inkludera troubleshooting-tips baserat på vanliga problem
    - Dokumentera vilken installationsplats som användes (`Documents\PowerShell`) och varför
    - Inkludera en sammanfattning av README.md-parsningen för att visa att alla sektioner lästes korrekt
    - **Lägg till en sektion om PowerShell Gallery-publicering och hur användare kan installera modulen efter publicering**

Skriptet ska vara idempotent (kan köras flera gånger utan bieffekter) och ska hantera både nya installationer och uppgraderingar från tidigare versioner. Det ska fungera i PowerShell 7+ och ska vara kompatibelt med Windows Terminal och VS Code.

Skriptet ska prioritera installationsplatsen `Documents\PowerShell` för PowerShell 7+, vilket ger optimal integration med användarens PowerShell-profil och modulhantering. **Dessutom ska skriptet förbereda modulen för PowerShell Gallery-publicering genom att skapa en korrekt strukturerad modulmanifest, validera alla Gallery-krav, och generera en publiceringsguide.**

Skriv skriptet som en `.ps1`-fil med tydlig struktur, kommentarer och felhantering. Använd `try-catch`-block för alla kritiska operationer och ge användarvänliga felmeddelanden. **Inkludera en dedikerad funktion `Parse-ReadmeForFunctions` som läser README.md och returnerar en strukturerad lista över alla funktioner och alias som ska verifieras. Inkludera också en funktion `New-GalleryManifest` som genererar en PowerShell Gallery-kompatibel `.psd1` fil baserat på README.md-parsningen och projektinformation.**
