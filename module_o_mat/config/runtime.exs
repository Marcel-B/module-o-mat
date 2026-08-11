import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/module_o_mat start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :module_o_mat, ModuleOMatWeb.Endpoint, server: true
end

config :module_o_mat, ModuleOMatWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :module_o_mat, ModuleOMatWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Router, Controllers, LiveViews and LiveComponents
        ~r"lib/module_o_mat_web/router\.ex$"E,
        ~r"lib/module_o_mat_web/(controllers|live|components)/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      "/data/module_o_mat.db"

  config :module_o_mat, ModuleOMat.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "1")

  config :module_o_mat,
         :manual_uploads_dir,
         System.get_env("MANUAL_UPLOADS_DIR") || "/data/uploads/manuals"

  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  scheme = System.get_env("PHX_SCHEME") || "https"

  # Public URL port: for http use the host-mapped port (PHX_PORT), for https default 443.
  # Behind a reverse proxy on :80, set PHX_PORT=80 (independent of the container host mapping).
  url_port =
    case scheme do
      "http" ->
        String.to_integer(System.get_env("PHX_PORT") || System.get_env("PORT") || "4000")

      _ ->
        String.to_integer(System.get_env("PHX_PORT") || "443")
    end

  # LiveView WebSockets reject mismatched Origin headers (403 → longpoll reconnect loop).
  # Default `true` allows only PHX_HOST. For hostname + direct IP access, set e.g.:
  # PHX_CHECK_ORIGIN=http://module.lan,http://192.168.2.197:4012
  check_origin =
    case System.get_env("PHX_CHECK_ORIGIN") do
      nil -> true
      "" -> true
      "true" -> true
      "false" -> false
      origins -> String.split(origins, ",", trim: true)
    end

  config :module_o_mat, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :module_o_mat, ModuleOMatWeb.Endpoint,
    url: [host: host, port: url_port, scheme: scheme],
    check_origin: check_origin,
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://bandit.hexdocs.pm/Bandit.html#t:options/0
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base

  # When TLS terminates at a reverse proxy (NPM etc.), set PHX_FORCE_SSL=true so
  # HTTP requests are redirected using X-Forwarded-Proto. Leave unset/false for
  # direct LAN http://IP:PORT access.
  if System.get_env("PHX_FORCE_SSL") in ~w(1 true TRUE yes YES) do
    config :module_o_mat, ModuleOMatWeb.Endpoint,
      force_ssl: [
        rewrite_on: [:x_forwarded_proto],
        hsts: true,
        exclude: [hosts: ["localhost", "127.0.0.1"]]
      ]
  end

  # ## SSL Support (TLS in the Phoenix process itself)
  #
  # Prefer terminating TLS at the reverse proxy. To terminate in Phoenix instead,
  # add an `https:` key to the Endpoint config with keyfile/certfile paths.
  # See https://plug.hexdocs.pm/Plug.SSL.html#configure/1
else
  if manual_uploads_dir = System.get_env("MANUAL_UPLOADS_DIR") do
    config :module_o_mat, :manual_uploads_dir, manual_uploads_dir
  end
end

# Optional daily Nextcloud backup (WebDAV). Disabled unless explicitly enabled.
nextcloud_backup_enabled? =
  System.get_env("NEXTCLOUD_BACKUP_ENABLED") in ~w(1 true TRUE yes YES)

if nextcloud_backup_enabled? do
  backup_at =
    case System.get_env("NEXTCLOUD_BACKUP_AT", "03:00") do
      <<h::binary-size(2), ?:, m::binary-size(2)>> ->
        {String.to_integer(h), String.to_integer(m)}

      other ->
        raise "NEXTCLOUD_BACKUP_AT must be HH:MM, got: #{inspect(other)}"
    end

  config :module_o_mat, ModuleOMat.Inventory.RemoteBackup,
    enabled: true,
    base_url: System.get_env("NEXTCLOUD_WEBDAV_URL"),
    username: System.get_env("NEXTCLOUD_USERNAME"),
    password: System.get_env("NEXTCLOUD_APP_PASSWORD"),
    at: backup_at,
    timezone: System.get_env("NEXTCLOUD_BACKUP_TIMEZONE") || "Europe/Berlin",
    ensure_collection: true
end
