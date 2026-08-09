import Config

config :module_o_mat, ecto_repos: [ModuleOMat.Repo]

import_config "#{config_env()}.exs"
