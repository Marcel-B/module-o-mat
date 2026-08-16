defmodule ModuleOMatWeb.Api.Schemas.ModuleTypeListResponse do
  @moduledoc false

  require OpenApiSpex

  alias ModuleOMatWeb.Api.Schemas.ModuleType

  OpenApiSpex.schema(%{
    title: "ModuleTypeListResponse",
    type: :object,
    properties: %{
      module_types: %OpenApiSpex.Schema{type: :array, items: ModuleType}
    },
    required: [:module_types]
  })
end
