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
     |> assign_filters(%{})
     |> reload_eurorack_modules()
     |> assign(:manufacturers, Inventory.list_manufacturers())
     |> assign(:types, available_types())
     |> assign(:module_to_delete, nil)
     |> assign(:module_types, [])
     |> assign(:used_module_types, [])
     |> assign(:module_type_form, to_form(Inventory.change_module_type(%ModuleType{})))
     |> assign(:editing_module_type, nil)
     |> assign(:module_type_edit_form, nil)
     |> allow_upload(:manual,
       accept: ~w(.pdf),
       max_entries: 1,
       max_file_size: 20_000_000
     )}
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
  def handle_event("filter", params, socket) do
    {:noreply,
     socket
     |> assign_filters(params)
     |> reload_eurorack_modules()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign_filters(%{})
     |> reload_eurorack_modules()}
  end

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
         |> reload_eurorack_modules()
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
         |> reload_eurorack_modules()
         |> assign(:module_to_delete, nil)
         |> put_flash(:info, "Modul \"#{eurorack_module.name}\" wurde geloescht.")}

      {:error, _changeset} ->
        {:noreply,
         socket
         |> assign(:module_to_delete, nil)
         |> put_flash(:error, "Modul \"#{eurorack_module.name}\" konnte nicht geloescht werden.")}
    end
  end

  def handle_event("cancel_manual_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :manual, ref)}
  end

  def handle_event("remove_manual", _params, socket) do
    case Inventory.remove_manual(socket.assigns.eurorack_module) do
      {:ok, eurorack_module} ->
        {:noreply,
         socket
         |> assign(:eurorack_module, eurorack_module)
         |> assign(:form, to_form(Inventory.change_eurorack_module(eurorack_module)))
         |> reload_eurorack_modules()
         |> put_flash(:info, "PDF-Anleitung wurde entfernt.")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "PDF-Anleitung konnte nicht entfernt werden.")}
    end
  end

  defp save_eurorack_module(socket, :new, params) do
    case Inventory.create_eurorack_module(params) do
      {:ok, eurorack_module} ->
        case maybe_attach_manual(socket, eurorack_module) do
          {:ok, eurorack_module} ->
            {:noreply,
             socket
             |> reload_eurorack_modules()
             |> assign(:manufacturers, Inventory.list_manufacturers())
             |> assign(:types, available_types())
             |> put_flash(:info, "Modul \"#{eurorack_module.name}\" wurde gespeichert.")
             |> push_patch(to: ~p"/")}

          {:error, :manual_upload} ->
            {:noreply,
             socket
             |> reload_eurorack_modules()
             |> assign(:manufacturers, Inventory.list_manufacturers())
             |> assign(:types, available_types())
             |> put_flash(
               :error,
               "Modul wurde gespeichert, aber die PDF-Anleitung konnte nicht uebernommen werden."
             )
             |> push_patch(to: ~p"/")}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_eurorack_module(socket, :edit, params) do
    case Inventory.update_eurorack_module(socket.assigns.eurorack_module, params) do
      {:ok, eurorack_module} ->
        case maybe_attach_manual(socket, eurorack_module) do
          {:ok, eurorack_module} ->
            {:noreply,
             socket
             |> reload_eurorack_modules()
             |> assign(:manufacturers, Inventory.list_manufacturers())
             |> assign(:types, available_types())
             |> put_flash(:info, "Modul \"#{eurorack_module.name}\" wurde aktualisiert.")
             |> push_patch(to: ~p"/")}

          {:error, :manual_upload} ->
            {:noreply,
             socket
             |> reload_eurorack_modules()
             |> assign(:manufacturers, Inventory.list_manufacturers())
             |> assign(:types, available_types())
             |> put_flash(
               :error,
               "Modul wurde aktualisiert, aber die PDF-Anleitung konnte nicht uebernommen werden."
             )
             |> push_patch(to: ~p"/")}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp maybe_attach_manual(socket, eurorack_module) do
    # Die Temp-Datei existiert nur innerhalb des Callbacks; speichern muss hier passieren.
    results =
      consume_uploaded_entries(socket, :manual, fn %{path: path}, entry ->
        case Inventory.attach_manual(eurorack_module, %{
               tmp_path: path,
               filename: entry.client_name,
               content_type: entry.client_type,
               size: entry.client_size
             }) do
          {:ok, updated} -> {:ok, updated}
          {:error, _changeset} -> {:ok, :manual_upload_failed}
        end
      end)

    case results do
      [updated] when is_struct(updated, EurorackModule) -> {:ok, updated}
      [:manual_upload_failed] -> {:error, :manual_upload}
      [] -> {:ok, eurorack_module}
    end
  end

  defp grouped_eurorack_modules(eurorack_modules) do
    eurorack_modules
    |> Enum.sort_by(&{&1.type, String.downcase(&1.manufacturer)})
    |> Enum.chunk_by(& &1.type)
  end

  defp reload_eurorack_modules(socket) do
    types =
      case socket.assigns.selected_type do
        "" -> []
        type -> [type]
      end

    socket
    |> assign(
      :eurorack_modules,
      Inventory.list_eurorack_modules(
        q: socket.assigns.search_query,
        types: types,
        min_hp: socket.assigns.min_hp,
        max_hp: socket.assigns.max_hp
      )
    )
    |> assign(:filter_types, Inventory.list_used_types())
  end

  defp assign_filters(socket, params) when is_map(params) do
    q = params |> Map.get("q", "") |> to_string()
    type = params |> Map.get("type", "") |> to_string()
    min_hp = params |> Map.get("min_hp", "") |> to_string()
    max_hp = params |> Map.get("max_hp", "") |> to_string()

    socket
    |> assign(:search_query, q)
    |> assign(:selected_type, type)
    |> assign(:min_hp, min_hp)
    |> assign(:max_hp, max_hp)
    |> assign(
      :filter_form,
      to_form(%{"q" => q, "type" => type, "min_hp" => min_hp, "max_hp" => max_hp})
    )
    |> assign(:filters_active?, filters_active?(q, type, min_hp, max_hp))
  end

  defp filters_active?(q, type, min_hp, max_hp) do
    String.trim(q) != "" or type != "" or String.trim(min_hp) != "" or String.trim(max_hp) != ""
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
  attr :uploads, :map, default: nil
  attr :eurorack_module, EurorackModule, default: nil

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
          <span class="label mb-1">Produktseite (URL)</span>
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
          label="Produktseite (URL)"
        />
      </div>
      <div class="sm:col-span-2">
        <.manual_pdf_fields
          form={@form}
          disabled={@disabled}
          uploads={@uploads}
          eurorack_module={@eurorack_module}
        />
      </div>
    </div>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :disabled, :boolean, default: false
  attr :uploads, :map, default: nil
  attr :eurorack_module, EurorackModule, default: nil

  defp manual_pdf_fields(assigns) do
    ~H"""
    <div id="manual-pdf-fields" class="fieldset mb-2">
      <span class="label mb-1">PDF-Anleitung</span>

      <div
        :if={@form[:manual_pdf_key].value not in [nil, ""]}
        id="manual-pdf-current"
        class="flex flex-wrap items-center gap-2 mb-2"
      >
        <span class="text-sm">
          {@form[:manual_pdf_filename].value}
          <span
            :if={@form[:manual_pdf_size_bytes].value}
            class="text-base-content/50"
          >
            ({format_bytes(@form[:manual_pdf_size_bytes].value)})
          </span>
        </span>
        <.link
          :if={@eurorack_module && @eurorack_module.id}
          href={~p"/eurorack_modules/#{@eurorack_module.id}/manual"}
          id="open-manual-pdf-button"
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-ghost btn-xs"
        >
          <.icon name="hero-document-text" class="size-4" /> PDF oeffnen
        </.link>
        <button
          :if={!@disabled}
          type="button"
          id="remove-manual-pdf-button"
          class="btn btn-ghost btn-xs text-error"
          phx-click="remove_manual"
        >
          Entfernen
        </button>
      </div>

      <span
        :if={@disabled and @form[:manual_pdf_key].value in [nil, ""]}
        class="text-base-content/50"
      >
        Keine Anleitung hinterlegt.
      </span>

      <div :if={!@disabled && @uploads} id="manual-pdf-upload">
        <div
          class="border border-dashed border-base-300 rounded-lg p-4 text-center"
          phx-drop-target={@uploads.manual.ref}
        >
          <p class="text-sm text-base-content/70 mb-2">
            PDF hierher ziehen oder Datei auswaehlen
          </p>
          <.live_file_input
            upload={@uploads.manual}
            class="file-input file-input-bordered file-input-sm w-full max-w-xs"
          />
        </div>

        <div
          :for={entry <- @uploads.manual.entries}
          id={"manual-upload-entry-#{entry.ref}"}
          class="mt-2"
        >
          <div class="flex items-center gap-2 text-sm">
            <span class="truncate">{entry.client_name}</span>
            <span class="text-base-content/50">{entry.progress}%</span>
            <button
              type="button"
              id={"cancel-manual-upload-#{entry.ref}"}
              class="btn btn-ghost btn-xs"
              phx-click="cancel_manual_upload"
              phx-value-ref={entry.ref}
            >
              Abbrechen
            </button>
          </div>
          <p
            :for={err <- upload_errors(@uploads.manual, entry)}
            class="mt-1.5 flex gap-2 items-center text-sm text-error"
          >
            <.icon name="hero-exclamation-circle" class="size-5" />
            {translate_upload_error(err)}
          </p>
        </div>

        <p
          :for={err <- upload_errors(@uploads.manual)}
          class="mt-1.5 flex gap-2 items-center text-sm text-error"
        >
          <.icon name="hero-exclamation-circle" class="size-5" />
          {translate_upload_error(err)}
        </p>
      </div>
    </div>
    """
  end

  defp format_bytes(bytes) when is_integer(bytes) and bytes < 1024, do: "#{bytes} B"

  defp format_bytes(bytes) when is_integer(bytes) and bytes < 1_048_576 do
    "#{Float.round(bytes / 1024, 1)} KB"
  end

  defp format_bytes(bytes) when is_integer(bytes) do
    "#{Float.round(bytes / 1_048_576, 1)} MB"
  end

  defp format_bytes(_), do: ""

  defp translate_upload_error(:too_large), do: "Datei ist zu gross (max. 20 MB)"
  defp translate_upload_error(:too_many_files), do: "Nur eine PDF-Datei erlaubt"
  defp translate_upload_error(:not_accepted), do: "Nur PDF-Dateien sind erlaubt"
  defp translate_upload_error(other), do: "Upload-Fehler: #{inspect(other)}"
end
