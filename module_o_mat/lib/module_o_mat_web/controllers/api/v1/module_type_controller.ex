defmodule ModuleOMatWeb.Api.V1.ModuleTypeController do
  @moduledoc """
  JSON-REST-API fuer definierbare Modultypen.
  """

  use ModuleOMatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias ModuleOMat.Inventory
  alias ModuleOMatWeb.Api.JSON
  alias ModuleOMatWeb.Api.Params
  alias ModuleOMatWeb.Api.Schemas

  action_fallback ModuleOMatWeb.Api.FallbackController

  tags ["module-types"]

  operation :index,
    summary: "Modultypen auflisten",
    responses: [
      ok: {"Typen", "application/json", Schemas.ModuleTypeListResponse}
    ]

  def index(conn, _params) do
    used = MapSet.new(Inventory.list_used_types())
    fallback = Inventory.fallback_type_name()

    json(conn, %{
      module_types:
        Enum.map(Inventory.list_module_type_records(), fn type ->
          JSON.module_type(type,
            fallback: type.name == fallback,
            used: MapSet.member?(used, type.name)
          )
        end)
    })
  end

  operation :create,
    summary: "Modultyp anlegen",
    request_body: {"Typ", "application/json", Schemas.ModuleTypeRequest},
    responses: [
      created: {"Angelegt", "application/json", Schemas.ModuleTypeResponse},
      unprocessable_entity: {"Validierung", "application/json", Schemas.Error}
    ]

  def create(conn, params) do
    attrs = Params.unwrap(params, "module_type")

    case Inventory.create_module_type(attrs) do
      {:ok, type} ->
        conn
        |> put_status(:created)
        |> json(%{module_type: encode_type(type)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation :update,
    summary: "Modultyp umbenennen",
    parameters: [
      id: [in: :path, type: :integer, description: "Typ-ID"]
    ],
    request_body: {"Typ", "application/json", Schemas.ModuleTypeRequest},
    responses: [
      ok: {"Aktualisiert", "application/json", Schemas.ModuleTypeResponse},
      not_found: {"Nicht gefunden", "application/json", Schemas.Error},
      unprocessable_entity: {"Validierung", "application/json", Schemas.Error}
    ]

  def update(conn, %{"id" => id} = params) do
    attrs = Params.unwrap(params, "module_type")

    with {:ok, type} <- fetch_type(id) do
      case Inventory.update_module_type(type, attrs) do
        {:ok, updated} -> json(conn, %{module_type: encode_type(updated)})
        {:error, reason} -> {:error, reason}
      end
    end
  end

  operation :delete,
    summary: "Modultyp loeschen",
    description:
      "Module mit diesem Haupttyp werden auf Sonstiges umgestellt; Subtyp-Vorkommen entfernt.",
    parameters: [
      id: [in: :path, type: :integer, description: "Typ-ID"]
    ],
    responses: [
      no_content: "Geloescht",
      not_found: {"Nicht gefunden", "application/json", Schemas.Error},
      unprocessable_entity: {"Validierung", "application/json", Schemas.Error}
    ]

  def delete(conn, %{"id" => id}) do
    with {:ok, type} <- fetch_type(id) do
      case Inventory.delete_module_type(type) do
        {:ok, _} -> send_resp(conn, :no_content, "")
        {:error, reason} -> {:error, reason}
      end
    end
  end

  defp fetch_type(id) do
    case Params.parse_id(id) do
      {:ok, parsed_id} ->
        case Inventory.get_module_type(parsed_id) do
          nil -> {:error, {:not_found, "Modultyp nicht gefunden"}}
          type -> {:ok, type}
        end

      :error ->
        {:error, {:not_found, "Modultyp nicht gefunden"}}
    end
  end

  defp encode_type(type) do
    used = MapSet.new(Inventory.list_used_types())
    fallback = Inventory.fallback_type_name()

    JSON.module_type(type,
      fallback: type.name == fallback,
      used: MapSet.member?(used, type.name)
    )
  end
end
