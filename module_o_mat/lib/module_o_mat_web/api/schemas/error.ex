defmodule ModuleOMatWeb.Api.Schemas.Error do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Error",
    description: "Fehlerantwort der HTTP-API",
    type: :object,
    properties: %{
      error: %Schema{type: :string, description: "Kurzbeschreibung"},
      details: %Schema{
        type: :object,
        description: "Feldfehler aus der Validierung",
        additionalProperties: %Schema{
          type: :array,
          items: %Schema{type: :string}
        }
      }
    },
    required: [:error],
    example: %{
      "error" => "Validierung fehlgeschlagen",
      "details" => %{"name" => ["muss ausgefuellt werden"]}
    }
  })
end
