defmodule ModuleOMatWeb.Api.Schemas.PriceObservation do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PriceObservation",
    description: "Beobachteter Verkaufs- oder Listenpreis",
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      amount: %Schema{type: :number, format: :float, description: "Betrag in EUR"},
      currency: %Schema{type: :string, description: "Waehrung, Default EUR"},
      source: %Schema{type: :string, description: "Quelle, z.B. ebay_sold oder shop"},
      source_url: %Schema{type: :string, nullable: true},
      observed_on: %Schema{type: :string, format: :date, nullable: true},
      notes: %Schema{type: :string, nullable: true}
    },
    required: [:id, :amount, :source],
    example: %{
      "id" => 1,
      "amount" => 199.0,
      "currency" => "EUR",
      "source" => "shop",
      "source_url" => "https://example.com",
      "observed_on" => "2026-08-10",
      "notes" => "neu"
    }
  })
end
