defmodule ModuleOMatWeb.SpaController do
  @moduledoc """
  Liefert die gebauten Vue-SPAs und faengt Client-Routen auf `index.html` ab.
  """

  use ModuleOMatWeb, :controller

  def ui(conn, _params), do: serve(conn, "ui")
  def ui_alt(conn, _params), do: serve(conn, "ui-alt")

  defp serve(conn, name) do
    path = Application.app_dir(:module_o_mat, ["priv", "vue", name, "index.html"])

    if File.exists?(path) do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(200, path)
    else
      conn
      |> put_flash(
        :error,
        "Die Oberflaeche \"#{name}\" wurde noch nicht gebaut. Lokal: mix assets.build_vue"
      )
      |> redirect(to: ~p"/")
    end
  end
end
