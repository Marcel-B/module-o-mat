defmodule ModuleOMat.Repo.Migrations.CreateEurorackModules do
  use Ecto.Migration

  def change do
    create table(:eurorack_modules) do
      add :manufacturer, :string, null: false
      add :name, :string, null: false
      add :hp, :integer, null: false
      add :type, :string, null: false

      add :current_draw_plus12v_ma, :integer
      add :current_draw_minus12v_ma, :integer
      add :current_draw_plus5v_ma, :integer

      add :depth_mm, :integer
      add :description, :text
      add :manual_url, :string

      timestamps(type: :utc_datetime)
    end

    create index(:eurorack_modules, [:manufacturer])
    create index(:eurorack_modules, [:type])
  end
end
