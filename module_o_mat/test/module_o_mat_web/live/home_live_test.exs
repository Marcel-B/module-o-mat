defmodule ModuleOMatWeb.HomeLiveTest do
  use ModuleOMatWeb.ConnCase, async: true

  describe "Landing" do
    test "zeigt die drei UI-Varianten zur Auswahl", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Welche Oberfläche möchtest du nutzen?"
      assert has_element?(view, "#ui-picker")
      assert has_element?(view, "#ui-choice-live-card")
      assert has_element?(view, "#ui-choice-vue-card")
      assert has_element?(view, "#ui-choice-vue-alt-card")
    end

    test "verlinkt LiveView, Vue-UI und alternative Vue-UI", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#ui-choice-live[href='/live']")
      assert has_element?(view, "#ui-choice-vue[href='/ui']")
      assert has_element?(view, "#ui-choice-vue-alt[href='/ui-alt']")
    end
  end
end
