defmodule ModuleOMatWeb.Api.Schemas.ValuationsResponse do
  @moduledoc false

  require OpenApiSpex

  alias ModuleOMatWeb.Api.Schemas.Module
  alias ModuleOMatWeb.Api.Schemas.PriceObservation
  alias ModuleOMatWeb.Api.Schemas.PriceRange

  OpenApiSpex.schema(%{
    title: "ValuationsResponse",
    type: :object,
    properties: %{
      module: Module,
      observations: %OpenApiSpex.Schema{type: :array, items: PriceObservation},
      price_range: PriceRange
    },
    required: [:module, :observations]
  })
end
