defmodule ModuleOMat.Repo.Migrations.CreateModulePriceObservations do
  use Ecto.Migration

  def change do
    create table(:module_price_observations) do
      add :amount, :decimal, null: false
      add :currency, :string, null: false, default: "EUR"
      add :source, :string, null: false
      add :source_url, :string
      add :observed_on, :date, null: false
      add :notes, :string

      add :eurorack_module_id,
          references(:eurorack_modules, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:module_price_observations, [:eurorack_module_id])
    create index(:module_price_observations, [:eurorack_module_id, :observed_on])
  end
end
