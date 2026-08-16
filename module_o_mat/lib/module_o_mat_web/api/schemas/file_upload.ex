defmodule ModuleOMatWeb.Api.Schemas.FileUpload do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "FileUpload",
    description: "Multipart-Upload mit Dateifeld `file`",
    type: :object,
    properties: %{
      file: %Schema{type: :string, format: :binary, description: "Hochzuladende Datei"}
    },
    required: [:file]
  })
end
