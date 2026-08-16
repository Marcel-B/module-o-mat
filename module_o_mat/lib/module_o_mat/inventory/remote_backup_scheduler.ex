defmodule ModuleOMat.Inventory.RemoteBackupScheduler do
  @moduledoc """
  Fuehrt das Nextcloud-Backup taeglich zur konfigurierten Uhrzeit aus
  und nach Inventar-Aenderungen zeitversetzt (Debounce).

  Beide Laeufe schreiben dieselbe Wochentags-Datei (`inventory-mon.zip` …
  `inventory-sun.zip`). Waehrend eines Laufs ist die UI im Wartungsmodus,
  damit keine parallelen Writes den Export verfaelschen.

  Statt eines einzelnen 24-Stunden-Timers prueft ein kurzer Tick die
  Wanduhr. Wurde der heutige Lauf verpasst (Neustart, Deploy, Schlaf),
  wird er nachgeholt. Der letzte erfolgreiche Tag wird neben der
  Datenbank persistiert, damit ein Restart nicht doppelt hochlaedt.
  """

  use GenServer

  require Logger

  alias ModuleOMat.Inventory.RemoteBackup

  @pubsub_topic "inventory:maintenance"
  @default_at {3, 0}
  @default_timezone "Europe/Berlin"
  @default_tick_ms :timer.seconds(60)
  @default_retry_after_ms :timer.minutes(15)
  @default_timeout_ms :timer.minutes(20)
  @default_idle_after_ms :timer.minutes(10)
  @default_maintenance_grace_ms :timer.seconds(2)

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
  Abonnieren von Wartungsmodus-Wechseln (`{:maintenance, boolean}`).
  """
  def subscribe do
    Phoenix.PubSub.subscribe(ModuleOMat.PubSub, @pubsub_topic)
  end

  @doc """
  Plant nach einer Inventar-Aenderung ein Backup. Weitere Aufrufe
  innerhalb von `idle_after_ms` setzen den Timer zurueck.
  """
  def schedule_after_change do
    case GenServer.whereis(__MODULE__) do
      nil -> :ok
      pid -> GenServer.cast(pid, :schedule_after_change)
    end
  end

  @doc """
  Reserviert einen Schreibzugriff. Schlaegt im Wartungsmodus fehl.
  """
  def begin_write do
    call_if_alive(:begin_write, :ok)
  end

  @doc """
  Gibt einen zuvor mit `begin_write/0` reservierten Schreibzugriff frei.
  """
  def end_write do
    call_if_alive(:end_write, :ok)
  end

  @doc """
  `true`, wenn gerade ein Backup laeuft bzw. vorbereitet wird.
  """
  def maintenance? do
    call_if_alive(:maintenance?, false)
  end

  @doc """
  Blockiert, bis kein Backup mehr laeuft. Fuer Tests.
  """
  def await_idle(timeout \\ 5_000) do
    call_if_alive(:await_idle, :ok, timeout)
  end

  @doc """
  Aktueller Scheduler-Status fuer die HTTP-API.
  """
  def status do
    call_if_alive(:status, %{maintenance: false, running: false, pending: false})
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
        idle_after_ms: config[:idle_after_ms] || @default_idle_after_ms,
        maintenance_grace_ms: config[:maintenance_grace_ms] || @default_maintenance_grace_ms,
        stamp_path: config[:stamp_path] || default_stamp_path(),
        last_run_date: nil,
        last_failure_at: nil,
        idle_ref: nil,
        maintenance?: false,
        running?: false,
        pending_after_change?: false,
        in_flight_writes: 0,
        backup_kind: nil,
        backup_pid: nil,
        backup_timeout_ref: nil,
        idle_waiters: []
      }

      state = %{state | last_run_date: read_stamp(state.stamp_path)}
      {hour, minute} = state.at

      Logger.info(
        "Nextcloud-Backup-Scheduler aktiv (taeglich #{pad(hour)}:#{pad(minute)} #{state.timezone}, " <>
          "nach Aenderungen #{div(state.idle_after_ms, 60_000)} min)"
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
  def handle_call(:begin_write, _from, %{maintenance?: true} = state) do
    {:reply, {:error, :maintenance}, state}
  end

  def handle_call(:begin_write, _from, %{running?: true} = state) do
    {:reply, {:error, :maintenance}, state}
  end

  def handle_call(:begin_write, _from, state) do
    {:reply, :ok, %{state | in_flight_writes: state.in_flight_writes + 1}}
  end

  def handle_call(:end_write, _from, state) do
    in_flight = max(state.in_flight_writes - 1, 0)
    {:reply, :ok, %{state | in_flight_writes: in_flight}}
  end

  def handle_call(:maintenance?, _from, state) do
    {:reply, state.maintenance? or state.running?, state}
  end

  def handle_call(:await_idle, from, %{running?: true} = state) do
    {:noreply, %{state | idle_waiters: [from | state.idle_waiters]}}
  end

  def handle_call(:await_idle, from, %{maintenance?: true} = state) do
    {:noreply, %{state | idle_waiters: [from | state.idle_waiters]}}
  end

  def handle_call(:await_idle, _from, state) do
    {:reply, :ok, state}
  end

  def handle_call(:status, _from, state) do
    {:reply,
     %{
       maintenance: state.maintenance? or state.running?,
       running: state.running?,
       pending: state.idle_ref != nil or state.pending_after_change?
     }, state}
  end

  @impl true
  def handle_cast(:schedule_after_change, state) do
    cond do
      state.running? or state.maintenance? ->
        {:noreply, %{state | pending_after_change?: true}}

      true ->
        {:noreply, reschedule_idle_backup(state)}
    end
  end

  @impl true
  def handle_info(:tick, state) do
    {:noreply, state |> maybe_run() |> schedule_tick()}
  end

  def handle_info(:run_backup, state) do
    {:noreply, maybe_run(state)}
  end

  def handle_info(:run_idle_backup, state) do
    state = %{state | idle_ref: nil}

    {:noreply,
     if state.maintenance? or state.running? do
       %{state | pending_after_change?: true}
     else
       begin_maintenance_and_backup(state, :idle)
     end}
  end

  def handle_info(:start_backup, state) do
    {:noreply, maybe_execute_backup(state)}
  end

  def handle_info({:backup_finished, pid, result}, %{backup_pid: pid} = state) do
    {:noreply, complete_backup(state, normalize_run_result(result))}
  end

  def handle_info({:backup_finished, _pid, _result}, state) do
    {:noreply, state}
  end

  def handle_info({:backup_timeout, pid}, %{backup_pid: pid} = state) do
    Process.exit(pid, :kill)
    {:noreply, complete_backup(%{state | backup_timeout_ref: nil}, {:error, :timeout})}
  end

  def handle_info({:backup_timeout, _pid}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, :normal}, %{backup_pid: pid} = state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, reason}, %{backup_pid: pid} = state) do
    {:noreply, complete_backup(state, {:error, reason})}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  defp maybe_run(state) do
    now = state.utc_now.()
    local_today = local_date(now, state.timezone)

    cond do
      state.running? or state.maintenance? ->
        state

      state.last_run_date == local_today ->
        state

      not due?(now, state.at, state.timezone) ->
        state

      retry_wait?(state) ->
        state

      true ->
        begin_maintenance_and_backup(state, :daily)
    end
  end

  defp begin_maintenance_and_backup(state, kind) do
    state =
      state
      |> cancel_idle()
      |> Map.merge(%{maintenance?: true, backup_kind: kind})

    broadcast_maintenance(true)

    Logger.info("Nextcloud-Backup startet (#{kind}), UI im Wartungsmodus")

    if state.maintenance_grace_ms > 0 do
      Process.send_after(self(), :start_backup, state.maintenance_grace_ms)
      state
    else
      maybe_execute_backup(state)
    end
  end

  defp maybe_execute_backup(%{maintenance?: false} = state), do: state

  defp maybe_execute_backup(%{in_flight_writes: n} = state) when n > 0 do
    Process.send_after(self(), :start_backup, 50)
    state
  end

  defp maybe_execute_backup(state) do
    start_backup_task(state)
  end

  defp start_backup_task(state) do
    scheduler = self()
    run_fun = state.run_fun

    {:ok, pid} =
      Task.Supervisor.start_child(ModuleOMat.TaskSupervisor, fn ->
        result =
          try do
            run_fun.()
          rescue
            error ->
              {:__backup_exception__, error, __STACKTRACE__}
          end

        send(scheduler, {:backup_finished, self(), result})
      end)

    timeout_ref = Process.send_after(self(), {:backup_timeout, pid}, state.timeout_ms)
    Process.monitor(pid)

    %{state | running?: true, backup_pid: pid, backup_timeout_ref: timeout_ref}
  end

  defp complete_backup(state, result) do
    if state.backup_timeout_ref, do: Process.cancel_timer(state.backup_timeout_ref)

    state = finish_backup(state, result)
    broadcast_maintenance(false)
    reply_idle_waiters(state.idle_waiters)

    state = %{
      state
      | running?: false,
        maintenance?: false,
        backup_kind: nil,
        backup_pid: nil,
        backup_timeout_ref: nil,
        idle_waiters: []
    }

    if state.pending_after_change? do
      reschedule_idle_backup(%{state | pending_after_change?: false})
    else
      state
    end
  end

  defp reply_idle_waiters(waiters) do
    Enum.each(waiters, &GenServer.reply(&1, :ok))
  end

  defp normalize_run_result({:__backup_exception__, error, stack}) do
    Logger.error(
      "Nextcloud-Backup-Job abgestürzt: #{Exception.message(error)}\n" <>
        Exception.format_stacktrace(stack)
    )

    {:error, error}
  end

  defp normalize_run_result({:ok, _} = ok), do: ok
  defp normalize_run_result(:ok), do: {:ok, :ok}
  defp normalize_run_result({:error, _} = error), do: error
  defp normalize_run_result(other), do: {:ok, other}

  defp finish_backup(state, {:ok, _result}) do
    case state.backup_kind do
      :daily ->
        local_today = local_date(state.utc_now.(), state.timezone)
        write_stamp(state.stamp_path, local_today)
        %{state | last_run_date: local_today, last_failure_at: nil}

      _ ->
        %{state | last_failure_at: nil}
    end
  end

  defp finish_backup(state, {:error, reason}) do
    Logger.error("Nextcloud-Backup-Lauf fehlgeschlagen: #{format_reason(reason)}")

    case state.backup_kind do
      :daily ->
        %{state | last_failure_at: System.monotonic_time(:millisecond)}

      _ ->
        state
    end
  end

  defp reschedule_idle_backup(state) do
    state = cancel_idle(state)
    ref = Process.send_after(self(), :run_idle_backup, state.idle_after_ms)
    Logger.debug("Nextcloud-Backup nach Aenderung in #{state.idle_after_ms} ms")
    %{state | idle_ref: ref, pending_after_change?: false}
  end

  defp cancel_idle(%{idle_ref: nil} = state), do: state

  defp cancel_idle(%{idle_ref: ref} = state) do
    Process.cancel_timer(ref)
    %{state | idle_ref: nil}
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

  defp broadcast_maintenance(active?) do
    Phoenix.PubSub.broadcast(ModuleOMat.PubSub, @pubsub_topic, {:maintenance, active?})
  end

  defp call_if_alive(request, default, timeout \\ 5_000) do
    case GenServer.whereis(__MODULE__) do
      nil ->
        default

      pid ->
        try do
          GenServer.call(pid, request, timeout)
        catch
          :exit, _ -> default
        end
    end
  end

  defp pad(number), do: number |> Integer.to_string() |> String.pad_leading(2, "0")

  defp format_reason(%{__exception__: true} = error), do: Exception.message(error)
  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(_), do: false
end
