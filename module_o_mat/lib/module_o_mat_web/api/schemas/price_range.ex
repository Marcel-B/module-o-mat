defmodule ModuleOMatWeb.Api.Schemas.PriceRange do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PriceRange",
    description: "Aggregierte Preisspanne der Beobachtungen eines Moduls",
    type: :object,
    nullable: true,
    properties: %{
      min: %Schema{type: :number, format: :float, description: "Kleinster Betrag in EUR"},
      max: %Schema{type: :number, format: :float, description: "Groesster Betrag in EUR"},
      count: %Schema{type: :integer, description: "Anzahl Beobachtungen"},
      last_observed_on: %Schema{
        type: :string,
        format: :date,
        nullable: true,
        description: "Datum der juengsten Beobachtung"
      }
    },
    example: %{
      "min" => 100.0,
      "max" => 140.0,
      "count" => 2,
      "last_observed_on" => "2026-08-02"
    }
  })
end
