defmodule ModuleOMatWeb.Api.Schemas.ModuleListResponse do
  @moduledoc false

  require OpenApiSpex

  alias ModuleOMatWeb.Api.Schemas.Module
  alias ModuleOMatWeb.Api.Schemas.Stats

  OpenApiSpex.schema(%{
    title: "ModuleListResponse",
    description: "Modulliste inklusive Statistik fuer dieselben Filter",
    type: :object,
    properties: %{
      modules: %OpenApiSpex.Schema{type: :array, items: Module},
      stats: Stats
    },
    required: [:modules, :stats]
  })
end
