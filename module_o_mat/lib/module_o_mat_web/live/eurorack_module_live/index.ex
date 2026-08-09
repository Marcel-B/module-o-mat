defmodule ModuleOMatWeb.EurorackModuleLive.Index do
  @moduledoc """
  Zeigt alle erfassten Eurorack-Module gruppiert nach Typ (sortiert nach
  Hersteller innerhalb eines Typs) und erlaubt das Anlegen, Anzeigen,
  Bearbeiten und (Soft-)Loeschen von Modulen ueber Dialoge.
  """

  use ModuleOMatWeb, :live_view

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.EurorackModule

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:eurorack_modules, Inventory.list_eurorack_modules())
     |> assign(:module_to_delete, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Neues Modul erfassen")
    |> assign(:eurorack_module, %EurorackModule{})
    |> assign(:form, to_form(Inventory.change_eurorack_module(%EurorackModule{})))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    eurorack_module = Inventory.get_eurorack_module!(id)

    socket
    |> assign(:page_title, "Modul bearbeiten")
    |> assign(:eurorack_module, eurorack_module)
    |> assign(:form, to_form(Inventory.change_eurorack_module(eurorack_module)))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    eurorack_module = Inventory.get_eurorack_module!(id)

    socket
    |> assign(:page_title, "Modul anzeigen")
    |> assign(:eurorack_module, eurorack_module)
    |> assign(:form, to_form(Inventory.change_eurorack_module(eurorack_module)))
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Eurorack-Module")
    |> assign(:eurorack_module, nil)
    |> assign(:form, nil)
  end

  @impl true
  def handle_event("validate", %{"eurorack_module" => params}, socket) do
    form =
      socket.assigns.eurorack_module
      |> Inventory.change_eurorack_module(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("save", %{"eurorack_module" => params}, socket) do
    save_eurorack_module(socket, socket.assigns.live_action, params)
  end

  def handle_event("delete", %{"id" => id}, socket) do
    {:noreply, assign(socket, :module_to_delete, Inventory.get_eurorack_module!(id))}
  end

  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, :module_to_delete, nil)}
  end

  def handle_event("confirm_delete", _params, socket) do
    eurorack_module = socket.assigns.module_to_delete

    case Inventory.soft_delete_eurorack_module(eurorack_module) do
      {:ok, _deleted} ->
        {:noreply,
         socket
         |> update(:eurorack_modules, fn modules ->
           Enum.reject(modules, &(&1.id == eurorack_module.id))
         end)
         |> assign(:module_to_delete, nil)
         |> put_flash(:info, "Modul \"#{eurorack_module.name}\" wurde geloescht.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:module_to_delete, nil)
         |> put_flash(:error, "Modul \"#{eurorack_module.name}\" konnte nicht geloescht werden.")}
    end
  end

  defp save_eurorack_module(socket, :new, params) do
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

  defp save_eurorack_module(socket, :edit, params) do
    case Inventory.update_eurorack_module(socket.assigns.eurorack_module, params) do
      {:ok, eurorack_module} ->
        {:noreply,
         socket
         |> update(:eurorack_modules, fn modules ->
           Enum.map(modules, fn
             %{id: id} when id == eurorack_module.id -> eurorack_module
             other -> other
           end)
         end)
         |> put_flash(:info, "Modul \"#{eurorack_module.name}\" wurde aktualisiert.")
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

  attr :form, Phoenix.HTML.Form, required: true
  attr :disabled, :boolean, default: false

  defp eurorack_module_fields(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-4">
      <.input field={@form[:manufacturer]} type="text" label="Hersteller" disabled={@disabled} />
      <.input field={@form[:name]} type="text" label="Name" disabled={@disabled} />
      <.input field={@form[:hp]} type="number" label="HP" disabled={@disabled} />
      <.input
        field={@form[:type]}
        type="select"
        label="Typ"
        prompt="Bitte waehlen"
        options={EurorackModule.type_options()}
        disabled={@disabled}
      />
      <.input
        field={@form[:current_draw_plus12v_ma]}
        type="number"
        label="Strombedarf +12V (mA)"
        disabled={@disabled}
      />
      <.input
        field={@form[:current_draw_minus12v_ma]}
        type="number"
        label="Strombedarf -12V (mA)"
        disabled={@disabled}
      />
      <.input
        field={@form[:current_draw_plus5v_ma]}
        type="number"
        label="Strombedarf +5V (mA)"
        disabled={@disabled}
      />
      <.input field={@form[:depth_mm]} type="number" label="Tiefe (mm)" disabled={@disabled} />
      <div class="sm:col-span-2">
        <.input
          field={@form[:description]}
          type="textarea"
          label="Beschreibung"
          disabled={@disabled}
        />
      </div>
      <div class="sm:col-span-2">
        <.input
          field={@form[:manual_url]}
          type="text"
          label="Anleitung / Produktseite (URL)"
          disabled={@disabled}
        />
      </div>
    </div>
    """
  end
end
