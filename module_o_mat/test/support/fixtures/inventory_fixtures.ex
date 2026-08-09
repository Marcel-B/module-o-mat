defmodule ModuleOMat.InventoryFixtures do
  @moduledoc """
  Helper-Funktionen, um valide Testdaten fuer den `Inventory`-Context zu
  erzeugen.
  """

  alias ModuleOMat.Inventory

  @doc """
  Gueltige Standard-Attribute fuer ein Eurorack-Modul, ueberschreibbar per
  `attrs`.
  """
  def valid_eurorack_module_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      manufacturer: "Make Noise",
      name: "Maths",
      hp: 20,
      type: "Envelope",
      current_draw_plus12v_ma: 55,
      current_draw_minus12v_ma: 30,
      current_draw_plus5v_ma: nil,
      depth_mm: 35,
      description: "Funktionsgenerator, oft als Envelope/LFO genutzt.",
      manual_url: "https://www.makenoisemusic.com/technology/maths"
    })
  end

  @doc """
  Legt ein Eurorack-Modul mit validen (ggf. ueberschriebenen) Attributen an
  und liefert den erzeugten Datensatz zurueck.
  """
  def eurorack_module_fixture(attrs \\ %{}) do
    {:ok, eurorack_module} =
      attrs
      |> valid_eurorack_module_attrs()
      |> Inventory.create_eurorack_module()

    eurorack_module
  end

  @doc """
  Gueltige Standard-Attribute fuer einen Modultyp, ueberschreibbar per
  `attrs`.
  """
  def valid_module_type_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{name: "Granular"})
  end

  @doc """
  Legt einen Modultyp mit validen (ggf. ueberschriebenen) Attributen an und
  liefert den erzeugten Datensatz zurueck.
  """
  def module_type_fixture(attrs \\ %{}) do
    {:ok, module_type} =
      attrs
      |> valid_module_type_attrs()
      |> Inventory.create_module_type()

    module_type
  end
end
