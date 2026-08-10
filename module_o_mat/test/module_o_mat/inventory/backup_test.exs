defmodule ModuleOMat.Inventory.BackupTest do
  use ModuleOMat.DataCase, async: false

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.ManualStorage.LocalDisk
  alias ModuleOMat.Inventory.ModulePriceObservation
  alias ModuleOMat.Repo

  @fixture Path.expand("../../support/fixtures/files/sample.pdf", __DIR__)

  describe "export_backup/1 and import_backup/1" do
    test "roundtrip erhaelt Module, Typen, Videos, Preisbeobachtungen und PDFs" do
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

      assert {:ok, %{observations: [obs_a, obs_b], module: valued}} =
               Inventory.create_price_observations(
                 module,
                 [
                   %{
                     amount: "240.00",
                     currency: "EUR",
                     source: "ebay_sold",
                     source_url: "https://ebay.example/item/1",
                     observed_on: ~D[2026-08-01],
                     notes: "guter Zustand"
                   },
                   %{
                     amount: "260.00",
                     source: "shop",
                     source_url: "https://shop.example/clouds",
                     observed_on: ~D[2026-08-05],
                     notes: nil
                   }
                 ],
                 set_current_value: nil
               )

      assert {:ok, with_manual} =
               Inventory.attach_manual(valued, %{
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

      restored_obs =
        Inventory.get_module_for_valuation!(with_manual.id).price_observations
        |> Enum.sort_by(& &1.id)

      assert length(restored_obs) == 2

      first = Enum.find(restored_obs, &(&1.id == obs_a.id))
      second = Enum.find(restored_obs, &(&1.id == obs_b.id))

      assert first.eurorack_module_id == with_manual.id
      assert Decimal.equal?(first.amount, Decimal.new("240.00"))
      assert first.currency == "EUR"
      assert first.source == "ebay_sold"
      assert first.source_url == "https://ebay.example/item/1"
      assert first.observed_on == ~D[2026-08-01]
      assert first.notes == "guter Zustand"

      assert second.eurorack_module_id == with_manual.id
      assert Decimal.equal?(second.amount, Decimal.new("260.00"))
      assert second.currency == "EUR"
      assert second.source == "shop"
      assert second.source_url == "https://shop.example/clouds"
      assert second.observed_on == ~D[2026-08-05]
      assert second.notes == nil

      assert Enum.any?(Inventory.list_module_type_records(), &(&1.id == module_type.id))
      assert "Granular" in Inventory.list_module_types()
    end

    test "import ersetzt bestehende Preisbeobachtungen durch Backup-Daten" do
      module = eurorack_module_fixture(%{name: "Clouds", manufacturer: "Mutable"})

      assert {:ok, %{observations: [kept]}} =
               Inventory.create_price_observations(
                 module,
                 [
                   %{
                     amount: "200.00",
                     source: "ebay_sold",
                     observed_on: ~D[2026-07-01],
                     notes: "im Backup"
                   }
                 ],
                 set_current_value: nil
               )

      zip_path = tmp_zip_path()
      assert {:ok, _} = Inventory.export_backup(zip_path)

      assert {:ok, %{observations: [extra]}} =
               Inventory.create_price_observations(
                 Inventory.get_eurorack_module!(module.id),
                 [
                   %{
                     amount: "999.00",
                     source: "shop",
                     observed_on: ~D[2026-08-10],
                     notes: "nicht im Backup"
                   }
                 ],
                 set_current_value: nil
               )

      assert Repo.get(ModulePriceObservation, extra.id)

      assert :ok = Inventory.import_backup(zip_path)

      restored_ids =
        Inventory.get_module_for_valuation!(module.id).price_observations
        |> Enum.map(& &1.id)

      assert restored_ids == [kept.id]
      assert Repo.get(ModulePriceObservation, extra.id) == nil

      [only] = Inventory.get_module_for_valuation!(module.id).price_observations
      assert Decimal.equal?(only.amount, Decimal.new("200.00"))
      assert only.notes == "im Backup"
    end

    test "importiert aeltere Backups ohne module_price_observations.csv" do
      module =
        eurorack_module_fixture(%{
          manufacturer: "Legacy",
          name: "OldFormat",
          hp: 10,
          type: "Utility"
        })

      zip_path = tmp_zip_path()
      assert {:ok, ^zip_path} = Inventory.export_backup(zip_path)

      stripped_zip = strip_file_from_zip!(zip_path, "module_price_observations.csv")

      assert :ok = Inventory.import_backup(stripped_zip)

      restored = Inventory.get_eurorack_module!(module.id)
      assert restored.manufacturer == "Legacy"
      assert restored.name == "OldFormat"
      assert Inventory.get_module_for_valuation!(module.id).price_observations == []
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

  defp strip_file_from_zip!(source_zip, filename) do
    extract_root =
      Path.join(
        System.tmp_dir!(),
        "module_o_mat_strip_#{System.unique_integer([:positive])}"
      )

    File.mkdir_p!(extract_root)
    {:ok, _} = :zip.extract(String.to_charlist(source_zip), cwd: String.to_charlist(extract_root))

    extract_root
    |> Path.join("**/#{filename}")
    |> Path.wildcard()
    |> Enum.each(&File.rm!/1)

    direct = Path.join(extract_root, filename)
    if File.regular?(direct), do: File.rm!(direct)

    stripped_zip = tmp_zip_path()

    entries =
      extract_root
      |> Path.join("**")
      |> Path.wildcard()
      |> Enum.filter(&File.regular?/1)
      |> Enum.map(fn absolute ->
        relative = Path.relative_to(absolute, extract_root)
        {String.to_charlist(relative), File.read!(absolute)}
      end)

    {:ok, _} = :zip.create(String.to_charlist(stripped_zip), entries)
    File.rm_rf!(extract_root)
    stripped_zip
  end
end
