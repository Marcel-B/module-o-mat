defmodule ModuleOMatWeb.BackupController do
  @moduledoc """
  Laedt ein Inventar-Backup als ZIP-Datei herunter.
  """

  use ModuleOMatWeb, :controller

  alias ModuleOMat.Inventory

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
          conn
          |> put_flash(:error, "Backup konnte nicht erstellt werden: #{reason}")
          |> redirect(to: ~p"/backup")
      end
    after
      File.rm(tmp_path)
    end
  end
end
