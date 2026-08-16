defmodule ModuleOMatWeb.Api.Schemas.YoutubeVideo do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "YoutubeVideo",
    description: "YouTube-Link eines Moduls. Position 0 ist das Primaervideo.",
    type: :object,
    properties: %{
      id: %Schema{type: :integer, description: "ID"},
      url: %Schema{type: :string, description: "Normalisierte Watch-URL"},
      position: %Schema{type: :integer, description: "Reihenfolge, beginnend bei 0"}
    },
    required: [:id, :url, :position],
    example: %{
      "id" => 1,
      "url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      "position" => 0
    }
  })
end
