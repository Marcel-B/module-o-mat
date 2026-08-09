# ModuleOMat

Eine Elixir/Phoenix-Anwendung zur Erfassung von Eurorack-Modulen (Hersteller,
Name, HP-Breite, Typ, Strombedarf, u.v.m.).

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
