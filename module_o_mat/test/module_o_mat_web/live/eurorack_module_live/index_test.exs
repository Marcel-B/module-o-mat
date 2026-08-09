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
      eurorack_module_fixture(%{manufacturer: "Doepfer", name: "A-140", type: "Envelope"})
      eurorack_module_fixture(%{manufacturer: "Mutable Instruments", name: "Plaits", type: "VCO"})
      eurorack_module_fixture(%{manufacturer: "Make Noise", name: "STO", type: "VCO"})

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#eurorack-modules-Envelope")
      assert has_element?(view, "#eurorack-modules-VCO")

      html = render(view)

      {envelope_at, _} = :binary.match(html, "Envelope")
      {vco_at, _} = :binary.match(html, "VCO")
      {make_noise_at, _} = :binary.match(html, "Make Noise")
      {mutable_at, _} = :binary.match(html, "Mutable Instruments")

      assert envelope_at < vco_at, "Gruppe \"Envelope\" sollte vor \"VCO\" angezeigt werden"

      assert make_noise_at < mutable_at,
             "Innerhalb der VCO-Gruppe sollte \"Make Noise\" vor \"Mutable Instruments\" stehen"
    end

    test "zeigt Filterfelder an", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#module-filter-form")
      assert has_element?(view, "#module-search-input")
      assert has_element?(view, "#module-type-filter")
      assert has_element?(view, "#module-min-hp")
      assert has_element?(view, "#module-max-hp")
      assert has_element?(view, "#clear-filters-button")
    end

    test "bietet im Typfilter nur Typen an, die an Modulen vorkommen", %{conn: conn} do
      eurorack_module_fixture(%{type: "VCO"})
      eurorack_module_fixture(%{type: "Envelope"})

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#module-type-filter option", "VCO")
      assert has_element?(view, "#module-type-filter option", "Envelope")
      refute has_element?(view, "#module-type-filter option", "Sequencer")
    end

    test "filtert die Tabelle nach Hersteller oder Modulname", %{conn: conn} do
      maths =
        eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths", type: "Envelope"})

      plaits =
        eurorack_module_fixture(%{
          manufacturer: "Mutable Instruments",
          name: "Plaits",
          type: "VCO"
        })

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#module-filter-form", %{"q" => "Make"})
      |> render_change()

      assert has_element?(view, "#eurorack-module-#{maths.id}")
      refute has_element?(view, "#eurorack-module-#{plaits.id}")
    end

    test "filtert kombiniert nach Suche und Typ", %{conn: conn} do
      matching =
        eurorack_module_fixture(%{
          manufacturer: "Erica Synths",
          name: "Black Sequencer",
          type: "Sequencer"
        })

      other_type =
        eurorack_module_fixture(%{
          manufacturer: "Erica Synths",
          name: "Black VCO",
          type: "VCO"
        })

      other_maker =
        eurorack_module_fixture(%{
          manufacturer: "Make Noise",
          name: "René",
          type: "Sequencer"
        })

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#module-filter-form", %{"q" => "Erica", "type" => "Sequencer"})
      |> render_change()

      assert has_element?(view, "#eurorack-module-#{matching.id}")
      refute has_element?(view, "#eurorack-module-#{other_type.id}")
      refute has_element?(view, "#eurorack-module-#{other_maker.id}")
    end

    test "filtert nach HP-Bereich", %{conn: conn} do
      mid = eurorack_module_fixture(%{name: "Mid", hp: 8})
      wide = eurorack_module_fixture(%{name: "Wide", hp: 16})

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#module-filter-form", %{"min_hp" => "6", "max_hp" => "12"})
      |> render_change()

      assert has_element?(view, "#eurorack-module-#{mid.id}")
      refute has_element?(view, "#eurorack-module-#{wide.id}")
    end

    test "leert Filter und Suche ueber den Clear-Button", %{conn: conn} do
      maths =
        eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths", type: "Envelope"})

      plaits =
        eurorack_module_fixture(%{
          manufacturer: "Mutable Instruments",
          name: "Plaits",
          type: "VCO"
        })

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#module-filter-form", %{"q" => "Make"})
      |> render_change()

      refute has_element?(view, "#eurorack-module-#{plaits.id}")

      view
      |> element("#clear-filters-button")
      |> render_click()

      assert has_element?(view, "#eurorack-module-#{maths.id}")
      assert has_element?(view, "#eurorack-module-#{plaits.id}")
    end

    test "zeigt einen Hinweis an, wenn die Suche keine Treffer liefert", %{conn: conn} do
      eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths"})

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> form("#module-filter-form", %{"q" => "xyz-nicht-vorhanden"})
      |> render_change()

      assert has_element?(view, "#no-search-results")
      refute has_element?(view, "#no-eurorack-modules")
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
        "type" => "Envelope"
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

    test "schlaegt bereits erfasste Herstellernamen als Autocomplete-Optionen vor", %{
      conn: conn
    } do
      eurorack_module_fixture(%{manufacturer: "Make Noise"})
      eurorack_module_fixture(%{manufacturer: "Mutable Instruments"})

      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/new")

      assert has_element?(
               view,
               "input[name='eurorack_module[manufacturer]'][list='manufacturer-options']"
             )

      assert has_element?(view, "datalist#manufacturer-options option[value='Make Noise']")

      assert has_element?(
               view,
               "datalist#manufacturer-options option[value='Mutable Instruments']"
             )
    end

    test "zeigt definierte und bereits verwendete Typen als Auswahloptionen an", %{conn: conn} do
      eurorack_module_fixture(%{type: "Granular"})

      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/new")

      assert has_element?(view, "select[name='eurorack_module[type]'] option[value='VCO']")
      assert has_element?(view, "select[name='eurorack_module[type]'] option[value='Granular']")
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
        eurorack_module_fixture(%{
          manufacturer: "Make Noise",
          name: "Maths",
          manual_url: "https://www.makenoisemusic.com/technology/maths"
        })

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

      assert has_element?(
               view,
               "#manual-url-link[href='https://www.makenoisemusic.com/technology/maths']"
             )
    end

    test "zeigt einen Hinweis an, wenn keine URL hinterlegt ist", %{conn: conn} do
      eurorack_module = eurorack_module_fixture(%{manual_url: nil})

      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/#{eurorack_module.id}")

      refute has_element?(view, "#manual-url-link")
      assert has_element?(view, "#eurorack-module-show", "Keine Angabe")
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

  describe "Typen verwalten" do
    test "oeffnet den Dialog beim Klick auf 'Typen verwalten' und zeigt vorhandene Typen an", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#module-types-modal")

      view
      |> element("#manage-module-types-button")
      |> render_click()

      assert_patch(view, ~p"/module_types")
      assert has_element?(view, "#module-types-modal")
      assert has_element?(view, "#module-types-list", "VCO")
      assert has_element?(view, "#module-types-list", "Envelope")
    end

    test "zeigt einen Validierungsfehler bei leerem Namen an", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/module_types")

      html =
        view
        |> form("#module-type-form", module_type: %{name: ""})
        |> render_submit()

      assert has_element?(view, "#module-types-modal")
      assert html =~ "muss ausgefuellt werden"
    end

    test "zeigt einen Fehler an, wenn der Typ bereits existiert", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/module_types")

      html =
        view
        |> form("#module-type-form", module_type: %{name: "VCO"})
        |> render_submit()

      assert has_element?(view, "#module-types-modal")
      assert html =~ "existiert bereits"
    end

    test "legt bei gueltigem Namen einen neuen Typ an, ohne den Dialog zu schliessen", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/module_types")

      html =
        view
        |> form("#module-type-form", module_type: %{name: "Granular"})
        |> render_submit()

      assert has_element?(view, "#module-types-modal")
      assert html =~ "wurde hinzugefuegt"
      assert has_element?(view, "#module-types-list", "Granular")
      assert "Granular" in Inventory.list_module_types()
    end

    test "neu angelegte Typen stehen danach im Auswahlfeld fuer neue Module zur Verfuegung", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/module_types")

      view
      |> form("#module-type-form", module_type: %{name: "Granular"})
      |> render_submit()

      view
      |> element("#close-module-types-button")
      |> render_click()

      view
      |> element("#new-eurorack-module-button")
      |> render_click()

      assert has_element?(view, "select[name='eurorack_module[type]'] option[value='Granular']")
    end

    test "schliesst den Dialog ueber 'Schliessen'", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/module_types")

      assert has_element?(view, "#module-types-modal")

      view
      |> element("#close-module-types-button")
      |> render_click()

      assert_patch(view, ~p"/")
      refute has_element?(view, "#module-types-modal")
    end

    test "hebt bereits verwendete Typen farblich hervor", %{conn: conn} do
      eurorack_module_fixture(%{type: "VCO"})

      {:ok, view, _html} = live(conn, ~p"/module_types")

      vco_id = module_type_id("VCO")
      lfo_id = module_type_id("LFO")

      assert has_element?(view, "#module-type-#{vco_id} .badge-primary")
      assert has_element?(view, "#module-type-#{lfo_id} .badge-outline")
    end

    test "erlaubt das Umbenennen eines Typs", %{conn: conn} do
      module_type = module_type_fixture(%{name: "Granular"})

      {:ok, view, _html} = live(conn, ~p"/module_types")

      view
      |> element("#edit-module-type-#{module_type.id}")
      |> render_click()

      assert has_element?(view, "#module-type-edit-form-#{module_type.id}")

      html =
        view
        |> form("#module-type-edit-form-#{module_type.id}",
          module_type: %{name: "Granularsynthese"}
        )
        |> render_submit()

      assert html =~ "wurde aktualisiert"
      assert has_element?(view, "#module-types-list", "Granularsynthese")
      refute has_element?(view, "#module-type-edit-form-#{module_type.id}")
    end

    test "loescht einen Typ direkt ueber das x am Badge", %{conn: conn} do
      module_type = module_type_fixture(%{name: "Granular"})

      {:ok, view, _html} = live(conn, ~p"/module_types")

      html =
        view
        |> element("#delete-module-type-#{module_type.id}")
        |> render_click()

      assert html =~ "wurde geloescht"
      refute has_element?(view, "#module-type-#{module_type.id}")
      refute "Granular" in Inventory.list_module_types()
    end

    test "stellt referenzierende Module beim Loeschen des Typs auf 'Sonstiges' um", %{conn: conn} do
      module_type = module_type_fixture(%{name: "Granular"})
      eurorack_module = eurorack_module_fixture(%{type: "Granular"})

      {:ok, view, _html} = live(conn, ~p"/module_types")

      view
      |> element("#delete-module-type-#{module_type.id}")
      |> render_click()

      assert Inventory.get_eurorack_module!(eurorack_module.id).type ==
               Inventory.fallback_type_name()
    end

    test "der Fallback-Typ 'Sonstiges' kann weder bearbeitet noch geloescht werden", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/module_types")

      fallback_id = module_type_id(Inventory.fallback_type_name())

      refute has_element?(view, "#edit-module-type-#{fallback_id}")
      refute has_element?(view, "#delete-module-type-#{fallback_id}")
    end
  end

  describe "PDF-Anleitung" do
    @fixture Path.expand("../../../support/fixtures/files/sample.pdf", __DIR__)

    test "zeigt den PDF-Button in der Tabelle nur bei vorhandener Anleitung", %{conn: conn} do
      without = eurorack_module_fixture(%{name: "Ohne PDF"})
      with_manual = eurorack_module_fixture(%{name: "Mit PDF"})

      assert {:ok, with_manual} =
               Inventory.attach_manual(with_manual, %{
                 tmp_path: @fixture,
                 filename: "sample.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(@fixture).size
               })

      {:ok, view, _html} = live(conn, ~p"/")

      refute has_element?(view, "#open-manual-pdf-#{without.id}")
      assert has_element?(view, "#open-manual-pdf-#{with_manual.id}")
    end

    test "laedt beim Anlegen eine PDF-Anleitung hoch", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/new")

      manual =
        file_input(view, "#eurorack-module-form", :manual, [
          %{
            name: "maths.pdf",
            content: File.read!(@fixture),
            type: "application/pdf"
          }
        ])

      assert render_upload(manual, "maths.pdf") =~ "maths.pdf"

      view
      |> form("#eurorack-module-form",
        eurorack_module: %{
          "manufacturer" => "Make Noise",
          "name" => "Maths",
          "hp" => "20",
          "type" => "Envelope"
        }
      )
      |> render_submit()

      assert_patch(view, ~p"/")

      assert [eurorack_module] = Inventory.list_eurorack_modules()
      assert eurorack_module.manual_pdf_filename == "maths.pdf"
      assert eurorack_module.manual_pdf_key
      assert has_element?(view, "#open-manual-pdf-#{eurorack_module.id}")
    end

    test "zeigt und entfernt eine vorhandene PDF-Anleitung im Bearbeiten-Dialog", %{conn: conn} do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, eurorack_module} =
               Inventory.attach_manual(eurorack_module, %{
                 tmp_path: @fixture,
                 filename: "sample.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(@fixture).size
               })

      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/#{eurorack_module.id}/edit")

      assert has_element?(view, "#manual-pdf-current", "sample.pdf")
      assert has_element?(view, "#open-manual-pdf-button")

      view
      |> element("#remove-manual-pdf-button")
      |> render_click()

      refute has_element?(view, "#manual-pdf-current")
      assert Inventory.get_eurorack_module!(eurorack_module.id).manual_pdf_key == nil
    end

    test "zeigt die PDF-Anleitung im Anzeige-Dialog", %{conn: conn} do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, eurorack_module} =
               Inventory.attach_manual(eurorack_module, %{
                 tmp_path: @fixture,
                 filename: "sample.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(@fixture).size
               })

      {:ok, view, _html} = live(conn, ~p"/eurorack_modules/#{eurorack_module.id}")

      assert has_element?(view, "#manual-pdf-current", "sample.pdf")
      assert has_element?(view, "#open-manual-pdf-button")
      refute has_element?(view, "#remove-manual-pdf-button")
      refute has_element?(view, "#manual-pdf-upload")
    end
  end

  defp module_type_id(name) do
    Inventory.list_module_type_records()
    |> Enum.find(&(&1.name == name))
    |> Map.fetch!(:id)
  end
end
