defmodule ModuleOMatWeb.Api.Schemas.ModuleTypeParams do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "ModuleTypeParams",
    description: "Felder zum Anlegen oder Umbenennen eines Modultyps",
    type: :object,
    properties: %{
      name: %Schema{type: :string}
    },
    required: [:name],
    example: %{"name" => "Granular"}
  })
end
