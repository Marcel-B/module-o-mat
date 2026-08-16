defmodule ModuleOMatWeb.Api.Schemas.ModuleType do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ModuleType",
    description: "Definierter Modultyp",
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      name: %Schema{type: :string},
      fallback: %Schema{
        type: :boolean,
        description: "true fuer den nicht loeschbaren Fallback-Typ Sonstiges"
      },
      used: %Schema{
        type: :boolean,
        description: "true, wenn mindestens ein Modul den Typ als Haupt- oder Subtyp nutzt"
      }
    },
    required: [:id, :name, :fallback, :used],
    example: %{
      "id" => 1,
      "name" => "VCO",
      "fallback" => false,
      "used" => true
    }
  })
end
