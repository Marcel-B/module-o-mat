defmodule ModuleOMatWeb.ManualController do
  @moduledoc """
  Liefert die PDF-Anleitung eines Eurorack-Moduls aus.
  """

  use ModuleOMatWeb, :controller

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.ManualStorage

  def show(conn, %{"id" => id}) do
    eurorack_module = Inventory.get_eurorack_module!(id)

    case eurorack_module.manual_pdf_key do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Keine Anleitung gefunden.")

      key ->
        ManualStorage.serve(conn, key,
          filename: eurorack_module.manual_pdf_filename,
          content_type: eurorack_module.manual_pdf_content_type || "application/pdf"
        )
    end
  end
end
