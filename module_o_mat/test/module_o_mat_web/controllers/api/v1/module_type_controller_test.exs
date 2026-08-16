defmodule ModuleOMatWeb.Api.V1.ModuleTypeControllerTest do
  use ModuleOMatWeb.ConnCase

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.ModuleType
  alias ModuleOMat.Repo

  describe "GET /api/v1/module-types" do
    test "listet Typen inkl. fallback- und used-Flags", %{conn: conn} do
      eurorack_module_fixture(%{type: "Envelope"})

      conn = get(conn, ~p"/api/v1/module-types")
      assert %{"module_types" => types} = json_response(conn, 200)

      sonstiges = Enum.find(types, &(&1["name"] == Inventory.fallback_type_name()))
      envelope = Enum.find(types, &(&1["name"] == "Envelope"))

      assert sonstiges["fallback"] == true
      assert envelope["used"] == true
    end
  end

  describe "POST /api/v1/module-types" do
    test "legt einen Typ an", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/module-types", %{"module_type" => %{"name" => "Granular"}})

      assert %{"module_type" => %{"name" => "Granular", "fallback" => false}} =
               json_response(conn, 201)
    end

    test "lehnt Duplikate ab", %{conn: conn} do
      module_type_fixture(%{name: "Granular"})

      conn =
        post(conn, ~p"/api/v1/module-types", %{"module_type" => %{"name" => "Granular"}})

      assert %{"error" => _} = json_response(conn, 422)
    end
  end

  describe "PATCH /api/v1/module-types/:id" do
    test "benennt einen Typ um", %{conn: conn} do
      type = module_type_fixture(%{name: "Granular"})

      conn =
        patch(conn, ~p"/api/v1/module-types/#{type.id}", %{
          "module_type" => %{"name" => "Texture"}
        })

      assert %{"module_type" => %{"name" => "Texture"}} = json_response(conn, 200)
    end

    test "lehnt den Fallback-Typ ab", %{conn: conn} do
      fallback = Repo.get_by!(ModuleType, name: Inventory.fallback_type_name())

      conn =
        patch(conn, ~p"/api/v1/module-types/#{fallback.id}", %{
          "module_type" => %{"name" => "Andere"}
        })

      assert %{"error" => message} = json_response(conn, 422)
      assert message =~ Inventory.fallback_type_name()
    end
  end

  describe "DELETE /api/v1/module-types/:id" do
    test "loescht einen Typ", %{conn: conn} do
      type = module_type_fixture(%{name: "Granular"})

      conn = delete(conn, ~p"/api/v1/module-types/#{type.id}")
      assert response(conn, 204)
      assert Inventory.get_module_type(type.id) == nil
    end

    test "lehnt den Fallback-Typ ab", %{conn: conn} do
      fallback = Repo.get_by!(ModuleType, name: Inventory.fallback_type_name())

      conn = delete(conn, ~p"/api/v1/module-types/#{fallback.id}")
      assert %{"error" => _} = json_response(conn, 422)
    end
  end
end
