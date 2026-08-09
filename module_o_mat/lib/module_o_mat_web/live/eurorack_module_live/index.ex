defmodule ModuleOMatWeb.EurorackModuleLive.Index do
  @moduledoc """
  Zeigt alle erfassten Eurorack-Module gruppiert nach Typ (sortiert nach
  Hersteller innerhalb eines Typs) und erlaubt das Anlegen neuer Module ueber
  einen Dialog.
  """

  use ModuleOMatWeb, :live_view

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.EurorackModule

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :eurorack_modules, Inventory.list_eurorack_modules())}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action)}
  end

  defp apply_action(socket, :new) do
    socket
    |> assign(:page_title, "Neues Modul")
    |> assign(:form, to_form(Inventory.change_eurorack_module(%EurorackModule{})))
  end

  defp apply_action(socket, :index) do
    socket
    |> assign(:page_title, "Eurorack-Module")
    |> assign(:form, nil)
  end

  @impl true
  def handle_event("validate", %{"eurorack_module" => params}, socket) do
    form =
      %EurorackModule{}
      |> Inventory.change_eurorack_module(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"eurorack_module" => params}, socket) do
    case Inventory.create_eurorack_module(params) do
      {:ok, eurorack_module} ->
        {:noreply,
         socket
         |> update(:eurorack_modules, &[eurorack_module | &1])
         |> put_flash(:info, "Modul \"#{eurorack_module.name}\" wurde gespeichert.")
         |> push_patch(to: ~p"/")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp grouped_eurorack_modules(eurorack_modules) do
    eurorack_modules
    |> Enum.sort_by(&{to_string(&1.type), String.downcase(&1.manufacturer)})
    |> Enum.chunk_by(& &1.type)
  end

  defp type_label(type), do: EurorackModule.type_label(type)
end
