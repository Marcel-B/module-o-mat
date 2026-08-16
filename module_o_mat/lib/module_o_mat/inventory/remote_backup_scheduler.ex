defmodule ModuleOMat.Inventory.RemoteBackupScheduler do
  @moduledoc """
  Fuehrt das Nextcloud-Backup taeglich zur konfigurierten Uhrzeit aus.

  Statt eines einzelnen 24-Stunden-Timers prueft ein kurzer Tick die
  Wanduhr. Wurde der heutige Lauf verpasst (Neustart, Deploy, Schlaf),
  wird er nachgeholt. Der letzte erfolgreiche Tag wird neben der
  Datenbank persistiert, damit ein Restart nicht doppelt hochlaedt.
  """

  use GenServer

  require Logger

  alias ModuleOMat.Inventory.RemoteBackup

  @default_at {3, 0}
  @default_timezone "Europe/Berlin"
  @default_tick_ms :timer.seconds(60)
  @default_retry_after_ms :timer.minutes(15)
  @default_timeout_ms :timer.minutes(10)

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
        run_fun: config[:run_fun] || (&RemoteBackup.run/0),
        utc_now: config[:utc_now] || (&DateTime.utc_now/0),
        tick_ms: config[:tick_ms] || @default_tick_ms,
        retry_after_ms: config[:retry_after_ms] || @default_retry_after_ms,
        timeout_ms: config[:timeout_ms] || @default_timeout_ms,
        stamp_path: config[:stamp_path] || default_stamp_path(),
        last_run_date: nil,
        last_failure_at: nil
      }

      state = %{state | last_run_date: read_stamp(state.stamp_path)}
      {hour, minute} = state.at

      Logger.info(
        "Nextcloud-Backup-Scheduler aktiv (taeglich #{pad(hour)}:#{pad(minute)} #{state.timezone})"
      )

      {:ok, schedule_tick(state), {:continue, :maybe_run}}
    else
      Logger.info("Nextcloud-Backup-Scheduler deaktiviert")
      :ignore
    end
  end

  @impl true
  def handle_continue(:maybe_run, state) do
    {:noreply, maybe_run(state)}
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, state |> maybe_run() |> schedule_tick()}
  end

  def handle_info(:run_backup, state) do
    {:noreply, maybe_run(state)}
  end

  defp maybe_run(state) do
    now = state.utc_now.()
    local_today = local_date(now, state.timezone)

    cond do
      state.last_run_date == local_today ->
        state

      not due?(now, state.at, state.timezone) ->
        state

      retry_wait?(state) ->
        state

      true ->
        case invoke_run(state) do
          {:ok, _result} ->
            write_stamp(state.stamp_path, local_today)
            %{state | last_run_date: local_today, last_failure_at: nil}

          {:error, reason} ->
            Logger.error("Nextcloud-Backup-Lauf fehlgeschlagen: #{format_reason(reason)}")
            %{state | last_failure_at: System.monotonic_time(:millisecond)}
        end
    end
  end

  defp due?(now, at, timezone) do
    {hour, minute} = at
    local_now = shift_zone!(now, timezone)
    today_run = DateTime.new!(DateTime.to_date(local_now), Time.new!(hour, minute, 0), timezone)
    DateTime.compare(local_now, today_run) != :lt
  end

  defp retry_wait?(%{last_failure_at: nil}), do: false

  defp retry_wait?(state) do
    System.monotonic_time(:millisecond) - state.last_failure_at < state.retry_after_ms
  end

  defp invoke_run(state) do
    task =
      Task.Supervisor.async_nolink(ModuleOMat.TaskSupervisor, fn ->
        try do
          state.run_fun.()
        rescue
          error ->
            {:__backup_exception__, error, __STACKTRACE__}
        end
      end)

    case Task.yield(task, state.timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:__backup_exception__, error, stack}} ->
        Logger.error(
          "Nextcloud-Backup-Job abgestürzt: #{Exception.message(error)}\n" <>
            Exception.format_stacktrace(stack)
        )

        {:error, error}

      {:ok, {:ok, _} = ok} ->
        ok

      {:ok, :ok} ->
        {:ok, :ok}

      {:ok, {:error, _} = error} ->
        error

      {:ok, other} ->
        {:ok, other}

      {:exit, reason} ->
        {:error, reason}

      nil ->
        {:error, :timeout}
    end
  end

  defp schedule_tick(state) do
    Process.send_after(self(), :tick, state.tick_ms)
    state
  end

  defp scheduler_config(opts) do
    Application.get_env(:module_o_mat, RemoteBackup, [])
    |> Enum.into(%{})
    |> Map.merge(Enum.into(opts, %{}))
  end

  defp local_date(now, timezone) do
    now
    |> shift_zone!(timezone)
    |> DateTime.to_date()
  end

  defp shift_zone!(datetime, timezone) do
    case DateTime.shift_zone(datetime, timezone) do
      {:ok, local} ->
        local

      {:error, reason} ->
        raise ArgumentError, "ungueltige Timezone #{inspect(timezone)}: #{inspect(reason)}"
    end
  end

  defp default_stamp_path do
    case Application.get_env(:module_o_mat, ModuleOMat.Repo)[:database] do
      path when is_binary(path) -> Path.join(Path.dirname(path), "last_remote_backup_date")
      _ -> nil
    end
  end

  defp read_stamp(nil), do: nil

  defp read_stamp(path) do
    case File.read(path) do
      {:ok, contents} ->
        case contents |> String.trim() |> Date.from_iso8601() do
          {:ok, date} -> date
          _ -> nil
        end

      {:error, _} ->
        nil
    end
  end

  defp write_stamp(nil, _date), do: :ok

  defp write_stamp(path, %Date{} = date) do
    File.mkdir_p!(Path.dirname(path))
    File.write!(path, Date.to_iso8601(date) <> "\n")
  end

  defp pad(number), do: number |> Integer.to_string() |> String.pad_leading(2, "0")

  defp format_reason(%{__exception__: true} = error), do: Exception.message(error)
  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false
end
