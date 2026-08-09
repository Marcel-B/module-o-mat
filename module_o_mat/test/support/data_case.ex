defmodule ModuleOMat.DataCase do
  @moduledoc """
  Test-Case fuer Tests, die den `ModuleOMat.Repo` benoetigen.

  Kapselt das Setup des Ecto SQL Sandbox, sodass jeder Test in einer
  eigenen, isolierten Transaktion laeuft, die am Ende zurueckgerollt wird.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias ModuleOMat.Repo

      import ModuleOMat.DataCase
    end
  end

  setup tags do
    ModuleOMat.DataCase.setup_sandbox(tags)
    :ok
  end

  @doc """
  Startet den Ecto SQL Sandbox fuer den aktuellen Test-Prozess.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(ModuleOMat.Repo, shared: not tags[:async])
    ExUnit.Callbacks.on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Wandelt Changeset-Fehler in eine Map von lesbaren Fehlermeldungen um, z.B.
  `%{name: ["can't be blank"]}`.
  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end
end
