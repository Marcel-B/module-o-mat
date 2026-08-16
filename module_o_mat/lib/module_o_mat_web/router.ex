defmodule ModuleOMatWeb.Router do
  use ModuleOMatWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ModuleOMatWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug OpenApiSpex.Plug.PutApiSpec, module: ModuleOMatWeb.ApiSpec
  end

  scope "/", ModuleOMatWeb do
    pipe_through :browser

    live "/", EurorackModuleLive.Index, :index
    live "/eurorack_modules/new", EurorackModuleLive.Index, :new
    get "/eurorack_modules/:id/manual", ManualController, :show
    live "/eurorack_modules/:id/price_history", EurorackModuleLive.Index, :price_history
    live "/eurorack_modules/:id", EurorackModuleLive.Index, :show
    live "/eurorack_modules/:id/edit", EurorackModuleLive.Index, :edit
    live "/eurorack_modules/:id/duplicate", EurorackModuleLive.Index, :duplicate
    live "/module_types", EurorackModuleLive.Index, :manage_types
    live "/backup", EurorackModuleLive.Index, :backup
    get "/backup/export", BackupController, :export
  end

  scope "/api" do
    pipe_through :browser

    get "/docs", OpenApiSpex.Plug.SwaggerUI, path: "/api/openapi"
  end

  scope "/api" do
    pipe_through :api

    get "/openapi", OpenApiSpex.Plug.RenderSpec, []
  end

  scope "/api", ModuleOMatWeb.Api do
    pipe_through :api

    get "/modules", ModuleController, :index
    get "/modules/:id", ModuleController, :show
    post "/modules/:id/valuations", ModuleController, :create_valuations
  end

  scope "/api/v1", ModuleOMatWeb.Api.V1 do
    pipe_through :api

    get "/modules", ModuleController, :index
    get "/modules/:id", ModuleController, :show
    post "/modules", ModuleController, :create
    patch "/modules/:id", ModuleController, :update
    delete "/modules/:id", ModuleController, :delete
    post "/modules/:id/duplicate", ModuleController, :duplicate
    post "/modules/:id/valuations", ModuleController, :create_valuations

    get "/modules/:id/manual", ModuleController, :show_manual
    put "/modules/:id/manual", ModuleController, :update_manual
    delete "/modules/:id/manual", ModuleController, :delete_manual

    get "/module-types", ModuleTypeController, :index
    post "/module-types", ModuleTypeController, :create
    patch "/module-types/:id", ModuleTypeController, :update
    delete "/module-types/:id", ModuleTypeController, :delete

    get "/manufacturers", LookupController, :manufacturers

    get "/backup/export", BackupController, :export
    post "/backup/import", BackupController, :import_backup
  end
end
