defmodule Mix.Tasks.Inventory.Import do
  @shortdoc "Importiert ein Inventar-ZIP-Backup (ersetzt alle Daten)"

  @moduledoc """
  Stellt ein Inventar-Backup wieder her und ersetzt dabei den gesamten Bestand.

      mix inventory.import path/to/backup.zip
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    path =
      case args do
        [custom] -> custom
        _ -> Mix.raise("Usage: mix inventory.import pfad.zip")
      end

    case ModuleOMat.Inventory.import_backup(path) do
      :ok ->
        Mix.shell().info("Backup importiert: #{Path.expand(path)}")

      {:error, reason} ->
        Mix.raise("Import fehlgeschlagen: #{reason}")
    end
  end
end
