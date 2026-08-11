defmodule ModuleOMat.Inventory.RemoteBackupSchedulerTest do
  use ExUnit.Case, async: false

  alias ModuleOMat.Inventory.RemoteBackupScheduler

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

  test "Scheduler fuehrt run_fun aus und plant erneut" do
    test_pid = self()

    run_fun = fn ->
      send(test_pid, :backup_ran)
      {:ok, "inventory-mon.zip"}
    end

    assert {:ok, pid} =
             start_supervised(
               {RemoteBackupScheduler,
                [
                  enabled: true,
                  base_url: "https://example.test/dav",
                  username: "u",
                  password: "p",
                  at: {3, 0},
                  timezone: "Europe/Berlin",
                  run_fun: run_fun
                ]}
             )

    send(pid, :run_backup)
    assert_receive :backup_ran, 1_000
  end
end
