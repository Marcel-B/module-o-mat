defmodule ModuleOMatWeb.Api.Schemas.ValuationsParams do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema
  alias ModuleOMatWeb.Api.Schemas.PriceObservationParams

  OpenApiSpex.schema(%{
    title: "ValuationsParams",
    description: "Neue Preisbeobachtungen; setzt current_value auf Median oder expliziten Wert",
    type: :object,
    properties: %{
      observations: %Schema{type: :array, items: PriceObservationParams},
      set_current_value: %Schema{
        description: "median (Default), null zum Beibehalten, oder ein Betrag",
        oneOf: [
          %Schema{type: :string, enum: ["median"]},
          %Schema{type: :number, format: :float},
          %Schema{type: :string}
        ],
        nullable: true
      },
      current_value: %Schema{
        type: :number,
        format: :float,
        description: "Expliziter neuer Modulwert (Alternative zu set_current_value)"
      }
    },
    required: [:observations]
  })
end
