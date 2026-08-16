defmodule ModuleOMatWeb.Api.ModuleController do
  @moduledoc """
  JSON-API fuer Agenten zur Modulbewertung: Module abrufen und
  Preisbeobachtungen speichern.
  """

  use ModuleOMatWeb, :controller

  alias ModuleOMat.Inventory
  alias ModuleOMatWeb.Api.JSON

  def index(conn, _params) do
    modules = Inventory.list_modules_for_valuation()
    ranges = Inventory.price_ranges_for_modules(Enum.map(modules, & &1.id))

    json(conn, %{
      modules:
        Enum.map(modules, fn module ->
          JSON.valuation_module(module, Map.get(ranges, module.id))
        end)
    })
  end

  def show(conn, %{"id" => id}) do
    module = Inventory.get_module_for_valuation!(id)

    json(conn, %{
      module:
        module
        |> JSON.valuation_module(Inventory.price_range_for_module(module.id))
        |> Map.put(:observations, Enum.map(module.price_observations, &JSON.observation/1))
    })
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{error: "Modul nicht gefunden"})
  end

  def create_valuations(conn, %{"id" => id} = params) do
    module = Inventory.get_module_for_valuation!(id)
    observations = Map.get(params, "observations") || []

    opts =
      cond do
        Map.has_key?(params, "current_value") ->
          [set_current_value: Map.get(params, "current_value")]

        true ->
          [set_current_value: parse_set_current_value(Map.get(params, "set_current_value"))]
      end

    case Inventory.create_price_observations(module, observations, opts) do
      {:ok, result} ->
        conn
        |> put_status(:created)
        |> json(%{
          module: JSON.valuation_module(result.module, result.price_range),
          observations: Enum.map(result.observations, &JSON.observation/1),
          price_range: JSON.price_range(result.price_range)
        })

      {:error, :empty_observations} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "observations darf nicht leer sein"})

      {:error, :invalid_current_value} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "current_value ist ungueltig"})

      {:error, %Ecto.Changeset{} = changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Validierung fehlgeschlagen", details: JSON.error_map(changeset)})
    end
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(:not_found)
      |> json(%{error: "Modul nicht gefunden"})
  end

  defp parse_set_current_value(nil), do: :median
  defp parse_set_current_value("median"), do: :median
  defp parse_set_current_value(:median), do: :median
  defp parse_set_current_value(other), do: other
end
