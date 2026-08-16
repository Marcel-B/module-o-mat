defmodule ModuleOMatWeb.Api.V1.ModuleController do
  @moduledoc """
  JSON-REST-API fuer Eurorack-Module (Vue und andere HTTP-Clients).
  """

  use ModuleOMatWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias ModuleOMat.Inventory
  alias ModuleOMat.Inventory.ManualStorage
  alias ModuleOMatWeb.Api.JSON
  alias ModuleOMatWeb.Api.Params
  alias ModuleOMatWeb.Api.Schemas

  action_fallback ModuleOMatWeb.Api.FallbackController

  @max_pdf_bytes 20_000_000

  tags ["modules"]

  operation :index,
    summary: "Module auflisten",
    description: "Aktive Module inkl. Statistik. Filter werden per AND verknuepft.",
    parameters: [
      q: [
        in: :query,
        type: :string,
        description: "Suche in Hersteller oder Name",
        required: false
      ],
      types: [
        in: :query,
        type: %OpenApiSpex.Schema{type: :array, items: %OpenApiSpex.Schema{type: :string}},
        description: "Haupt- oder Subtypen (OR untereinander)",
        required: false
      ],
      min_hp: [in: :query, type: :integer, description: "Minimale HP", required: false],
      max_hp: [in: :query, type: :integer, description: "Maximale HP", required: false]
    ],
    responses: [
      ok: {"Modulliste", "application/json", Schemas.ModuleListResponse}
    ]

  def index(conn, params) do
    opts = Params.filter_opts(params)
    modules = Inventory.list_eurorack_modules(opts)
    ranges = Inventory.price_ranges_for_modules(Enum.map(modules, & &1.id))

    json(conn, %{
      modules: Enum.map(modules, &JSON.module(&1, Map.get(ranges, &1.id))),
      stats: JSON.stats(Inventory.inventory_stats(opts))
    })
  end

  operation :show,
    summary: "Modul anzeigen",
    parameters: [
      id: [in: :path, type: :integer, description: "Modul-ID"]
    ],
    responses: [
      ok: {"Modul", "application/json", Schemas.ModuleResponse},
      not_found: {"Nicht gefunden", "application/json", Schemas.Error}
    ]

  def show(conn, %{"id" => id}) do
    with {:ok, module} <- fetch_module(id, price_observations: true) do
      json(conn, %{
        module: JSON.module(module, Inventory.price_range_for_module(module.id))
      })
    end
  end

  operation :create,
    summary: "Modul anlegen",
    request_body: {"Modul", "application/json", Schemas.ModuleRequest},
    responses: [
      created: {"Angelegt", "application/json", Schemas.ModuleResponse},
      unprocessable_entity: {"Validierung", "application/json", Schemas.Error}
    ]

  def create(conn, params) do
    attrs = Params.unwrap(params, "module")

    case Inventory.create_eurorack_module(attrs) do
      {:ok, module} ->
        conn
        |> put_status(:created)
        |> json(%{module: JSON.module(module)})

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  operation :update,
    summary: "Modul aktualisieren",
    parameters: [
      id: [in: :path, type: :integer, description: "Modul-ID"]
    ],
    request_body: {"Modul", "application/json", Schemas.ModuleRequest},
    responses: [
      ok: {"Aktualisiert", "application/json", Schemas.ModuleResponse},
      not_found: {"Nicht gefunden", "application/json", Schemas.Error},
      unprocessable_entity: {"Validierung", "application/json", Schemas.Error}
    ]

  def update(conn, %{"id" => id} = params) do
    attrs = Params.unwrap(params, "module")

    with {:ok, module} <- fetch_module(id) do
      case Inventory.update_eurorack_module(module, attrs) do
        {:ok, updated} ->
          json(conn, %{
            module: JSON.module(updated, Inventory.price_range_for_module(updated.id))
          })

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  operation :delete,
    summary: "Modul soft-loeschen",
    parameters: [
      id: [in: :path, type: :integer, description: "Modul-ID"]
    ],
    responses: [
      no_content: "Geloescht",
      not_found: {"Nicht gefunden", "application/json", Schemas.Error}
    ]

  def delete(conn, %{"id" => id}) do
    with {:ok, module} <- fetch_module(id) do
      case Inventory.soft_delete_eurorack_module(module) do
        {:ok, _} -> send_resp(conn, :no_content, "")
        {:error, changeset} -> {:error, changeset}
      end
    end
  end

  operation :duplicate,
    summary: "Modul duplizieren",
    parameters: [
      id: [in: :path, type: :integer, description: "Quell-Modul-ID"]
    ],
    request_body: {"Optionen", "application/json", Schemas.DuplicateParams, [required: false]},
    responses: [
      created: {"Kopie", "application/json", Schemas.ModuleResponse},
      not_found: {"Nicht gefunden", "application/json", Schemas.Error},
      unprocessable_entity: {"Validierung", "application/json", Schemas.Error}
    ]

  def duplicate(conn, %{"id" => id} = params) do
    with {:ok, source} <- fetch_module(id) do
      attrs = duplicate_attrs(source, Map.get(params, "module"))
      copy_manual? = Params.truthy?(Map.get(params, "copy_manual"), true)

      case Inventory.create_eurorack_module(attrs) do
        {:ok, created} ->
          created = maybe_copy_manual(created, source, copy_manual?)

          conn
          |> put_status(:created)
          |> json(%{module: JSON.module(created)})

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  operation :create_valuations,
    summary: "Preisbeobachtungen speichern",
    parameters: [
      id: [in: :path, type: :integer, description: "Modul-ID"]
    ],
    request_body: {"Beobachtungen", "application/json", Schemas.ValuationsParams},
    responses: [
      created: {"Gespeichert", "application/json", Schemas.ValuationsResponse},
      not_found: {"Nicht gefunden", "application/json", Schemas.Error},
      unprocessable_entity: {"Validierung", "application/json", Schemas.Error}
    ]

  def create_valuations(conn, %{"id" => id} = params) do
    with {:ok, module} <- fetch_module(id) do
      observations = Map.get(params, "observations") || []

      opts =
        cond do
          Map.has_key?(params, "current_value") ->
            [set_current_value: Map.get(params, "current_value")]

          true ->
            [set_current_value: parse_set_current_value(Map.get(params, "set_current_value"))]
        end

      case Inventory.create_price_observations(module, observations, opts) do
        {:ok, result} ->
          conn
          |> put_status(:created)
          |> json(%{
            module: JSON.module(result.module, result.price_range),
            observations: Enum.map(result.observations, &JSON.observation/1),
            price_range: JSON.price_range(result.price_range)
          })

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  operation :show_manual,
    summary: "PDF-Anleitung herunterladen",
    parameters: [
      id: [in: :path, type: :integer, description: "Modul-ID"]
    ],
    responses: [
      ok: {"PDF", "application/pdf", %OpenApiSpex.Schema{type: :string, format: :binary}},
      not_found: {"Nicht gefunden", "application/json", Schemas.Error}
    ]

  def show_manual(conn, %{"id" => id}) do
    with {:ok, module} <- fetch_module(id) do
      case module.manual_pdf_key do
        key when is_binary(key) ->
          if ManualStorage.exists?(key) do
            ManualStorage.serve(conn, key,
              filename: module.manual_pdf_filename,
              content_type: module.manual_pdf_content_type || "application/pdf"
            )
          else
            {:error, {:not_found, "Keine Anleitung gefunden"}}
          end

        _ ->
          {:error, {:not_found, "Keine Anleitung gefunden"}}
      end
    end
  end

  operation :update_manual,
    summary: "PDF-Anleitung hochladen",
    parameters: [
      id: [in: :path, type: :integer, description: "Modul-ID"]
    ],
    request_body: {"PDF-Datei", "multipart/form-data", Schemas.FileUpload},
    responses: [
      ok: {"Aktualisiert", "application/json", Schemas.ModuleResponse},
      not_found: {"Nicht gefunden", "application/json", Schemas.Error},
      unprocessable_entity: {"Validierung", "application/json", Schemas.Error}
    ]

  def update_manual(conn, %{"id" => id} = params) do
    with {:ok, module} <- fetch_module(id),
         {:ok, upload} <- Params.fetch_upload(params),
         :ok <- validate_pdf_upload(upload) do
      attach_manual(conn, module, upload)
    end
  end

  operation :delete_manual,
    summary: "PDF-Anleitung entfernen",
    parameters: [
      id: [in: :path, type: :integer, description: "Modul-ID"]
    ],
    responses: [
      ok: {"Aktualisiert", "application/json", Schemas.ModuleResponse},
      not_found: {"Nicht gefunden", "application/json", Schemas.Error}
    ]

  def delete_manual(conn, %{"id" => id}) do
    with {:ok, module} <- fetch_module(id) do
      case Inventory.remove_manual(module) do
        {:ok, updated} ->
          json(conn, %{
            module: JSON.module(updated, Inventory.price_range_for_module(updated.id))
          })

        {:error, changeset} ->
          {:error, changeset}
      end
    end
  end

  defp attach_manual(conn, module, upload) do
    case Inventory.attach_manual(module, %{
           tmp_path: upload.path,
           filename: upload.filename,
           content_type: upload.content_type || "application/pdf",
           size: Params.upload_size(upload)
         }) do
      {:ok, updated} ->
        json(conn, %{
          module: JSON.module(updated, Inventory.price_range_for_module(updated.id))
        })

      {:error, changeset} ->
        {:error, changeset}
    end
  rescue
    e in [ArgumentError, File.Error] ->
      {:error, {:unprocessable, Exception.message(e)}}
  end

  defp fetch_module(id, opts \\ []) do
    case Params.parse_id(id) do
      {:ok, parsed_id} ->
        case Inventory.get_active_eurorack_module(parsed_id, opts) do
          nil -> {:error, {:not_found, "Modul nicht gefunden"}}
          module -> {:ok, module}
        end

      :error ->
        {:error, {:not_found, "Modul nicht gefunden"}}
    end
  end

  defp duplicate_attrs(source, overrides) do
    videos =
      source.youtube_videos
      |> List.wrap()
      |> Enum.map(fn video -> %{"url" => video.url} end)

    base = %{
      "manufacturer" => source.manufacturer,
      "name" => source.name,
      "hp" => source.hp,
      "type" => source.type,
      "subtypes" => source.subtypes || [],
      "current_draw_plus12v_ma" => source.current_draw_plus12v_ma,
      "current_draw_minus12v_ma" => source.current_draw_minus12v_ma,
      "current_draw_plus5v_ma" => source.current_draw_plus5v_ma,
      "depth_mm" => source.depth_mm,
      "description" => source.description,
      "manual_url" => source.manual_url,
      "purchase_price" => source.purchase_price,
      "current_value" => source.current_value,
      "youtube_videos" => videos
    }

    Map.merge(base, stringify_keys(overrides || %{}))
  end

  defp maybe_copy_manual(created, source, true) when is_binary(source.manual_pdf_key) do
    meta = %{
      filename: source.manual_pdf_filename,
      content_type: source.manual_pdf_content_type,
      size_bytes: source.manual_pdf_size_bytes
    }

    case Inventory.copy_manual(created, source.manual_pdf_key, meta) do
      {:ok, copied} -> copied
      {:error, _} -> created
    end
  end

  defp maybe_copy_manual(created, _source, _copy?), do: created

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  defp validate_pdf_upload(upload) do
    size = Params.upload_size(upload)
    filename = upload.filename || ""
    content_type = upload.content_type || ""

    cond do
      size > @max_pdf_bytes ->
        {:error, {:unprocessable, "PDF darf hoechstens 20 MB gross sein"}}

      not pdf_upload?(filename, content_type) ->
        {:error, {:unprocessable, "Nur PDF-Dateien sind erlaubt"}}

      true ->
        :ok
    end
  end

  defp pdf_upload?(filename, content_type) do
    String.ends_with?(String.downcase(filename), ".pdf") or
      String.contains?(content_type, "pdf")
  end

  defp parse_set_current_value(nil), do: :median
  defp parse_set_current_value("median"), do: :median
  defp parse_set_current_value(:median), do: :median
  defp parse_set_current_value(other), do: other
end
