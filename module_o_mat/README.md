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
erreichbar.

## Tests

```bash
mix test
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
   dann `PHX_SCHEME=https` und `PHX_HOST` auf den öffentlichen Hostnamen setzen.
   Zusätzlich in `config/prod.exs` wieder `force_ssl` aktivieren und Image neu
   bauen. Für reinen LAN-Zugriff über `http://IP:PORT` ist kein Proxy nötig.

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
```

`PHX_HOST` muss dem Hostnamen in der Browser-URL entsprechen. Sonst lehnt
Phoenix LiveView-WebSockets mit `403` ab und fällt in eine Longpoll-
Reconnect-Schleife.

4. Image pullen und starten:

```bash
docker compose pull
docker compose up -d
```

Falls das GHCR-Paket privat ist: einmal `docker login ghcr.io` mit einem
GitHub-Token (`read:packages`), danach Package unter GitHub → Packages auf
**Public** stellen (empfohlen für LAN-Homelab).

5. Im LAN-Browser öffnen: `http://<CT-LAN-IP>:4012` bzw. `http://module.lan`

Update später: `docker compose pull && docker compose up -d`

Falls eine Firewall auf Node oder CT aktiv ist, Port `4012` freigeben. Immich
bleibt unberührt. Später Domain/HTTPS: Reverse-Proxy davor, dann
`PHX_SCHEME=https`, `force_ssl` in `prod.exs` wieder einschalten und neu bauen.

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
