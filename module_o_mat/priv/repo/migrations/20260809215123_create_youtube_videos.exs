defmodule ModuleOMat.Repo.Migrations.CreateYoutubeVideos do
  use Ecto.Migration

  def change do
    create table(:youtube_videos) do
      add :url, :string, null: false
      add :position, :integer, null: false, default: 0

      add :eurorack_module_id,
          references(:eurorack_modules, on_delete: :delete_all),
          null: false

      timestamps(type: :utc_datetime)
    end

    create index(:youtube_videos, [:eurorack_module_id])
    create index(:youtube_videos, [:eurorack_module_id, :position])
  end
end
