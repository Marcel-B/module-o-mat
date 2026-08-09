defmodule ModuleOMatWeb.ManualControllerTest do
  use ModuleOMatWeb.ConnCase

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.ManualStorage.LocalDisk

  @fixture Path.expand("../../support/fixtures/files/sample.pdf", __DIR__)

  describe "GET /eurorack_modules/:id/manual" do
    test "liefert die PDF-Datei inline aus", %{conn: conn} do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, with_manual} =
               Inventory.attach_manual(eurorack_module, %{
                 tmp_path: @fixture,
                 filename: "maths-manual.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(@fixture).size
               })

      conn = get(conn, ~p"/eurorack_modules/#{with_manual.id}/manual")

      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/pdf"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "inline"
      assert get_resp_header(conn, "content-disposition") |> hd() =~ "maths-manual.pdf"
      assert conn.resp_body =~ "%PDF-"
    end

    test "liefert 404, wenn keine Anleitung hinterlegt ist", %{conn: conn} do
      eurorack_module = eurorack_module_fixture()

      conn = get(conn, ~p"/eurorack_modules/#{eurorack_module.id}/manual")

      assert conn.status == 404
      assert conn.resp_body =~ "Keine Anleitung gefunden"
    end

    test "liefert 404, wenn die Datei im Storage fehlt", %{conn: conn} do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, with_manual} =
               Inventory.attach_manual(eurorack_module, %{
                 tmp_path: @fixture,
                 filename: "missing.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(@fixture).size
               })

      File.rm!(LocalDisk.path_for(with_manual.manual_pdf_key))

      conn = get(conn, ~p"/eurorack_modules/#{with_manual.id}/manual")

      assert conn.status == 404
    end

    test "liefert 404 fuer unbekannte Modul-IDs", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/eurorack_modules/999999/manual")
      end
    end
  end
end
