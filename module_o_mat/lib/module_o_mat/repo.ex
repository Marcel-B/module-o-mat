defmodule ModuleOMat.Repo do
  use Ecto.Repo,
    otp_app: :module_o_mat,
    adapter: Ecto.Adapters.SQLite3
end
