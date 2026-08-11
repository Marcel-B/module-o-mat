defmodule ModuleOMat.Inventory.RemoteBackup do
  @moduledoc """
  Erzeugt ein Inventar-ZIP und laedt es per WebDAV nach Nextcloud hoch.

  Retention: genau sieben feste Wochentags-Dateien (`inventory-mon.zip` …
  `inventory-sun.zip`); der aktuelle Wochentag wird ueberschrieben.
  """

  require Logger

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.WebDAV

  @weekday_names %{
    1 => "mon",
    2 => "tue",
    3 => "wed",
    4 => "thu",
    5 => "fri",
    6 => "sat",
    7 => "sun"
  }

  @doc """
  Fuehrt Export und Upload aus.

  Ohne Optionen wird die Runtime-Config unter
  `:module_o_mat, ModuleOMat.Inventory.RemoteBackup` gelesen.
  """
  def run(opts \\ []) when is_list(opts) do
    config = config(opts)

    if config[:enabled] do
      do_run(config)
    else
      {:error, :disabled}
    end
  end

  @doc """
  Dateiname fuer den Wochentag von `datetime` in der konfigurierten Timezone.
  """
  def weekday_filename(datetime, timezone) when is_binary(timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, local} ->
        "inventory-#{Map.fetch!(@weekday_names, Date.day_of_week(local))}.zip"

      {:error, reason} ->
        raise ArgumentError, "ungueltige Timezone #{inspect(timezone)}: #{inspect(reason)}"
    end
  end

  defp do_run(config) do
    with :ok <- validate_config(config) do
      filename = weekday_filename(DateTime.utc_now(), config.timezone)
      tmp_path = tmp_zip_path(filename)
      webdav_opts = webdav_opts(config)

      try do
        with :ok <- maybe_ensure_collection(config, webdav_opts),
             {:ok, ^tmp_path} <- Inventory.export_backup(tmp_path),
             :ok <- WebDAV.put_file(config.base_url, filename, tmp_path, webdav_opts) do
          Logger.info("Nextcloud-Backup hochgeladen: #{filename}")
          {:ok, filename}
        else
          {:error, reason} ->
            Logger.error("Nextcloud-Backup fehlgeschlagen: #{format_reason(reason)}")
            {:error, reason}
        end
      after
        File.rm(tmp_path)
      end
    end
  end

  defp validate_config(config) do
    cond do
      not present?(config.base_url) ->
        {:error, "NEXTCLOUD_WEBDAV_URL fehlt"}

      not present?(config.username) ->
        {:error, "NEXTCLOUD_USERNAME fehlt"}

      not present?(config.password) ->
        {:error, "NEXTCLOUD_APP_PASSWORD fehlt"}

      true ->
        :ok
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false

  defp maybe_ensure_collection(config, webdav_opts) do
    if config[:ensure_collection] do
      WebDAV.ensure_collection(config[:base_url], webdav_opts)
    else
      :ok
    end
  end

  defp webdav_opts(config) do
    [
      username: config.username,
      password: config.password,
      req_options: config.req_options
    ]
  end

  defp config(overrides) do
    Application.get_env(:module_o_mat, __MODULE__, [])
    |> Enum.into(%{})
    |> Map.merge(Map.new(overrides))
    |> Map.put_new(:enabled, false)
    |> Map.put_new(:timezone, "Europe/Berlin")
    |> Map.put_new(:ensure_collection, true)
    |> Map.put_new(:req_options, [])
    |> Map.put_new(:base_url, nil)
    |> Map.put_new(:username, nil)
    |> Map.put_new(:password, nil)
    |> then(fn map -> Map.update!(map, :base_url, &normalize_base_url/1) end)
  end

  defp normalize_base_url(nil), do: nil
  defp normalize_base_url(url) when is_binary(url), do: String.trim_trailing(url, "/")

  defp tmp_zip_path(filename) do
    Path.join(
      System.tmp_dir!(),
      "module_o_mat_remote_#{Path.rootname(filename)}_#{System.unique_integer([:positive])}.zip"
    )
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
