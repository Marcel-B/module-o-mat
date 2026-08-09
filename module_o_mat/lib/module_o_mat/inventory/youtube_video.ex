defmodule ModuleOMat.Inventory.YoutubeVideo do
  @moduledoc """
  Ein YouTube-Link, der einem Eurorack-Modul zugeordnet ist. Die `position`
  bestimmt die Reihenfolge; der erste Eintrag ist das Primaervideo.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ModuleOMat.Inventory.EurorackModule
  alias ModuleOMat.Inventory.Youtube

  schema "youtube_videos" do
    field(:url, :string)
    field(:position, :integer, default: 0)

    belongs_to(:eurorack_module, EurorackModule)

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(youtube_video, attrs) do
    youtube_video
    |> cast(attrs, [:url, :position])
    |> update_change(:url, &trim/1)
    |> validate_required([:url], message: "muss ausgefuellt werden")
    |> validate_youtube_url()
    |> maybe_normalize_url()
  end

  defp validate_youtube_url(changeset) do
    validate_change(changeset, :url, fn :url, url ->
      if Youtube.valid_url?(url) do
        []
      else
        [url: "muss eine gueltige YouTube-URL sein"]
      end
    end)
  end

  defp maybe_normalize_url(changeset) do
    case get_change(changeset, :url) do
      nil ->
        changeset

      url ->
        case Youtube.watch_url(url) do
          nil -> changeset
          watch -> put_change(changeset, :url, watch)
        end
    end
  end

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value
end
