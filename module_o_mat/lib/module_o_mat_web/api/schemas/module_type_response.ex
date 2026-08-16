defmodule ModuleOMatWeb.Api.Schemas.ModuleTypeResponse do
  @moduledoc false

  require OpenApiSpex

  alias ModuleOMatWeb.Api.Schemas.ModuleType

  OpenApiSpex.schema(%{
    title: "ModuleTypeResponse",
    type: :object,
    properties: %{
      module_type: ModuleType
    },
    required: [:module_type]
  })
end
