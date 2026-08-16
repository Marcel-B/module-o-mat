defmodule ModuleOMatWeb.HomeLive do
  @moduledoc """
  Landing-Page zur Auswahl der drei verfuegbaren Oberflaechen.
  """

  use ModuleOMatWeb, :live_view

  alias ModuleOMat.Inventory.RemoteBackupScheduler

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Oberflaeche waehlen")
     |> assign_maintenance()}
  end

  @impl true
  def handle_info({:maintenance, active?}, socket) do
    {:noreply, assign(socket, :maintenance?, active?)}
  end

  defp assign_maintenance(socket) do
    if connected?(socket), do: RemoteBackupScheduler.subscribe()
    assign(socket, :maintenance?, RemoteBackupScheduler.maintenance?())
  end
end
