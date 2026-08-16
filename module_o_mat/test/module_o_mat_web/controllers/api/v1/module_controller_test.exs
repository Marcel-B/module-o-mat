defmodule ModuleOMatWeb.Api.V1.ModuleControllerTest do
  use ModuleOMatWeb.ConnCase

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory

  @fixture Path.expand("../../../../support/fixtures/files/sample.pdf", __DIR__)

  describe "GET /api/v1/modules" do
    test "listet Module inkl. Stats und Filter", %{conn: conn} do
      maths =
        eurorack_module_fixture(%{
          manufacturer: "Make Noise",
          name: "Maths",
          hp: 20,
          type: "Envelope",
          purchase_price: "289.00"
        })

      _clouds =
        eurorack_module_fixture(%{
          manufacturer: "Mutable",
          name: "Clouds",
          hp: 18,
          type: "Granular"
        })

      conn = get(conn, ~p"/api/v1/modules?q=Maths")

      assert %{"modules" => [entry], "stats" => stats} = json_response(conn, 200)
      assert entry["id"] == maths.id
      assert entry["type"] == "Envelope"
      assert entry["has_manual"] == false
      assert stats["count"] == 1
      assert stats["total_hp"] == 20
    end

    test "filtert nach Typ", %{conn: conn} do
      eurorack_module_fixture(%{name: "Maths", type: "Envelope"})
      eurorack_module_fixture(%{name: "Clouds", type: "Granular"})

      conn = get(conn, ~p"/api/v1/modules?types=Envelope")

      assert %{"modules" => [entry]} = json_response(conn, 200)
      assert entry["name"] == "Maths"
    end
  end

  describe "GET /api/v1/modules/:id" do
    test "liefert Detail inkl. Observations", %{conn: conn} do
      module = eurorack_module_fixture()

      {:ok, _} =
        Inventory.create_price_observations(module, [
          %{amount: "199", source: "shop", notes: "neu"}
        ])

      conn = get(conn, ~p"/api/v1/modules/#{module.id}")

      assert %{"module" => payload} = json_response(conn, 200)
      assert payload["id"] == module.id
      assert payload["manufacturer"] == "Make Noise"
      assert length(payload["price_observations"]) == 1
      assert hd(payload["price_observations"])["source"] == "shop"
    end

    test "liefert 404 fuer unbekannte oder geloeschte Module", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/modules/999999")
      assert %{"error" => _} = json_response(conn, 404)

      module = eurorack_module_fixture()
      {:ok, _} = Inventory.soft_delete_eurorack_module(module)

      conn = get(build_conn(), ~p"/api/v1/modules/#{module.id}")
      assert %{"error" => _} = json_response(conn, 404)
    end
  end

  describe "POST /api/v1/modules" do
    test "legt ein Modul an", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/modules", %{
          "module" => %{
            "manufacturer" => "Intellijel",
            "name" => "Quad VCA",
            "hp" => 12,
            "type" => "VCA",
            "youtube_videos" => [
              %{"url" => "https://www.youtube.com/watch?v=abcdefghijk"}
            ]
          }
        })

      assert %{"module" => payload} = json_response(conn, 201)
      assert payload["name"] == "Quad VCA"
      assert payload["type"] == "VCA"
      assert length(payload["youtube_videos"]) == 1
    end

    test "liefert 422 bei fehlenden Pflichtfeldern", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/modules", %{"module" => %{}})

      assert %{"error" => _, "details" => details} = json_response(conn, 422)
      assert Map.has_key?(details, "name")
    end
  end

  describe "PATCH /api/v1/modules/:id" do
    test "aktualisiert ein Modul", %{conn: conn} do
      module = eurorack_module_fixture()

      conn =
        patch(conn, ~p"/api/v1/modules/#{module.id}", %{
          "module" => %{"name" => "Maths 2"}
        })

      assert %{"module" => %{"name" => "Maths 2"}} = json_response(conn, 200)
    end
  end

  describe "DELETE /api/v1/modules/:id" do
    test "soft-loescht ein Modul", %{conn: conn} do
      module = eurorack_module_fixture()

      conn = delete(conn, ~p"/api/v1/modules/#{module.id}")
      assert response(conn, 204)

      assert Inventory.get_eurorack_module!(module.id).deleted_at != nil
    end
  end

  describe "POST /api/v1/modules/:id/duplicate" do
    test "legt eine Kopie an und kopiert die Anleitung", %{conn: conn} do
      module = eurorack_module_fixture(%{name: "Maths"})

      assert {:ok, with_manual} =
               Inventory.attach_manual(module, %{
                 tmp_path: @fixture,
                 filename: "maths.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(@fixture).size
               })

      conn = post(conn, ~p"/api/v1/modules/#{with_manual.id}/duplicate", %{})

      assert %{"module" => copy} = json_response(conn, 201)
      assert copy["id"] != with_manual.id
      assert copy["name"] == "Maths"
      assert copy["has_manual"] == true
      assert copy["manual_pdf_filename"] == "maths.pdf"
    end

    test "laesst das Kopieren der Anleitung per copy_manual=false aus", %{conn: conn} do
      module = eurorack_module_fixture()

      assert {:ok, with_manual} =
               Inventory.attach_manual(module, %{
                 tmp_path: @fixture,
                 filename: "maths.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(@fixture).size
               })

      conn =
        post(conn, ~p"/api/v1/modules/#{with_manual.id}/duplicate", %{
          "copy_manual" => false
        })

      assert %{"module" => %{"has_manual" => false}} = json_response(conn, 201)
    end
  end

  describe "POST /api/v1/modules/:id/valuations" do
    test "speichert Beobachtungen", %{conn: conn} do
      module = eurorack_module_fixture(%{current_value: nil})

      conn =
        post(conn, ~p"/api/v1/modules/#{module.id}/valuations", %{
          "observations" => [
            %{"amount" => 150, "source" => "ebay_sold", "observed_on" => "2026-08-10"},
            %{"amount" => 210, "source" => "shop", "observed_on" => "2026-08-10"}
          ]
        })

      assert %{
               "module" => %{"current_value" => 180.0},
               "observations" => observations
             } = json_response(conn, 201)

      assert length(observations) == 2
    end
  end

  describe "PDF-Anleitung" do
    test "upload, download und delete", %{conn: conn} do
      module = eurorack_module_fixture()

      upload = %Plug.Upload{
        path: @fixture,
        filename: "maths-manual.pdf",
        content_type: "application/pdf"
      }

      conn = put(conn, ~p"/api/v1/modules/#{module.id}/manual", %{"file" => upload})
      assert %{"module" => %{"has_manual" => true}} = json_response(conn, 200)

      conn = get(build_conn(), ~p"/api/v1/modules/#{module.id}/manual")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "application/pdf"
      assert conn.resp_body =~ "%PDF-"

      conn = delete(build_conn(), ~p"/api/v1/modules/#{module.id}/manual")
      assert %{"module" => %{"has_manual" => false}} = json_response(conn, 200)
    end

    test "liefert 404 ohne Anleitung", %{conn: conn} do
      module = eurorack_module_fixture()
      conn = get(conn, ~p"/api/v1/modules/#{module.id}/manual")
      assert %{"error" => _} = json_response(conn, 404)
    end
  end
end
