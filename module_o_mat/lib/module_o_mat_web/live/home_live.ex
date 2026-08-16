defmodule ModuleOMatWeb.HomeLive do
  @moduledoc """
  Landing-Page zur Auswahl der drei verfuegbaren Oberflaechen.
  """

  use ModuleOMatWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, "Oberflaeche waehlen")}
  end
end
