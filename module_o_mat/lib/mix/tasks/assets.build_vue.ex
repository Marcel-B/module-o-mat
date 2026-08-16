defmodule Mix.Tasks.Assets.BuildVue do
  @shortdoc "Baut die Vue-UIs nach priv/vue"

  @moduledoc """
  Installiert Dependencies und baut `ui` sowie `ui-alt` nach `priv/vue`.

  Phoenix liefert die fertigen SPAs unter `/ui` und `/ui-alt` aus.

      mix assets.build_vue
  """

  use Mix.Task

  @impl Mix.Task
  def run(_args) do
    build("ui")
    build("ui-alt")
  end

  defp build(src) do
    Mix.shell().info("Vue-UI bauen: #{src}")

    npm!(src, ["ci"])
    npm!(src, ["run", "build"])

    dest = Path.join(["priv", "vue", src])
    File.rm_rf!(dest)
    File.mkdir_p!(Path.dirname(dest))
    File.cp_r!(Path.join(src, "dist"), dest)
    Mix.shell().info("Kopiert nach #{dest}")
  end

  defp npm!(dir, args) do
    case System.cmd("npm", args, cd: dir, into: IO.stream()) do
      {_, 0} -> :ok
      {_, status} -> Mix.raise("npm #{Enum.join(args, " ")} in #{dir} failed (#{status})")
    end
  end
end
