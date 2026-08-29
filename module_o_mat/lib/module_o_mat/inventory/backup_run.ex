defmodule ModuleOMat.Inventory.BackupRun do
  @moduledoc """
  Ein dokumentierter Sicherungsversuch (Nextcloud-Upload).

  Die Historie gehoert nicht zum Inventar-Backup und wird beim Export
  nicht mitgeschrieben.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "backup_runs" do
    field(:filename, :string)
    field(:size_bytes, :integer)
    field(:success, :boolean)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(backup_run, attrs) do
    backup_run
    |> cast(attrs, [:filename, :size_bytes, :success])
    |> validate_required([:success], message: "muss ausgefuellt werden")
    |> validate_number(:size_bytes,
      greater_than_or_equal_to: 0,
      message: "muss mindestens 0 sein"
    )
    |> update_change(:filename, &blank_to_nil/1)
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value
end
