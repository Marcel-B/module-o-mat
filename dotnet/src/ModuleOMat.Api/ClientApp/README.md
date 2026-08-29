# ModuleOMat UI (PrimeVue + Tailwind)

Vue-3-Oberfläche mit TypeScript, PrimeVue, Tailwind CSS, VeeValidate + Yup und Pinia.
Sie spricht die JSON-API unter `/api/v1` an.

Liegt als `ClientApp` der .NET-API. `dotnet run` startet Vite über
`Microsoft.AspNetCore.SpaServices.Extensions` (`npm run dev`) und stellt
die App unter [http://localhost:5012/ui](http://localhost:5012/ui) bereit.

```bash
cd dotnet
dotnet run --project src/ModuleOMat.Api
```

Vite allein (API muss parallel laufen):

```bash
cd src/ModuleOMat.Api/ClientApp
npm install
npm run dev
```

Phoenix kann denselben Stand nach `mix assets.build_vue` unter `/ui` ausliefern.

## Tests

```bash
npm test
```
