defmodule ModuleOMat.Inventory.ManualStorage.LocalDisk do
  @moduledoc """
  Speichert PDF-Anleitungen als Dateien auf dem lokalen Dateisystem.
  """

  @behaviour ModuleOMat.Inventory.ManualStorage.Adapter

  import Plug.Conn

  @impl true
  def store!(key, source_path) when is_binary(key) and is_binary(source_path) do
    dest = path_for(key)
    File.mkdir_p!(Path.dirname(dest))
    File.cp!(source_path, dest)
    :ok
  end

  @impl true
  def delete(key) when is_binary(key) do
    case File.rm(path_for(key)) do
      :ok ->
        :ok

      {:error, :enoent} ->
        :ok

      {:error, reason} ->
        raise File.Error, reason: reason, action: "delete file", path: path_for(key)
    end
  end

  @impl true
  def serve(conn, key, opts) when is_binary(key) do
    path = path_for(key)
    content_type = Keyword.get(opts, :content_type, "application/pdf")
    filename = Keyword.get(opts, :filename) || "#{key}.pdf"

    if File.exists?(path) do
      conn
      |> put_resp_content_type(content_type)
      |> put_resp_header(
        "content-disposition",
        ~s(inline; filename="#{sanitize_filename(filename)}")
      )
      |> send_file(200, path)
    else
      send_resp(conn, 404, "Keine Anleitung gefunden.")
    end
  end

  @impl true
  def copy_out!(key, dest_path) when is_binary(key) and is_binary(dest_path) do
    source = path_for(key)

    if File.exists?(source) do
      File.mkdir_p!(Path.dirname(dest_path))
      File.cp!(source, dest_path)
      :ok
    else
      raise File.Error, reason: :enoent, action: "copy file", path: source
    end
  end

  @impl true
  def replace_all!(source_dir) when is_binary(source_dir) do
    unless File.dir?(source_dir) do
      raise ArgumentError, "Quellverzeichnis existiert nicht: #{source_dir}"
    end

    dest = upload_dir()
    File.mkdir_p!(dest)

    dest
    |> File.ls!()
    |> Enum.each(fn name ->
      path = Path.join(dest, name)
      File.rm_rf!(path)
    end)

    source_dir
    |> File.ls!()
    |> Enum.each(fn name ->
      from = Path.join(source_dir, name)
      to = Path.join(dest, name)

      if File.regular?(from) do
        File.cp!(from, to)
      end
    end)

    :ok
  end

  @impl true
  def exists?(key) when is_binary(key) do
    File.exists?(path_for(key))
  end

  @doc """
  Absoluter Pfad zur Datei mit dem gegebenen Key.
  """
  def path_for(key) when is_binary(key) do
    Path.join(upload_dir(), key)
  end

  @doc """
  Verzeichnis, in dem die PDF-Dateien abgelegt werden.
  """
  def upload_dir do
    Application.get_env(:module_o_mat, :manual_uploads_dir) ||
      Path.join(:code.priv_dir(:module_o_mat), "static/uploads/manuals")
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/["\\\r\n]/, "_")
    |> String.trim()
    |> case do
      "" -> "manual.pdf"
      sanitized -> sanitized
    end
  end
end
