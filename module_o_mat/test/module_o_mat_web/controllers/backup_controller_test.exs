defmodule ModuleOMatWeb.BackupControllerTest do
  use ModuleOMatWeb.ConnCase

  import ModuleOMat.InventoryFixtures

  describe "GET /backup/export" do
    test "liefert eine ZIP-Datei", %{conn: conn} do
      eurorack_module_fixture()

      conn = get(conn, ~p"/backup/export")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/zip"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "attachment"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "inventory-"
      assert is_binary(conn.resp_body)
      assert byte_size(conn.resp_body) > 0
    end
  end
end
