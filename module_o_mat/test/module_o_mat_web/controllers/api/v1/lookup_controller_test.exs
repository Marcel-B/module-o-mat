defmodule ModuleOMatWeb.Api.V1.LookupControllerTest do
  use ModuleOMatWeb.ConnCase

  import ModuleOMat.InventoryFixtures

  describe "GET /api/v1/manufacturers" do
    test "liefert sortierte Hersteller ohne Duplikate", %{conn: conn} do
      eurorack_module_fixture(%{manufacturer: "Mutable", name: "Clouds", type: "Granular"})
      eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths"})
      eurorack_module_fixture(%{manufacturer: "Make Noise", name: "DPO", type: "VCO"})

      conn = get(conn, ~p"/api/v1/manufacturers")

      assert %{"manufacturers" => ["Make Noise", "Mutable"]} = json_response(conn, 200)
    end
  end
end
