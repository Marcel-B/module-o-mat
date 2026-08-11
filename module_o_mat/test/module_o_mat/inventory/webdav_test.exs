defmodule ModuleOMat.Inventory.WebDAVTest do
  use ExUnit.Case, async: true

  alias ModuleOMat.Inventory.WebDAV

  setup do
    tmp =
      Path.join(
        System.tmp_dir!(),
        "webdav_upload_#{System.unique_integer([:positive])}.zip"
      )

    File.write!(tmp, "zip-bytes")
    on_exit(fn -> File.rm(tmp) end)
    %{tmp: tmp}
  end

  test "put_file sendet PUT mit Basic Auth", %{tmp: tmp} do
    Req.Test.stub(ModuleOMat.Inventory.WebDAV, fn conn ->
      assert conn.method == "PUT"
      assert String.ends_with?(conn.request_path, "/inventory-mon.zip")
      assert Plug.Conn.get_req_header(conn, "authorization") != []
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      assert body == "zip-bytes"
      Plug.Conn.send_resp(conn, 201, "")
    end)

    assert :ok =
             WebDAV.put_file(
               "http://nextcloud.test/remote.php/dav/files/user/Backups/module-o-mat",
               "inventory-mon.zip",
               tmp,
               username: "user",
               password: "app-pass",
               req_options: [plug: {Req.Test, ModuleOMat.Inventory.WebDAV}]
             )
  end

  test "put_file meldet HTTP-Fehler", %{tmp: tmp} do
    Req.Test.stub(ModuleOMat.Inventory.WebDAV, fn conn ->
      Plug.Conn.send_resp(conn, 401, "unauthorized")
    end)

    assert {:error, reason} =
             WebDAV.put_file(
               "http://nextcloud.test/dav",
               "inventory-mon.zip",
               tmp,
               username: "user",
               password: "bad",
               req_options: [plug: {Req.Test, ModuleOMat.Inventory.WebDAV}]
             )

    assert reason =~ "401"
  end

  test "ensure_collection akzeptiert vorhandene Ordner" do
    Req.Test.stub(ModuleOMat.Inventory.WebDAV, fn conn ->
      assert conn.method == "MKCOL"
      Plug.Conn.send_resp(conn, 405, "already exists")
    end)

    assert :ok =
             WebDAV.ensure_collection(
               "http://nextcloud.test/dav/Backups/module-o-mat",
               username: "user",
               password: "app-pass",
               req_options: [plug: {Req.Test, ModuleOMat.Inventory.WebDAV}]
             )
  end
end
