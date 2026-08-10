defmodule ModuleOMat.Inventory.BackupTest do
  use ModuleOMat.DataCase, async: false

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.ManualStorage.LocalDisk
  alias ModuleOMat.Repo

  @fixture Path.expand("../../support/fixtures/files/sample.pdf", __DIR__)

  describe "export_backup/1 and import_backup/1" do
    test "roundtrip erhaelt Module, Typen, Videos und PDFs" do
      module_type = module_type_fixture(%{name: "Granular"})

      module =
        eurorack_module_fixture(%{
          manufacturer: "Mutable",
          name: "Clouds",
          hp: 18,
          type: "Granular",
          subtypes: ["Reverb"],
          purchase_price: Decimal.new("299.00"),
          current_value: Decimal.new("250.50"),
          youtube_videos: [
            %{url: "https://www.youtube.com/watch?v=first111111"},
            %{url: "https://www.youtube.com/watch?v=second22222"}
          ]
        })

      assert {:ok, with_manual} =
               Inventory.attach_manual(module, %{
                 tmp_path: @fixture,
                 filename: "clouds.pdf",
                 content_type: "application/pdf",
                 size: File.stat!(@fixture).size
               })

      zip_path = tmp_zip_path()
      assert {:ok, ^zip_path} = Inventory.export_backup(zip_path)
      assert File.regular?(zip_path)

      other =
        eurorack_module_fixture(%{
          manufacturer: "Other",
          name: "Noise",
          type: "Utility"
        })

      assert :ok = Inventory.import_backup(zip_path)

      assert Repo.get(ModuleOMat.Inventory.EurorackModule, other.id) == nil

      restored = Inventory.get_eurorack_module!(with_manual.id)
      assert restored.manufacturer == "Mutable"
      assert restored.name == "Clouds"
      assert restored.hp == 18
      assert restored.type == "Granular"
      assert restored.subtypes == ["Reverb"]
      assert Decimal.equal?(restored.purchase_price, Decimal.new("299.00"))
      assert Decimal.equal?(restored.current_value, Decimal.new("250.50"))
      assert restored.manual_pdf_key == with_manual.manual_pdf_key
      assert restored.manual_pdf_filename == "clouds.pdf"
      assert File.exists?(LocalDisk.path_for(restored.manual_pdf_key))

      assert Enum.map(restored.youtube_videos, & &1.url) == [
               "https://www.youtube.com/watch?v=first111111",
               "https://www.youtube.com/watch?v=second22222"
             ]

      assert Enum.any?(Inventory.list_module_type_records(), &(&1.id == module_type.id))
      assert "Granular" in Inventory.list_module_types()
    end

    test "exportiert keine soft-geloeschten Module" do
      active = eurorack_module_fixture(%{name: "Active"})
      deleted = eurorack_module_fixture(%{name: "Deleted", manufacturer: "X"})

      assert {:ok, _} = Inventory.soft_delete_eurorack_module(deleted)

      zip_path = tmp_zip_path()
      assert {:ok, _} = Inventory.export_backup(zip_path)

      assert {:ok, _} =
               Inventory.create_eurorack_module(%{
                 manufacturer: "Temp",
                 name: "Temp",
                 hp: 4,
                 type: "Utility"
               })

      assert :ok = Inventory.import_backup(zip_path)

      assert Inventory.get_eurorack_module!(active.id).name == "Active"
      assert_raise Ecto.NoResultsError, fn -> Inventory.get_eurorack_module!(deleted.id) end
      assert Enum.map(Inventory.list_eurorack_modules(), & &1.name) == ["Active"]
    end

    test "liefert Fehler bei fehlender Datei" do
      assert {:error, reason} = Inventory.import_backup("/tmp/does-not-exist-backup.zip")
      assert reason =~ "nicht gefunden"
    end

    test "importiert Backup mit zusaetzlichem Wrapper-Ordner im ZIP" do
      module =
        eurorack_module_fixture(%{
          manufacturer: "Nested",
          name: "Wrapped",
          hp: 8,
          type: "Utility"
        })

      flat_zip = tmp_zip_path()
      assert {:ok, ^flat_zip} = Inventory.export_backup(flat_zip)

      nested_zip = wrap_zip_in_folder!(flat_zip, "inventory-backup")

      assert :ok = Inventory.import_backup(nested_zip)
      restored = Inventory.get_eurorack_module!(module.id)
      assert restored.manufacturer == "Nested"
      assert restored.name == "Wrapped"
    end
  end

  defp tmp_zip_path do
    Path.join(
      System.tmp_dir!(),
      "module_o_mat_backup_test_#{System.unique_integer([:positive])}.zip"
    )
  end

  defp wrap_zip_in_folder!(source_zip, folder_name) do
    extract_root =
      Path.join(
        System.tmp_dir!(),
        "module_o_mat_wrap_#{System.unique_integer([:positive])}"
      )

    folder = Path.join(extract_root, folder_name)
    File.mkdir_p!(folder)

    {:ok, _} = :zip.extract(String.to_charlist(source_zip), cwd: String.to_charlist(folder))

    nested_zip = tmp_zip_path()

    entries =
      extract_root
      |> Path.join("**")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(fn absolute ->
        relative = Path.relative_to(absolute, extract_root)
        {String.to_charlist(relative), File.read!(absolute)}
      end)

    {:ok, _} = :zip.create(String.to_charlist(nested_zip), entries)
    File.rm_rf!(extract_root)
    nested_zip
  end
end
