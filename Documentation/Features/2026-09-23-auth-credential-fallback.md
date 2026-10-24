# Auth: Självläkande credentials och fast lagringsplats

**Versioner:** v3.2.10 (2026-09-23), v3.2.11 (2026-10-24)
**Berörda filer:** `modules/Core/AuthenticationManager.psm1`, `SpotifyCLI.psd1`, `README.md`

## Bakgrund

Alias som `play` och `next` körs ofta direkt i en vanlig PowerShell-prompt, utan att gå via
`Start-SpotifyCLI`/`CliLoop.psm1`. Den vägen anropade aldrig `Initialize-SpotifyCredentials`,
så `$script:ClientId`/`$script:ClientSecret` i `AuthenticationManager.psm1` förblev tomma.

- **v3.2.10-problemet:** Den sparade access-token fungerade tills den behövde förnyas
  (~varje timme). Då skickades refresh-anropet med tomma credentials och användaren fick
  `"Token refresh failed. Re-authenticating..."` → `"Credentials not set"`.
- **v3.2.11-problemet (regression av v3.2.10-fixen):** Efter fixen hämtades credentials i
  varje ny session, men `.env` söktes bara i aktuell katalog. Från t.ex. `~`, utan
  miljövariabler, frågade CLI:t därför efter `SPOTIFY_CLIENT_ID`/`SECRET` varje gång.

## Implementation

### Självläkning i `Get-SpotifyAccessToken` (v3.2.10)
`Get-SpotifyAccessToken` är den gemensamma inkörsporten för både `LegacyApiClient.psm1`
och `CliLoop.psm1`. Om `$script:ClientId`/`$script:ClientSecret` saknas anropar den
`Initialize-SpotifyCredentials` innan tokens läses eller förnyas.

### Fast lagringsplats för credentials (v3.2.11)
`Initialize-SpotifyCredentials` löser credentials i denna ordning:

1. Parametrar (`-ClientId`, `-ClientSecret`)
2. `.env` i aktuell katalog
3. `%APPDATA%\SpotifyCLI\.env` (`$script:CredentialsFile`, bredvid `tokens.json`)
4. Miljövariablerna `SPOTIFY_CLIENT_ID` / `SPOTIFY_CLIENT_SECRET`
5. Interaktiv `Read-Host`-prompt

Credentials som kommer från `.env` i aktuell katalog eller från prompten skrivs till
`%APPDATA%\SpotifyCLI\.env` (bara om värdena skiljer sig). Därmed fungerar alias från vilken
katalog som helst efter första körningen, och en roterad secret i projektets `.env`
uppdaterar den sparade kopian nästa gång man kör därifrån.

Filformat (samma som `.env`):

```
SPOTIFY_CLIENT_ID=<id>
SPOTIFY_CLIENT_SECRET=<secret>
```

Den privata hjälpfunktionen `Read-CredentialsFile` parsar `KEY=VALUE`-filer till en hashtable.

### Avvägningar
- `.env`-filer går före miljövariabler med avsikt: en ärvd miljövariabel på User/Machine-nivå
  kan vara inaktuell sedan den första installationen, medan `.env` är det dokumenterade
  sättet att byta credentials.
- Den sparade filen går också före miljövariabler. Den som byter secret enbart via
  miljövariabel måste därför även uppdatera eller ta bort `%APPDATA%\SpotifyCLI\.env`.
- Credentials lagras i klartext, precis som `tokens.json` och projektets `.env`.

## Verifiering

- **v3.2.10:** I en ny session gav `Import-Module SpotifyCLI` följt direkt av
  `Get-SpotifyAccessToken` satta credentials, vilket bekräftar att självläkningen körs.
- **v3.2.11, isolerad `APPDATA`:**
  1. Körning från repot skapar den sparade filen med samma värden som repo-`.env`.
  2. En ny `-NonInteractive`-session från en annan katalog, utan miljövariabler, får
     credentials utan prompt.
  3. Kontroll: utan sparad fil försöker den fortfarande fråga.
- **v3.2.11, skarpt:** Med installerad 3.2.11 gav `Get-SpotifyAccessToken` från `$HOME` i en
  `-NonInteractive`-session en giltig token utan prompt.

## Sammanfattning

Credentials laddas nu automatiskt oavsett hur eller varifrån ett kommando körs. Användaren
anger dem en gång (eller kör en gång från projektmappen), sedan läses de från
`%APPDATA%\SpotifyCLI\.env`. Token-förnyelsen kraschar inte längre och CLI:t frågar
inte längre efter credentials i varje ny session.
