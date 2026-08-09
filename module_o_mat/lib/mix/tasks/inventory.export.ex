defmodule Mix.Tasks.Inventory.Export do
  @shortdoc "Exportiert das Inventar als ZIP-Backup"

  @moduledoc """
  Exportiert Module, Typen, YouTube-Videos und Manual-PDFs als ZIP.

      mix inventory.export
      mix inventory.export path/to/backup.zip

  Ohne Pfad wird die Datei unter `priv/backups/inventory-YYYYMMDD-HHMMSS.zip`
  abgelegt.
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    path =
      case args do
        [custom] -> custom
        [] -> default_path()
        _ -> Mix.raise("Usage: mix inventory.export [pfad.zip]")
      end

    case ModuleOMat.Inventory.export_backup(path) do
      {:ok, written} ->
        Mix.shell().info("Backup geschrieben: #{Path.expand(written)}")

      {:error, reason} ->
        Mix.raise("Export fehlgeschlagen: #{reason}")
    end
  end

  defp default_path do
    stamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d-%H%M%S")
    Path.join(["priv", "backups", "inventory-#{stamp}.zip"])
  end
end
