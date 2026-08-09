import Config

config :module_o_mat, ModuleOMat.Repo,
  database: Path.expand("../module_o_mat_test.db", __DIR__),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 5

config :logger, level: :warning
