defmodule ModuleOMatWeb.Api.Params do
  @moduledoc false

  def parse_id(id) when is_integer(id) and id > 0, do: {:ok, id}

  def parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} when int > 0 -> {:ok, int}
      _ -> :error
    end
  end

  def parse_id(_), do: :error

  def filter_opts(params) when is_map(params) do
    types =
      params
      |> Map.get("types")
      |> List.wrap()
      |> Enum.flat_map(&split_csv/1)
      |> Enum.reject(&(&1 in [nil, ""]))

    []
    |> maybe_put(:q, blank_to_nil(params["q"]))
    |> maybe_put(:types, types)
    |> maybe_put(:min_hp, params["min_hp"])
    |> maybe_put(:max_hp, params["max_hp"])
  end

  def unwrap(params, key) when is_binary(key) do
    Map.get(params, key) || params
  end

  def fetch_upload(params) when is_map(params) do
    case Map.get(params, "file") do
      %Plug.Upload{} = upload -> {:ok, upload}
      _ -> {:error, {:unprocessable, "Datei fehlt"}}
    end
  end

  def upload_size(%Plug.Upload{path: path}) do
    case File.stat(path) do
      {:ok, %{size: size}} -> size
      _ -> 0
    end
  end

  def truthy?(value, default \\ false)
  def truthy?(nil, default), do: default
  def truthy?(true, _default), do: true
  def truthy?(false, _default), do: false
  def truthy?(1, _default), do: true
  def truthy?(0, _default), do: false
  def truthy?("true", _default), do: true
  def truthy?("false", _default), do: false
  def truthy?("1", _default), do: true
  def truthy?("0", _default), do: false
  def truthy?(_other, default), do: default

  defp maybe_put(opts, _key, nil), do: opts
  defp maybe_put(opts, _key, []), do: opts
  defp maybe_put(opts, _key, ""), do: opts
  defp maybe_put(opts, key, value), do: Keyword.put(opts, key, value)

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(value), do: value

  defp split_csv(value) when is_binary(value), do: String.split(value, ",", trim: true)
  defp split_csv(value), do: [to_string(value)]
end
