defmodule ModuleOMatWeb.Api.Schemas.DuplicateParams do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema
  alias ModuleOMatWeb.Api.Schemas.ModuleParams

  OpenApiSpex.schema(%{
    title: "DuplicateParams",
    description: "Optionen beim Duplizieren eines Moduls",
    type: :object,
    properties: %{
      copy_manual: %Schema{
        type: :boolean,
        description: "PDF-Anleitung mitkopieren (Default true, wenn eine vorhanden ist)"
      },
      module: ModuleParams
    },
    example: %{"copy_manual" => true}
  })
end
