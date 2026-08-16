defmodule ModuleOMatWeb.Api.V1.MaintenanceController do
  @moduledoc """
  JSON-Status, ob gerade ein Inventar-Backup laeuft (Wartungsmodus).
  """

  use ModuleOMatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias ModuleOMat.Inventory.RemoteBackupScheduler
  alias ModuleOMatWeb.Api.Schemas

  tags ["maintenance"]

  operation :show,
    summary: "Wartungsstatus",
    description: "true, waehrend ein Nextcloud-Backup geschrieben wird.",
    responses: [
      ok: {"Status", "application/json", Schemas.MaintenanceStatus}
    ]

  def show(conn, _params) do
    json(conn, %{maintenance: RemoteBackupScheduler.maintenance?()})
  end
end
