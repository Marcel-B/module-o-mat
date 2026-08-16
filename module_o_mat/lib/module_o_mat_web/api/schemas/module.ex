defmodule ModuleOMatWeb.Api.Schemas.Module do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema
  alias ModuleOMatWeb.Api.Schemas.PriceObservation
  alias ModuleOMatWeb.Api.Schemas.PriceRange
  alias ModuleOMatWeb.Api.Schemas.YoutubeVideo

  OpenApiSpex.schema(%{
    title: "Module",
    description: "Eurorack-Modul inklusive Metadaten",
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      manufacturer: %Schema{type: :string},
      name: %Schema{type: :string},
      hp: %Schema{type: :integer, description: "Breite in HP"},
      type: %Schema{type: :string, description: "Haupttyp"},
      subtypes: %Schema{type: :array, items: %Schema{type: :string}},
      current_draw_plus12v_ma: %Schema{type: :integer, nullable: true},
      current_draw_minus12v_ma: %Schema{type: :integer, nullable: true},
      current_draw_plus5v_ma: %Schema{type: :integer, nullable: true},
      depth_mm: %Schema{type: :integer, nullable: true},
      description: %Schema{type: :string, nullable: true},
      manual_url: %Schema{type: :string, nullable: true, description: "Produktseiten-URL"},
      purchase_price: %Schema{type: :number, format: :float, nullable: true},
      current_value: %Schema{type: :number, format: :float, nullable: true},
      has_manual: %Schema{type: :boolean},
      manual_pdf_filename: %Schema{type: :string, nullable: true},
      manual_pdf_content_type: %Schema{type: :string, nullable: true},
      manual_pdf_size_bytes: %Schema{type: :integer, nullable: true},
      youtube_videos: %Schema{type: :array, items: YoutubeVideo},
      price_range: PriceRange,
      price_observations: %Schema{
        type: :array,
        items: PriceObservation,
        description: "Nur in der Detailansicht enthalten"
      },
      inserted_at: %Schema{type: :string, format: :"date-time"},
      updated_at: %Schema{type: :string, format: :"date-time"}
    },
    required: [:id, :manufacturer, :name, :hp, :type, :has_manual],
    example: %{
      "id" => 1,
      "manufacturer" => "Make Noise",
      "name" => "Maths",
      "hp" => 20,
      "type" => "Envelope",
      "subtypes" => ["LFO"],
      "current_draw_plus12v_ma" => 55,
      "current_draw_minus12v_ma" => 30,
      "current_draw_plus5v_ma" => nil,
      "depth_mm" => 35,
      "description" => "Funktionsgenerator",
      "manual_url" => "https://www.makenoisemusic.com/technology/maths",
      "purchase_price" => 289.0,
      "current_value" => 250.0,
      "has_manual" => false,
      "manual_pdf_filename" => nil,
      "manual_pdf_content_type" => nil,
      "manual_pdf_size_bytes" => nil,
      "youtube_videos" => [],
      "price_range" => nil
    }
  })
end
