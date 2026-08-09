defmodule ModuleOMat.Inventory.ManualStorage do
  @moduledoc """
  Oeffentliche Fassade fuer die Persistenz von PDF-Anleitungen.

  Delegiert an den konfigurierten Adapter (Standard:
  `ModuleOMat.Inventory.ManualStorage.LocalDisk`). Prueft vor dem Speichern
  die PDF-Magic-Bytes, damit umbenannte Nicht-PDFs abgelehnt werden.
  """

  alias ModuleOMat.Inventory.ManualStorage.LocalDisk

  @pdf_magic "%PDF-"

  @doc """
  Erzeugt einen neuen, opaken Storage-Key.
  """
  def new_key do
    Ecto.UUID.generate()
  end

  @doc """
  Speichert die Datei unter dem gegebenen Key beim konfigurierten Adapter.

  Wirft `ArgumentError`, wenn die Datei kein PDF zu sein scheint.
  """
  def store!(key, source_path) when is_binary(key) and is_binary(source_path) do
    validate_pdf!(source_path)
    adapter().store!(key, source_path)
  end

  @doc """
  Loescht die Datei mit dem gegebenen Key. Idempotent.
  """
  def delete(nil), do: :ok

  def delete(key) when is_binary(key) do
    adapter().delete(key)
  end

  @doc """
  Liefert die PDF-Datei als HTTP-Antwort aus.
  """
  def serve(conn, key, opts \\ []) when is_binary(key) and is_list(opts) do
    adapter().serve(conn, key, opts)
  end

  @doc """
  Konfigurierter Storage-Adapter.
  """
  def adapter do
    Application.get_env(:module_o_mat, :manual_storage_adapter, LocalDisk)
  end

  defp validate_pdf!(source_path) do
    case File.open(source_path, [:read], &IO.binread(&1, byte_size(@pdf_magic))) do
      {:ok, @pdf_magic} ->
        :ok

      {:ok, _other} ->
        raise ArgumentError, "Datei ist kein PDF (Magic-Bytes fehlen)"

      {:error, reason} ->
        raise File.Error, reason: reason, action: "read file", path: source_path
    end
  end
end
