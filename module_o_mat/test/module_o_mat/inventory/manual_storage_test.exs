defmodule ModuleOMat.Inventory.ManualStorageTest do
  use ExUnit.Case, async: false

  alias ModuleOMat.Inventory.ManualStorage
  alias ModuleOMat.Inventory.ManualStorage.LocalDisk

  @fixture Path.expand("../../support/fixtures/files/sample.pdf", __DIR__)

  setup do
    key = ManualStorage.new_key()
    on_exit(fn -> ManualStorage.delete(key) end)
    %{key: key}
  end

  describe "new_key/0" do
    test "liefert eine UUID" do
      key = ManualStorage.new_key()
      assert {:ok, _} = Ecto.UUID.cast(key)
    end
  end

  describe "store!/2 und delete/1" do
    test "speichert und loescht eine PDF-Datei", %{key: key} do
      assert :ok = ManualStorage.store!(key, @fixture)
      assert File.exists?(LocalDisk.path_for(key))

      assert :ok = ManualStorage.delete(key)
      refute File.exists?(LocalDisk.path_for(key))
    end

    test "delete/1 ist idempotent", %{key: key} do
      assert :ok = ManualStorage.delete(key)
      assert :ok = ManualStorage.delete(nil)
    end

    test "lehnt Nicht-PDF-Dateien ab", %{key: key} do
      tmp = Path.join(System.tmp_dir!(), "not-a-pdf-#{System.unique_integer([:positive])}.txt")
      File.write!(tmp, "hello")

      try do
        assert_raise ArgumentError, ~r/kein PDF/, fn ->
          ManualStorage.store!(key, tmp)
        end
      after
        File.rm(tmp)
      end
    end
  end

  describe "adapter/0" do
    test "liefert den konfigurierten Adapter" do
      assert ManualStorage.adapter() == LocalDisk
    end
  end
end
