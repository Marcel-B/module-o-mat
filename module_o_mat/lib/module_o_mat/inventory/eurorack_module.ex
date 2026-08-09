defmodule ModuleOMat.Inventory.EurorackModule do
  @moduledoc """
  Domain-Typ und Persistenz-Mapping fuer ein einzelnes Eurorack-Modul.

  Das Schema definiert sowohl die Felder/Typen des Domain-Modells als auch
  das Mapping auf die Tabelle `eurorack_modules`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias ModuleOMat.Inventory.YoutubeVideo

  @required_fields [:manufacturer, :name, :hp, :type]
  @optional_fields [
    :subtypes,
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
    field(:subtypes, {:array, :string}, default: [])

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

    has_many(:youtube_videos, YoutubeVideo,
      preload_order: [asc: :position],
      on_replace: :delete
    )

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(eurorack_module, attrs) do
    attrs = inject_youtube_positions(attrs)

    eurorack_module
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> update_change(:type, &trim/1)
    |> update_change(:subtypes, &normalize_subtypes/1)
    |> validate_required(@required_fields, message: "muss ausgefuellt werden")
    |> exclude_haupttyp_from_subtypes()
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
    |> cast_assoc(:youtube_videos,
      with: &YoutubeVideo.changeset/2,
      sort_param: :youtube_videos_order,
      drop_param: :youtube_videos_drop
    )
  end

  @doc false
  def manual_changeset(eurorack_module, attrs) do
    cast(eurorack_module, attrs, @manual_fields)
  end

  defp inject_youtube_positions(attrs) when is_map(attrs) do
    cond do
      is_list(Map.get(attrs, :youtube_videos)) ->
        Map.update!(attrs, :youtube_videos, &assign_positions/1)

      is_list(Map.get(attrs, "youtube_videos")) ->
        Map.update!(attrs, "youtube_videos", &assign_positions/1)

      is_map(Map.get(attrs, "youtube_videos")) ->
        order = Map.get(attrs, "youtube_videos_order") || Map.get(attrs, :youtube_videos_order)
        Map.update!(attrs, "youtube_videos", &assign_positions_map(&1, order))

      is_map(Map.get(attrs, :youtube_videos)) ->
        order = Map.get(attrs, :youtube_videos_order) || Map.get(attrs, "youtube_videos_order")
        Map.update!(attrs, :youtube_videos, &assign_positions_map(&1, order))

      true ->
        attrs
    end
  end

  defp inject_youtube_positions(attrs), do: attrs

  defp assign_positions(videos) when is_list(videos) do
    videos
    |> Enum.with_index()
    |> Enum.map(fn {video, index} -> put_position(video, index) end)
  end

  defp assign_positions_map(videos, order) when is_map(videos) do
    keys =
      cond do
        is_list(order) and order != [] ->
          Enum.map(order, &to_string/1)

        true ->
          videos
          |> Map.keys()
          |> Enum.map(&to_string/1)
          |> Enum.sort_by(fn key ->
            case Integer.parse(key) do
              {int, ""} -> int
              _ -> 0
            end
          end)
      end

    keys
    |> Enum.with_index()
    |> Map.new(fn {key, index} ->
      video = Map.get(videos, key) || Map.get(videos, maybe_int_key(key)) || %{}
      {key, put_position(video, index)}
    end)
  end

  defp maybe_int_key(key) do
    case Integer.parse(to_string(key)) do
      {int, ""} -> int
      _ -> key
    end
  end

  defp put_position(video, index) when is_map(video) do
    cond do
      Map.has_key?(video, "url") or Map.has_key?(video, "id") or Map.has_key?(video, "position") ->
        Map.put(video, "position", index)

      true ->
        Map.put(video, :position, index)
    end
  end

  defp put_position(video, _index), do: video

  defp trim(value) when is_binary(value), do: String.trim(value)
  defp trim(value), do: value

  defp normalize_subtypes(nil), do: []
  defp normalize_subtypes(subtype) when is_binary(subtype), do: normalize_subtypes([subtype])

  defp normalize_subtypes(subtypes) when is_list(subtypes) do
    subtypes
    |> Enum.map(&trim_subtype/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.uniq()
  end

  defp normalize_subtypes(_), do: []

  defp trim_subtype(value) when is_binary(value), do: String.trim(value)
  defp trim_subtype(_), do: nil

  defp exclude_haupttyp_from_subtypes(changeset) do
    type = get_field(changeset, :type)
    subtypes = get_field(changeset, :subtypes) || []

    cleaned = Enum.reject(subtypes, &(&1 == type))

    if cleaned == subtypes do
      changeset
    else
      put_change(changeset, :subtypes, cleaned)
    end
  end
end
