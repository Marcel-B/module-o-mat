defmodule ModuleOMatWeb.ApiSpec do
  @moduledoc """
  OpenAPI-3-Spezifikation der JSON-API. Wird unter `/api/openapi` ausgeliefert
  und von der Swagger-UI unter `/api/docs` gelesen.
  """

  alias OpenApiSpex.{Info, OpenApi, Paths, Server}
  alias ModuleOMatWeb.{Endpoint, Router}

  @behaviour OpenApi

  @impl OpenApi
  def spec do
    %OpenApi{
      servers: [
        Server.from_endpoint(Endpoint)
      ],
      info: %Info{
        title: "Module-O-Mat API",
        version: "1.0",
        description: """
        JSON-REST-API fuer die Eurorack-Inventar-App. Vue und andere Clients
        nutzen das Prefix `/api/v1`. Die schmalen Agenten-Routen unter
        `/api/modules` bleiben fuer die Preisbewertung erhalten.
        """
      },
      paths: Paths.from_router(Router)
    }
    |> OpenApiSpex.resolve_schema_modules()
  end
end
