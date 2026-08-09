defmodule ModuleOMat.Inventory.EurorackModule do
  @moduledoc """
  Domain-Typ und Persistenz-Mapping fuer ein einzelnes Eurorack-Modul.

  Das Schema definiert sowohl die Felder/Typen des Domain-Modells als auch
  das Mapping auf die Tabelle `eurorack_modules`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @required_fields [:manufacturer, :name, :hp, :type]
  @optional_fields [
    :current_draw_plus12v_ma,
    :current_draw_minus12v_ma,
    :current_draw_plus5v_ma,
    :depth_mm,
    :description,
    :manual_url
  ]
  @manual_fields [
    :manual_pdf_key,
    :manual_pdf_filename,
    :manual_pdf_content_type,
    :manual_pdf_size_bytes
  ]

  schema "eurorack_modules" do
    field(:manufacturer, :string)
    field(:name, :string)
    field(:hp, :integer)
    field(:type, :string)

    field(:current_draw_plus12v_ma, :integer)
    field(:current_draw_minus12v_ma, :integer)
    field(:current_draw_plus5v_ma, :integer)

    field(:depth_mm, :integer)
    field(:description, :string)
    field(:manual_url, :string)

    field(:manual_pdf_key, :string)
    field(:manual_pdf_filename, :string)
    field(:manual_pdf_content_type, :string)
    field(:manual_pdf_size_bytes, :integer)

    field(:deleted_at, :utc_datetime)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(eurorack_module, attrs) do
    eurorack_module
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> update_change(:type, &trim/1)
    |> validate_required(@required_fields, message: "muss ausgefuellt werden")
    |> validate_number(:hp, greater_than: 0, message: "muss groesser als 0 sein")
    |> validate_number(:current_draw_plus12v_ma,
      greater_than_or_equal_to: 0,
      message: "darf nicht negativ sein"
    )
    |> validate_number(:current_draw_minus12v_ma,
      greater_than_or_equal_to: 0,
      message: "darf nicht negativ sein"
    )
    |> validate_number(:current_draw_plus5v_ma,
      greater_than_or_equal_to: 0,
      message: "darf nicht negativ sein"
    )
    |> validate_number(:depth_mm, greater_than_or_equal_to: 0, message: "darf nicht negativ sein")
  end

  @doc false
  def manual_changeset(eurorack_module, attrs) do
    cast(eurorack_module, attrs, @manual_fields)
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value
end
