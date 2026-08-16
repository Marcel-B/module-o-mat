# ModuleOMat

Eine Elixir/Phoenix-Anwendung zur Erfassung von Eurorack-Modulen (Hersteller,
Name, HP-Breite, Typ, Strombedarf, u.v.m.).

Page [https://marcel-b.github.io/module-o-mat/](https://marcel-b.github.io/module-o-mat/)
## Architektur

- `ModuleOMat.Inventory.EurorackModule` – Ecto-Schema, definiert das
  Domain-Modell und das Mapping auf die Tabelle `eurorack_modules`.
- `ModuleOMat.Inventory` – Context-Modul mit der öffentlichen API zum Lesen
  und Schreiben von Modulen (`list_eurorack_modules/0`,
  `create_eurorack_module/1`, ...).
- `ModuleOMat.Repo` – Ecto-Repo mit SQLite3-Adapter (`ecto_sqlite3`) zur
  Persistierung.
- `ModuleOMatWeb.EurorackModuleLive.Index` – Phoenix-LiveView, zeigt die
  erfassten Module gruppiert nach Typ (sortiert nach Hersteller) an und
  erlaubt das Anlegen neuer Module über einen Dialog mit Validierung.

## Setup

```bash
mix setup
```

Legt die Dependencies an, richtet die SQLite-Datenbank ein (erstellen +
migrieren) und installiert/baut die Assets (Tailwind/esbuild).

## Anwendung starten

```bash
mix phx.server
```

Die Oberfläche ist danach unter [http://localhost:4000](http://localhost:4000)
erreichbar. Die Landing-Page lässt zwischen drei UIs wählen:

- [LiveView](http://localhost:4000/live)
- [Vue UI](http://localhost:4000/ui) (nach `mix assets.build_vue` bzw. im Docker-Image)
- [Vue UI-Alt](http://localhost:4000/ui-alt)

## Vue-UIs

Zwei Vue-3-Oberflächen liegen neben der LiveView. Beide sprechen `/api/v1`
an; Vite proxied in der Entwicklung nach `http://localhost:4000`.

- [`ui/`](ui/README.md) — fertige PrimeVue-Variante (Tailwind CSS, VeeValidate + Yup, Pinia).
  Start: `cd ui && npm install && npm run dev` →
  [http://localhost:5173](http://localhost:5173)
- [`ui-alt/`](ui-alt/README.md) — Platzhalter für eine zweite Implementierung.
  Start: `cd ui-alt && npm install && npm run dev` →
  [http://localhost:5174](http://localhost:5174)

Für die Auslieferung durch Phoenix (Landing-Page-Links `/ui` und `/ui-alt`):

```bash
mix assets.build_vue
```

Im Docker-Image werden beide Vue-Apps automatisch mitgebaut. Phoenix (`mix phx.server`)
muss für die Vite-Entwicklung parallel laufen.

## HTTP-API

Die JSON-REST-API liegt unter `/api/v1`. Interaktive Dokumentation
(Swagger UI) unter
[http://localhost:4000/api/docs](http://localhost:4000/api/docs),
OpenAPI-Spec unter
[http://localhost:4000/api/openapi](http://localhost:4000/api/openapi).

Keine Authentifizierung (LAN-Homelab). LiveView bleibt parallel bestehen.

### `/api/v1` (Vue / HTTP-Clients)

- `GET /api/v1/modules` — Liste, Query: `q`, `types`, `min_hp`, `max_hp`;
  Response inkl. `stats`
- `GET /api/v1/modules/:id` — Detail inkl. YouTube und Preisbeobachtungen
- `POST /api/v1/modules` — anlegen (`{"module": {...}}`)
- `PATCH /api/v1/modules/:id` — aktualisieren
- `DELETE /api/v1/modules/:id` — Soft-Delete
- `POST /api/v1/modules/:id/duplicate` — Kopie (`copy_manual`, optional `module`)
- `POST /api/v1/modules/:id/valuations` — Preisbeobachtungen speichern
- `GET|PUT|DELETE /api/v1/modules/:id/manual` — PDF lesen / hochladen / entfernen
- `GET|POST /api/v1/module-types`, `PATCH|DELETE /api/v1/module-types/:id`
- `GET /api/v1/manufacturers` — Autocomplete
- `GET /api/v1/backup/export` — ZIP-Download
- `POST /api/v1/backup/import` — ZIP-Upload, ersetzt den Bestand
- `GET /api/v1/maintenance` — `{"maintenance": true}` während eines Backups

### `/api/modules` (Bewertungs-Agent)

Unverändert schmales Payload, siehe
[`priv/agent_prompts/module_valuation.md`](priv/agent_prompts/module_valuation.md):

- `GET /api/modules`
- `GET /api/modules/:id`
- `POST /api/modules/:id/valuations`

## Tests

```bash
mix test
```

Die Vue-UI hat eigene Tests:

```bash
cd ui && npm test
```

## Deploy mit Docker / Podman

Die Produktions-App läuft als Container mit **SQLite** und persistentem Volume
unter `/data` (Datenbank + PDF-Anleitungen).

Nach erfolgreichen Tests auf `main` baut CI das Image und pusht es nach
**GHCR**: `ghcr.io/marcel-b/module-o-mat:latest` (zusätzlich Tag mit Commit-SHA).

1. Secrets vorbereiten:

```bash
cp .env.example .env
mix phx.gen.secret
# Wert als SECRET_KEY_BASE in .env eintragen
# PHX_HOST auf den Browser-Hostnamen setzen (ohne Schema)
# LAN direkt: IP; hinter Proxy: module.lan
# PHX_SCHEME=http und PORT=4012 (o.ä.)
# Hinter Proxy zusätzlich PHX_PORT=80
# Optional PHX_CHECK_ORIGIN für Hostname + IP gleichzeitig
```

2. Image holen und starten (ohne lokalen Build):

```bash
docker compose pull
docker compose up -d

# optional lokal aus dem Dockerfile bauen:
# docker compose up -d --build
```

Beim Start werden Migrationen automatisch ausgeführt. Die App lauscht im
Container auf Port `4000` (über `PORT` in `.env` am Host mappbar).

3. Persistenz: Das Compose-Volume `module_o_mat_data` hält
   `/data/module_o_mat.db` und `/data/uploads/manuals`. Ohne Volume gehen
   Daten bei Container-Neustarts verloren.

4. Reverse-Proxy (optional): TLS und `X-Forwarded-Proto` am Proxy terminieren,
   dann in `.env` setzen:

```bash
PHX_HOST=module.lan
PHX_SCHEME=https
PHX_PORT=443
PHX_FORCE_SSL=true
PHX_CHECK_ORIGIN=https://module.lan
```

   Danach `docker compose up -d` (kein Image-Rebuild nötig — `PHX_FORCE_SSL` ist
   Runtime-Config). Für reinen LAN-Zugriff über `http://IP:PORT` ist kein Proxy
   nötig und `PHX_FORCE_SSL` bleibt aus.

## Deploy auf Proxmox (LAN, eigener CT)

Nicht im Immich-CT mitinstallieren — eigener LXC hält Updates, Backups und
Ressourcen getrennt. **Kein Git-Repo nötig**, nur Docker + Compose-Datei.

### Alten lokalen Build entfernen

Falls du vorher per Git + `docker compose build` deployt hast:

```bash
curl -fsSL -o /tmp/cleanup-local-deploy.sh \
  https://raw.githubusercontent.com/Marcel-B/module-o-mat/main/module_o_mat/scripts/cleanup-local-deploy.sh
bash /tmp/cleanup-local-deploy.sh
```

Löscht Compose-Stack, lokale Images, Volumes und typische Quellordner
(` /opt/module-o-mat` usw.). Bestätigung mit `y`; ohne Nachfrage: `--yes`.

1. In Proxmox **Erstelle CT**: Debian 12, unprivileged, 1–2 vCPU, ~1–2 GB RAM,
   ~8–16 GB Disk (`local-lvm`), DHCP oder feste LAN-IP. Unter Options → Features
   **Nesting** aktivieren (für Docker), CT neu starten.
2. Im CT Docker installieren, dann Compose + Env holen:

```bash
apt update && apt install -y ca-certificates curl
curl -fsSL https://get.docker.com | sh
mkdir -p /opt/module-o-mat && cd /opt/module-o-mat
curl -fsSL -o docker-compose.yml \
  https://raw.githubusercontent.com/Marcel-B/module-o-mat/main/module_o_mat/docker-compose.yml
curl -fsSL -o .env.example \
  https://raw.githubusercontent.com/Marcel-B/module-o-mat/main/module_o_mat/.env.example
cp .env.example .env
```

3. `.env` anpassen (`hostname -I` für die CT-IP):

```bash
# SECRET_KEY_BASE aus `mix phx.gen.secret` (lokal erzeugen und eintragen)
# Direkter LAN-Zugriff:
#   PHX_HOST=<CT-LAN-IP>
#   PHX_SCHEME=http
#   PORT=4012
# Hinter Nginx Proxy Manager (http://module.lan):
#   PHX_HOST=module.lan
#   PHX_SCHEME=http
#   PORT=4012
#   PHX_PORT=80
#   PHX_CHECK_ORIGIN=http://module.lan,http://<CT-LAN-IP>:4012
#
# Hinter NPM mit HTTPS (https://module.lan):
#   PHX_HOST=module.lan
#   PHX_SCHEME=https
#   PORT=4012
#   PHX_PORT=443
#   PHX_FORCE_SSL=true
#   PHX_CHECK_ORIGIN=https://module.lan
```

`PHX_HOST` muss dem Hostnamen in der Browser-URL entsprechen. Sonst lehnt
Phoenix LiveView-WebSockets mit `403` ab und fällt in eine Longpoll-
Reconnect-Schleife.

#### HTTPS in Nginx Proxy Manager (LAN / `module.lan`)

`module.lan` ist typischerweise **nicht** öffentlich — Let’s Encrypt per HTTP-Challenge
funktioniert dann nicht. In NPM:

1. **SSL Certificates** → **Add SSL Certificate** → **Custom** (oder „Self Signed“):
   Domain `module.lan`, Zertifikat erzeugen/hochladen.
2. **Hosts** → Proxy Host für `module.lan`:
   - Scheme/Forward: `http://<CT-LAN-IP>:4012` (App bleibt HTTP intern)
   - **Websockets Support**: an
   - **Block Common Exploits**: optional an
   - Tab **SSL**: Zertifikat wählen, **Force SSL** an, **HTTP/2** an
3. App-`.env` wie oben auf `PHX_SCHEME=https` / `PHX_PORT=443` / `PHX_FORCE_SSL=true`
   umstellen und Stack neu starten: `docker compose up -d`
4. Browser: `https://module.lan` öffnen. Bei selbstsigniertem Zertifikat einmalig
   die Warnung bestätigen (oder das NPM-Root-CA im System/Browser importieren).

Firefox mit HTTPS-Only-Mode braucht `https://` — genau dieses Setup.

4. Image pullen und starten:

```bash
docker compose pull
docker compose up -d
```

Falls das GHCR-Paket privat ist: einmal `docker login ghcr.io` mit einem
GitHub-Token (`read:packages`), danach Package unter GitHub → Packages auf
**Public** stellen (empfohlen für LAN-Homelab).

5. Im LAN-Browser öffnen: `http://<CT-LAN-IP>:4012` bzw. `http://module.lan`
   (mit TLS: `https://module.lan`)

Update später: `docker compose pull && docker compose up -d`

Falls eine Firewall auf Node oder CT aktiv ist, Port `4012` freigeben. Immich
bleibt unberührt. HTTPS: TLS am Reverse-Proxy terminieren und `.env` wie oben
auf `PHX_SCHEME=https` / `PHX_FORCE_SSL=true` stellen — kein Image-Rebuild nötig.

### Nextcloud-Backup (optional)

Die App kann täglich ein Inventar-ZIP per WebDAV nach Nextcloud (z.B. Hetzner)
hochladen. Es liegen immer sieben Dateien (`inventory-mon.zip` …
`inventory-sun.zip`); der aktuelle Wochentag wird überschrieben.

1. In Nextcloud unter Einstellungen → Sicherheit ein **App-Passwort** erzeugen.
2. Zielordner anlegen, z.B. `Backups/module-o-mat`.
3. In `.env` setzen:

```bash
NEXTCLOUD_BACKUP_ENABLED=true
NEXTCLOUD_WEBDAV_URL=https://nxNNNN.your-storageshare.de/remote.php/dav/files/USER/Backups/module-o-mat
NEXTCLOUD_USERNAME=USER
NEXTCLOUD_APP_PASSWORD=xxxx-xxxx-xxxx-xxxx
NEXTCLOUD_BACKUP_AT=03:00
NEXTCLOUD_BACKUP_TIMEZONE=Europe/Berlin
NEXTCLOUD_BACKUP_IDLE_MINUTES=10
NEXTCLOUD_BACKUP_HTTP_TIMEOUT_SECONDS=300
```

4. Stack neu starten: `docker compose up -d`

Nach einer Inventar-Änderung wartet die App 10 Minuten (konfigurierbar) und
lädt dann dieselbe Wochentags-Datei erneut hoch. Solange das Backup läuft,
ist die Oberfläche im Wartungsmodus – Schreibzugriffe sind gesperrt.
Der WebDAV-Upload hat 5 Minuten HTTP-Timeout (Req-Default wären 15 Sekunden)
und wiederholt kurze Netzfehler; bei sehr großen ZIP-Dateien
`NEXTCLOUD_BACKUP_HTTP_TIMEOUT_SECONDS` erhöhen.

Nach einem Neustart (Deploy, Reboot) holt der Scheduler einen versäumten
heutigen Lauf nach, sobald die Sollzeit vorbei ist. Sofortiger Upload:

```bash
docker compose exec web bin/module_o_mat eval 'ModuleOMat.Inventory.RemoteBackup.run()'
# oder lokal:
mix inventory.remote_backup
```

Wiederherstellen: ZIP aus Nextcloud laden und über die UI unter `/backup` oder
mit `mix inventory.import path/to/inventory-mon.zip` importieren (ersetzt alle
Inventardaten).

## Dokumentation

Dokumentation kann lokal mit [ExDoc](https://github.com/elixir-lang/ex_doc)
generiert werden:

```bash
mix docs
```

Das Ergebnis liegt anschließend als HTML-Seite unter `doc/index.html`.

Alternativ direkt in einer interaktiven Shell:

```bash
iex -S mix
```

```elixir
h ModuleOMat.Inventory
h ModuleOMat.Inventory.create_eurorack_module/1
```
