defmodule ModuleOMatWeb.Api.JSON do
  @moduledoc """
  Gemeinsame JSON-Serialisierung fuer die HTTP-API (v1 und Agenten-Aliase).
  """

  alias ModuleOMat.Inventory.EurorackModule
  alias ModuleOMat.Inventory.ModulePriceObservation
  alias ModuleOMat.Inventory.ModuleType
  alias ModuleOMat.Inventory.YoutubeVideo

  def decimal(nil), do: nil
  def decimal(%Decimal{} = value), do: Decimal.to_float(Decimal.round(value, 2))

  def price_range(nil), do: nil

  def price_range(range) do
    %{
      min: decimal(range.min),
      max: decimal(range.max),
      count: range.count,
      last_observed_on: range.last_observed_on
    }
  end

  def observation(%ModulePriceObservation{} = observation) do
    %{
      id: observation.id,
      amount: decimal(observation.amount),
      currency: observation.currency,
      source: observation.source,
      source_url: observation.source_url,
      observed_on: observation.observed_on,
      notes: observation.notes
    }
  end

  def youtube_video(%YoutubeVideo{} = video) do
    %{
      id: video.id,
      url: video.url,
      position: video.position
    }
  end

  @doc """
  Schlankes Modul-JSON fuer den Bewertungs-Agenten. Felder nicht erweitern,
  der Prompt in `priv/agent_prompts/module_valuation.md` haengt daran.
  """
  def valuation_module(%EurorackModule{} = module, price_range) do
    %{
      id: module.id,
      manufacturer: module.manufacturer,
      name: module.name,
      hp: module.hp,
      current_value: decimal(module.current_value),
      price_range: price_range(price_range)
    }
  end

  def module(%EurorackModule{} = module, price_range \\ nil) do
    %{
      id: module.id,
      manufacturer: module.manufacturer,
      name: module.name,
      hp: module.hp,
      type: module.type,
      subtypes: module.subtypes || [],
      current_draw_plus12v_ma: module.current_draw_plus12v_ma,
      current_draw_minus12v_ma: module.current_draw_minus12v_ma,
      current_draw_plus5v_ma: module.current_draw_plus5v_ma,
      depth_mm: module.depth_mm,
      description: module.description,
      manual_url: module.manual_url,
      purchase_price: decimal(module.purchase_price),
      current_value: decimal(module.current_value),
      has_manual: not is_nil(module.manual_pdf_key),
      manual_pdf_filename: module.manual_pdf_filename,
      manual_pdf_content_type: module.manual_pdf_content_type,
      manual_pdf_size_bytes: module.manual_pdf_size_bytes,
      youtube_videos: encode_youtube_videos(module),
      price_range: price_range(price_range),
      inserted_at: module.inserted_at,
      updated_at: module.updated_at
    }
    |> maybe_put_observations(module)
  end

  def stats(stats) when is_map(stats) do
    %{
      count: stats.count,
      total_hp: stats.total_hp,
      total_width_mm: decimal(stats.total_width_mm),
      total_width_cm: decimal(stats.total_width_cm),
      total_width_m: decimal(stats.total_width_m),
      total_purchase_price: decimal(stats.total_purchase_price),
      total_current_value: decimal(stats.total_current_value)
    }
  end

  def module_type(%ModuleType{} = type, opts \\ []) do
    %{
      id: type.id,
      name: type.name,
      fallback: Keyword.get(opts, :fallback, false),
      used: Keyword.get(opts, :used, false)
    }
  end

  def error_map(%Ecto.Changeset{} = changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
        opts
        |> Enum.into(%{}, fn {k, v} -> {Atom.to_string(k), v} end)
        |> Map.get(key, key)
        |> to_string()
      end)
    end)
  end

  defp encode_youtube_videos(%EurorackModule{youtube_videos: videos}) when is_list(videos) do
    Enum.map(videos, &youtube_video/1)
  end

  defp encode_youtube_videos(_), do: []

  defp maybe_put_observations(payload, %EurorackModule{price_observations: observations})
       when is_list(observations) do
    Map.put(payload, :price_observations, Enum.map(observations, &observation/1))
  end

  defp maybe_put_observations(payload, _module), do: payload
end
