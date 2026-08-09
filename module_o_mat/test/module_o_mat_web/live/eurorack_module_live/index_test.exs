defmodule ModuleOMatWeb.EurorackModuleLive.IndexTest do
  use ModuleOMatWeb.ConnCase

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory

  describe "Uebersicht" do
    test "zeigt einen Hinweis an, wenn noch keine Module erfasst sind", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/")

      assert html =~ "Es sind noch keine Module erfasst."
    end

    test "zeigt erfasste Module gruppiert nach Typ und sortiert nach Hersteller an", %{
      conn: conn
    } do
      eurorack_module_fixture(%{manufacturer: "Doepfer", name: "A-140", type: :envelope})
      eurorack_module_fixture(%{manufacturer: "Mutable Instruments", name: "Plaits", type: :vco})
      eurorack_module_fixture(%{manufacturer: "Make Noise", name: "STO", type: :vco})

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#eurorack-modules-envelope")
      assert has_element?(view, "#eurorack-modules-vco")

      html = render(view)

      {envelope_at, _} = :binary.match(html, "Envelope")
      {vco_at, _} = :binary.match(html, "VCO")
      {make_noise_at, _} = :binary.match(html, "Make Noise")
      {mutable_at, _} = :binary.match(html, "Mutable Instruments")

      assert envelope_at < vco_at, "Gruppe \"Envelope\" sollte vor \"VCO\" angezeigt werden"

      assert make_noise_at < mutable_at,
             "Innerhalb der VCO-Gruppe sollte \"Make Noise\" vor \"Mutable Instruments\" stehen"
    end
  end

  describe "Neues Modul anlegen" do
    test "oeffnet den Dialog beim Klick auf 'Neues Modul'", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#eurorack-module-modal")

      view
      |> element("#new-eurorack-module-button")
      |> render_click()

      assert_patch(view, ~p"/eurorack_modules/new")
      assert has_element?(view, "#eurorack-module-modal")
      assert has_element?(view, "#eurorack-module-form")
    end

    test "zeigt Validierungsfehler bei leerem Formular an und laesst den Dialog offen", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/new")

      html =
        view
        |> form("#eurorack-module-form", eurorack_module: %{})
        |> render_submit()

      assert has_element?(view, "#eurorack-module-modal")
      assert html =~ "muss ausgefuellt werden"
      assert Inventory.list_eurorack_modules() == []
    end

    test "legt bei gueltigen Daten ein neues Modul an, schliesst den Dialog und zeigt es in der Tabelle",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/new")

      attrs = %{
        "manufacturer" => "Make Noise",
        "name" => "Maths",
        "hp" => "20",
        "type" => "envelope"
      }

      html =
        view
        |> form("#eurorack-module-form", eurorack_module: attrs)
        |> render_submit()

      assert_patch(view, ~p"/")
      refute has_element?(view, "#eurorack-module-modal")
      assert html =~ "wurde gespeichert"

      assert [eurorack_module] = Inventory.list_eurorack_modules()
      assert eurorack_module.manufacturer == "Make Noise"
      assert eurorack_module.name == "Maths"

      assert has_element?(view, "#eurorack-module-#{eurorack_module.id}")
    end

    test "bricht die Erfassung ueber 'Abbrechen' ab, ohne etwas zu speichern", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/new")

      assert has_element?(view, "#eurorack-module-modal")

      view
      |> element("#cancel-eurorack-module-button")
      |> render_click()

      assert_patch(view, ~p"/")
      refute has_element?(view, "#eurorack-module-modal")
      assert Inventory.list_eurorack_modules() == []
    end
  end
end
