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
  alias ModuleOMat.Inventory.ManualStorage
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

  Akzeptiert einen Suchstring oder Keyword-Optionen:

    * `:q` – case-insensitive Teilstring in `manufacturer` oder `name`
    * `:types` – Liste von Typnamen; Module muessen einen davon haben
    * `:min_hp` / `:max_hp` – HP-Grenzen (nur positive Ganzzahlen)

  Alle gesetzten Kriterien werden per AND verknuepft; Typen untereinander
  per OR.
  """
  def list_eurorack_modules(opts \\ [])

  def list_eurorack_modules(query) when is_binary(query) do
    list_eurorack_modules(q: query)
  end

  def list_eurorack_modules(opts) when is_list(opts) do
    q = opts |> Keyword.get(:q, "") |> to_string() |> String.trim()
    types = opts |> Keyword.get(:types, []) |> List.wrap() |> Enum.reject(&(&1 in [nil, ""]))
    min_hp = positive_integer(Keyword.get(opts, :min_hp))
    max_hp = positive_integer(Keyword.get(opts, :max_hp))

    EurorackModule
    |> where([m], is_nil(m.deleted_at))
    |> maybe_filter_query(q)
    |> maybe_filter_types(types)
    |> maybe_filter_min_hp(min_hp)
    |> maybe_filter_max_hp(max_hp)
    |> order_by([m], asc: m.type, asc: m.manufacturer)
    |> Repo.all()
  end

  defp maybe_filter_query(query, ""), do: query

  defp maybe_filter_query(query, q) do
    pattern = "%#{escape_like(q)}%"
    downcased = String.downcase(pattern)

    where(
      query,
      [m],
      fragment("lower(?) LIKE ? ESCAPE '\\'", m.manufacturer, ^downcased) or
        fragment("lower(?) LIKE ? ESCAPE '\\'", m.name, ^downcased)
    )
  end

  defp maybe_filter_types(query, []), do: query

  defp maybe_filter_types(query, types) do
    where(query, [m], m.type in ^types)
  end

  defp maybe_filter_min_hp(query, nil), do: query
  defp maybe_filter_min_hp(query, min_hp), do: where(query, [m], m.hp >= ^min_hp)

  defp maybe_filter_max_hp(query, nil), do: query
  defp maybe_filter_max_hp(query, max_hp), do: where(query, [m], m.hp <= ^max_hp)

  defp positive_integer(value) when is_integer(value) and value > 0, do: value

  defp positive_integer(value) when is_binary(value) do
    case Integer.parse(String.trim(value)) do
      {int, ""} when int > 0 -> int
      _ -> nil
    end
  end

  defp positive_integer(_), do: nil

  defp escape_like(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
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
    |> where([m], is_nil(m.deleted_at))
    |> select([m], m.type)
    |> distinct(true)
    |> order_by([m], asc: m.type)
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
  Loescht ein Eurorack-Modul unwiderruflich aus der Datenbank und entfernt
  eine ggf. vorhandene PDF-Anleitung vom Storage.
  """
  def delete_eurorack_module(%EurorackModule{} = eurorack_module) do
    case Repo.delete(eurorack_module) do
      {:ok, deleted} ->
        ManualStorage.delete(deleted.manual_pdf_key)
        {:ok, deleted}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Markiert ein Eurorack-Modul als geloescht (Soft-Delete), ohne den
  Datensatz aus der Datenbank zu entfernen. Ein so markiertes Modul taucht
  nicht mehr in `list_eurorack_modules/0` auf. Eine vorhandene PDF-Anleitung
  bleibt erhalten.
  """
  def soft_delete_eurorack_module(%EurorackModule{} = eurorack_module) do
    eurorack_module
    |> Ecto.Changeset.change(deleted_at: DateTime.utc_now(:second))
    |> Repo.update()
  end

  @doc """
  Speichert eine PDF-Anleitung fuer das Modul und aktualisiert die
  zugehoerigen Metadaten. Eine bisherige Anleitung wird nach erfolgreichem
  Speichern ersetzt und vom Storage entfernt.
  """
  def attach_manual(%EurorackModule{} = eurorack_module, %{
        tmp_path: tmp_path,
        filename: filename,
        content_type: content_type,
        size: size
      })
      when is_binary(tmp_path) and is_binary(filename) do
    new_key = ManualStorage.new_key()
    old_key = eurorack_module.manual_pdf_key

    ManualStorage.store!(new_key, tmp_path)

    attrs = %{
      manual_pdf_key: new_key,
      manual_pdf_filename: filename,
      manual_pdf_content_type: content_type || "application/pdf",
      manual_pdf_size_bytes: size
    }

    case eurorack_module |> EurorackModule.manual_changeset(attrs) |> Repo.update() do
      {:ok, updated} ->
        if old_key && old_key != new_key, do: ManualStorage.delete(old_key)
        {:ok, updated}

      {:error, changeset} ->
        ManualStorage.delete(new_key)
        {:error, changeset}
    end
  end

  @doc """
  Entfernt die PDF-Anleitung eines Moduls aus der Datenbank und vom Storage.
  """
  def remove_manual(%EurorackModule{} = eurorack_module) do
    key = eurorack_module.manual_pdf_key

    attrs = %{
      manual_pdf_key: nil,
      manual_pdf_filename: nil,
      manual_pdf_content_type: nil,
      manual_pdf_size_bytes: nil
    }

    case eurorack_module |> EurorackModule.manual_changeset(attrs) |> Repo.update() do
      {:ok, updated} ->
        ManualStorage.delete(key)
        {:ok, updated}

      {:error, _} = error ->
        error
    end
  end

  @doc """
  Liefert ein `%Ecto.Changeset{}`, um Aenderungen an einem Eurorack-Modul
  nachzuverfolgen, z.B. fuer eine spaetere Formular-Anbindung.
  """
  def change_eurorack_module(%EurorackModule{} = eurorack_module, attrs \\ %{}) do
    EurorackModule.changeset(eurorack_module, attrs)
  end
end
