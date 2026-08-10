defmodule ModuleOMat.Inventory.ModulePriceObservation do
  @moduledoc """
  Eine beobachtete Verkaufspreisangabe fuer ein Eurorack-Modul (z.B. aus
  eBay-Verkaufspreisen oder Ladenangeboten), inklusive Quelle und Datum.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ModuleOMat.Inventory.EurorackModule

  @required_fields [:amount, :source, :observed_on, :eurorack_module_id]
  @optional_fields [:currency, :source_url, :notes]

  schema "module_price_observations" do
    field(:amount, :decimal)
    field(:currency, :string, default: "EUR")
    field(:source, :string)
    field(:source_url, :string)
    field(:observed_on, :date)
    field(:notes, :string)

    belongs_to(:eurorack_module, EurorackModule)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(observation, attrs) do
    observation
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> update_change(:currency, &trim_or_nil/1)
    |> update_change(:source, &trim_or_nil/1)
    |> update_change(:source_url, &trim_or_nil/1)
    |> update_change(:notes, &trim_or_nil/1)
    |> maybe_default_currency()
    |> maybe_default_observed_on()
    |> validate_required(@required_fields, message: "muss ausgefuellt werden")
    |> validate_number(:amount, greater_than_or_equal_to: 0, message: "darf nicht negativ sein")
    |> validate_length(:currency, max: 8)
    |> validate_length(:source, max: 64)
    |> foreign_key_constraint(:eurorack_module_id)
  end

  defp maybe_default_currency(changeset) do
    case get_field(changeset, :currency) do
      nil -> put_change(changeset, :currency, "EUR")
      "" -> put_change(changeset, :currency, "EUR")
      _ -> changeset
    end
  end

  defp maybe_default_observed_on(changeset) do
    case get_field(changeset, :observed_on) do
      nil -> put_change(changeset, :observed_on, Date.utc_today())
      _ -> changeset
    end
  end

  defp trim_or_nil(nil), do: nil
  defp trim_or_nil(value) when is_binary(value), do: String.trim(value)
  defp trim_or_nil(value), do: value
end
