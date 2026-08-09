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

  describe "Modul anzeigen" do
    test "oeffnet den Dialog im Anzeige-Modus mit den Moduldaten, ohne editierbar zu sein", %{
      conn: conn
    } do
      eurorack_module =
        eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths"})

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#show-eurorack-module-#{eurorack_module.id}")
      |> render_click()

      assert_patch(view, ~p"/eurorack_modules/#{eurorack_module.id}")
      assert has_element?(view, "#eurorack-module-modal")

      html = render(view)
      assert html =~ "Modul anzeigen"
      assert has_element?(view, "#eurorack-module-show")
      refute has_element?(view, "#eurorack-module-form")
      assert has_element?(view, "#eurorack-module-show input[disabled]")
      assert has_element?(view, "#eurorack-module-show select[disabled]")
      assert has_element?(view, "#eurorack-module-show input[value='Maths']")
      refute has_element?(view, "#save-eurorack-module-button")
    end

    test "schliesst den Dialog ueber 'Schliessen'", %{conn: conn} do
      eurorack_module = eurorack_module_fixture()

      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/#{eurorack_module.id}")

      assert has_element?(view, "#eurorack-module-modal")

      view
      |> element("#close-eurorack-module-button")
      |> render_click()

      assert_patch(view, ~p"/")
      refute has_element?(view, "#eurorack-module-modal")
    end
  end

  describe "Modul bearbeiten" do
    test "oeffnet den Dialog im Bearbeiten-Modus mit vorausgefuellten, editierbaren Feldern", %{
      conn: conn
    } do
      eurorack_module =
        eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths"})

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#edit-eurorack-module-#{eurorack_module.id}")
      |> render_click()

      assert_patch(view, ~p"/eurorack_modules/#{eurorack_module.id}/edit")

      html = render(view)
      assert html =~ "Modul bearbeiten"
      assert has_element?(view, "#eurorack-module-form")
      refute has_element?(view, "#eurorack-module-form input[disabled]")
      assert has_element?(view, "#eurorack-module-form input[value='Maths']")
      assert has_element?(view, "#save-eurorack-module-button")
    end

    test "zeigt Validierungsfehler beim Bearbeiten an und laesst den Dialog offen", %{
      conn: conn
    } do
      eurorack_module = eurorack_module_fixture()

      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/#{eurorack_module.id}/edit")

      html =
        view
        |> form("#eurorack-module-form", eurorack_module: %{name: "", hp: "0"})
        |> render_submit()

      assert has_element?(view, "#eurorack-module-modal")
      assert html =~ "muss ausgefuellt werden"
      assert html =~ "muss groesser als 0 sein"

      assert Inventory.get_eurorack_module!(eurorack_module.id).name == eurorack_module.name
    end

    test "aktualisiert bei gueltigen Daten das Modul, schliesst den Dialog und zeigt die Aenderung in der Tabelle",
         %{conn: conn} do
      eurorack_module =
        eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths", hp: 20})

      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/#{eurorack_module.id}/edit")

      html =
        view
        |> form("#eurorack-module-form", eurorack_module: %{name: "Maths (aktualisiert)"})
        |> render_submit()

      assert_patch(view, ~p"/")
      refute has_element?(view, "#eurorack-module-modal")
      assert html =~ "wurde aktualisiert"

      assert Inventory.get_eurorack_module!(eurorack_module.id).name == "Maths (aktualisiert)"
      assert has_element?(view, "#eurorack-module-#{eurorack_module.id}", "Maths (aktualisiert)")
    end

    test "bricht die Bearbeitung ueber 'Abbrechen' ab, ohne etwas zu speichern", %{conn: conn} do
      eurorack_module = eurorack_module_fixture()

      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/#{eurorack_module.id}/edit")

      view
      |> element("#cancel-eurorack-module-button")
      |> render_click()

      assert_patch(view, ~p"/")
      refute has_element?(view, "#eurorack-module-modal")
      assert Inventory.get_eurorack_module!(eurorack_module.id).name == eurorack_module.name
    end
  end

  describe "Modul loeschen" do
    test "zeigt eine Sicherheitsabfrage beim Klick auf 'Loeschen' an", %{conn: conn} do
      eurorack_module = eurorack_module_fixture(%{name: "Maths"})

      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#delete-eurorack-module-modal")

      html =
        view
        |> element("#delete-eurorack-module-#{eurorack_module.id}")
        |> render_click()

      assert has_element?(view, "#delete-eurorack-module-modal")
      assert html =~ "Maths"
      assert Inventory.list_eurorack_modules() |> Enum.any?(&(&1.id == eurorack_module.id))
    end

    test "bricht das Loeschen ueber 'Abbrechen' ab, ohne das Modul zu entfernen", %{conn: conn} do
      eurorack_module = eurorack_module_fixture()

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#delete-eurorack-module-#{eurorack_module.id}")
      |> render_click()

      assert has_element?(view, "#delete-eurorack-module-modal")

      view
      |> element("#cancel-delete-eurorack-module-button")
      |> render_click()

      refute has_element?(view, "#delete-eurorack-module-modal")
      assert has_element?(view, "#eurorack-module-#{eurorack_module.id}")
      assert Inventory.get_eurorack_module!(eurorack_module.id).deleted_at == nil
    end

    test "markiert das Modul nach Bestaetigung als geloescht und entfernt es aus der Tabelle",
         %{conn: conn} do
      eurorack_module = eurorack_module_fixture(%{name: "Maths"})

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("#delete-eurorack-module-#{eurorack_module.id}")
      |> render_click()

      html =
        view
        |> element("#confirm-delete-eurorack-module-button")
        |> render_click()

      refute has_element?(view, "#delete-eurorack-module-modal")
      refute has_element?(view, "#eurorack-module-#{eurorack_module.id}")
      assert html =~ "wurde geloescht"

      assert Inventory.get_eurorack_module!(eurorack_module.id).deleted_at != nil
      refute Inventory.list_eurorack_modules() |> Enum.any?(&(&1.id == eurorack_module.id))
    end
  end
end
