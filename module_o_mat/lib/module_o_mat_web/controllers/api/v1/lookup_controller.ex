defmodule ModuleOMatWeb.Api.V1.LookupController do
  @moduledoc """
  Nachschlage-Endpunkte fuer Formulare (Hersteller-Autocomplete).
  """

  use ModuleOMatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias ModuleOMat.Inventory
  alias ModuleOMatWeb.Api.Schemas

  tags ["lookups"]

  operation :manufacturers,
    summary: "Hersteller auflisten",
    responses: [
      ok: {"Hersteller", "application/json", Schemas.ManufacturersResponse}
    ]

  def manufacturers(conn, _params) do
    json(conn, %{manufacturers: Inventory.list_manufacturers()})
  end
end
