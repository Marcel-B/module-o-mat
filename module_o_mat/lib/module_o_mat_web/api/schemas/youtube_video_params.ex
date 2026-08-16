defmodule ModuleOMatWeb.Api.Schemas.YoutubeVideoParams do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "YoutubeVideoParams",
    description: "YouTube-Link beim Anlegen oder Aktualisieren",
    type: :object,
    properties: %{
      id: %Schema{
        type: :integer,
        description: "Bestehende Video-ID (nur beim Update, sonst weglassen)"
      },
      url: %Schema{type: :string, description: "Gueltige YouTube-URL"}
    },
    required: [:url],
    example: %{"url" => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}
  })
end
