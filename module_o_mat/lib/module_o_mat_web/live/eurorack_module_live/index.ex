defmodule ModuleOMatWeb.EurorackModuleLive.Index do
  @moduledoc """
  Zeigt alle erfassten Eurorack-Module gruppiert nach Typ (sortiert nach
  Hersteller innerhalb eines Typs) und erlaubt das Anlegen, Anzeigen,
  Bearbeiten und (Soft-)Loeschen von Modulen ueber Dialoge.
  """

  use ModuleOMatWeb, :live_view

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.EurorackModule
  alias ModuleOMat.Inventory.ModuleType

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:eurorack_modules, Inventory.list_eurorack_modules())
     |> assign(:manufacturers, Inventory.list_manufacturers())
     |> assign(:types, available_types())
     |> assign(:module_to_delete, nil)
     |> assign(:module_types, [])
     |> assign(:used_module_types, [])
     |> assign(:module_type_form, to_form(Inventory.change_module_type(%ModuleType{})))
     |> assign(:editing_module_type, nil)
     |> assign(:module_type_edit_form, nil)}
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

  defp apply_action(socket, :manage_types, _params) do
    socket
    |> assign(:page_title, "Typen verwalten")
    |> assign(:module_types, Inventory.list_module_type_records())
    |> assign(:used_module_types, Inventory.list_used_types())
    |> assign(:module_type_form, to_form(Inventory.change_module_type(%ModuleType{})))
    |> assign(:editing_module_type, nil)
    |> assign(:module_type_edit_form, nil)
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

  def handle_event("validate_module_type", %{"module_type" => params}, socket) do
    form =
      %ModuleType{}
      |> Inventory.change_module_type(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :module_type_form, form)}
  end

  def handle_event("add_module_type", %{"module_type" => params}, socket) do
    case Inventory.create_module_type(params) do
      {:ok, module_type} ->
        {:noreply,
         socket
         |> refresh_module_types()
         |> assign(:module_type_form, to_form(Inventory.change_module_type(%ModuleType{})))
         |> put_flash(:info, "Typ \"#{module_type.name}\" wurde hinzugefuegt.")}

      {:error, changeset} ->
        {:noreply, assign(socket, :module_type_form, to_form(changeset))}
    end
  end

  def handle_event("edit_module_type", %{"id" => id}, socket) do
    module_type = Enum.find(socket.assigns.module_types, &(&1.id == String.to_integer(id)))

    {:noreply,
     socket
     |> assign(:editing_module_type, module_type)
     |> assign(:module_type_edit_form, to_form(Inventory.change_module_type(module_type)))}
  end

  def handle_event("cancel_edit_module_type", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_module_type, nil)
     |> assign(:module_type_edit_form, nil)}
  end

  def handle_event("validate_edit_module_type", %{"module_type" => params}, socket) do
    form =
      socket.assigns.editing_module_type
      |> Inventory.change_module_type(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :module_type_edit_form, form)}
  end

  def handle_event("update_module_type", %{"module_type" => params}, socket) do
    case Inventory.update_module_type(socket.assigns.editing_module_type, params) do
      {:ok, module_type} ->
        {:noreply,
         socket
         |> refresh_module_types()
         |> assign(:editing_module_type, nil)
         |> assign(:module_type_edit_form, nil)
         |> put_flash(:info, "Typ \"#{module_type.name}\" wurde aktualisiert.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :module_type_edit_form, to_form(changeset))}

      {:error, :fallback_type} ->
        {:noreply,
         socket
         |> assign(:editing_module_type, nil)
         |> assign(:module_type_edit_form, nil)
         |> put_flash(
           :error,
           "Der Typ \"#{Inventory.fallback_type_name()}\" kann nicht umbenannt werden."
         )}
    end
  end

  def handle_event("delete_module_type", %{"id" => id}, socket) do
    module_type = Enum.find(socket.assigns.module_types, &(&1.id == String.to_integer(id)))

    case Inventory.delete_module_type(module_type) do
      {:ok, deleted} ->
        {:noreply,
         socket
         |> assign(:eurorack_modules, Inventory.list_eurorack_modules())
         |> refresh_module_types()
         |> put_flash(:info, "Typ \"#{deleted.name}\" wurde geloescht.")}

      {:error, :fallback_type} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Der Typ \"#{Inventory.fallback_type_name()}\" kann nicht geloescht werden."
         )}
    end
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
         |> assign(:manufacturers, Inventory.list_manufacturers())
         |> assign(:types, available_types())
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
         |> assign(:manufacturers, Inventory.list_manufacturers())
         |> assign(:types, available_types())
         |> put_flash(:info, "Modul \"#{eurorack_module.name}\" wurde aktualisiert.")
         |> push_patch(to: ~p"/")}

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp grouped_eurorack_modules(eurorack_modules) do
    eurorack_modules
    |> Enum.sort_by(&{&1.type, String.downcase(&1.manufacturer)})
    |> Enum.chunk_by(& &1.type)
  end

  defp available_types do
    (Inventory.list_module_types() ++ Inventory.list_used_types())
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp refresh_module_types(socket) do
    socket
    |> assign(:module_types, Inventory.list_module_type_records())
    |> assign(:used_module_types, Inventory.list_used_types())
    |> assign(:types, available_types())
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :disabled, :boolean, default: false
  attr :manufacturers, :list, default: []
  attr :types, :list, default: []

  defp eurorack_module_fields(assigns) do
    ~H"""
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-x-4">
      <.input
        field={@form[:manufacturer]}
        type="text"
        label="Hersteller"
        list="manufacturer-options"
        disabled={@disabled}
      />
      <datalist id="manufacturer-options">
        <option :for={manufacturer <- @manufacturers} value={manufacturer} />
      </datalist>
      <.input field={@form[:name]} type="text" label="Name" disabled={@disabled} />
      <.input field={@form[:hp]} type="number" label="HP" disabled={@disabled} />
      <.input
        field={@form[:type]}
        type="select"
        label="Typ"
        prompt="Bitte waehlen"
        options={@types}
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
        <div :if={@disabled} class="fieldset mb-2">
          <span class="label mb-1">Anleitung / Produktseite (URL)</span>
          <a
            :if={@form[:manual_url].value not in [nil, ""]}
            id="manual-url-link"
            href={@form[:manual_url].value}
            target="_blank"
            rel="noopener noreferrer"
            class="link link-primary break-all"
          >
            {@form[:manual_url].value}
          </a>
          <span :if={@form[:manual_url].value in [nil, ""]} class="text-base-content/50">
            Keine Angabe
          </span>
        </div>
        <.input
          :if={!@disabled}
          field={@form[:manual_url]}
          type="text"
          label="Anleitung / Produktseite (URL)"
        />
      </div>
    </div>
    """
  end
end
