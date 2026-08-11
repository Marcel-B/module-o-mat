defmodule ModuleOMat.Inventory.RemoteBackupScheduler do
  @moduledoc """
  Plant taeglich ein Nextcloud-Backup zur konfigurierten Uhrzeit.

  Startet nur, wenn Remote-Backup aktiviert und vollstaendig konfiguriert ist.
  """

  use GenServer

  require Logger

  alias ModuleOMat.Inventory.RemoteBackup

  @default_at {3, 0}
  @default_timezone "Europe/Berlin"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  `true`, wenn Scheduler laut Config gestartet werden soll.
  """
  def enabled?(config \\ Application.get_env(:module_o_mat, RemoteBackup, [])) do
    config = Enum.into(config, %{})

    config[:enabled] == true and
      present?(config[:base_url]) and
      present?(config[:username]) and
      present?(config[:password])
  end

  @doc """
  Millisekunden bis zur naechsten Ausfuehrung von `at` in `timezone`.
  """
  def ms_until_next_run(
        now \\ DateTime.utc_now(),
        at \\ @default_at,
        timezone \\ @default_timezone
      ) do
    {hour, minute} = at

    with {:ok, local_now} <- DateTime.shift_zone(now, timezone),
         {:ok, today_run} <-
           DateTime.new(DateTime.to_date(local_now), Time.new!(hour, minute, 0), timezone) do
      next_run =
        if DateTime.compare(local_now, today_run) == :lt do
          today_run
        else
          today_run
          |> DateTime.to_date()
          |> Date.add(1)
          |> then(&DateTime.new!(&1, Time.new!(hour, minute, 0), timezone))
        end

      max(DateTime.diff(next_run, local_now, :millisecond), 0)
    else
      {:error, reason} ->
        raise ArgumentError,
              "ungueltige Backup-Zeit/Timezone #{inspect(at)}/#{inspect(timezone)}: #{inspect(reason)}"
    end
  end

  @impl true
  def init(opts) do
    config = scheduler_config(opts)

    if enabled?(config) do
      state = %{
        at: config[:at] || @default_at,
        timezone: config[:timezone] || @default_timezone,
        run_fun: config[:run_fun] || (&RemoteBackup.run/0)
      }

      {:ok, schedule_next(state)}
    else
      Logger.info("Nextcloud-Backup-Scheduler deaktiviert")
      :ignore
    end
  end

  @impl true
  def handle_info(:run_backup, state) do
    try do
      _ = state.run_fun.()
    rescue
      error ->
        Logger.error(
          "Nextcloud-Backup-Job abgestürzt: #{Exception.message(error)}\n" <>
            Exception.format_stacktrace(__STACKTRACE__)
        )
    end

    {:noreply, schedule_next(state)}
  end

  defp schedule_next(state) do
    delay = ms_until_next_run(DateTime.utc_now(), state.at, state.timezone)
    Process.send_after(self(), :run_backup, delay)
    Logger.info("Nextcloud-Backup geplant in #{div(delay, 1000)}s")
    state
  end

  defp scheduler_config(opts) do
    Application.get_env(:module_o_mat, RemoteBackup, [])
    |> Enum.into(%{})
    |> Map.merge(Enum.into(opts, %{}))
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false
end
