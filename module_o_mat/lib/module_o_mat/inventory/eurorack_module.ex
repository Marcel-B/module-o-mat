defmodule ModuleOMat.Inventory.EurorackModule do
  @moduledoc """
  Domain-Typ und Persistenz-Mapping fuer ein einzelnes Eurorack-Modul.

  Das Schema definiert sowohl die Felder/Typen des Domain-Modells als auch
  das Mapping auf die Tabelle `eurorack_modules`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @types [
    :vco,
    :vca,
    :vcf,
    :lfo,
    :envelope,
    :sequencer,
    :quantizer,
    :clock,
    :random,
    :logic,
    :mixer,
    :effect,
    :utility,
    :midi_interface,
    :multiple,
    :attenuator,
    :noise,
    :other
  ]

  @required_fields [:manufacturer, :name, :hp, :type]
  @optional_fields [
    :current_draw_plus12v_ma,
    :current_draw_minus12v_ma,
    :current_draw_plus5v_ma,
    :depth_mm,
    :description,
    :manual_url
  ]

  schema "eurorack_modules" do
    field(:manufacturer, :string)
    field(:name, :string)
    field(:hp, :integer)
    field(:type, Ecto.Enum, values: @types)

    field(:current_draw_plus12v_ma, :integer)
    field(:current_draw_minus12v_ma, :integer)
    field(:current_draw_plus5v_ma, :integer)

    field(:depth_mm, :integer)
    field(:description, :string)
    field(:manual_url, :string)

    timestamps(type: :utc_datetime)
  end

  @doc "Liste der zulaessigen Werte fuer das Feld `type`."
  def types, do: @types

  @doc false
  def changeset(eurorack_module, attrs) do
    eurorack_module
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:hp, greater_than: 0)
    |> validate_number(:current_draw_plus12v_ma, greater_than_or_equal_to: 0)
    |> validate_number(:current_draw_minus12v_ma, greater_than_or_equal_to: 0)
    |> validate_number(:current_draw_plus5v_ma, greater_than_or_equal_to: 0)
    |> validate_number(:depth_mm, greater_than_or_equal_to: 0)
  end
end
