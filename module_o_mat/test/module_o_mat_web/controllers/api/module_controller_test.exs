defmodule ModuleOMatWeb.Api.ModuleControllerTest do
  use ModuleOMatWeb.ConnCase

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory

  describe "GET /api/modules" do
    test "listet aktive Module inkl. Preisspanne", %{conn: conn} do
      module =
        eurorack_module_fixture(%{
          manufacturer: "Make Noise",
          name: "Maths",
          hp: 20,
          current_value: "120.00"
        })

      {:ok, _} =
        Inventory.create_price_observations(module, [
          %{amount: "100", source: "ebay_sold", observed_on: ~D[2026-08-01]},
          %{amount: "140", source: "shop", observed_on: ~D[2026-08-02]}
        ])

      conn = get(conn, ~p"/api/modules")

      assert %{"modules" => [entry]} = json_response(conn, 200)
      assert entry["id"] == module.id
      assert entry["manufacturer"] == "Make Noise"
      assert entry["name"] == "Maths"
      assert entry["hp"] == 20
      assert entry["price_range"]["min"] == 100.0
      assert entry["price_range"]["max"] == 140.0
      assert entry["price_range"]["count"] == 2
    end
  end

  describe "GET /api/modules/:id" do
    test "liefert Modul inkl. Observations", %{conn: conn} do
      module = eurorack_module_fixture()

      {:ok, _} =
        Inventory.create_price_observations(module, [
          %{amount: "199", source: "shop", source_url: "https://example.com", notes: "neu"}
        ])

      conn = get(conn, ~p"/api/modules/#{module.id}")

      assert %{"module" => payload} = json_response(conn, 200)
      assert payload["id"] == module.id
      assert length(payload["observations"]) == 1
      assert hd(payload["observations"])["source"] == "shop"
      assert hd(payload["observations"])["notes"] == "neu"
    end

    test "liefert 404 fuer unbekannte ID", %{conn: conn} do
      conn = get(conn, ~p"/api/modules/999999")
      assert %{"error" => _} = json_response(conn, 404)
    end
  end

  describe "POST /api/modules/:id/valuations" do
    test "speichert Beobachtungen und setzt Median", %{conn: conn} do
      module = eurorack_module_fixture(%{current_value: nil})

      conn =
        post(conn, ~p"/api/modules/#{module.id}/valuations", %{
          "observations" => [
            %{
              "amount" => 150,
              "source" => "ebay_sold",
              "observed_on" => "2026-08-10"
            },
            %{
              "amount" => 210,
              "source" => "shop",
              "observed_on" => "2026-08-10"
            }
          ]
        })

      assert %{
               "module" => %{"current_value" => 180.0},
               "observations" => observations,
               "price_range" => %{"min" => 150.0, "max" => 210.0, "count" => 2}
             } = json_response(conn, 201)

      assert length(observations) == 2
    end

    test "lehnt leere Observations ab", %{conn: conn} do
      module = eurorack_module_fixture()

      conn =
        post(conn, ~p"/api/modules/#{module.id}/valuations", %{"observations" => []})

      assert %{"error" => _} = json_response(conn, 422)
    end

    test "akzeptiert expliziten current_value", %{conn: conn} do
      module = eurorack_module_fixture()

      conn =
        post(conn, ~p"/api/modules/#{module.id}/valuations", %{
          "observations" => [%{"amount" => 100, "source" => "shop"}],
          "current_value" => 95.5
        })

      assert %{"module" => %{"current_value" => 95.5}} = json_response(conn, 201)
    end
  end
end
