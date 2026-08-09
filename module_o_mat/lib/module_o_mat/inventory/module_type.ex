defmodule ModuleOMat.Inventory.ModuleType do
  @moduledoc """
  Ein vom Anwender definierbarer Modultyp (z.B. "VCO", "Granular"), der als
  Option fuer das `type`-Feld eines `EurorackModule` zur Verfuegung steht.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "module_types" do
    field(:name, :string)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(module_type, attrs) do
    module_type
    |> cast(attrs, [:name])
    |> update_change(:name, &trim/1)
    |> validate_required([:name], message: "muss ausgefuellt werden")
    |> unique_constraint(:name, message: "existiert bereits")
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value
end
