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
  alias ModuleOMat.Inventory.ModuleType

  @doc """
  Name des Fallback-Typs, auf den Module zurueckfallen, wenn ihr bisheriger
  Typ geloescht wird. Dieser Typ kann selbst weder umbenannt noch geloescht
  werden.
  """
  @fallback_type_name "Sonstiges"
  def fallback_type_name, do: @fallback_type_name

  @doc """
  Liefert alle nicht geloeschten Eurorack-Module, sortiert nach Typ und
  Hersteller.
  """
  def list_eurorack_modules do
    EurorackModule
    |> where([m], is_nil(m.deleted_at))
    |> order_by([m], asc: m.type, asc: m.manufacturer)
    |> Repo.all()
  end

  @doc """
  Liefert alle bereits erfassten Herstellernamen (ohne Duplikate, sortiert),
  z.B. um sie als Autocomplete-Vorschlaege in einem Formular anzubieten.
  """
  def list_manufacturers do
    EurorackModule
    |> select([m], m.manufacturer)
    |> distinct(true)
    |> order_by([m], asc: m.manufacturer)
    |> Repo.all()
  end

  @doc """
  Liefert alle definierten Modultypen als vollstaendige Datensaetze,
  sortiert nach Namen. Wird z.B. im "Typen verwalten"-Dialog benoetigt, wo
  neben dem Namen auch die ID (fuer Bearbeiten/Loeschen) gebraucht wird.
  """
  def list_module_type_records do
    ModuleType
    |> order_by([t], asc: t.name)
    |> Repo.all()
  end

  @doc """
  Liefert die Namen aller definierten Modultypen, sortiert. Diese Typen
  koennen ueber `create_module_type/1` (z.B. im "Typen verwalten"-Dialog)
  vom Anwender erweitert werden.
  """
  def list_module_types do
    list_module_type_records()
    |> Enum.map(& &1.name)
  end

  @doc """
  Liefert alle Typwerte, die bereits an einem Eurorack-Modul verwendet
  werden (ohne Duplikate). Damit bleiben auch Typen im Auswahlfeld
  sichtbar, die aus irgendeinem Grund (noch) nicht ueber
  `create_module_type/1` definiert wurden.
  """
  def list_used_types do
    EurorackModule
    |> select([m], m.type)
    |> distinct(true)
    |> Repo.all()
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  Legt einen neuen Modultyp an, der danach im Auswahlfeld fuer Module zur
  Verfuegung steht.
  """
  def create_module_type(attrs \\ %{}) do
    %ModuleType{}
    |> ModuleType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Liefert ein `%Ecto.Changeset{}`, um Aenderungen an einem Modultyp
  nachzuverfolgen, z.B. fuer eine Formular-Anbindung.
  """
  def change_module_type(%ModuleType{} = module_type, attrs \\ %{}) do
    ModuleType.changeset(module_type, attrs)
  end

  @doc """
  Benennt einen Modultyp um. Module, die den bisherigen Namen referenzieren,
  werden automatisch auf den neuen Namen umgestellt.

  Der Fallback-Typ (siehe `fallback_type_name/0`) kann nicht umbenannt
  werden; in diesem Fall wird `{:error, :fallback_type}` geliefert.
  """
  def update_module_type(%ModuleType{name: @fallback_type_name}, _attrs) do
    {:error, :fallback_type}
  end

  def update_module_type(%ModuleType{} = module_type, attrs) do
    old_name = module_type.name

    Repo.transaction(fn ->
      case module_type |> ModuleType.changeset(attrs) |> Repo.update() do
        {:ok, updated} ->
          if updated.name != old_name do
            EurorackModule
            |> where([m], m.type == ^old_name)
            |> Repo.update_all(set: [type: updated.name])
          end

          updated

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  @doc """
  Loescht einen Modultyp. Module, die diesen Typ referenzieren, werden
  automatisch auf den Fallback-Typ (siehe `fallback_type_name/0`)
  umgestellt, statt verwaist zu bleiben.

  Der Fallback-Typ selbst kann nicht geloescht werden; in diesem Fall wird
  `{:error, :fallback_type}` geliefert.
  """
  def delete_module_type(%ModuleType{name: @fallback_type_name}) do
    {:error, :fallback_type}
  end

  def delete_module_type(%ModuleType{} = module_type) do
    Repo.transaction(fn ->
      EurorackModule
      |> where([m], m.type == ^module_type.name)
      |> Repo.update_all(set: [type: @fallback_type_name])

      case Repo.delete(module_type) do
        {:ok, deleted} -> deleted
        {:error, changeset} -> Repo.rollback(changeset)
      end
    end)
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
  Loescht ein Eurorack-Modul unwiderruflich aus der Datenbank.
  """
  def delete_eurorack_module(%EurorackModule{} = eurorack_module) do
    Repo.delete(eurorack_module)
  end

  @doc """
  Markiert ein Eurorack-Modul als geloescht (Soft-Delete), ohne den
  Datensatz aus der Datenbank zu entfernen. Ein so markiertes Modul taucht
  nicht mehr in `list_eurorack_modules/0` auf.
  """
  def soft_delete_eurorack_module(%EurorackModule{} = eurorack_module) do
    eurorack_module
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  @doc """
  Liefert ein `%Ecto.Changeset{}`, um Aenderungen an einem Eurorack-Modul
  nachzuverfolgen, z.B. fuer eine spaetere Formular-Anbindung.
  """
  def change_eurorack_module(%EurorackModule{} = eurorack_module, attrs \\ %{}) do
    EurorackModule.changeset(eurorack_module, attrs)
  end
end
