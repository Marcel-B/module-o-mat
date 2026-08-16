defmodule ModuleOMatWeb.SpaControllerTest do
  use ModuleOMatWeb.ConnCase

  describe "ohne gebaute Vue-UI" do
    test "leitet /ui zur Landing-Page um", %{conn: conn} do
      conn = get(conn, ~p"/ui")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "ui"
    end

    test "leitet /ui-alt zur Landing-Page um", %{conn: conn} do
      conn = get(conn, ~p"/ui-alt")

      assert redirected_to(conn) == ~p"/"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "ui-alt"
    end
  end

  describe "mit gebauter Vue-UI" do
    setup do
      ui_dir = Application.app_dir(:module_o_mat, ["priv", "vue", "ui"])
      alt_dir = Application.app_dir(:module_o_mat, ["priv", "vue", "ui-alt"])

      File.mkdir_p!(ui_dir)
      File.mkdir_p!(alt_dir)
      File.write!(Path.join(ui_dir, "index.html"), "<!doctype html><title>vue-ui</title>")
      File.write!(Path.join(alt_dir, "index.html"), "<!doctype html><title>vue-ui-alt</title>")

      on_exit(fn ->
        File.rm_rf!(Application.app_dir(:module_o_mat, ["priv", "vue"]))
      end)

      :ok
    end

    test "liefert die Vue-UI unter /ui", %{conn: conn} do
      conn = get(conn, ~p"/ui")

      assert conn.status == 200
      assert conn.resp_body =~ "vue-ui"
    end

    test "liefert index.html auch fuer Client-Routen", %{conn: conn} do
      conn = get(conn, ~p"/ui/modules/new")

      assert conn.status == 200
      assert conn.resp_body =~ "vue-ui"
    end

    test "liefert die alternative Vue-UI unter /ui-alt", %{conn: conn} do
      conn = get(conn, ~p"/ui-alt")

      assert conn.status == 200
      assert conn.resp_body =~ "vue-ui-alt"
    end
  end
end
