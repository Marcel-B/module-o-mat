# module-o-mat

Inventar für Eurorack-Module: Hersteller, HP, Typ, Strombedarf, Preise,
PDF-Anleitungen, YouTube-Videos, ZIP-Backup und tägliches Nextcloud-Backup.
Gedacht fürs Homelab im LAN, ohne Authentifizierung.

- Backend: ASP.NET Core 10 mit EF Core und SQLite, siehe [`dotnet/`](dotnet/README.md)
- Oberfläche: Vue 3 mit PrimeVue, siehe [`dotnet/src/ModuleOMat.Api/ClientApp`](dotnet/src/ModuleOMat.Api/ClientApp/README.md)

Nach einem Push auf `main` baut CI das Image `ghcr.io/marcel-b/module-o-mat-dotnet`.
