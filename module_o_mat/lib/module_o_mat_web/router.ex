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
  end

  scope "/", ModuleOMatWeb do
    pipe_through :browser

    live "/", EurorackModuleLive.Index, :index
    live "/eurorack_modules/new", EurorackModuleLive.Index, :new
    get "/eurorack_modules/:id/manual", ManualController, :show
    live "/eurorack_modules/:id", EurorackModuleLive.Index, :show
    live "/eurorack_modules/:id/edit", EurorackModuleLive.Index, :edit
    live "/module_types", EurorackModuleLive.Index, :manage_types
    live "/backup", EurorackModuleLive.Index, :backup
    get "/backup/export", BackupController, :export
  end

  # Other scopes may use custom stacks.
  scope "/api", ModuleOMatWeb.Api do
    pipe_through :api

    get "/modules", ModuleController, :index
    get "/modules/:id", ModuleController, :show
    post "/modules/:id/valuations", ModuleController, :create_valuations
  end
end
