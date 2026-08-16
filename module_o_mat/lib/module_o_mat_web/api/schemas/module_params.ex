defmodule ModuleOMatWeb.Api.Schemas.ModuleParams do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema
  alias ModuleOMatWeb.Api.Schemas.YoutubeVideoParams

  OpenApiSpex.schema(%{
    title: "ModuleParams",
    description: "Felder zum Anlegen oder Aktualisieren eines Moduls",
    type: :object,
    properties: %{
      manufacturer: %Schema{type: :string},
      name: %Schema{type: :string},
      hp: %Schema{type: :integer, minimum: 1},
      type: %Schema{type: :string},
      subtypes: %Schema{type: :array, items: %Schema{type: :string}},
      current_draw_plus12v_ma: %Schema{type: :integer, nullable: true, minimum: 0},
      current_draw_minus12v_ma: %Schema{type: :integer, nullable: true, minimum: 0},
      current_draw_plus5v_ma: %Schema{type: :integer, nullable: true, minimum: 0},
      depth_mm: %Schema{type: :integer, nullable: true, minimum: 0},
      description: %Schema{type: :string, nullable: true},
      manual_url: %Schema{type: :string, nullable: true},
      purchase_price: %Schema{type: :number, format: :float, nullable: true, minimum: 0},
      current_value: %Schema{type: :number, format: :float, nullable: true, minimum: 0},
      youtube_videos: %Schema{type: :array, items: YoutubeVideoParams}
    },
    example: %{
      "manufacturer" => "Make Noise",
      "name" => "Maths",
      "hp" => 20,
      "type" => "Envelope",
      "subtypes" => ["LFO"],
      "purchase_price" => 289.0
    }
  })
end
