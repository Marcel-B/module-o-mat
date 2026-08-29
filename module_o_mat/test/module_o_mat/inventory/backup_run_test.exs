defmodule ModuleOMat.Inventory.BackupRunTest do
  use ModuleOMat.DataCase, async: true

  import ModuleOMat.InventoryFixtures

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.BackupRun

  describe "record_backup_run/1" do
    test "speichert Datum, Dateiname, Groesse und Erfolg" do
      assert {:ok, %BackupRun{} = run} =
               Inventory.record_backup_run(%{
                 filename: "inventory-sat.zip",
                 size_bytes: 4096,
                 success: true
               })

      assert run.filename == "inventory-sat.zip"
      assert run.size_bytes == 4096
      assert run.success
      assert %DateTime{} = run.inserted_at
    end

    test "erlaubt fehlende Groesse und fehlenden Dateinamen bei Fehlschlag" do
      assert {:ok, %BackupRun{} = run} =
               Inventory.record_backup_run(%{filename: nil, size_bytes: nil, success: false})

      refute run.success
      assert run.filename == nil
      assert run.size_bytes == nil
    end
  end

  describe "list_backup_runs/1" do
    test "liefert die neuesten fuenf Eintraege und laedt weitere Seiten nach" do
      runs =
        for n <- 1..6 do
          backup_run_fixture(%{filename: "inventory-#{n}.zip", size_bytes: n, success: n != 2})
        end

      first_page = Inventory.list_backup_runs(page: 1)
      assert first_page.page == 1
      assert first_page.per_page == 5
      assert first_page.total == 6
      assert length(first_page.backup_runs) == 5

      assert Enum.map(first_page.backup_runs, & &1.id) ==
               runs |> Enum.reverse() |> Enum.take(5) |> Enum.map(& &1.id)

      second_page = Inventory.list_backup_runs(page: 2)
      assert second_page.page == 2
      assert length(second_page.backup_runs) == 1
      assert hd(second_page.backup_runs).id == hd(runs).id
    end

    test "behandelt ungueltige Seiten als Seite 1" do
      backup_run_fixture()
      page = Inventory.list_backup_runs(page: 0)
      assert page.page == 1
      assert length(page.backup_runs) == 1
    end
  end

  describe "backup_run_status/0" do
    test "liefert die Zeitpunkte des letzten Erfolgs und Fehlschlags" do
      _older_success = backup_run_fixture(%{filename: "old.zip", success: true})
      failure = backup_run_fixture(%{filename: "fail.zip", success: false})
      newer_success = backup_run_fixture(%{filename: "new.zip", success: true})

      status = Inventory.backup_run_status()
      assert status.last_success_at == newer_success.inserted_at
      assert status.last_failure_at == failure.inserted_at
    end

    test "liefert nil, wenn noch keine Laeufe existieren" do
      assert Inventory.backup_run_status() == %{last_success_at: nil, last_failure_at: nil}
    end
  end
end
