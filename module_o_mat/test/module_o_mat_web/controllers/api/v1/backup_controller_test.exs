defmodule ModuleOMatWeb.Api.V1.BackupControllerTest do
  use ModuleOMatWeb.ConnCase

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory

  describe "GET /api/v1/backup/export" do
    test "liefert eine ZIP-Datei", %{conn: conn} do
      eurorack_module_fixture()

      conn = get(conn, ~p"/api/v1/backup/export")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/zip"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "inventory-"
      assert is_binary(conn.resp_body)
      assert byte_size(conn.resp_body) > 0
    end
  end

  describe "POST /api/v1/backup/import" do
    test "ersetzt den Bestand aus einem ZIP", %{conn: conn} do
      original = eurorack_module_fixture(%{name: "Maths"})

      zip_path =
        Path.join(System.tmp_dir!(), "module_o_mat_api_backup_#{System.unique_integer()}.zip")

      try do
        assert {:ok, ^zip_path} = Inventory.export_backup(zip_path)

        _other =
          eurorack_module_fixture(%{
            manufacturer: "Other",
            name: "Noise",
            type: "Utility"
          })

        upload = %Plug.Upload{
          path: zip_path,
          filename: "inventory.zip",
          content_type: "application/zip"
        }

        conn = post(conn, ~p"/api/v1/backup/import", %{"file" => upload})
        assert %{"imported" => true} = json_response(conn, 200)

        names =
          Inventory.list_eurorack_modules()
          |> Enum.map(& &1.name)
          |> Enum.sort()

        assert names == ["Maths"]
        assert Inventory.get_eurorack_module!(original.id).name == "Maths"
      after
        File.rm(zip_path)
      end
    end

    test "lehnt fehlende Datei ab", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/backup/import", %{})
      assert %{"error" => _} = json_response(conn, 422)
    end
  end

  describe "GET /api/v1/backup/history" do
    test "liefert eine Seite mit fuenf Eintraegen und Status", %{conn: conn} do
      for n <- 1..6 do
        backup_run_fixture(%{
          filename: "inventory-#{n}.zip",
          size_bytes: n * 100,
          success: n != 3
        })
      end

      conn = get(conn, ~p"/api/v1/backup/history")
      body = json_response(conn, 200)

      assert body["page"] == 1
      assert body["per_page"] == 5
      assert body["total"] == 6
      assert length(body["backup_runs"]) == 5
      assert body["last_success_at"]
      assert body["last_failure_at"]

      [first | _] = body["backup_runs"]
      assert first["filename"] == "inventory-6.zip"
      assert first["success"] == true
      assert first["size_bytes"] == 600
      assert first["occurred_at"]
    end

    test "laedt die naechste Seite vom Server", %{conn: conn} do
      for n <- 1..6 do
        backup_run_fixture(%{filename: "inventory-#{n}.zip"})
      end

      conn = get(conn, ~p"/api/v1/backup/history", %{"page" => "2"})
      body = json_response(conn, 200)

      assert body["page"] == 2
      assert length(body["backup_runs"]) == 1
      assert hd(body["backup_runs"])["filename"] == "inventory-1.zip"
    end
  end
end
