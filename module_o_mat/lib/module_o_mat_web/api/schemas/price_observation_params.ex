defmodule ModuleOMatWeb.Api.Schemas.PriceObservationParams do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "PriceObservationParams",
    description: "Neue Preisbeobachtung",
    type: :object,
    properties: %{
      amount: %Schema{type: :number, format: :float, description: "Betrag"},
      currency: %Schema{type: :string, description: "Default EUR"},
      source: %Schema{type: :string, description: "z.B. ebay_sold, shop, other"},
      source_url: %Schema{type: :string},
      observed_on: %Schema{type: :string, format: :date, description: "Default: heute"},
      notes: %Schema{type: :string}
    },
    required: [:amount, :source],
    example: %{
      "amount" => 189.0,
      "currency" => "EUR",
      "source" => "ebay_sold",
      "source_url" => "https://www.ebay.de/...",
      "observed_on" => "2026-08-10",
      "notes" => "guter Zustand"
    }
  })
end
