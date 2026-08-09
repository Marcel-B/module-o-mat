defmodule ModuleOMat.Repo.Migrations.AddSubtypesToEurorackModules do
  use Ecto.Migration

  def change do
    alter table(:eurorack_modules) do
      add :subtypes, {:array, :string}, null: false, default: []
    end
  end
end
