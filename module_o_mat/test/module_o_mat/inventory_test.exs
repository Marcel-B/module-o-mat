defmodule ModuleOMat.InventoryTest do
  use ModuleOMat.DataCase, async: true

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.EurorackModule

  import ModuleOMat.InventoryFixtures

  describe "create_eurorack_module/1" do
    test "legt ein Modul mit gueltigen Attributen an und setzt Zeitstempel" do
      attrs = valid_eurorack_module_attrs()

      assert {:ok, %EurorackModule{} = eurorack_module} = Inventory.create_eurorack_module(attrs)

      assert eurorack_module.manufacturer == "Make Noise"
      assert eurorack_module.name == "Maths"
      assert eurorack_module.hp == 20
      assert eurorack_module.type == :envelope
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
      assert "can't be blank" in errors.manufacturer
      assert "can't be blank" in errors.name
      assert "can't be blank" in errors.hp
      assert "can't be blank" in errors.type
    end

    test "liefert einen Fehler bei ungueltigem type" do
      attrs = valid_eurorack_module_attrs(%{type: :not_a_real_type})

      assert {:error, changeset} = Inventory.create_eurorack_module(attrs)
      assert "is invalid" in errors_on(changeset).type
    end

    test "liefert einen Fehler bei hp <= 0" do
      attrs = valid_eurorack_module_attrs(%{hp: 0})

      assert {:error, changeset} = Inventory.create_eurorack_module(attrs)
      assert "must be greater than 0" in errors_on(changeset).hp
    end

    test "liefert einen Fehler bei negativem Strombedarf" do
      attrs = valid_eurorack_module_attrs(%{current_draw_plus12v_ma: -10})

      assert {:error, changeset} = Inventory.create_eurorack_module(attrs)
      assert "must be greater than or equal to 0" in errors_on(changeset).current_draw_plus12v_ma
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
      assert "must be greater than 0" in errors_on(changeset).hp

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

  describe "change_eurorack_module/2" do
    test "liefert ein Changeset fuer das Modul" do
      eurorack_module = eurorack_module_fixture()

      assert %Ecto.Changeset{} = Inventory.change_eurorack_module(eurorack_module)
    end
  end
end
