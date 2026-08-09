upload_dir = Application.fetch_env!(:module_o_mat, :manual_uploads_dir)
File.rm_rf!(upload_dir)
File.mkdir_p!(upload_dir)

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(ModuleOMat.Repo, :manual)
