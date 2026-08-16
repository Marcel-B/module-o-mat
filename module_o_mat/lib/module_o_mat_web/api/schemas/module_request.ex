defmodule ModuleOMatWeb.Api.Schemas.ModuleRequest do
  @moduledoc false

  require OpenApiSpex

  alias ModuleOMatWeb.Api.Schemas.ModuleParams

  OpenApiSpex.schema(%{
    title: "ModuleRequest",
    description: "Request-Body fuer Modul-Create und -Update",
    type: :object,
    properties: %{
      module: ModuleParams
    },
    required: [:module],
    example: %{
      "module" => %{
        "manufacturer" => "Make Noise",
        "name" => "Maths",
        "hp" => 20,
        "type" => "Envelope"
      }
    }
  })
end
