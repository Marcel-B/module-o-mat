defmodule ModuleOMatWeb.Api.FallbackController do
  @moduledoc """
  Einheitliche JSON-Fehlerantworten fuer die v1-API.
  """

  use ModuleOMatWeb, :controller

  alias ModuleOMat.Inventory
  alias ModuleOMatWeb.Api.JSON

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: "Validierung fehlgeschlagen", details: JSON.error_map(changeset)})
  end

  def call(conn, {:error, {:not_found, message}}) when is_binary(message) do
    conn
    |> put_status(:not_found)
    |> json(%{error: message})
  end

  def call(conn, {:error, :not_found}) do
    call(conn, {:error, {:not_found, "Nicht gefunden"}})
  end

  def call(conn, {:error, :fallback_type}) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{
      error:
        "Der Typ \"#{Inventory.fallback_type_name()}\" kann nicht umbenannt oder geloescht werden."
    })
  end

  def call(conn, {:error, {:unprocessable, message}}) when is_binary(message) do
    conn
    |> put_status(:unprocessable_entity)
    |> json(%{error: message})
  end

  def call(conn, {:error, :empty_observations}) do
    call(conn, {:error, {:unprocessable, "observations darf nicht leer sein"}})
  end

  def call(conn, {:error, :invalid_current_value}) do
    call(conn, {:error, {:unprocessable, "current_value ist ungueltig"}})
  end

  def call(conn, {:error, :maintenance}) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{error: "Datensicherung laeuft. Bitte warte einen Moment."})
  end
end
