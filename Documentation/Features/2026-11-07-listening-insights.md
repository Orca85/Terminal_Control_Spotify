# Lyssningsinsikter: utökad `peak`, `today` och `artist`

**Version:** v3.2.17 (2026-11-07)
**Berörda filer:** `modules/UI/PeakDashboard.psm1`, `modules/UI/SpotifyInsights.psm1` (ny),
`SpotifyCLI.psd1`, `SpotifyCLI.psm1` (`spcommands`), `modules/Core/AliasManagement.psm1`,
`modules/Core/InstallationCommands.psm1`, `Install-SpotifyCLI-Complete.ps1`,
`Clear-SpotifyCliInstallation.ps1`, `README.md`

## Bakgrund

Efter att `peak` flyttats till terminalen (v3.2.15) ville användaren ha mer rolig lyssningsinfo.
Allt bygger på endpoints som appen har åtkomst till. Följande är stängda för appen och används inte:
`/audio-features` (403), `/artists/{id}/related-artists` (404) och `/recommendations` (404).

## Kommandon

| Kommando | Alias | Gör |
|---|---|---|
| `Show-SpotifyPeak [-Watch]` | `peak` | Låtinsikter, nu med rader om dig och låten (se nedan) |
| `Show-SpotifyToday` | `today` | Dagens lyssning |
| `Show-SpotifyArtist [name] [-Play n]` | `artist` | Artistkort för pågående eller sökt artist; `-Play n` spelar topplåt #n |

## `peak` – nya rader

| Rad | Källa | Innehåll |
|---|---|---|
| Your top | `/me/top/tracks`, `/me/top/artists` (`short_term`, 50 st) | Låtens och artistens plats i dina topplistor senaste ~4 veckorna |
| Artist rank | `/artists/{id}/top-tracks` | Låtens plats bland artistens 10 populäraste |
| Hidden gem | samma | 💎 om låten inte är i artistens topp 10 och har popularitet ≥ 25 under topp 10-snittet |
| Album info | `/albums/{id}` | Albumets popularitet och skivbolag |
| Liked | `/me/tracks/contains` | ♥ om låten finns i ditt bibliotek |

`Get-SpotifyPeakInfo -Cache <hashtable>` returnerar allt som objekt (nya fält: `ArtistName`,
`TopTrackRank`, `TopArtistRank`, `ArtistTopRank`, `ArtistTopAvg`, `IsHiddenGem`, `AlbumPop`, `Label`,
`Liked`). Cachen håller artistdata, topplistor (en gång per session), artistens topplåtar, album och
gillad-status per låt, så `peak -Watch` inte gör extra anrop varannan sekund. Parametern ersätter
tidigare `-ArtistData`. Poddavsnitt (inga artister) ger `$null` i stället för fel.

Fönstret (`showpeak`) är oförändrat; de nya raderna visas bara i terminalen.

## `today`

Bygger på `/me/player/recently-played` (Spotify returnerar max 50 spelningar). Visar lyssnad tid,
antal låtar och artister, toppartist, mest spelade låt, första spelningen och en stapel per timme
(24 tecken, `·` för timmar utan lyssning). `played_at` konverteras till lokal tid oavsett om den
kommer som UTC-`DateTime` eller ISO-sträng. Om alla 50 är från idag visas `50+` och en notis om att
tidigare spelningar saknas.

## `artist`

Hittar artisten via pågående låt eller `/search?type=artist`. Visar popularitet (stapel), följare,
genrer, topp 5 låtar med popularitet, senaste släpp och antal album/singlar
(`/artists/{id}/albums`, `album,single`, max 50). `-Play n` spelar topplåt #n med
`context_uri` = albumet och `offset` = låten – en lös `uris`-begäran ignoreras tyst av Spotify
(se v3.2.16).

## Verifiering

- Live: `peak` (Malibu Nights – LANY) visade "LANY is your #11 artist", "#5 of LANY's 10 most
  popular", albumets popularitet/skivbolag och ♥. `today`, `artist` och `artist "Gracie Abrams"` gav
  korrekta kort. Användaren har testat via `spdev`.
- Testdata: hidden gem-raden, "not saved" och "not in top 50" renderas rätt; poddavsnitt ger `$null`.
- Inga parserfel; aliaslistan matchar sessionen (27 alias); `spcommands` listar de nya kommandona.

## Begränsningar

- Genrer är oftast `n/a` – Spotify skickar dem inte längre till appen.
- `today` ser bara de 50 senaste spelningarna.
