defmodule ModuleOMatWeb.Api.Schemas.MaintenanceStatus do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "MaintenanceStatus",
    description: "Ob die UI wegen einer Datensicherung im Wartungsmodus ist",
    type: :object,
    properties: %{
      maintenance: %Schema{type: :boolean}
    },
    required: [:maintenance],
    example: %{"maintenance" => false}
  })
end
