# ModuleOMat .NET Backend

ASP.NET-Core-Port des Inventars. Das Elixir-Backend unter `module_o_mat/` bleibt unverändert.

## Start

```bash
export PATH="$HOME/.dotnet:$PATH"
cd dotnet
dotnet run --project src/ModuleOMat.Api
```

Die API lauscht auf http://localhost:5012. Im Development startet
`Microsoft.AspNetCore.SpaServices.Extensions` Vite in `ClientApp`
(`npm run dev`) und proxied `/ui`. Die Oberfläche liegt unter
http://localhost:5012/ui. `ui-alt` bleibt unter `module_o_mat/ui-alt`.

Daten aus Elixir: ZIP unter `/api/v1/backup/export` exportieren und unter `/api/v1/backup/import` (oder `dotnet run --project src/ModuleOMat.Cli -- import datei.zip`) einspielen.

## Tests

```bash
dotnet test
```

## Docker

Lokal:

```bash
docker compose -f dotnet/docker-compose.yml up --build
```

Nach einem Push auf `main` veröffentlicht CI das Image nach GHCR als `ghcr.io/<owner>/module-o-mat-dotnet` (Tags `latest` und Commit-SHA). Das Elixir-Image bleibt `ghcr.io/<owner>/module-o-mat`.
