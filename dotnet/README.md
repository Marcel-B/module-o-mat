# ModuleOMat .NET Backend

ASP.NET-Core-Backend des Eurorack-Inventars.

## Start

```bash
export PATH="$HOME/.dotnet:$PATH"
cd dotnet
dotnet run --project src/ModuleOMat.Api
```

Die API lauscht auf http://localhost:5012. Im Development startet
`Microsoft.AspNetCore.SpaServices.Extensions` Vite in `ClientApp`
(`npm run dev`) und proxied `/ui`. Die Oberfläche liegt unter
http://localhost:5012/ui.

Datenübernahme aus einer anderen Instanz: ZIP unter `/api/v1/backup/export` exportieren und unter `/api/v1/backup/import` (oder `dotnet run --project src/ModuleOMat.Cli -- import datei.zip`) einspielen.

## Tests

```bash
dotnet test
```

## Docker

Lokal:

```bash
docker compose -f dotnet/docker-compose.yml up --build
```

Nach einem Push auf `main` veröffentlicht CI das Image nach GHCR als `ghcr.io/<owner>/module-o-mat-dotnet` (Tags `latest` und Commit-SHA).

### Autodeployment auf dem Host

Auf dem Host läuft `docker-compose.host.yml`. Es startet die App aus dem GHCR-Image und einen Watchtower, der alle 5 Minuten nach einem neuen `latest` schaut und dann nur diesen Container neu startet (Label `com.centurylinklabs.watchtower.enable`). Ein Push auf `main` ist so spätestens nach CI-Laufzeit plus 5 Minuten live.

```bash
cd module-o-mat/dotnet
cp .env.example .env   # falls noch nicht vorhanden
docker compose -f docker-compose.host.yml up -d
docker logs -f module-o-mat-watchtower
```

- Das Intervall lässt sich über `WATCHTOWER_INTERVAL` (Sekunden) in `.env` ändern.
- Ist das GHCR-Paket privat, einmal `docker login ghcr.io` mit einem PAT (`read:packages`) und die Zeile mit `config.json` im Watchtower-Service einkommentieren. Bei einem öffentlichen Paket ist nichts zu tun.
- Läuft der Container bisher anders, vorher den alten stoppen und prüfen, dass das Volume `module_o_mat_dotnet_data` (Compose-Projektname `dotnet`, also `dotnet_module_o_mat_dotnet_data`) die bestehenden Daten enthält, sonst das alte Volume per `external: true` einbinden.

