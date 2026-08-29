FROM node:22-alpine AS vue
WORKDIR /src
COPY dotnet/src/ModuleOMat.Api/ClientApp/package.json dotnet/src/ModuleOMat.Api/ClientApp/package-lock.json ./ui/
RUN cd ui && npm ci
COPY dotnet/src/ModuleOMat.Api/ClientApp ./ui
RUN cd ui && npm run build

COPY module_o_mat/ui-alt/package.json module_o_mat/ui-alt/package-lock.json ./ui-alt/
RUN cd ui-alt && npm ci
COPY module_o_mat/ui-alt ./ui-alt
RUN cd ui-alt && npm run build

FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY dotnet/Directory.Build.props dotnet/global.json dotnet/ModuleOMat.slnx ./
COPY dotnet/src ./src
COPY dotnet/tests ./tests
RUN dotnet restore src/ModuleOMat.Api/ModuleOMat.Api.csproj
RUN dotnet publish src/ModuleOMat.Api/ModuleOMat.Api.csproj -c Release -o /app/publish --no-restore -p:SkipClientAppBuild=true

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS final
WORKDIR /app
ENV ASPNETCORE_URLS=http://0.0.0.0:8080
ENV PORT=8080
ENV DATABASE_PATH=/data/module_o_mat.db
ENV MANUAL_UPLOADS_DIR=/data/uploads/manuals
COPY --from=build /app/publish .
COPY --from=vue /src/ui/dist ./wwwroot/ui
COPY --from=vue /src/ui-alt/dist ./wwwroot/ui-alt
EXPOSE 8080
VOLUME ["/data"]
ENTRYPOINT ["dotnet", "ModuleOMat.Api.dll"]
