defmodule Mix.Tasks.Inventory.RemoteBackup do
  @shortdoc "Laedt jetzt ein Inventar-Backup nach Nextcloud hoch"

  @moduledoc """
  Fuehrt den Nextcloud-WebDAV-Upload sofort aus (derselbe Job wie der
  taegliche Scheduler). Der Dateiname richtet sich nach dem Wochentag.

      mix inventory.remote_backup
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    unless args == [] do
      Mix.raise("Usage: mix inventory.remote_backup")
    end

    Mix.Task.run("app.start")

    case ModuleOMat.Inventory.RemoteBackup.run() do
      {:ok, filename} ->
        Mix.shell().info("Backup hochgeladen: #{filename}")

      {:error, reason} ->
        Mix.raise("Remote-Backup fehlgeschlagen: #{format(reason)}")
    end
  end

  defp format(reason) when is_binary(reason), do: reason
  defp format(reason), do: inspect(reason)
end
