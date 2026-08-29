defmodule ModuleOMatWeb.Api.Schemas.BackupHistoryResponse do
  @moduledoc false

  require OpenApiSpex

  alias ModuleOMatWeb.Api.Schemas.BackupRun
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "BackupHistoryResponse",
    description: "Seite der Sicherungshistorie inklusive Status der letzten Laeufe",
    type: :object,
    properties: %{
      backup_runs: %Schema{type: :array, items: BackupRun},
      page: %Schema{type: :integer},
      per_page: %Schema{type: :integer},
      total: %Schema{type: :integer},
      last_success_at: %Schema{type: :string, format: :"date-time", nullable: true},
      last_failure_at: %Schema{type: :string, format: :"date-time", nullable: true}
    },
    required: [
      :backup_runs,
      :page,
      :per_page,
      :total,
      :last_success_at,
      :last_failure_at
    ],
    example: %{
      "backup_runs" => [
        %{
          "id" => 1,
          "occurred_at" => "2026-08-29T01:00:00Z",
          "filename" => "inventory-sat.zip",
          "size_bytes" => 184_320,
          "success" => true
        }
      ],
      "page" => 1,
      "per_page" => 5,
      "total" => 1,
      "last_success_at" => "2026-08-29T01:00:00Z",
      "last_failure_at" => nil
    }
  })
end
