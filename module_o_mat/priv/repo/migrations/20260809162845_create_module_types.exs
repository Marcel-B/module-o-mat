defmodule ModuleOMat.Repo.Migrations.CreateModuleTypes do
  use Ecto.Migration

  @default_types [
    "VCO",
    "VCA",
    "VCF",
    "LFO",
    "Envelope",
    "Sequencer",
    "Quantizer",
    "Clock",
    "Random",
    "Logic",
    "Mixer",
    "Effect",
    "Utility",
    "MIDI-Interface",
    "Multiple",
    "Attenuator",
    "Noise",
    "Sonstiges"
  ]

  def up do
    create table(:module_types) do
      add :name, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:module_types, [:name])

    flush()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    entries = Enum.map(@default_types, &%{name: &1, inserted_at: now, updated_at: now})

    repo().insert_all("module_types", entries)
  end

  def down do
    drop table(:module_types)
  end
end
