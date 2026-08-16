defmodule ModuleOMatWeb.Api.V1.MaintenanceControllerTest do
  use ModuleOMatWeb.ConnCase, async: false

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.RemoteBackupScheduler

  setup do
    stamp_path =
      Path.join(
        System.tmp_dir!(),
        "remote_backup_stamp_#{System.unique_integer([:positive])}"
      )

    File.write!(stamp_path, "2026-08-16\n")
    on_exit(fn -> File.rm(stamp_path) end)
    %{stamp_path: stamp_path}
  end

  describe "GET /api/v1/maintenance" do
    test "liefert false wenn kein Backup laeuft", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/maintenance")
      assert %{"maintenance" => false} = json_response(conn, 200)
    end
  end

  describe "Wartungsmodus" do
    test "legt nach einem Write ein zeitversetztes Backup an und sperrt weitere Writes", %{
      conn: conn,
      stamp_path: stamp_path
    } do
      test_pid = self()

      run_fun = fn ->
        send(test_pid, {:started, self()})

        receive do
          :go -> {:ok, "inventory-sun.zip"}
        end
      end

      opts = [
        enabled: true,
        base_url: "https://example.test/dav",
        username: "u",
        password: "p",
        at: {3, 0},
        timezone: "Europe/Berlin",
        run_fun: run_fun,
        utc_now: fn -> ~U[2026-08-16 10:00:00Z] end,
        stamp_path: stamp_path,
        tick_ms: 60_000,
        retry_after_ms: 0,
        timeout_ms: 2_000,
        idle_after_ms: 30,
        maintenance_grace_ms: 0
      ]

      assert {:ok, _pid} = start_supervised({RemoteBackupScheduler, opts})

      attrs = %{
        "manufacturer" => "Make Noise",
        "name" => "Maths",
        "hp" => 20,
        "type" => "Envelope"
      }

      conn = post(conn, ~p"/api/v1/modules", %{"module" => attrs})
      assert json_response(conn, 201)

      assert_receive {:started, run_pid}, 1_000
      assert RemoteBackupScheduler.maintenance?()

      blocked = post(build_conn(), ~p"/api/v1/modules", %{"module" => attrs})
      assert %{"error" => message} = json_response(blocked, 503)
      assert message =~ "Datensicherung"

      status_conn = get(build_conn(), ~p"/api/v1/maintenance")
      assert %{"maintenance" => true} = json_response(status_conn, 200)

      send(run_pid, :go)
      assert :ok = RemoteBackupScheduler.await_idle()
      refute RemoteBackupScheduler.maintenance?()
    end

    test "Inventory.create_eurorack_module liefert :maintenance", %{stamp_path: stamp_path} do
      test_pid = self()

      run_fun = fn ->
        send(test_pid, {:started, self()})

        receive do
          :go -> {:ok, "ok"}
        end
      end

      opts = [
        enabled: true,
        base_url: "https://example.test/dav",
        username: "u",
        password: "p",
        at: {3, 0},
        timezone: "Europe/Berlin",
        run_fun: run_fun,
        utc_now: fn -> ~U[2026-08-16 10:00:00Z] end,
        stamp_path: stamp_path,
        tick_ms: 60_000,
        retry_after_ms: 0,
        timeout_ms: 2_000,
        idle_after_ms: 20,
        maintenance_grace_ms: 0
      ]

      assert {:ok, _pid} = start_supervised({RemoteBackupScheduler, opts})
      RemoteBackupScheduler.schedule_after_change()
      assert_receive {:started, run_pid}, 1_000

      assert {:error, :maintenance} =
               Inventory.create_eurorack_module(valid_eurorack_module_attrs())

      send(run_pid, :go)
      assert :ok = RemoteBackupScheduler.await_idle()
    end
  end
end
