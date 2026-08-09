defmodule ModuleOMat.Inventory.Youtube do
  @moduledoc """
  Hilfsfunktionen fuer YouTube-URLs: Video-ID extrahieren sowie Watch-
  und Embed-URLs erzeugen.
  """

  @doc """
  Extrahiert die 11-stellige Video-ID aus gaengigen YouTube-URL-Formaten
  (`watch`, `youtu.be`, `embed`, `shorts`). Liefert `nil`, wenn keine
  gueltige ID gefunden wird.
  """
  def video_id(url) when is_binary(url) do
    url = String.trim(url)

    case Regex.run(
           ~r/(?:youtube\.com\/(?:watch\?(?:[^#]*&)?v=|embed\/|shorts\/)|youtu\.be\/)([A-Za-z0-9_-]{11})/,
           url
         ) do
      [_, id] -> id
      _ -> nil
    end
  end

  def video_id(_), do: nil

  @doc """
  Liefert die kanonische Watch-URL fuer eine Video-URL bzw. -ID, oder `nil`.
  """
  def watch_url(url_or_id) do
    case video_id(url_or_id) do
      nil -> nil
      id -> "https://www.youtube.com/watch?v=#{id}"
    end
  end

  @doc """
  Liefert die privacy-enhanced Embed-URL (youtube-nocookie.com), optional
  mit Autoplay/Mute-Query-Parametern fuer Hover-Previews.
  """
  def embed_url(url_or_id, opts \\ []) do
    case video_id(url_or_id) do
      nil ->
        nil

      id ->
        base = "https://www.youtube-nocookie.com/embed/#{id}"

        query =
          []
          |> maybe_append_query("autoplay", Keyword.get(opts, :autoplay))
          |> maybe_append_query("mute", Keyword.get(opts, :mute))
          |> Enum.join("&")

        if query == "", do: base, else: base <> "?" <> query
    end
  end

  @doc """
  Prueft, ob der String eine erkennbare YouTube-URL ist.
  """
  def valid_url?(url), do: video_id(url) != nil

  defp maybe_append_query(query, _key, nil), do: query
  defp maybe_append_query(query, _key, false), do: query
  defp maybe_append_query(query, key, true), do: query ++ ["#{key}=1"]
  defp maybe_append_query(query, key, value), do: query ++ ["#{key}=#{value}"]
end
