defmodule ModuleOMatWeb.Api.OpenApiTest do
  use ModuleOMatWeb.ConnCase

  describe "GET /api/openapi" do
    test "liefert die OpenAPI-Spec", %{conn: conn} do
      conn = get(conn, ~p"/api/openapi")
      assert %{"openapi" => "3.0.0", "paths" => paths, "info" => info} = json_response(conn, 200)
      assert info["title"] =~ "Module-O-Mat"
      assert Map.has_key?(paths, "/api/v1/modules")
      assert Map.has_key?(paths, "/api/v1/module-types")
      assert Map.has_key?(paths, "/api/v1/backup/export")
    end
  end

  describe "GET /api/docs" do
    test "liefert die Swagger-UI", %{conn: conn} do
      conn = get(conn, ~p"/api/docs")
      assert response(conn, 200) =~ "swagger-ui"
    end
  end
end
