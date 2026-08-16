defmodule ModuleOMatWeb.Api.Schemas.Stats do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "Stats",
    description: "Aggregat-Statistik ueber den (gefilterten) Bestand",
    type: :object,
    properties: %{
      count: %Schema{type: :integer},
      total_hp: %Schema{type: :integer},
      total_width_mm: %Schema{type: :number, format: :float},
      total_width_cm: %Schema{type: :number, format: :float},
      total_width_m: %Schema{type: :number, format: :float},
      total_purchase_price: %Schema{type: :number, format: :float},
      total_current_value: %Schema{type: :number, format: :float}
    },
    required: [
      :count,
      :total_hp,
      :total_width_mm,
      :total_width_cm,
      :total_width_m,
      :total_purchase_price,
      :total_current_value
    ],
    example: %{
      "count" => 12,
      "total_hp" => 168,
      "total_width_mm" => 853.44,
      "total_width_cm" => 85.34,
      "total_width_m" => 0.85,
      "total_purchase_price" => 4200.0,
      "total_current_value" => 3890.5
    }
  })
end
