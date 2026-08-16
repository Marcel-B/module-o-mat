defmodule ModuleOMatWeb.Api.V1.BackupController do
  @moduledoc """
  JSON-REST-API fuer Inventar-Backup (ZIP-Export und -Import).
  """

  use ModuleOMatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias ModuleOMat.Inventory
  alias ModuleOMatWeb.Api.Params
  alias ModuleOMatWeb.Api.Schemas

  action_fallback ModuleOMatWeb.Api.FallbackController

  @max_zip_bytes 100_000_000

  tags ["backup"]

  operation :export,
    summary: "Inventar als ZIP exportieren",
    responses: [
      ok: {"ZIP-Archiv", "application/zip", %OpenApiSpex.Schema{type: :string, format: :binary}},
      unprocessable_entity: {"Fehler", "application/json", Schemas.Error}
    ]

  def export(conn, _params) do
    stamp = Calendar.strftime(DateTime.utc_now(), "%Y%m%d-%H%M%S")
    filename = "inventory-#{stamp}.zip"
    tmp_path = Path.join(System.tmp_dir!(), "module_o_mat_#{filename}")

    try do
      case Inventory.export_backup(tmp_path) do
        {:ok, path} ->
          binary = File.read!(path)

          conn
          |> put_resp_content_type("application/zip")
          |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
          |> send_resp(200, binary)

        {:error, reason} ->
          {:error, {:unprocessable, "Backup konnte nicht erstellt werden: #{reason}"}}
      end
    after
      File.rm(tmp_path)
    end
  end

  operation :import_backup,
    summary: "Inventar aus ZIP importieren",
    description: "Ersetzt den gesamten Bestand.",
    request_body: {"ZIP-Datei", "multipart/form-data", Schemas.FileUpload},
    responses: [
      ok: {"Importiert", "application/json", Schemas.BackupImportResponse},
      unprocessable_entity: {"Fehler", "application/json", Schemas.Error}
    ]

  def import_backup(conn, params) do
    with {:ok, upload} <- Params.fetch_upload(params),
         :ok <- validate_zip_upload(upload) do
      case Inventory.import_backup(upload.path) do
        :ok -> json(conn, %{imported: true})
        {:error, reason} -> {:error, {:unprocessable, to_string(reason)}}
      end
    end
  end

  defp validate_zip_upload(upload) do
    size = Params.upload_size(upload)
    filename = upload.filename || ""
    content_type = upload.content_type || ""

    cond do
      size > @max_zip_bytes ->
        {:error, {:unprocessable, "ZIP darf hoechstens 100 MB gross sein"}}

      not zip_upload?(filename, content_type) ->
        {:error, {:unprocessable, "Nur ZIP-Dateien sind erlaubt"}}

      true ->
        :ok
    end
  end

  defp zip_upload?(filename, content_type) do
    String.ends_with?(String.downcase(filename), ".zip") or
      String.contains?(content_type, "zip")
  end
end
