defmodule ModuleOMat.Repo.Migrations.AddPurchasePriceAndCurrentValueToEurorackModules do
  use Ecto.Migration

  def change do
    alter table(:eurorack_modules) do
      add :purchase_price, :decimal, precision: 10, scale: 2
      add :current_value, :decimal, precision: 10, scale: 2
    end
  end
end
