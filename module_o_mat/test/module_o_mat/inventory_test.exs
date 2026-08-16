defmodule ModuleOMat.InventoryTest do
  use ModuleOMat.DataCase, async: true

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.EurorackModule
  alias ModuleOMat.Inventory.ModuleType
  alias ModuleOMat.Repo

  import ModuleOMat.InventoryFixtures

  describe "create_eurorack_module/1" do
    test "legt ein Modul mit gueltigen Attributen an und setzt Zeitstempel" do
      attrs = valid_eurorack_module_attrs()

      assert {:ok, %EurorackModule{} = eurorack_module} = Inventory.create_eurorack_module(attrs)

      assert eurorack_module.manufacturer == "Make Noise"
      assert eurorack_module.name == "Maths"
      assert eurorack_module.hp == 20
      assert eurorack_module.type == "Envelope"
      assert eurorack_module.current_draw_plus12v_ma == 55
      assert eurorack_module.current_draw_minus12v_ma == 30
      assert eurorack_module.current_draw_plus5v_ma == nil
      assert eurorack_module.depth_mm == 35
      assert %DateTime{} = eurorack_module.inserted_at
      assert %DateTime{} = eurorack_module.updated_at
    end

    test "erlaubt fehlenden Strombedarf, da dieser optional ist" do
      attrs =
        valid_eurorack_module_attrs(%{
          current_draw_plus12v_ma: nil,
          current_draw_minus12v_ma: nil,
          current_draw_plus5v_ma: nil
        })

      assert {:ok, %EurorackModule{}} = Inventory.create_eurorack_module(attrs)
    end

    test "liefert einen Fehler, wenn Pflichtfelder fehlen" do
      assert {:error, changeset} = Inventory.create_eurorack_module(%{})

      errors = errors_on(changeset)
      assert "muss ausgefuellt werden" in errors.manufacturer
      assert "muss ausgefuellt werden" in errors.name
      assert "muss ausgefuellt werden" in errors.hp
      assert "muss ausgefuellt werden" in errors.type
    end

    test "erlaubt einen neuen, noch nicht vorhandenen Typ" do
      attrs = valid_eurorack_module_attrs(%{type: "Granular"})

      assert {:ok, %EurorackModule{type: "Granular"}} = Inventory.create_eurorack_module(attrs)
    end

    test "entfernt fuehrende und abschliessende Leerzeichen aus dem Typ" do
      attrs = valid_eurorack_module_attrs(%{type: "  VCO  "})

      assert {:ok, %EurorackModule{type: "VCO"}} = Inventory.create_eurorack_module(attrs)
    end

    test "speichert Subtypen und entfernt den Haupttyp aus der Liste" do
      attrs = valid_eurorack_module_attrs(%{type: "VCO", subtypes: ["LFO", "VCO", "  LFO  ", ""]})

      assert {:ok, %EurorackModule{type: "VCO", subtypes: ["LFO"]}} =
               Inventory.create_eurorack_module(attrs)
    end

    test "liefert einen Fehler, wenn der Typ nur aus Leerzeichen besteht" do
      attrs = valid_eurorack_module_attrs(%{type: "   "})

      assert {:error, changeset} = Inventory.create_eurorack_module(attrs)
      assert "muss ausgefuellt werden" in errors_on(changeset).type
    end

    test "liefert einen Fehler bei hp <= 0" do
      attrs = valid_eurorack_module_attrs(%{hp: 0})

      assert {:error, changeset} = Inventory.create_eurorack_module(attrs)
      assert "muss groesser als 0 sein" in errors_on(changeset).hp
    end

    test "liefert einen Fehler bei negativem Strombedarf" do
      attrs = valid_eurorack_module_attrs(%{current_draw_plus12v_ma: -10})

      assert {:error, changeset} = Inventory.create_eurorack_module(attrs)
      assert "darf nicht negativ sein" in errors_on(changeset).current_draw_plus12v_ma
    end

    test "speichert optionale Kaufpreis- und Wert-Angaben" do
      attrs =
        valid_eurorack_module_attrs(%{
          purchase_price: "249.99",
          current_value: "199.50"
        })

      assert {:ok, %EurorackModule{} = eurorack_module} = Inventory.create_eurorack_module(attrs)
      assert Decimal.eq?(eurorack_module.purchase_price, Decimal.new("249.99"))
      assert Decimal.eq?(eurorack_module.current_value, Decimal.new("199.50"))
    end

    test "liefert einen Fehler bei negativem Kaufpreis oder Wert" do
      attrs = valid_eurorack_module_attrs(%{purchase_price: "-1", current_value: "-0.01"})

      assert {:error, changeset} = Inventory.create_eurorack_module(attrs)
      errors = errors_on(changeset)
      assert "darf nicht negativ sein" in errors.purchase_price
      assert "darf nicht negativ sein" in errors.current_value
    end

    test "speichert mehrere YouTube-Links mit Position und normalisierter URL" do
      attrs =
        valid_eurorack_module_attrs(%{
          youtube_videos: [
            %{url: "https://youtu.be/dQw4w9WgXcQ"},
            %{url: "https://www.youtube.com/watch?v=aaaaaaaaaaa"}
          ]
        })

      assert {:ok, eurorack_module} = Inventory.create_eurorack_module(attrs)
      eurorack_module = Inventory.get_eurorack_module!(eurorack_module.id)

      assert [
               %{url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ", position: 0},
               %{url: "https://www.youtube.com/watch?v=aaaaaaaaaaa", position: 1}
             ] = eurorack_module.youtube_videos
    end

    test "liefert einen Fehler bei ungueltiger YouTube-URL" do
      attrs =
        valid_eurorack_module_attrs(%{
          youtube_videos: [%{url: "https://example.com/video"}]
        })

      assert {:error, changeset} = Inventory.create_eurorack_module(attrs)

      assert %{youtube_videos: [%{url: ["muss eine gueltige YouTube-URL sein"]}]} =
               errors_on(changeset)
    end
  end

  describe "primary_youtube_video/1" do
    test "liefert das erste Video nach Position" do
      eurorack_module =
        eurorack_module_fixture(%{
          youtube_videos: [
            %{url: "https://www.youtube.com/watch?v=bbbbbbbbbbb"},
            %{url: "https://www.youtube.com/watch?v=ccccccccccc"}
          ]
        })

      primary = Inventory.primary_youtube_video(eurorack_module)
      assert primary.url == "https://www.youtube.com/watch?v=bbbbbbbbbbb"
      assert primary.position == 0
    end

    test "liefert nil ohne Videos" do
      eurorack_module = eurorack_module_fixture()
      assert Inventory.primary_youtube_video(eurorack_module) == nil
    end
  end

  describe "update_eurorack_module/2 youtube_videos" do
    test "aendert die Reihenfolge der YouTube-Links" do
      eurorack_module =
        eurorack_module_fixture(%{
          youtube_videos: [
            %{url: "https://www.youtube.com/watch?v=first111111"},
            %{url: "https://www.youtube.com/watch?v=second22222"}
          ]
        })

      [first, second] = eurorack_module.youtube_videos

      assert {:ok, _} =
               Inventory.update_eurorack_module(eurorack_module, %{
                 youtube_videos: [
                   %{"id" => second.id, "url" => second.url},
                   %{"id" => first.id, "url" => first.url}
                 ]
               })

      updated = Inventory.get_eurorack_module!(eurorack_module.id)

      assert Enum.map(updated.youtube_videos, & &1.url) == [
               "https://www.youtube.com/watch?v=second22222",
               "https://www.youtube.com/watch?v=first111111"
             ]

      assert Enum.map(updated.youtube_videos, & &1.position) == [0, 1]
    end
  end

  describe "list_eurorack_modules/0" do
    test "liefert alle gespeicherten Module" do
      module_1 = eurorack_module_fixture(%{name: "Maths"})
      module_2 = eurorack_module_fixture(%{name: "Plaits", manufacturer: "Mutable Instruments"})

      ids = Inventory.list_eurorack_modules() |> Enum.map(& &1.id)

      assert module_1.id in ids
      assert module_2.id in ids
      assert length(ids) == 2
    end

    test "liefert eine leere Liste, wenn keine Module existieren" do
      assert Inventory.list_eurorack_modules() == []
    end

    test "enthaelt keine als geloescht markierten Module" do
      sichtbares_modul = eurorack_module_fixture(%{name: "Maths"})
      geloeschtes_modul = eurorack_module_fixture(%{name: "Plaits"})

      {:ok, _} = Inventory.soft_delete_eurorack_module(geloeschtes_modul)

      ids = Inventory.list_eurorack_modules() |> Enum.map(& &1.id)

      assert sichtbares_modul.id in ids
      refute geloeschtes_modul.id in ids
    end

    test "sortiert nach Typ und innerhalb eines Typs nach Hersteller" do
      eurorack_module_fixture(%{manufacturer: "Mutable Instruments", name: "Plaits", type: "VCO"})
      eurorack_module_fixture(%{manufacturer: "Make Noise", name: "STO", type: "VCO"})
      eurorack_module_fixture(%{manufacturer: "Doepfer", name: "A-140", type: "Envelope"})

      assert Inventory.list_eurorack_modules() |> Enum.map(&{&1.type, &1.manufacturer}) == [
               {"Envelope", "Doepfer"},
               {"VCO", "Make Noise"},
               {"VCO", "Mutable Instruments"}
             ]
    end
  end

  describe "list_eurorack_modules/1" do
    test "findet Module anhand des Herstellers" do
      matching = eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths"})
      _other = eurorack_module_fixture(%{manufacturer: "Doepfer", name: "A-140"})

      ids = Inventory.list_eurorack_modules("make") |> Enum.map(& &1.id)

      assert ids == [matching.id]
    end

    test "findet Module anhand des Namens" do
      matching = eurorack_module_fixture(%{manufacturer: "Mutable Instruments", name: "Plaits"})
      _other = eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths"})

      ids = Inventory.list_eurorack_modules("plai") |> Enum.map(& &1.id)

      assert ids == [matching.id]
    end

    test "liefert alle Module bei leerem Query" do
      module_1 = eurorack_module_fixture(%{name: "Maths"})
      module_2 = eurorack_module_fixture(%{name: "Plaits", manufacturer: "Mutable Instruments"})

      ids = Inventory.list_eurorack_modules("  ") |> Enum.map(& &1.id)

      assert module_1.id in ids
      assert module_2.id in ids
      assert length(ids) == 2
    end

    test "enthaelt keine als geloescht markierten Module" do
      sichtbares_modul = eurorack_module_fixture(%{name: "Maths"})
      geloeschtes_modul = eurorack_module_fixture(%{name: "Maths Deluxe"})

      {:ok, _} = Inventory.soft_delete_eurorack_module(geloeschtes_modul)

      ids = Inventory.list_eurorack_modules("Maths") |> Enum.map(& &1.id)

      assert ids == [sichtbares_modul.id]
    end

    test "filtert nach Typ" do
      sequencer =
        eurorack_module_fixture(%{
          manufacturer: "Erica Synths",
          name: "Black Sequencer",
          type: "Sequencer"
        })

      _vco =
        eurorack_module_fixture(%{
          manufacturer: "Erica Synths",
          name: "Black VCO",
          type: "VCO"
        })

      ids = Inventory.list_eurorack_modules(types: ["Sequencer"]) |> Enum.map(& &1.id)

      assert ids == [sequencer.id]
    end

    test "findet Module auch ueber Subtypen" do
      vco_lfo =
        eurorack_module_fixture(%{
          manufacturer: "Mutable Instruments",
          name: "Plaits",
          type: "VCO",
          subtypes: ["LFO"]
        })

      _other = eurorack_module_fixture(%{type: "Envelope"})

      ids = Inventory.list_eurorack_modules(types: ["LFO"]) |> Enum.map(& &1.id)

      assert ids == [vco_lfo.id]
    end

    test "kombiniert Suche und Typfilter per AND" do
      matching =
        eurorack_module_fixture(%{
          manufacturer: "Erica Synths",
          name: "Black Sequencer",
          type: "Sequencer"
        })

      _other_erica =
        eurorack_module_fixture(%{
          manufacturer: "Erica Synths",
          name: "Black VCO",
          type: "VCO"
        })

      _other_sequencer =
        eurorack_module_fixture(%{
          manufacturer: "Make Noise",
          name: "René",
          type: "Sequencer"
        })

      ids =
        Inventory.list_eurorack_modules(q: "Erica", types: ["Sequencer"])
        |> Enum.map(& &1.id)

      assert ids == [matching.id]
    end

    test "filtert nach min und max HP" do
      narrow = eurorack_module_fixture(%{name: "Narrow", hp: 4})
      mid = eurorack_module_fixture(%{name: "Mid", hp: 8})
      wide = eurorack_module_fixture(%{name: "Wide", hp: 16})

      ids =
        Inventory.list_eurorack_modules(min_hp: 6, max_hp: 12)
        |> Enum.map(& &1.id)

      assert ids == [mid.id]
      refute narrow.id in ids
      refute wide.id in ids
    end

    test "ignoriert ungueltige HP-Werte" do
      module = eurorack_module_fixture(%{name: "Maths", hp: 20})

      ids =
        Inventory.list_eurorack_modules(min_hp: "abc", max_hp: "-3")
        |> Enum.map(& &1.id)

      assert module.id in ids
    end
  end

  describe "inventory_stats/1" do
    test "liefert Nullwerte, wenn keine Module existieren" do
      stats = Inventory.inventory_stats()

      assert stats.count == 0
      assert stats.total_hp == 0
      assert Decimal.eq?(stats.total_width_mm, Decimal.new(0))
      assert Decimal.eq?(stats.total_width_cm, Decimal.new(0))
      assert Decimal.eq?(stats.total_width_m, Decimal.new(0))
      assert Decimal.eq?(stats.total_purchase_price, Decimal.new(0))
      assert Decimal.eq?(stats.total_current_value, Decimal.new(0))
    end

    test "summiert Module, HP und Eurobetraege ueber den gesamten Bestand" do
      eurorack_module_fixture(%{
        name: "Maths",
        hp: 20,
        purchase_price: "100.50",
        current_value: "120.00"
      })

      eurorack_module_fixture(%{
        name: "Plaits",
        manufacturer: "Mutable Instruments",
        hp: 12,
        purchase_price: "199.50",
        current_value: nil
      })

      stats = Inventory.inventory_stats()

      assert stats.count == 2
      assert stats.total_hp == 32
      assert Decimal.eq?(stats.total_width_mm, Decimal.new("162.56"))
      assert Decimal.eq?(stats.total_width_cm, Decimal.new("16.256"))
      assert Decimal.eq?(stats.total_width_m, Decimal.new("0.16256"))
      assert Decimal.eq?(stats.total_purchase_price, Decimal.new("300.00"))
      assert Decimal.eq?(stats.total_current_value, Decimal.new("120.00"))
    end

    test "wendet dieselben Filter wie list_eurorack_modules an" do
      eurorack_module_fixture(%{
        manufacturer: "Make Noise",
        name: "Maths",
        type: "Envelope",
        hp: 20,
        purchase_price: "100.00",
        current_value: "110.00"
      })

      eurorack_module_fixture(%{
        manufacturer: "Mutable Instruments",
        name: "Plaits",
        type: "VCO",
        hp: 12,
        purchase_price: "200.00",
        current_value: "180.00"
      })

      stats = Inventory.inventory_stats(types: ["VCO"])

      assert stats.count == 1
      assert stats.total_hp == 12
      assert Decimal.eq?(stats.total_width_mm, Decimal.new("60.96"))
      assert Decimal.eq?(stats.total_purchase_price, Decimal.new("200.00"))
      assert Decimal.eq?(stats.total_current_value, Decimal.new("180.00"))
    end

    test "ignoriert soft-geloeschte Module" do
      sichtbares =
        eurorack_module_fixture(%{
          name: "Maths",
          hp: 20,
          purchase_price: "50.00",
          current_value: "60.00"
        })

      geloeschtes =
        eurorack_module_fixture(%{
          name: "Plaits",
          manufacturer: "Mutable Instruments",
          hp: 12,
          purchase_price: "100.00",
          current_value: "90.00"
        })

      {:ok, _} = Inventory.soft_delete_eurorack_module(geloeschtes)

      stats = Inventory.inventory_stats()

      assert stats.count == 1
      assert stats.total_hp == sichtbares.hp
      assert Decimal.eq?(stats.total_purchase_price, Decimal.new("50.00"))
      assert Decimal.eq?(stats.total_current_value, Decimal.new("60.00"))
    end
  end

  describe "list_used_types/0" do
    test "liefert alle bereits an Modulen verwendeten Typen ohne Duplikate, sortiert" do
      eurorack_module_fixture(%{type: "VCO"})
      eurorack_module_fixture(%{type: "Envelope"})
      eurorack_module_fixture(%{type: "Envelope"})

      assert Inventory.list_used_types() == ["Envelope", "VCO"]
    end

    test "beruecksichtigt auch Subtypen" do
      eurorack_module_fixture(%{type: "VCO", subtypes: ["LFO"]})

      assert Inventory.list_used_types() == ["LFO", "VCO"]
    end

    test "liefert eine leere Liste, wenn keine Module existieren" do
      assert Inventory.list_used_types() == []
    end
  end

  describe "list_module_types/0" do
    test "enthaelt die per Migration angelegten Standardtypen" do
      types = Inventory.list_module_types()

      assert "VCO" in types
      assert "Envelope" in types
    end

    test "enthaelt neu angelegte Typen zusaetzlich zu den Standardtypen, sortiert" do
      module_type_fixture(%{name: "Granular"})

      types = Inventory.list_module_types()

      assert "Granular" in types
      assert types == Enum.sort(types)
    end
  end

  describe "create_module_type/1" do
    test "legt einen neuen Typ mit gueltigem Namen an" do
      assert {:ok, %ModuleType{name: "Granular"}} =
               Inventory.create_module_type(valid_module_type_attrs(%{name: "Granular"}))
    end

    test "entfernt fuehrende und abschliessende Leerzeichen aus dem Namen" do
      assert {:ok, %ModuleType{name: "Granular"}} =
               Inventory.create_module_type(valid_module_type_attrs(%{name: "  Granular  "}))
    end

    test "liefert einen Fehler, wenn der Name fehlt" do
      assert {:error, changeset} = Inventory.create_module_type(%{})
      assert "muss ausgefuellt werden" in errors_on(changeset).name
    end

    test "liefert einen Fehler, wenn der Name nur aus Leerzeichen besteht" do
      assert {:error, changeset} =
               Inventory.create_module_type(valid_module_type_attrs(%{name: "   "}))

      assert "muss ausgefuellt werden" in errors_on(changeset).name
    end

    test "liefert einen Fehler, wenn der Name bereits existiert" do
      assert {:error, changeset} =
               Inventory.create_module_type(valid_module_type_attrs(%{name: "VCO"}))

      assert "existiert bereits" in errors_on(changeset).name
    end
  end

  describe "change_module_type/2" do
    test "liefert ein Changeset fuer den Typ" do
      assert %Ecto.Changeset{} = Inventory.change_module_type(%ModuleType{})
    end
  end

  describe "update_module_type/2" do
    test "benennt den Typ um" do
      module_type = module_type_fixture(%{name: "Granular"})

      assert {:ok, %ModuleType{name: "Granularsynthese"}} =
               Inventory.update_module_type(module_type, %{name: "Granularsynthese"})
    end

    test "stellt referenzierende Module auf den neuen Namen um" do
      module_type = module_type_fixture(%{name: "Granular"})
      eurorack_module = eurorack_module_fixture(%{type: "Granular"})

      assert {:ok, _updated} =
               Inventory.update_module_type(module_type, %{name: "Granularsynthese"})

      assert Inventory.get_eurorack_module!(eurorack_module.id).type == "Granularsynthese"
    end

    test "benennt Subtypen in referenzierenden Modulen um" do
      module_type = module_type_fixture(%{name: "Granular"})

      eurorack_module =
        eurorack_module_fixture(%{type: "VCO", subtypes: ["Granular", "Envelope"]})

      assert {:ok, _updated} =
               Inventory.update_module_type(module_type, %{name: "Granularsynthese"})

      assert Inventory.get_eurorack_module!(eurorack_module.id).subtypes == [
               "Granularsynthese",
               "Envelope"
             ]
    end

    test "liefert einen Fehler, wenn der neue Name bereits existiert" do
      module_type_fixture(%{name: "Granular"})
      module_type = module_type_fixture(%{name: "Wavetable"})

      assert {:error, changeset} = Inventory.update_module_type(module_type, %{name: "Granular"})
      assert "existiert bereits" in errors_on(changeset).name
    end

    test "verweigert das Umbenennen des Fallback-Typs" do
      fallback = Repo.get_by!(ModuleType, name: Inventory.fallback_type_name())

      assert {:error, :fallback_type} = Inventory.update_module_type(fallback, %{name: "Andere"})
    end
  end

  describe "delete_module_type/1" do
    test "loescht den Typ" do
      module_type = module_type_fixture(%{name: "Granular"})

      assert {:ok, %ModuleType{}} = Inventory.delete_module_type(module_type)
      refute Inventory.list_module_types() |> Enum.member?("Granular")
    end

    test "stellt referenzierende Module auf den Fallback-Typ um" do
      module_type = module_type_fixture(%{name: "Granular"})
      eurorack_module = eurorack_module_fixture(%{type: "Granular"})

      assert {:ok, _deleted} = Inventory.delete_module_type(module_type)

      assert Inventory.get_eurorack_module!(eurorack_module.id).type ==
               Inventory.fallback_type_name()
    end

    test "entfernt den geloeschten Typ aus Subtypen-Listen" do
      module_type = module_type_fixture(%{name: "Granular"})

      eurorack_module =
        eurorack_module_fixture(%{type: "VCO", subtypes: ["Granular", "Envelope"]})

      assert {:ok, _deleted} = Inventory.delete_module_type(module_type)

      assert Inventory.get_eurorack_module!(eurorack_module.id).subtypes == ["Envelope"]
    end

    test "verweigert das Loeschen des Fallback-Typs" do
      fallback = Repo.get_by!(ModuleType, name: Inventory.fallback_type_name())

      assert {:error, :fallback_type} = Inventory.delete_module_type(fallback)
      assert Inventory.fallback_type_name() in Inventory.list_module_types()
    end
  end

  describe "list_manufacturers/0" do
    test "liefert alle bereits erfassten Herstellernamen ohne Duplikate, sortiert" do
      eurorack_module_fixture(%{manufacturer: "Mutable Instruments", name: "Plaits"})
      eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths"})
      eurorack_module_fixture(%{manufacturer: "Make Noise", name: "Maths II"})

      assert Inventory.list_manufacturers() == ["Make Noise", "Mutable Instruments"]
    end

    test "liefert eine leere Liste, wenn keine Module existieren" do
      assert Inventory.list_manufacturers() == []
    end
  end

  describe "get_eurorack_module!/1" do
    test "liefert das Modul mit der gegebenen ID" do
      %{id: id} = eurorack_module_fixture()

      assert %EurorackModule{id: ^id} = Inventory.get_eurorack_module!(id)
    end

    test "wirft, wenn kein Modul mit der ID existiert" do
      assert_raise Ecto.NoResultsError, fn ->
        Inventory.get_eurorack_module!(-1)
      end
    end
  end

  describe "update_eurorack_module/2" do
    test "aktualisiert die Felder mit gueltigen Attributen" do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, %EurorackModule{} = updated} =
               Inventory.update_eurorack_module(eurorack_module, %{
                 name: "Maths (aktualisiert)",
                 hp: 24
               })

      assert updated.name == "Maths (aktualisiert)"
      assert updated.hp == 24
      assert DateTime.compare(updated.updated_at, eurorack_module.updated_at) in [:gt, :eq]
    end

    test "liefert einen Fehler bei ungueltigen Attributen und aendert nichts" do
      eurorack_module = eurorack_module_fixture()

      assert {:error, changeset} = Inventory.update_eurorack_module(eurorack_module, %{hp: -5})
      assert "muss groesser als 0 sein" in errors_on(changeset).hp

      assert Inventory.get_eurorack_module!(eurorack_module.id).hp == eurorack_module.hp
    end
  end

  describe "delete_eurorack_module/1" do
    test "entfernt das Modul" do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, %EurorackModule{}} = Inventory.delete_eurorack_module(eurorack_module)

      assert_raise Ecto.NoResultsError, fn ->
        Inventory.get_eurorack_module!(eurorack_module.id)
      end
    end

    test "entfernt eine vorhandene PDF-Anleitung vom Storage" do
      eurorack_module = eurorack_module_fixture()
      fixture = Path.expand("../support/fixtures/files/sample.pdf", __DIR__)

      assert {:ok, with_manual} =
               Inventory.attach_manual(eurorack_module, %{
                 tmp_path: fixture,
                 filename: "sample.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(fixture).size
               })

      path = ModuleOMat.Inventory.ManualStorage.LocalDisk.path_for(with_manual.manual_pdf_key)
      assert File.exists?(path)

      assert {:ok, _} = Inventory.delete_eurorack_module(with_manual)
      refute File.exists?(path)
    end
  end

  describe "soft_delete_eurorack_module/1" do
    test "setzt deleted_at, ohne den Datensatz zu entfernen" do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, %EurorackModule{} = deleted} =
               Inventory.soft_delete_eurorack_module(eurorack_module)

      assert %DateTime{} = deleted.deleted_at
      assert Inventory.get_eurorack_module!(eurorack_module.id).deleted_at != nil
    end

    test "behaelt eine vorhandene PDF-Anleitung" do
      eurorack_module = eurorack_module_fixture()
      fixture = Path.expand("../support/fixtures/files/sample.pdf", __DIR__)

      assert {:ok, with_manual} =
               Inventory.attach_manual(eurorack_module, %{
                 tmp_path: fixture,
                 filename: "sample.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(fixture).size
               })

      path = ModuleOMat.Inventory.ManualStorage.LocalDisk.path_for(with_manual.manual_pdf_key)

      assert {:ok, _} = Inventory.soft_delete_eurorack_module(with_manual)
      assert File.exists?(path)
    end
  end

  describe "get_active_eurorack_module/2" do
    test "liefert aktive Module und ignoriert Soft-Deletes" do
      module = eurorack_module_fixture()
      assert %EurorackModule{id: id} = Inventory.get_active_eurorack_module(module.id)
      assert id == module.id

      {:ok, _} = Inventory.soft_delete_eurorack_module(module)
      assert Inventory.get_active_eurorack_module(module.id) == nil

      assert_raise Ecto.NoResultsError, fn ->
        Inventory.get_active_eurorack_module!(module.id)
      end
    end
  end

  describe "attach_manual/2" do
    @fixture Path.expand("../support/fixtures/files/sample.pdf", __DIR__)

    test "speichert PDF und setzt Metadaten" do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, updated} =
               Inventory.attach_manual(eurorack_module, %{
                 tmp_path: @fixture,
                 filename: "maths.pdf",
                 content_type: "application/pdf",
                 size: 1234
               })

      assert updated.manual_pdf_key
      assert updated.manual_pdf_filename == "maths.pdf"
      assert updated.manual_pdf_content_type == "application/pdf"
      assert updated.manual_pdf_size_bytes == 1234

      assert File.exists?(
               ModuleOMat.Inventory.ManualStorage.LocalDisk.path_for(updated.manual_pdf_key)
             )
    end

    test "ersetzt eine vorhandene Anleitung und loescht die alte Datei" do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, first} =
               Inventory.attach_manual(eurorack_module, %{
                 tmp_path: @fixture,
                 filename: "old.pdf",
                 content_type: "application/pdf",
                 size: 100
               })

      old_key = first.manual_pdf_key
      old_path = ModuleOMat.Inventory.ManualStorage.LocalDisk.path_for(old_key)

      assert {:ok, second} =
               Inventory.attach_manual(first, %{
                 tmp_path: @fixture,
                 filename: "new.pdf",
                 content_type: "application/pdf",
                 size: 200
               })

      assert second.manual_pdf_key != old_key
      assert second.manual_pdf_filename == "new.pdf"
      refute File.exists?(old_path)

      assert File.exists?(
               ModuleOMat.Inventory.ManualStorage.LocalDisk.path_for(second.manual_pdf_key)
             )
    end
  end

  describe "remove_manual/1" do
    test "entfernt Metadaten und Datei" do
      eurorack_module = eurorack_module_fixture()
      fixture = Path.expand("../support/fixtures/files/sample.pdf", __DIR__)

      assert {:ok, with_manual} =
               Inventory.attach_manual(eurorack_module, %{
                 tmp_path: fixture,
                 filename: "sample.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(fixture).size
               })

      path = ModuleOMat.Inventory.ManualStorage.LocalDisk.path_for(with_manual.manual_pdf_key)

      assert {:ok, cleared} = Inventory.remove_manual(with_manual)
      assert cleared.manual_pdf_key == nil
      assert cleared.manual_pdf_filename == nil
      assert cleared.manual_pdf_content_type == nil
      assert cleared.manual_pdf_size_bytes == nil
      refute File.exists?(path)
    end
  end

  describe "prepare_duplicate_eurorack_module/1" do
    test "kopiert Felder und YouTube-URLs ohne IDs" do
      source =
        eurorack_module_fixture(%{
          name: "Maths",
          purchase_price: "250.00",
          current_value: "300.00",
          youtube_videos: [%{url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ"}]
        })

      duplicate = Inventory.prepare_duplicate_eurorack_module(source)

      assert duplicate.id == nil
      assert duplicate.name == "Maths"
      assert Decimal.eq?(duplicate.purchase_price, Decimal.new("250.00"))
      assert Decimal.eq?(duplicate.current_value, Decimal.new("300.00"))
      assert length(duplicate.youtube_videos) == 1
      assert hd(duplicate.youtube_videos).id == nil
      assert hd(duplicate.youtube_videos).url == "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
    end
  end

  describe "copy_manual/2" do
    @fixture Path.expand("../support/fixtures/files/sample.pdf", __DIR__)

    test "kopiert die PDF-Datei unter einem neuen Key" do
      source = eurorack_module_fixture()

      assert {:ok, with_manual} =
               Inventory.attach_manual(source, %{
                 tmp_path: @fixture,
                 filename: "maths.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(@fixture).size
               })

      target = eurorack_module_fixture(%{name: "Maths II", manufacturer: "Make Noise"})

      assert {:ok, copied} =
               Inventory.copy_manual(target, with_manual.manual_pdf_key, %{
                 filename: with_manual.manual_pdf_filename,
                 content_type: with_manual.manual_pdf_content_type,
                 size_bytes: with_manual.manual_pdf_size_bytes
               })

      assert copied.manual_pdf_key
      assert copied.manual_pdf_key != with_manual.manual_pdf_key
      assert copied.manual_pdf_filename == "maths.pdf"

      assert File.exists?(
               ModuleOMat.Inventory.ManualStorage.LocalDisk.path_for(copied.manual_pdf_key)
             )

      assert File.exists?(
               ModuleOMat.Inventory.ManualStorage.LocalDisk.path_for(with_manual.manual_pdf_key)
             )
    end
  end

  describe "change_eurorack_module/2" do
    test "liefert ein Changeset fuer das Modul" do
      eurorack_module = eurorack_module_fixture()

      assert %Ecto.Changeset{} = Inventory.change_eurorack_module(eurorack_module)
    end
  end

  describe "price observations" do
    test "create_price_observations speichert Beobachtungen und setzt Median als current_value" do
      module = eurorack_module_fixture(%{current_value: nil})

      assert {:ok, result} =
               Inventory.create_price_observations(module, [
                 %{amount: "150.00", source: "ebay_sold", observed_on: ~D[2026-08-01]},
                 %{amount: "210.00", source: "shop", observed_on: ~D[2026-08-02]},
                 %{amount: "180.00", source: "ebay_sold", observed_on: ~D[2026-08-03]}
               ])

      assert length(result.observations) == 3
      assert Decimal.eq?(result.module.current_value, Decimal.new("180.00"))
      assert Decimal.eq?(result.price_range.min, Decimal.new("150.00"))
      assert Decimal.eq?(result.price_range.max, Decimal.new("210.00"))
      assert result.price_range.count == 3
      assert result.price_range.last_observed_on == ~D[2026-08-03]
    end

    test "Median bei gerader Anzahl ist Mittel der beiden mittleren Werte" do
      module = eurorack_module_fixture()

      assert {:ok, result} =
               Inventory.create_price_observations(module, [
                 %{amount: "100", source: "shop"},
                 %{amount: "200", source: "shop"}
               ])

      assert Decimal.eq?(result.module.current_value, Decimal.new("150"))
    end

    test "erlaubt expliziten current_value statt Median" do
      module = eurorack_module_fixture()

      assert {:ok, result} =
               Inventory.create_price_observations(
                 module,
                 [%{amount: "100", source: "shop"}, %{amount: "200", source: "shop"}],
                 set_current_value: "175.50"
               )

      assert Decimal.eq?(result.module.current_value, Decimal.new("175.50"))
    end

    test "leere Observation-Liste liefert Fehler" do
      module = eurorack_module_fixture()
      assert {:error, :empty_observations} = Inventory.create_price_observations(module, [])
    end

    test "price_ranges_for_modules aggregiert pro Modul-ID" do
      a = eurorack_module_fixture(%{name: "A"})
      b = eurorack_module_fixture(%{name: "B", manufacturer: "Other"})

      {:ok, _} =
        Inventory.create_price_observations(a, [
          %{amount: "10", source: "shop"},
          %{amount: "30", source: "shop"}
        ])

      ranges = Inventory.price_ranges_for_modules([a.id, b.id])

      assert Map.has_key?(ranges, a.id)
      refute Map.has_key?(ranges, b.id)
      assert Decimal.eq?(ranges[a.id].min, Decimal.new("10"))
      assert Decimal.eq?(ranges[a.id].max, Decimal.new("30"))
    end

    test "list_modules_for_valuation und get_module_for_valuation! ignorieren Soft-Deletes" do
      active = eurorack_module_fixture(%{name: "Active"})
      deleted = eurorack_module_fixture(%{name: "Deleted", manufacturer: "X"})
      {:ok, _} = Inventory.soft_delete_eurorack_module(deleted)

      ids = Inventory.list_modules_for_valuation() |> Enum.map(& &1.id)
      assert active.id in ids
      refute deleted.id in ids

      assert_raise Ecto.NoResultsError, fn ->
        Inventory.get_module_for_valuation!(deleted.id)
      end
    end
  end
end
