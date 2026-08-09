defmodule ModuleOMat.Repo.Migrations.AddManualPdfToEurorackModules do
  use Ecto.Migration

  def change do
    alter table(:eurorack_modules) do
      add :manual_pdf_key, :string
      add :manual_pdf_filename, :string
      add :manual_pdf_content_type, :string
      add :manual_pdf_size_bytes, :integer
    end
  end
end
