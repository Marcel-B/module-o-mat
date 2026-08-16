defmodule ModuleOMatWeb.Api.Schemas.ModuleResponse do
  @moduledoc false

  require OpenApiSpex

  alias ModuleOMatWeb.Api.Schemas.Module

  OpenApiSpex.schema(%{
    title: "ModuleResponse",
    description: "Einzelnes Modul",
    type: :object,
    properties: %{
      module: Module
    },
    required: [:module]
  })
end
