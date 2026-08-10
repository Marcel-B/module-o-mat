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
# PHX_HOST auf den öffentlichen Hostnamen setzen (ohne https://)
```

2. Bauen und starten:

```bash
# Docker
docker compose up -d --build

# oder Podman
podman compose up -d --build
# alternativ: podman build -t module_o_mat . && podman run ...
```

Beim Start werden Migrationen automatisch ausgeführt. Die App lauscht auf Port
`4000` (über `PORT` in `.env` am Host mappbar).

3. Persistenz: Das Compose-Volume `module_o_mat_data` hält
   `/data/module_o_mat.db` und `/data/uploads/manuals`. Ohne Volume gehen
   Daten bei Container-Neustarts verloren.

4. Reverse-Proxy: TLS und `X-Forwarded-Proto` am Proxy terminieren. Die App
   erzwingt HTTPS über `force_ssl` mit `rewrite_on: [:x_forwarded_proto]` und
   erwartet `PHX_HOST` als öffentlichen Hostnamen.

Nur Image bauen:

```bash
docker build -t module_o_mat .
# oder: podman build -t module_o_mat .
```

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
