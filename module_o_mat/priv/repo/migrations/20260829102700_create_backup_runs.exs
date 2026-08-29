defmodule ModuleOMat.Repo.Migrations.CreateBackupRuns do
  use Ecto.Migration

  def change do
    create table(:backup_runs) do
      add :filename, :string
      add :size_bytes, :integer
      add :success, :boolean, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:backup_runs, [:inserted_at])
    create index(:backup_runs, [:success, :inserted_at])
  end
end
