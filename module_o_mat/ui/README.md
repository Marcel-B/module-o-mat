# ModuleOMat UI (PrimeVue + Tailwind)

Vue-3-Oberfläche mit TypeScript, PrimeVue 4.5 (MIT, ohne Lizenzschlüssel), Tailwind CSS v4, VeeValidate + Yup und Pinia. Sie spricht die JSON-API unter `/api/v1` an und bildet die Phoenix-LiveView ab.

## Start

Phoenix muss parallel laufen (`mix phx.server`, Port 4000).

```bash
cd ui
npm install
npm run dev
```

Die App liegt unter [http://localhost:5173](http://localhost:5173). Vite proxied `/api` nach `http://localhost:4000`.
Über die Phoenix-Landing-Page ist der Produktions-Build unter
[http://localhost:4000/ui](http://localhost:4000/ui) erreichbar (`mix assets.build_vue`).

## Tests

```bash
npm test
```

## Funktionen

- Inventar gruppiert nach Typ, sortiert nach Hersteller
- Suche, Typ- und HP-Filter, Statistik
- Anlegen, Anzeigen, Bearbeiten, Duplizieren, Soft-Delete
- PDF-Anleitungen und YouTube-Links (Hover-Vorschau)
- Preisverlauf aus `price_observations`
- Typen verwalten
- ZIP-Backup exportieren und importieren
- Hell-/Dunkel-/System-Theme
