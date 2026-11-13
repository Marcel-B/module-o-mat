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
