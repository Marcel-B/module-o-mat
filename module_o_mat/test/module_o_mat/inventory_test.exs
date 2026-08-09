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

  describe "list_used_types/0" do
    test "liefert alle bereits an Modulen verwendeten Typen ohne Duplikate, sortiert" do
      eurorack_module_fixture(%{type: "VCO"})
      eurorack_module_fixture(%{type: "Envelope"})
      eurorack_module_fixture(%{type: "Envelope"})

      assert Inventory.list_used_types() == ["Envelope", "VCO"]
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
  end

  describe "soft_delete_eurorack_module/1" do
    test "setzt deleted_at, ohne den Datensatz zu entfernen" do
      eurorack_module = eurorack_module_fixture()

      assert {:ok, %EurorackModule{} = deleted} =
               Inventory.soft_delete_eurorack_module(eurorack_module)

      assert %DateTime{} = deleted.deleted_at
      assert Inventory.get_eurorack_module!(eurorack_module.id).deleted_at != nil
    end
  end

  describe "change_eurorack_module/2" do
    test "liefert ein Changeset fuer das Modul" do
      eurorack_module = eurorack_module_fixture()

      assert %Ecto.Changeset{} = Inventory.change_eurorack_module(eurorack_module)
    end
  end
end
