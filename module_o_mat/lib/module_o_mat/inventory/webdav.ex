defmodule ModuleOMat.Inventory.WebDAV do
  @moduledoc """
  Minimaler WebDAV-Client fuer Nextcloud-Uploads (PUT / MKCOL) via Req.
  """

  @doc """
  Laedt den Inhalt von `local_path` per PUT nach `base_url/filename`.

  `opts` erwartet mindestens `:username` und `:password`. Optionale
  `:req_options` werden an Req durchgereicht (z.B. fuer Tests).
  """
  def put_file(base_url, filename, local_path, opts)
      when is_binary(base_url) and is_binary(filename) and is_binary(local_path) and
             is_list(opts) do
    with :ok <- ensure_readable_file(local_path),
         {:ok, body} <- read_file(local_path),
         url <- join_url(base_url, filename),
         {:ok, %Req.Response{status: status}} <-
           request(:put, url, [body: body] ++ auth_and_req_opts(opts)) do
      if status in 200..299 do
        :ok
      else
        {:error, "WebDAV PUT fehlgeschlagen (HTTP #{status}): #{url}"}
      end
    end
  end

  @doc """
  Stellt sicher, dass die Collection `base_url` existiert (MKCOL).

  Bereits vorhandene Ordner (HTTP 405/409) gelten als Erfolg.
  """
  def ensure_collection(base_url, opts)
      when is_binary(base_url) and is_list(opts) do
    url = String.trim_trailing(base_url, "/")

    # Finch accepts only a few methods as atoms; MKCOL must be a binary.
    case request("MKCOL", url, auth_and_req_opts(opts)) do
      {:ok, %Req.Response{status: status}} when status in [201, 405, 409] ->
        :ok

      {:ok, %Req.Response{status: status}} when status in 200..299 ->
        :ok

      {:ok, %Req.Response{status: status}} ->
        {:error, "WebDAV MKCOL fehlgeschlagen (HTTP #{status}): #{url}"}

      {:error, reason} ->
        {:error, format_req_error(reason)}
    end
  end

  defp request(method, url, opts) do
    case Req.request([method: method, url: url] ++ opts) do
      {:ok, response} ->
        {:ok, response}

      {:error, reason} ->
        {:error, format_req_error(reason)}
    end
  end

  defp auth_and_req_opts(opts) do
    username = Keyword.fetch!(opts, :username)
    password = Keyword.fetch!(opts, :password)
    req_options = Keyword.get(opts, :req_options, [])

    [auth: {:basic, "#{username}:#{password}"}] ++ req_options
  end

  defp ensure_readable_file(path) do
    if File.regular?(path) do
      :ok
    else
      {:error, "Datei nicht gefunden: #{path}"}
    end
  end

  defp read_file(path) do
    case File.read(path) do
      {:ok, body} -> {:ok, body}
      {:error, reason} -> {:error, "Datei konnte nicht gelesen werden: #{inspect(reason)}"}
    end
  end

  defp join_url(base_url, filename) do
    base = String.trim_trailing(base_url, "/")
    name = String.trim_leading(filename, "/")
    "#{base}/#{name}"
  end

  defp format_req_error(%{__exception__: true} = error), do: Exception.message(error)
  defp format_req_error(reason) when is_binary(reason), do: reason
  defp format_req_error(reason), do: inspect(reason)
end
