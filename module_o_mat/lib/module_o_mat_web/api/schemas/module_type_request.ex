defmodule ModuleOMatWeb.Api.Schemas.ModuleTypeRequest do
  @moduledoc false

  require OpenApiSpex

  alias ModuleOMatWeb.Api.Schemas.ModuleTypeParams

  OpenApiSpex.schema(%{
    title: "ModuleTypeRequest",
    description: "Request-Body fuer Modultypen",
    type: :object,
    properties: %{
      module_type: ModuleTypeParams
    },
    required: [:module_type]
  })
end
