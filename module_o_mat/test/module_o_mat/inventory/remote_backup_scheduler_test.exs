defmodule ModuleOMat.Inventory.RemoteBackupSchedulerTest do
  use ExUnit.Case, async: false

  alias ModuleOMat.Inventory.RemoteBackupScheduler

  setup do
    stamp_path =
      Path.join(
        System.tmp_dir!(),
        "remote_backup_stamp_#{System.unique_integer([:positive])}"
      )

    on_exit(fn -> File.rm(stamp_path) end)
    %{stamp_path: stamp_path}
  end

  test "enabled? erfordert Flag und Credentials" do
    refute RemoteBackupScheduler.enabled?([])
    refute RemoteBackupScheduler.enabled?(enabled: true, base_url: "https://x", username: "u")

    assert RemoteBackupScheduler.enabled?(
             enabled: true,
             base_url: "https://x/dav",
             username: "u",
             password: "p"
           )
  end

  test "ms_until_next_run plant heute wenn Uhrzeit noch bevorsteht" do
    # Europe/Berlin Sommerzeit: 2026-08-10 01:00 UTC = 03:00 CEST
    now = ~U[2026-08-10 00:30:00Z]
    ms = RemoteBackupScheduler.ms_until_next_run(now, {3, 0}, "Europe/Berlin")
    # 30 Minuten bis 03:00 Berlin
    assert_in_delta ms, 30 * 60 * 1000, 1000
  end

  test "ms_until_next_run plant Folgetag wenn Uhrzeit vorbei ist" do
    # 04:00 Berlin = 02:00 UTC im August
    now = ~U[2026-08-10 02:30:00Z]
    ms = RemoteBackupScheduler.ms_until_next_run(now, {3, 0}, "Europe/Berlin")
    # ~22.5 Stunden bis naechsten Tag 03:00
    assert ms > 22 * 60 * 60 * 1000
    assert ms < 24 * 60 * 60 * 1000
  end

  test "Scheduler startet nicht wenn deaktiviert" do
    assert :ignore =
             RemoteBackupScheduler.start_link(
               enabled: false,
               base_url: "https://x",
               username: "u",
               password: "p"
             )
  end

  test "holt den Lauf nach wenn der Start nach der Sollzeit liegt", %{stamp_path: stamp_path} do
    test_pid = self()

    run_fun = fn ->
      send(test_pid, :backup_ran)
      {:ok, "inventory-sun.zip"}
    end

    assert {:ok, pid} =
             start_supervised(
               {RemoteBackupScheduler,
                scheduler_opts(stamp_path, run_fun, ~U[2026-08-16 10:00:00Z])}
             )

    _ = :sys.get_state(pid)
    assert_receive :backup_ran, 1_000
    assert :ok = RemoteBackupScheduler.await_idle()
    assert File.read!(stamp_path) |> String.trim() == "2026-08-16"
  end

  test "laeuft nicht vor der Sollzeit", %{stamp_path: stamp_path} do
    test_pid = self()

    run_fun = fn ->
      send(test_pid, :backup_ran)
      {:ok, "inventory-sun.zip"}
    end

    assert {:ok, pid} =
             start_supervised(
               {RemoteBackupScheduler,
                scheduler_opts(stamp_path, run_fun, ~U[2026-08-16 00:00:00Z])}
             )

    _ = :sys.get_state(pid)
    refute_receive :backup_ran, 150
  end

  test "laeuft denselben lokalen Tag nicht zweimal", %{stamp_path: stamp_path} do
    test_pid = self()

    run_fun = fn ->
      send(test_pid, :backup_ran)
      {:ok, "inventory-sun.zip"}
    end

    assert {:ok, pid} =
             start_supervised(
               {RemoteBackupScheduler,
                scheduler_opts(stamp_path, run_fun, ~U[2026-08-16 10:00:00Z])}
             )

    _ = :sys.get_state(pid)
    assert_receive :backup_ran, 1_000
    assert :ok = RemoteBackupScheduler.await_idle()

    send(pid, :tick)
    _ = :sys.get_state(pid)
    refute_receive :backup_ran, 150
  end

  test "laeuft am naechsten Tag erneut", %{stamp_path: stamp_path} do
    test_pid = self()
    {:ok, now_agent} = Agent.start_link(fn -> ~U[2026-08-16 10:00:00Z] end)

    run_fun = fn ->
      send(test_pid, :backup_ran)
      {:ok, "ok"}
    end

    opts =
      stamp_path
      |> scheduler_opts(run_fun, fn -> Agent.get(now_agent, & &1) end)
      |> Keyword.put(:tick_ms, 60_000)

    assert {:ok, pid} = start_supervised({RemoteBackupScheduler, opts})
    _ = :sys.get_state(pid)
    assert_receive :backup_ran, 1_000
    assert :ok = RemoteBackupScheduler.await_idle()

    Agent.update(now_agent, fn _ -> ~U[2026-08-17 10:00:00Z] end)
    send(pid, :tick)
    _ = :sys.get_state(pid)
    assert_receive :backup_ran, 1_000
  end

  test "Scheduler bleibt bei Exception im Job am Leben", %{stamp_path: stamp_path} do
    test_pid = self()

    run_fun = fn ->
      send(test_pid, :about_to_raise)
      raise "boom"
    end

    opts =
      stamp_path
      |> scheduler_opts(run_fun, ~U[2026-08-16 10:00:00Z])
      |> Keyword.put(:retry_after_ms, 60_000)

    assert {:ok, pid} = start_supervised({RemoteBackupScheduler, opts})

    _ = :sys.get_state(pid)
    assert_receive :about_to_raise, 1_000
    assert :ok = RemoteBackupScheduler.await_idle()
    assert %{at: {3, 0}} = :sys.get_state(pid)
  end

  test "ueberspringt Catch-up wenn der Stamp von heute schon existiert", %{stamp_path: stamp_path} do
    File.write!(stamp_path, "2026-08-16\n")
    test_pid = self()

    run_fun = fn ->
      send(test_pid, :backup_ran)
      {:ok, "inventory-sun.zip"}
    end

    assert {:ok, pid} =
             start_supervised(
               {RemoteBackupScheduler,
                scheduler_opts(stamp_path, run_fun, ~U[2026-08-16 10:00:00Z])}
             )

    _ = :sys.get_state(pid)
    refute_receive :backup_ran, 150
  end

  test "plant nach Aenderung ein Backup und debounce't weitere Aufrufe", %{stamp_path: stamp_path} do
    File.write!(stamp_path, "2026-08-16\n")
    test_pid = self()

    run_fun = fn ->
      send(test_pid, :backup_ran)
      {:ok, "inventory-sun.zip"}
    end

    opts =
      stamp_path
      |> scheduler_opts(run_fun, ~U[2026-08-16 10:00:00Z])
      |> Keyword.merge(idle_after_ms: 80, maintenance_grace_ms: 0)

    assert {:ok, pid} = start_supervised({RemoteBackupScheduler, opts})
    _ = :sys.get_state(pid)

    RemoteBackupScheduler.schedule_after_change()
    _ = :sys.get_state(pid)
    RemoteBackupScheduler.schedule_after_change()
    _ = :sys.get_state(pid)
    refute_receive :backup_ran, 40
    assert_receive :backup_ran, 500
    assert :ok = RemoteBackupScheduler.await_idle()
    refute RemoteBackupScheduler.maintenance?()
    assert File.read!(stamp_path) |> String.trim() == "2026-08-16"
  end

  test "begin_write ist waehrend des Backups gesperrt", %{stamp_path: stamp_path} do
    File.write!(stamp_path, "2026-08-16\n")
    test_pid = self()

    run_fun = fn ->
      send(test_pid, {:started, self()})

      receive do
        :go -> {:ok, "inventory-sun.zip"}
      end
    end

    opts =
      stamp_path
      |> scheduler_opts(run_fun, ~U[2026-08-16 10:00:00Z])
      |> Keyword.merge(idle_after_ms: 20, timeout_ms: 2_000)

    assert {:ok, _pid} = start_supervised({RemoteBackupScheduler, opts})
    RemoteBackupScheduler.schedule_after_change()
    assert_receive {:started, run_pid}, 1_000
    assert RemoteBackupScheduler.maintenance?()
    assert {:error, :maintenance} = RemoteBackupScheduler.begin_write()
    send(run_pid, :go)
    assert :ok = RemoteBackupScheduler.await_idle()
    refute RemoteBackupScheduler.maintenance?()
  end

  test "Idle-Backup laesst den taeglichen Stamp unangetastet", %{stamp_path: stamp_path} do
    test_pid = self()

    run_fun = fn ->
      send(test_pid, :backup_ran)
      {:ok, "inventory-sun.zip"}
    end

    opts =
      stamp_path
      |> scheduler_opts(run_fun, ~U[2026-08-16 00:00:00Z])
      |> Keyword.merge(idle_after_ms: 20)

    assert {:ok, pid} = start_supervised({RemoteBackupScheduler, opts})
    _ = :sys.get_state(pid)
    RemoteBackupScheduler.schedule_after_change()
    assert_receive :backup_ran, 1_000
    assert :ok = RemoteBackupScheduler.await_idle()
    refute File.exists?(stamp_path)
  end

  defp scheduler_opts(stamp_path, run_fun, utc_now) do
    utc_now_fun =
      case utc_now do
        %DateTime{} = datetime -> fn -> datetime end
        fun when is_function(fun, 0) -> fun
      end

    [
      enabled: true,
      base_url: "https://example.test/dav",
      username: "u",
      password: "p",
      at: {3, 0},
      timezone: "Europe/Berlin",
      run_fun: run_fun,
      utc_now: utc_now_fun,
      stamp_path: stamp_path,
      tick_ms: 60_000,
      retry_after_ms: 0,
      timeout_ms: 1_000,
      idle_after_ms: 60_000,
      maintenance_grace_ms: 0
    ]
  end
end
