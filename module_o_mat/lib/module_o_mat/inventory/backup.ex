defmodule ModuleOMat.Inventory.Backup do
  @moduledoc """
  Export und Import des Inventars als ZIP-Datei mit CSVs und Manual-PDFs.

  Soft-geloeschte Module (`deleted_at`) werden beim Export ausgelassen.
  Der Import ersetzt den gesamten Bestand (Tabellen + Manual-Storage).
  """

  import Ecto.Query, warn: false

  alias ModuleOMat.Repo
  alias ModuleOMat.Inventory.Backup.CSV
  alias ModuleOMat.Inventory.EurorackModule
  alias ModuleOMat.Inventory.ManualStorage
  alias ModuleOMat.Inventory.ModuleType
  alias ModuleOMat.Inventory.YoutubeVideo

  @module_types_file "module_types.csv"
  @modules_file "eurorack_modules.csv"
  @videos_file "youtube_videos.csv"
  @manuals_dir "manuals"

  @module_type_headers ~w(id name inserted_at updated_at)
  @module_headers ~w(
    id manufacturer name hp type subtypes
    current_draw_plus12v_ma current_draw_minus12v_ma current_draw_plus5v_ma
    depth_mm description manual_url purchase_price current_value
    manual_pdf_key manual_pdf_filename manual_pdf_content_type manual_pdf_size_bytes
    inserted_at updated_at
  )
  @video_headers ~w(id eurorack_module_id url position inserted_at updated_at)

  @doc """
  Schreibt ein Inventar-Backup als ZIP nach `path`.

  Erzeugt fehlende Elternverzeichnisse. Liefert `{:ok, path}` oder
  `{:error, reason}`.
  """
  def export_to_path(path) when is_binary(path) do
    File.mkdir_p!(Path.dirname(path))

    tmp_root = tmp_dir!("export")

    try do
      write_csvs!(tmp_root)
      copy_manuals_for_export!(tmp_root)
      create_zip!(tmp_root, path)
      {:ok, path}
    rescue
      e -> {:error, Exception.message(e)}
    after
      File.rm_rf(tmp_root)
    end
  end

  @doc """
  Stellt ein Inventar-Backup aus der ZIP-Datei `path` wieder her.

  Loescht alle vorhandenen Eintraege in den Inventar-Tabellen und ersetzt
  den Manual-Storage. Liefert `:ok` oder `{:error, reason}`.
  """
  def import_from_path(path) when is_binary(path) do
    unless File.regular?(path) do
      {:error, "Backup-Datei nicht gefunden: #{path}"}
    else
      tmp_root = tmp_dir!("import")

      try do
        extract_zip!(path, tmp_root)

        types = read_csv!(tmp_root, @module_types_file, @module_type_headers)
        modules = read_csv!(tmp_root, @modules_file, @module_headers)
        videos = read_csv!(tmp_root, @videos_file, @video_headers)
        manuals_source = ensure_manuals_dir!(tmp_root)

        case replace_database(types, modules, videos) do
          {:ok, _} ->
            ManualStorage.replace_all!(manuals_source)
            :ok

          {:error, reason} ->
            {:error, format_import_error(reason)}
        end
      rescue
        e -> {:error, Exception.message(e)}
      after
        File.rm_rf(tmp_root)
      end
    end
  end

  defp write_csvs!(tmp_root) do
    modules = list_active_modules()
    module_ids = Enum.map(modules, & &1.id)
    types = Repo.all(from(t in ModuleType, order_by: [asc: t.id]))
    videos = list_videos_for_modules(module_ids)

    write_csv!(tmp_root, @module_types_file, @module_type_headers, Enum.map(types, &type_row/1))
    write_csv!(tmp_root, @modules_file, @module_headers, Enum.map(modules, &module_row/1))
    write_csv!(tmp_root, @videos_file, @video_headers, Enum.map(videos, &video_row/1))
  end

  defp list_active_modules do
    EurorackModule
    |> where([m], is_nil(m.deleted_at))
    |> order_by([m], asc: m.id)
    |> Repo.all()
  end

  defp list_videos_for_modules([]), do: []

  defp list_videos_for_modules(module_ids) do
    YoutubeVideo
    |> where([v], v.eurorack_module_id in ^module_ids)
    |> order_by([v], asc: v.id)
    |> Repo.all()
  end

  defp copy_manuals_for_export!(tmp_root) do
    manuals_dir = Path.join(tmp_root, @manuals_dir)
    File.mkdir_p!(manuals_dir)

    EurorackModule
    |> where([m], is_nil(m.deleted_at) and not is_nil(m.manual_pdf_key))
    |> select([m], m.manual_pdf_key)
    |> Repo.all()
    |> Enum.uniq()
    |> Enum.each(fn key ->
      if ManualStorage.exists?(key) do
        ManualStorage.copy_out!(key, Path.join(manuals_dir, key))
      end
    end)
  end

  defp write_csv!(tmp_root, filename, headers, rows) do
    path = Path.join(tmp_root, filename)
    iodata = CSV.dump_to_iodata([headers | rows])
    File.write!(path, iodata)
  end

  defp type_row(%ModuleType{} = t) do
    [to_csv(t.id), to_csv(t.name), to_csv(t.inserted_at), to_csv(t.updated_at)]
  end

  defp module_row(%EurorackModule{} = m) do
    [
      to_csv(m.id),
      to_csv(m.manufacturer),
      to_csv(m.name),
      to_csv(m.hp),
      to_csv(m.type),
      to_csv_subtypes(m.subtypes),
      to_csv(m.current_draw_plus12v_ma),
      to_csv(m.current_draw_minus12v_ma),
      to_csv(m.current_draw_plus5v_ma),
      to_csv(m.depth_mm),
      to_csv(m.description),
      to_csv(m.manual_url),
      to_csv(m.purchase_price),
      to_csv(m.current_value),
      to_csv(m.manual_pdf_key),
      to_csv(m.manual_pdf_filename),
      to_csv(m.manual_pdf_content_type),
      to_csv(m.manual_pdf_size_bytes),
      to_csv(m.inserted_at),
      to_csv(m.updated_at)
    ]
  end

  defp video_row(%YoutubeVideo{} = v) do
    [
      to_csv(v.id),
      to_csv(v.eurorack_module_id),
      to_csv(v.url),
      to_csv(v.position),
      to_csv(v.inserted_at),
      to_csv(v.updated_at)
    ]
  end

  defp to_csv(nil), do: ""
  defp to_csv(%Decimal{} = value), do: Decimal.to_string(value, :normal)
  defp to_csv(%DateTime{} = value), do: DateTime.to_iso8601(value)
  defp to_csv(%NaiveDateTime{} = value), do: NaiveDateTime.to_iso8601(value)
  defp to_csv(value) when is_binary(value), do: value
  defp to_csv(value) when is_integer(value), do: Integer.to_string(value)
  defp to_csv(value) when is_float(value), do: Float.to_string(value)
  defp to_csv(value) when is_atom(value), do: Atom.to_string(value)

  defp to_csv_subtypes(nil), do: ""
  defp to_csv_subtypes(subtypes) when is_list(subtypes), do: Enum.join(subtypes, "|")

  defp create_zip!(tmp_root, zip_path) do
    if File.exists?(zip_path), do: File.rm!(zip_path)

    entries =
      tmp_root
      |> Path.join("**")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(fn absolute ->
        relative = Path.relative_to(absolute, tmp_root)
        {String.to_charlist(relative), File.read!(absolute)}
      end)

    case :zip.create(String.to_charlist(zip_path), entries) do
      {:ok, _} -> :ok
      {:error, reason} -> raise "ZIP konnte nicht erstellt werden: #{inspect(reason)}"
    end
  end

  defp extract_zip!(zip_path, tmp_root) do
    case :zip.extract(String.to_charlist(zip_path), cwd: String.to_charlist(tmp_root)) do
      {:ok, _files} -> :ok
      {:error, reason} -> raise "ZIP konnte nicht gelesen werden: #{inspect(reason)}"
    end
  end

  defp read_csv!(tmp_root, filename, expected_headers) do
    path = Path.join(tmp_root, filename)

    unless File.regular?(path) do
      raise "Pflicht-Datei fehlt im Backup: #{filename}"
    end

    path
    |> File.stream!()
    |> CSV.parse_stream(skip_headers: false)
    |> Enum.to_list()
    |> case do
      [] ->
        []

      [headers | rows] ->
        if headers != expected_headers do
          raise "Unerwartete CSV-Header in #{filename}: #{inspect(headers)}"
        end

        Enum.map(rows, fn row ->
          expected_headers
          |> Enum.zip(row)
          |> Map.new(fn {header, value} -> {header, value} end)
        end)
    end
  end

  defp ensure_manuals_dir!(tmp_root) do
    path = Path.join(tmp_root, @manuals_dir)
    File.mkdir_p!(path)
    path
  end

  defp replace_database(types, modules, videos) do
    Repo.transaction(fn ->
      Repo.delete_all(YoutubeVideo)
      Repo.delete_all(EurorackModule)
      Repo.delete_all(ModuleType)

      Enum.each(types, &insert_module_type!/1)
      Enum.each(modules, &insert_module!/1)
      Enum.each(videos, &insert_video!/1)

      reset_sqlite_sequence!("module_types")
      reset_sqlite_sequence!("eurorack_modules")
      reset_sqlite_sequence!("youtube_videos")

      :ok
    end)
  end

  defp reset_sqlite_sequence!(table) when is_binary(table) do
    %{rows: [[max_id]]} =
      Repo.query!("SELECT COALESCE(MAX(id), 0) FROM #{table}")

    case Repo.query("DELETE FROM sqlite_sequence WHERE name = ?", [table]) do
      {:ok, _} ->
        if max_id > 0 do
          Repo.query!("INSERT INTO sqlite_sequence(name, seq) VALUES (?, ?)", [table, max_id])
        end

        :ok

      {:error, _} ->
        # sqlite_sequence existiert nur bei AUTOINCREMENT-Tabellen
        :ok
    end
  end

  defp insert_module_type!(row) do
    Repo.insert!(%ModuleType{
      id: parse_integer!(row["id"], "module_types.id"),
      name: required_string!(row["name"], "module_types.name"),
      inserted_at: parse_datetime!(row["inserted_at"], "module_types.inserted_at"),
      updated_at: parse_datetime!(row["updated_at"], "module_types.updated_at")
    })
  end

  defp insert_module!(row) do
    Repo.insert!(%EurorackModule{
      id: parse_integer!(row["id"], "eurorack_modules.id"),
      manufacturer: required_string!(row["manufacturer"], "eurorack_modules.manufacturer"),
      name: required_string!(row["name"], "eurorack_modules.name"),
      hp: parse_integer!(row["hp"], "eurorack_modules.hp"),
      type: required_string!(row["type"], "eurorack_modules.type"),
      subtypes: parse_subtypes(row["subtypes"]),
      current_draw_plus12v_ma: parse_optional_integer(row["current_draw_plus12v_ma"]),
      current_draw_minus12v_ma: parse_optional_integer(row["current_draw_minus12v_ma"]),
      current_draw_plus5v_ma: parse_optional_integer(row["current_draw_plus5v_ma"]),
      depth_mm: parse_optional_integer(row["depth_mm"]),
      description: empty_to_nil(row["description"]),
      manual_url: empty_to_nil(row["manual_url"]),
      purchase_price: parse_optional_decimal(row["purchase_price"]),
      current_value: parse_optional_decimal(row["current_value"]),
      manual_pdf_key: empty_to_nil(row["manual_pdf_key"]),
      manual_pdf_filename: empty_to_nil(row["manual_pdf_filename"]),
      manual_pdf_content_type: empty_to_nil(row["manual_pdf_content_type"]),
      manual_pdf_size_bytes: parse_optional_integer(row["manual_pdf_size_bytes"]),
      deleted_at: nil,
      inserted_at: parse_datetime!(row["inserted_at"], "eurorack_modules.inserted_at"),
      updated_at: parse_datetime!(row["updated_at"], "eurorack_modules.updated_at")
    })
  end

  defp insert_video!(row) do
    Repo.insert!(%YoutubeVideo{
      id: parse_integer!(row["id"], "youtube_videos.id"),
      eurorack_module_id:
        parse_integer!(row["eurorack_module_id"], "youtube_videos.eurorack_module_id"),
      url: required_string!(row["url"], "youtube_videos.url"),
      position: parse_integer!(row["position"], "youtube_videos.position"),
      inserted_at: parse_datetime!(row["inserted_at"], "youtube_videos.inserted_at"),
      updated_at: parse_datetime!(row["updated_at"], "youtube_videos.updated_at")
    })
  end

  defp parse_subtypes(nil), do: []
  defp parse_subtypes(""), do: []

  defp parse_subtypes(value) when is_binary(value) do
    value
    |> String.split("|")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  defp empty_to_nil(nil), do: nil
  defp empty_to_nil(""), do: nil
  defp empty_to_nil(value), do: value

  defp required_string!(value, field) do
    case empty_to_nil(value) do
      nil -> raise "Pflichtfeld fehlt: #{field}"
      string -> string
    end
  end

  defp parse_integer!(value, field) do
    case Integer.parse(value |> to_string() |> String.trim()) do
      {int, ""} -> int
      _ -> raise "Ungueltige Ganzzahl in #{field}: #{inspect(value)}"
    end
  end

  defp parse_optional_integer(nil), do: nil
  defp parse_optional_integer(""), do: nil

  defp parse_optional_integer(value) do
    case Integer.parse(value |> to_string() |> String.trim()) do
      {int, ""} -> int
      _ -> raise "Ungueltige Ganzzahl: #{inspect(value)}"
    end
  end

  defp parse_optional_decimal(nil), do: nil
  defp parse_optional_decimal(""), do: nil

  defp parse_optional_decimal(value) do
    case Decimal.parse(value |> to_string() |> String.trim()) do
      {decimal, ""} -> decimal
      _ -> raise "Ungueltiger Dezimalwert: #{inspect(value)}"
    end
  end

  defp parse_datetime!(value, field) do
    value = value |> to_string() |> String.trim()

    cond do
      value == "" ->
        raise "Pflichtfeld fehlt: #{field}"

      match?({:ok, _, _}, DateTime.from_iso8601(value)) ->
        {:ok, dt, _} = DateTime.from_iso8601(value)
        DateTime.truncate(dt, :second)

      match?({:ok, _}, NaiveDateTime.from_iso8601(value)) ->
        {:ok, ndt} = NaiveDateTime.from_iso8601(value)
        ndt |> DateTime.from_naive!("Etc/UTC") |> DateTime.truncate(:second)

      true ->
        raise "Ungueltiger Zeitstempel in #{field}: #{inspect(value)}"
    end
  end

  defp format_import_error(%Ecto.Changeset{} = changeset) do
    "Import fehlgeschlagen: #{inspect(changeset.errors)}"
  end

  defp format_import_error(reason), do: "Import fehlgeschlagen: #{inspect(reason)}"

  defp tmp_dir!(prefix) do
    base =
      Path.join([
        System.tmp_dir!(),
        "module_o_mat_backup_#{prefix}_#{System.unique_integer([:positive])}"
      ])

    File.rm_rf!(base)
    File.mkdir_p!(base)
    base
  end
end
