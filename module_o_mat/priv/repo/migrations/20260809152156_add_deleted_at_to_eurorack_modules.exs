defmodule ModuleOMat.Repo.Migrations.AddDeletedAtToEurorackModules do
  use Ecto.Migration

  def change do
    alter table(:eurorack_modules) do
      add :deleted_at, :utc_datetime
    end

    create index(:eurorack_modules, [:deleted_at])
  end
end
