defmodule ModuleOMatWeb.EurorackModuleLive.Index do
  @moduledoc """
  Zeigt alle erfassten Eurorack-Module gruppiert nach Typ (sortiert nach
  Hersteller innerhalb eines Typs) und erlaubt das Anlegen, Anzeigen,
  Bearbeiten, Duplizieren und (Soft-)Loeschen von Modulen ueber Dialoge.
  """

  use ModuleOMatWeb, :live_view

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.EurorackModule
  alias ModuleOMat.Inventory.ModuleType
  alias ModuleOMat.Inventory.Youtube

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
     |> assign(:price_chart_data, nil)
     |> assign(:source_manual, nil)
     |> allow_upload(:manual,
       accept: ~w(.pdf),
       max_entries: 1,
       max_file_size: 20_000_000
     )
     |> allow_upload(:backup,
       accept: ~w(.zip),
       max_entries: 1,
       max_file_size: 100_000_000
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    eurorack_module = %EurorackModule{youtube_videos: []}

    socket
    |> assign(:page_title, "Neues Modul erfassen")
    |> assign(:eurorack_module, eurorack_module)
    |> assign(:form, to_form(Inventory.change_eurorack_module(eurorack_module)))
    |> assign(:price_chart_data, nil)
    |> assign(:source_manual, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    eurorack_module = Inventory.get_eurorack_module!(id)

    socket
    |> assign(:page_title, "Modul bearbeiten")
    |> assign(:eurorack_module, eurorack_module)
    |> assign(:form, to_form(Inventory.change_eurorack_module(eurorack_module)))
    |> assign(:price_chart_data, nil)
    |> assign(:source_manual, nil)
  end

  defp apply_action(socket, :duplicate, %{"id" => id}) do
    source = Inventory.get_eurorack_module!(id)
    eurorack_module = Inventory.prepare_duplicate_eurorack_module(source)

    socket
    |> assign(:page_title, "Modul duplizieren")
    |> assign(:eurorack_module, eurorack_module)
    |> assign(:form, to_form(Inventory.change_eurorack_module(eurorack_module)))
    |> assign(:price_chart_data, nil)
    |> assign(:source_manual, source_manual_from(source))
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    eurorack_module = Inventory.get_eurorack_module!(id)

    socket
    |> assign(:page_title, "Modul anzeigen")
    |> assign(:eurorack_module, eurorack_module)
    |> assign(:form, to_form(Inventory.change_eurorack_module(eurorack_module)))
    |> assign(:price_chart_data, nil)
    |> assign(:source_manual, nil)
  end

  defp apply_action(socket, :price_history, %{"id" => id}) do
    eurorack_module = Inventory.get_module_for_valuation!(id)

    socket
    |> assign(
      :page_title,
      "Preisverlauf: #{eurorack_module.manufacturer} - #{eurorack_module.name}"
    )
    |> assign(:eurorack_module, eurorack_module)
    |> assign(:form, nil)
    |> assign(:price_chart_data, build_price_chart_data(eurorack_module.price_observations))
    |> assign(:source_manual, nil)
  end

  defp apply_action(socket, :manage_types, _params) do
    socket
    |> assign(:page_title, "Typen verwalten")
    |> assign(:module_types, Inventory.list_module_type_records())
    |> assign(:used_module_types, Inventory.list_used_types())
    |> assign(:module_type_form, to_form(Inventory.change_module_type(%ModuleType{})))
    |> assign(:editing_module_type, nil)
    |> assign(:module_type_edit_form, nil)
    |> assign(:price_chart_data, nil)
    |> assign(:source_manual, nil)
  end

  defp apply_action(socket, :backup, _params) do
    socket
    |> assign(:page_title, "Datensicherung")
    |> assign(:eurorack_module, nil)
    |> assign(:form, nil)
    |> assign(:price_chart_data, nil)
    |> assign(:source_manual, nil)
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Eurorack-Module")
    |> assign(:eurorack_module, nil)
    |> assign(:form, nil)
    |> assign(:price_chart_data, nil)
    |> assign(:source_manual, nil)
  end

  defp source_manual_from(%EurorackModule{manual_pdf_key: nil}), do: nil

  defp source_manual_from(%EurorackModule{} = source) do
    %{
      key: source.manual_pdf_key,
      filename: source.manual_pdf_filename,
      content_type: source.manual_pdf_content_type,
      size_bytes: source.manual_pdf_size_bytes
    }
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
    params = ensure_subtypes_param(params)

    form =
      socket.assigns.eurorack_module
      |> Inventory.change_eurorack_module(params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, :form, form)}
  end

  def handle_event("toggle_subtype", %{"type" => type}, socket) do
    type = String.trim(type)

    {:noreply,
     update_form_subtypes(socket, fn subtypes ->
       if type in subtypes do
         List.delete(subtypes, type)
       else
         Enum.uniq(subtypes ++ [type])
       end
     end)}
  end

  def handle_event("save", %{"eurorack_module" => params}, socket) do
    save_eurorack_module(socket, socket.assigns.live_action, ensure_subtypes_param(params))
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

  def handle_event("cancel_backup_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :backup, ref)}
  end

  def handle_event("validate_backup", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("import_backup", _params, socket) do
    results =
      consume_uploaded_entries(socket, :backup, fn %{path: path}, _entry ->
        case Inventory.import_backup(path) do
          :ok -> {:ok, :imported}
          {:error, reason} -> {:ok, {:error, reason}}
        end
      end)

    case results do
      [:imported] ->
        {:noreply,
         socket
         |> reload_eurorack_modules()
         |> assign(:manufacturers, Inventory.list_manufacturers())
         |> assign(:types, available_types())
         |> put_flash(:info, "Backup wurde importiert. Alle bisherigen Daten wurden ersetzt.")
         |> push_patch(to: ~p"/")}

      [{:error, reason}] ->
        {:noreply, put_flash(socket, :error, "Import fehlgeschlagen: #{reason}")}

      [] ->
        {:noreply, put_flash(socket, :error, "Bitte zuerst eine ZIP-Datei auswaehlen.")}
    end
  end

  def handle_event("remove_manual", _params, socket) do
    case socket.assigns.eurorack_module do
      %EurorackModule{id: nil} = module ->
        cleared = %{
          module
          | manual_pdf_key: nil,
            manual_pdf_filename: nil,
            manual_pdf_content_type: nil,
            manual_pdf_size_bytes: nil
        }

        {:noreply,
         socket
         |> assign(:eurorack_module, cleared)
         |> assign(:source_manual, nil)
         |> assign(:form, to_form(Inventory.change_eurorack_module(cleared)))}

      eurorack_module ->
        case Inventory.remove_manual(eurorack_module) do
          {:ok, updated} ->
            {:noreply,
             socket
             |> assign(:eurorack_module, updated)
             |> assign(:form, to_form(Inventory.change_eurorack_module(updated)))
             |> reload_eurorack_modules()
             |> put_flash(:info, "PDF-Anleitung wurde entfernt.")}

          {:error, _changeset} ->
            {:noreply, put_flash(socket, :error, "PDF-Anleitung konnte nicht entfernt werden.")}
        end
    end
  end

  def handle_event("add_youtube_video", _params, socket) do
    {:noreply, update_form_youtube_videos(socket, &(&1 ++ [%{"url" => ""}]))}
  end

  def handle_event("remove_youtube_video", %{"index" => index}, socket) do
    index = String.to_integer(index)

    {:noreply, update_form_youtube_videos(socket, &List.delete_at(&1, index))}
  end

  def handle_event("move_youtube_video", %{"index" => index, "direction" => direction}, socket) do
    index = String.to_integer(index)
    offset = if direction == "up", do: -1, else: 1
    new_index = index + offset

    {:noreply,
     update_form_youtube_videos(socket, fn videos ->
       cond do
         new_index < 0 -> videos
         new_index >= length(videos) -> videos
         true -> swap_at(videos, index, new_index)
       end
     end)}
  end

  defp save_eurorack_module(socket, :new, params) do
    case Inventory.create_eurorack_module(params) do
      {:ok, eurorack_module} ->
        case maybe_attach_manual(socket, eurorack_module) do
          {:ok, eurorack_module} ->
            {:noreply, after_module_saved(socket, eurorack_module, :saved)}

          {:error, :manual_upload} ->
            {:noreply, after_module_saved(socket, eurorack_module, :manual_upload_error)}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp save_eurorack_module(socket, :duplicate, params) do
    case Inventory.create_eurorack_module(params) do
      {:ok, eurorack_module} ->
        case maybe_attach_manual(socket, eurorack_module) do
          {:ok, eurorack_module} ->
            case maybe_copy_source_manual(socket, eurorack_module) do
              {:ok, eurorack_module} ->
                {:noreply, after_module_saved(socket, eurorack_module, :saved)}

              {:error, :manual_copy} ->
                {:noreply, after_module_saved(socket, eurorack_module, :manual_upload_error)}
            end

          {:error, :manual_upload} ->
            {:noreply, after_module_saved(socket, eurorack_module, :manual_upload_error)}
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
            {:noreply, after_module_saved(socket, eurorack_module, :updated)}

          {:error, :manual_upload} ->
            {:noreply, after_module_saved(socket, eurorack_module, :manual_update_error)}
        end

      {:error, changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset))}
    end
  end

  defp after_module_saved(socket, eurorack_module, outcome) do
    socket =
      socket
      |> reload_eurorack_modules()
      |> assign(:manufacturers, Inventory.list_manufacturers())
      |> assign(:types, available_types())

    socket =
      case outcome do
        :saved ->
          put_flash(socket, :info, "Modul \"#{eurorack_module.name}\" wurde gespeichert.")

        :updated ->
          put_flash(socket, :info, "Modul \"#{eurorack_module.name}\" wurde aktualisiert.")

        :manual_upload_error ->
          put_flash(
            socket,
            :error,
            "Modul wurde gespeichert, aber die PDF-Anleitung konnte nicht uebernommen werden."
          )

        :manual_update_error ->
          put_flash(
            socket,
            :error,
            "Modul wurde aktualisiert, aber die PDF-Anleitung konnte nicht uebernommen werden."
          )
      end

    push_patch(socket, to: ~p"/")
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

  defp maybe_copy_source_manual(socket, eurorack_module) do
    case socket.assigns.source_manual do
      %{key: source_key} = source_manual
      when is_binary(source_key) and eurorack_module.manual_pdf_key in [nil, ""] ->
        case Inventory.copy_manual(eurorack_module, source_key, source_manual) do
          {:ok, updated} -> {:ok, updated}
          {:error, _} -> {:error, :manual_copy}
        end

      _ ->
        {:ok, eurorack_module}
    end
  end

  defp grouped_eurorack_modules(eurorack_modules) do
    eurorack_modules
    |> Enum.sort_by(&{&1.type, String.downcase(&1.manufacturer)})
    |> Enum.chunk_by(& &1.type)
  end

  defp format_hp_width(%{total_width_cm: cm, total_width_m: m}) do
    cm_str =
      cm
      |> Decimal.round(1)
      |> Decimal.to_string(:normal)
      |> String.replace(".", ",")

    m_str =
      m
      |> Decimal.round(2)
      |> Decimal.to_string(:normal)
      |> String.replace(".", ",")

    "#{cm_str} cm / #{m_str} m"
  end

  defp format_value_cell(nil, current_value), do: format_euro(current_value)

  defp format_value_cell(%{min: min, max: max}, _current_value) do
    if Decimal.eq?(min, max) do
      format_euro(min)
    else
      "#{format_euro_amount(min)}–#{format_euro(max)}"
    end
  end

  defp build_price_chart_data(observations) when is_list(observations) do
    observations = Enum.sort_by(observations, &{&1.observed_on, &1.id}, :asc)

    labels =
      observations
      |> Enum.map(&Date.to_iso8601(&1.observed_on))
      |> Enum.uniq()

    datasets =
      observations
      |> Enum.group_by(& &1.source)
      |> Enum.map(fn {source, source_observations} ->
        points =
          Enum.map(source_observations, fn observation ->
            %{
              x: Date.to_iso8601(observation.observed_on),
              y: decimal_to_number(observation.amount),
              source: source,
              notes: observation.notes,
              source_url: observation.source_url
            }
          end)

        %{source: source, points: points}
      end)
      |> Enum.sort_by(& &1.source)

    %{labels: labels, datasets: datasets}
  end

  defp decimal_to_number(%Decimal{} = amount), do: Decimal.to_float(amount)

  defp price_range_title(nil), do: nil

  defp price_range_title(%{count: count, last_observed_on: date}) do
    "Basierend auf #{count} Beobachtung(en), zuletzt #{Calendar.strftime(date, "%d.%m.%Y")}"
  end

  defp format_euro_amount(%Decimal{} = amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> then(fn str ->
      case String.split(str, ".") do
        [int] -> "#{format_thousands(int)},00"
        [int, frac] -> "#{format_thousands(int)},#{String.pad_trailing(frac, 2, "0")}"
      end
    end)
  end

  defp format_euro(nil), do: "—"

  defp format_euro(%Decimal{} = amount) do
    format_euro_sum(amount)
  end

  defp format_euro_sum(amount) when is_integer(amount) do
    amount
    |> Decimal.new()
    |> format_euro_sum()
  end

  defp format_euro_sum(amount) when is_float(amount) do
    amount
    |> Decimal.from_float()
    |> format_euro_sum()
  end

  defp format_euro_sum(%Decimal{} = amount) do
    amount
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> then(fn str ->
      case String.split(str, ".") do
        [int] -> "#{format_thousands(int)},00 €"
        [int, frac] -> "#{format_thousands(int)},#{String.pad_trailing(frac, 2, "0")} €"
      end
    end)
  end

  defp format_thousands(int_str) do
    int_str
    |> String.replace(~r/\A-/, "")
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1.")
    |> String.reverse()
    |> then(fn formatted ->
      if String.starts_with?(int_str, "-"), do: "-" <> formatted, else: formatted
    end)
  end

  defp reload_eurorack_modules(socket) do
    types =
      case socket.assigns.selected_type do
        "" -> []
        type -> [type]
      end

    filter_opts = [
      q: socket.assigns.search_query,
      types: types,
      min_hp: socket.assigns.min_hp,
      max_hp: socket.assigns.max_hp
    ]

    modules = Inventory.list_eurorack_modules(filter_opts)

    socket
    |> assign(:eurorack_modules, modules)
    |> assign(:price_ranges, Inventory.price_ranges_for_modules(Enum.map(modules, & &1.id)))
    |> assign(:inventory_stats, Inventory.inventory_stats(filter_opts))
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

  defp update_form_youtube_videos(socket, fun) do
    form = socket.assigns.form
    videos = form |> youtube_videos_as_params() |> fun.() |> index_youtube_video_params()
    params = form |> module_form_params() |> Map.put("youtube_videos", videos)

    form =
      socket.assigns.eurorack_module
      |> Inventory.change_eurorack_module(params)
      |> Map.put(:action, :validate)
      |> to_form()

    assign(socket, :form, form)
  end

  defp update_form_subtypes(socket, fun) do
    form = socket.assigns.form
    subtypes = form |> form_subtypes() |> fun.()
    params = form |> module_form_params() |> Map.put("subtypes", subtypes)

    form =
      socket.assigns.eurorack_module
      |> Inventory.change_eurorack_module(params)
      |> Map.put(:action, :validate)
      |> to_form()

    assign(socket, :form, form)
  end

  defp ensure_subtypes_param(params) when is_map(params) do
    Map.put_new(params, "subtypes", [])
  end

  defp form_subtypes(form) do
    cond do
      is_list(form.params["subtypes"]) ->
        form.params["subtypes"]

      true ->
        Ecto.Changeset.get_field(form.source, :subtypes) || []
    end
    |> List.wrap()
    |> Enum.map(&to_string/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp module_form_params(form) do
    fields = [
      "manufacturer",
      "name",
      "hp",
      "type",
      "current_draw_plus12v_ma",
      "current_draw_minus12v_ma",
      "current_draw_plus5v_ma",
      "depth_mm",
      "description",
      "manual_url",
      "purchase_price",
      "current_value"
    ]

    params =
      Enum.reduce(fields, %{}, fn field, acc ->
        Map.put(acc, field, form_field_param(form, field))
      end)

    Map.put(params, "subtypes", form_subtypes(form))
  end

  defp form_field_param(%{params: params}, field) when is_map_key(params, field) do
    case Map.get(params, field) do
      nil -> ""
      value -> to_string(value)
    end
  end

  defp form_field_param(form, field) do
    atom = String.to_existing_atom(field)

    case Ecto.Changeset.get_field(form.source, atom) do
      nil -> ""
      value -> to_string(value)
    end
  end

  defp youtube_videos_as_params(%{params: %{"youtube_videos" => videos}}) when is_map(videos) do
    videos
    |> Enum.sort_by(fn {key, _} ->
      case Integer.parse(to_string(key)) do
        {int, ""} -> int
        _ -> 0
      end
    end)
    |> Enum.map(fn {_key, video} ->
      video
      |> Map.take(["id", "url"])
      |> Map.update("url", "", fn
        nil -> ""
        url -> to_string(url)
      end)
      |> then(fn map ->
        case Map.get(map, "id") do
          id when id in [nil, ""] -> Map.delete(map, "id")
          id -> Map.put(map, "id", to_string(id))
        end
      end)
    end)
  end

  defp youtube_videos_as_params(form) do
    (Ecto.Changeset.get_field(form.source, :youtube_videos) || [])
    |> Enum.map(fn video ->
      id = Map.get(video, :id)
      url = Map.get(video, :url) || ""

      if id do
        %{"id" => to_string(id), "url" => url}
      else
        %{"url" => url}
      end
    end)
  end

  defp index_youtube_video_params(videos) do
    videos
    |> Enum.with_index()
    |> Map.new(fn {video, index} -> {to_string(index), video} end)
  end

  defp swap_at(list, i, j) do
    a = Enum.at(list, i)
    b = Enum.at(list, j)

    list
    |> List.replace_at(i, b)
    |> List.replace_at(j, a)
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :disabled, :boolean, default: false
  attr :manufacturers, :list, default: []
  attr :types, :list, default: []
  attr :uploads, :map, default: nil
  attr :eurorack_module, EurorackModule, default: nil

  defp eurorack_module_fields(assigns) do
    subtypes = form_subtypes(assigns.form)
    haupttyp = form_field_param(assigns.form, "type")
    subtype_options = Enum.reject(assigns.types, &(&1 == haupttyp))

    assigns =
      assigns
      |> assign(:subtypes, subtypes)
      |> assign(:subtype_options, subtype_options)

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
        field={@form[:purchase_price]}
        type="number"
        label="Kaufpreis (€)"
        step="0.01"
        min="0"
        disabled={@disabled}
      />
      <.input
        field={@form[:current_value]}
        type="number"
        label="Wert (€)"
        step="0.01"
        min="0"
        disabled={@disabled}
      />
      <.input
        field={@form[:type]}
        type="select"
        label="Typ"
        prompt="Bitte waehlen"
        options={@types}
        disabled={@disabled}
      />
      <div class="sm:col-span-2 fieldset mb-2" id="module-subtypes">
        <span class="label mb-1">Subtypen</span>
        <input
          :for={subtype <- @subtypes}
          type="hidden"
          name="eurorack_module[subtypes][]"
          value={subtype}
        />
        <div :if={@subtype_options == []} class="text-base-content/50 text-sm">
          Keine weiteren Typen verfuegbar.
        </div>
        <div :if={@subtype_options != []} class="flex flex-wrap gap-1.5">
          <%= for type <- @subtype_options do %>
            <% selected? = type in @subtypes %>
            <%= if @disabled do %>
              <span
                :if={selected?}
                id={"subtype-chip-#{type}"}
                class="badge badge-primary badge-sm"
              >
                {type}
              </span>
            <% else %>
              <button
                type="button"
                id={"subtype-chip-#{type}"}
                phx-click="toggle_subtype"
                phx-value-type={type}
                class={[
                  "badge badge-sm transition-colors",
                  selected? && "badge-primary",
                  !selected? && "badge-outline hover:badge-primary"
                ]}
              >
                {type}
              </button>
            <% end %>
          <% end %>
        </div>
        <p
          :if={@disabled and @subtypes == []}
          class="text-base-content/50 text-sm"
          id="module-subtypes-empty"
        >
          Keine Subtypen
        </p>
      </div>
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
      <div class="sm:col-span-2">
        <.youtube_video_fields
          form={@form}
          disabled={@disabled}
          youtube_videos={youtube_videos_for_display(@eurorack_module, @form)}
        />
      </div>
    </div>
    """
  end

  defp youtube_videos_for_display(%EurorackModule{youtube_videos: videos}, _form)
       when is_list(videos),
       do: videos

  defp youtube_videos_for_display(_eurorack_module, form) do
    Ecto.Changeset.get_field(form.source, :youtube_videos) || []
  end

  attr :eurorack_module, EurorackModule, required: true

  defp youtube_play_button(assigns) do
    primary = Inventory.primary_youtube_video(assigns.eurorack_module)

    assigns =
      assign(assigns,
        primary: primary,
        watch_url: primary && Youtube.watch_url(primary.url),
        embed_url: primary && Youtube.embed_url(primary.url, autoplay: true, mute: true)
      )

    ~H"""
    <%= if @primary && @watch_url do %>
      <a
        href={@watch_url}
        id={"open-youtube-#{@eurorack_module.id}"}
        class="btn btn-ghost btn-xs relative"
        title="YouTube-Video oeffnen"
        aria-label="YouTube-Video oeffnen"
        target="_blank"
        rel="noopener noreferrer"
        phx-hook=".YoutubePreview"
        phx-update="ignore"
        data-embed-url={@embed_url}
      >
        <.icon name="hero-play" />
      </a>
    <% else %>
      <button
        type="button"
        id={"open-youtube-#{@eurorack_module.id}"}
        class="btn btn-ghost btn-xs btn-disabled"
        title="Kein YouTube-Video"
        aria-label="Kein YouTube-Video"
        disabled
      >
        <.icon name="hero-play" />
      </button>
    <% end %>
    """
  end

  attr :form, Phoenix.HTML.Form, required: true
  attr :disabled, :boolean, default: false
  attr :youtube_videos, :list, default: []

  defp youtube_video_fields(assigns) do
    video_count =
      assigns.form.source
      |> Ecto.Changeset.get_field(:youtube_videos)
      |> List.wrap()
      |> length()

    assigns = assign(assigns, :youtube_video_count, video_count)

    ~H"""
    <div id="youtube-video-fields" class="fieldset mb-2">
      <span class="label mb-1">YouTube-Videos</span>

      <div :if={@disabled} id="youtube-videos-show" class="space-y-2">
        <a
          :for={{video, index} <- Enum.with_index(@youtube_videos)}
          id={"youtube-video-link-#{index}"}
          href={Youtube.watch_url(video.url) || video.url}
          target="_blank"
          rel="noopener noreferrer"
          class="link link-primary block break-all"
        >
          {video.url}
        </a>
        <span :if={@youtube_videos == []} class="text-base-content/50">
          Keine Videos hinterlegt.
        </span>
      </div>

      <div :if={!@disabled} id="youtube-videos-edit" class="space-y-3">
        <.inputs_for :let={v} field={@form[:youtube_videos]}>
          <div
            id={"youtube-video-row-#{v.index}"}
            class="flex flex-col gap-2 sm:flex-row sm:items-start"
          >
            <input :if={v[:id].value} type="hidden" name={v[:id].name} value={v[:id].value} />
            <div class="min-w-0 grow">
              <.input
                field={v[:url]}
                type="text"
                label={"Video #{v.index + 1}"}
                placeholder="https://www.youtube.com/watch?v=…"
              />
            </div>
            <div class="flex shrink-0 gap-1 sm:mt-8">
              <button
                type="button"
                id={"move-youtube-video-up-#{v.index}"}
                class="btn btn-ghost btn-square btn-xs"
                title="Nach oben"
                aria-label="Nach oben"
                phx-click="move_youtube_video"
                phx-value-index={v.index}
                phx-value-direction="up"
                disabled={v.index == 0}
              >
                <.icon name="hero-arrow-up" class="size-4" />
              </button>
              <button
                type="button"
                id={"move-youtube-video-down-#{v.index}"}
                class="btn btn-ghost btn-square btn-xs"
                title="Nach unten"
                aria-label="Nach unten"
                phx-click="move_youtube_video"
                phx-value-index={v.index}
                phx-value-direction="down"
                disabled={v.index >= @youtube_video_count - 1}
              >
                <.icon name="hero-arrow-down" class="size-4" />
              </button>
              <button
                type="button"
                id={"remove-youtube-video-#{v.index}"}
                class="btn btn-ghost btn-square btn-xs text-error"
                title="Entfernen"
                aria-label="Entfernen"
                phx-click="remove_youtube_video"
                phx-value-index={v.index}
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </div>
        </.inputs_for>

        <button
          type="button"
          id="add-youtube-video-button"
          class="btn btn-sm"
          phx-click="add_youtube_video"
        >
          <.icon name="hero-plus" class="size-4" /> Link hinzufuegen
        </button>
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

  defp translate_backup_upload_error(:too_large), do: "Datei ist zu gross (max. 100 MB)"
  defp translate_backup_upload_error(:too_many_files), do: "Nur eine ZIP-Datei erlaubt"
  defp translate_backup_upload_error(:not_accepted), do: "Nur ZIP-Dateien sind erlaubt"
  defp translate_backup_upload_error(other), do: "Upload-Fehler: #{inspect(other)}"
end
