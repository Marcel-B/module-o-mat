defmodule ModuleOMatWeb.Api.ModuleController do
  @moduledoc """
  JSON-API fuer Agenten zur Modulbewertung: Module abrufen und
  Preisbeobachtungen speichern.
  """

  use ModuleOMatWeb, :controller

  alias ModuleOMat.Inventory

  def index(conn, _params) do
    modules = Inventory.list_modules_for_valuation()
    ranges = Inventory.price_ranges_for_modules(Enum.map(modules, & &1.id))

    json(conn, %{
      modules:
        Enum.map(modules, fn module ->
          module_json(module, Map.get(ranges, module.id))
        end)
    })
  end

  def show(conn, %{"id" => id}) do
    module = Inventory.get_module_for_valuation!(id)

    json(conn, %{
      module:
        module
        |> module_json(Inventory.price_range_for_module(module.id))
        |> Map.put(:observations, Enum.map(module.price_observations, &observation_json/1))
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
          module: module_json(result.module, result.price_range),
          observations: Enum.map(result.observations, &observation_json/1),
          price_range: price_range_json(result.price_range)
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
        |> json(%{error: "Validierung fehlgeschlagen", details: error_map(changeset)})
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

  defp module_json(module, price_range) do
    %{
      id: module.id,
      manufacturer: module.manufacturer,
      name: module.name,
      hp: module.hp,
      current_value: decimal_json(module.current_value),
      price_range: price_range_json(price_range)
    }
  end

  defp observation_json(observation) do
    %{
      id: observation.id,
      amount: decimal_json(observation.amount),
      currency: observation.currency,
      source: observation.source,
      source_url: observation.source_url,
      observed_on: observation.observed_on,
      notes: observation.notes
    }
  end

  defp price_range_json(nil), do: nil

  defp price_range_json(range) do
    %{
      min: decimal_json(range.min),
      max: decimal_json(range.max),
      count: range.count,
      last_observed_on: range.last_observed_on
    }
  end

  defp decimal_json(nil), do: nil
  defp decimal_json(%Decimal{} = value), do: Decimal.to_float(Decimal.round(value, 2))

  defp error_map(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts
        |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)
        |> Map.get(key, key)
        |> to_string()
      end)
    end)
  end
end
