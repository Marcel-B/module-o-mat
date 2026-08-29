defmodule ModuleOMat.Inventory.RemoteBackupTest do
  use ModuleOMat.DataCase, async: false

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.RemoteBackup

  test "weekday_filename nutzt Timezone fuer Wochentag" do
    # 2026-08-10 22:00 UTC = 2026-08-11 00:00 Europe/Berlin (Dienstag)
    dt = ~U[2026-08-10 22:00:00Z]
    assert RemoteBackup.weekday_filename(dt, "Europe/Berlin") == "inventory-tue.zip"
    assert RemoteBackup.weekday_filename(dt, "UTC") == "inventory-mon.zip"
  end

  test "run ist deaktiviert ohne enabled-Flag" do
    assert {:error, :disabled} = RemoteBackup.run(enabled: false)
    assert Inventory.list_backup_runs().total == 0
  end

  test "run exportiert und laedt Wochentags-ZIP hoch" do
    _module = eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths", hp: 20})

    filename = RemoteBackup.weekday_filename(DateTime.utc_now(), "Europe/Berlin")
    test_pid = self()

    Req.Test.stub(ModuleOMat.Inventory.WebDAV, fn conn ->
      cond do
        conn.method == "MKCOL" ->
          Plug.Conn.send_resp(conn, 201, "")

        conn.method == "PUT" ->
          assert String.ends_with?(conn.request_path, "/#{filename}")
          {:ok, body, conn} = Plug.Conn.read_body(conn)
          assert byte_size(body) > 0
          send(test_pid, {:uploaded, filename, byte_size(body)})
          Plug.Conn.send_resp(conn, 201, "")
      end
    end)

    assert {:ok, ^filename} =
             RemoteBackup.run(
               enabled: true,
               base_url: "http://nextcloud.test/dav/Backups/module-o-mat",
               username: "user",
               password: "app-pass",
               timezone: "Europe/Berlin",
               ensure_collection: true,
               req_options: [plug: {Req.Test, ModuleOMat.Inventory.WebDAV}]
             )

    assert_received {:uploaded, ^filename, size} when size > 0

    page = Inventory.list_backup_runs()
    assert page.total == 1
    [run] = page.backup_runs
    assert run.filename == filename
    assert run.size_bytes == size
    assert run.success
  end

  test "run meldet fehlende Credentials" do
    assert {:error, "NEXTCLOUD_WEBDAV_URL fehlt"} =
             RemoteBackup.run(
               enabled: true,
               base_url: nil,
               username: "user",
               password: "secret"
             )

    page = Inventory.list_backup_runs()
    assert page.total == 1
    [run] = page.backup_runs
    refute run.success
    assert run.filename
    assert run.size_bytes == nil
  end
end
