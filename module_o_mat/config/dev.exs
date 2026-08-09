import Config

config :module_o_mat, ModuleOMat.Repo,
  database: Path.expand("../module_o_mat_dev.db", __DIR__),
  pool_size: 1,
  show_sensitive_data_on_connection_error: true
