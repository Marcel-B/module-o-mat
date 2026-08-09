defmodule ModuleOMat.Inventory do
  @moduledoc """
  Der `Inventory`-Context ist die oeffentliche API fuer das Verwalten von
  Eurorack-Modulen. Aufrufer (z.B. eine spaetere Web-Schicht) sollen
  ausschliesslich ueber dieses Modul lesen und schreiben, nie direkt ueber
  `ModuleOMat.Repo` oder das Schema.
  """

  import Ecto.Query, warn: false

  alias ModuleOMat.Repo
  alias ModuleOMat.Inventory.EurorackModule

  @doc """
  Liefert alle erfassten Eurorack-Module, sortiert nach Typ und Hersteller.
  """
  def list_eurorack_modules do
    EurorackModule
    |> order_by([m], asc: m.type, asc: m.manufacturer)
    |> Repo.all()
  end

  @doc """
  Liefert ein einzelnes Eurorack-Modul anhand der ID.

  Wirft `Ecto.NoResultsError`, falls kein Modul mit der ID existiert.
  """
  def get_eurorack_module!(id) do
    Repo.get!(EurorackModule, id)
  end

  @doc """
  Legt ein neues Eurorack-Modul mit den gegebenen Attributen an.
  """
  def create_eurorack_module(attrs \\ %{}) do
    %EurorackModule{}
    |> EurorackModule.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Aktualisiert ein bestehendes Eurorack-Modul mit den gegebenen Attributen.
  """
  def update_eurorack_module(%EurorackModule{} = eurorack_module, attrs) do
    eurorack_module
    |> EurorackModule.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Loescht ein Eurorack-Modul.
  """
  def delete_eurorack_module(%EurorackModule{} = eurorack_module) do
    Repo.delete(eurorack_module)
  end

  @doc """
  Liefert ein `%Ecto.Changeset{}`, um Aenderungen an einem Eurorack-Modul
  nachzuverfolgen, z.B. fuer eine spaetere Formular-Anbindung.
  """
  def change_eurorack_module(%EurorackModule{} = eurorack_module, attrs \\ %{}) do
    EurorackModule.changeset(eurorack_module, attrs)
  end
end
