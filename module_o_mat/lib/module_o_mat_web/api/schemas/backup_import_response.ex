defmodule ModuleOMatWeb.Api.Schemas.BackupImportResponse do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "BackupImportResponse",
    type: :object,
    properties: %{
      imported: %Schema{type: :boolean}
    },
    required: [:imported],
    example: %{"imported" => true}
  })
end
