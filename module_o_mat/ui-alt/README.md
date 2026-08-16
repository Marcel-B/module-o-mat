# ModuleOMat UI (eigene Version)

Zweite Vue-Oberfläche. Der Stack ist vorbereitet, die Screens baust du selbst.

## Stack

- Vue 3 + Vite + TypeScript
- PrimeVue 4.5 (MIT, ohne Lizenzschlüssel; Aura, Orange wie LiveView)
- VeeValidate + Yup
- Pinia
- Vue Router

## Start

Phoenix-API parallel laufen lassen (`mix phx.server` in `module_o_mat`, Port 4000).

```bash
cd ui-alt
npm install
npm run dev
```

Die App liegt dann unter [http://localhost:5174](http://localhost:5174).
`/api` wird nach `http://localhost:4000` geproxied (kein CORS).
Über die Phoenix-Landing-Page ist der Produktions-Build unter
[http://localhost:4000/ui-alt](http://localhost:4000/ui-alt) erreichbar.

## Was die UI können soll

Dieselbe Funktionalität wie die Elixir-LiveView bzw. die fertige Variante in `../ui`:

- Inventar-Tabelle, gruppiert nach Typ
- Filter: Suche, Typ, Min/Max HP, Statistik
- Modul CRUD, Anzeigen, Duplizieren, Soft-Delete
- PDF-Anleitung, YouTube-Links, Preisverlauf
- Typen verwalten
- ZIP-Backup export/import

API-Helfer: `src/api/inventory.ts`. OpenAPI: [http://localhost:4000/api/docs](http://localhost:4000/api/docs).
