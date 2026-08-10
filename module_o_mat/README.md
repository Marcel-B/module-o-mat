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

## Deploy mit Docker / Podman (Einzel-VPS)

Die Produktions-App läuft als Container mit **SQLite** und persistentem Volume
unter `/data` (Datenbank + PDF-Anleitungen).

1. Secrets vorbereiten:

```bash
cp .env.example .env
mix phx.gen.secret
# Wert als SECRET_KEY_BASE in .env eintragen
# PHX_HOST auf Hostnamen oder LAN-IP setzen (ohne Schema)
# LAN: PHX_SCHEME=http und PORT=4012 (o.ä.)
# Hinter Proxy: PHX_SCHEME=https und PHX_HOST=dein.hostname
```

2. Bauen und starten:

```bash
# Docker
docker compose up -d --build

# oder Podman
podman compose up -d --build
# alternativ: podman build -t module_o_mat . && podman run ...
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

Nur Image bauen:

```bash
docker build -t module_o_mat .
# oder: podman build -t module_o_mat .
```

## Deploy auf Proxmox (LAN, eigener CT)

Nicht im Immich-CT mitinstallieren — eigener LXC hält Updates, Backups und
Ressourcen getrennt.

1. In Proxmox **Erstelle CT**: Debian 12, unprivileged, 1–2 vCPU, ~1–2 GB RAM,
   ~8–16 GB Disk (`local-lvm`), DHCP oder feste LAN-IP.
2. Im CT Docker installieren, dieses Repo klonen (oder den Quellbaum
   kopieren).
3. `.env` anlegen, z. B.:

```bash
cp .env.example .env
# SECRET_KEY_BASE aus `mix phx.gen.secret` (lokal erzeugen und eintragen)
# PHX_HOST=<CT-LAN-IP>
# PHX_SCHEME=http
# PORT=4012
```

4. Starten:

```bash
docker compose up -d --build
```

5. Im LAN-Browser öffnen: `http://<CT-LAN-IP>:4012`

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
