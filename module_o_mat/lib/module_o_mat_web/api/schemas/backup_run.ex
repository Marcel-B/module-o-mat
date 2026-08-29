defmodule ModuleOMatWeb.Api.Schemas.BackupRun do
  @moduledoc false

  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "BackupRun",
    description: "Ein dokumentierter Sicherungsversuch",
    type: :object,
    properties: %{
      id: %Schema{type: :integer},
      occurred_at: %Schema{type: :string, format: :"date-time"},
      filename: %Schema{type: :string, nullable: true},
      size_bytes: %Schema{type: :integer, nullable: true},
      success: %Schema{type: :boolean}
    },
    required: [:id, :occurred_at, :success],
    example: %{
      "id" => 1,
      "occurred_at" => "2026-08-29T01:00:00Z",
      "filename" => "inventory-sat.zip",
      "size_bytes" => 184_320,
      "success" => true
    }
  })
end
