defmodule ModuleOMatWeb.Api.Schemas.ManufacturersResponse do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ManufacturersResponse",
    description: "Sortierte Herstellerliste fuer Autocomplete",
    type: :object,
    properties: %{
      manufacturers: %Schema{type: :array, items: %Schema{type: :string}}
    },
    required: [:manufacturers],
    example: %{"manufacturers" => ["Make Noise", "Mutable Instruments"]}
  })
end
