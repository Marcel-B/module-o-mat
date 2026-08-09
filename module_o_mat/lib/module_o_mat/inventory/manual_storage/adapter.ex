defmodule ModuleOMat.Inventory.ManualStorage.Adapter do
  @moduledoc """
  Behaviour fuer die Persistenz von PDF-Anleitungen.

  Implementierungen koennen die Dateien lokal speichern oder spaeter z.B.
  an einen Object-Storage-Dienst weiterreichen. `serve/3` ist verantwortlich
  fuer die komplette HTTP-Antwort, damit Adapter z.B. auf eine presigned
  URL umleiten koennen, ohne dass der Controller davon wissen muss.
  """

  @type key :: String.t()
  @type serve_opts :: [
          filename: String.t() | nil,
          content_type: String.t()
        ]

  @callback store!(key(), Path.t()) :: :ok
  @callback delete(key()) :: :ok
  @callback serve(Plug.Conn.t(), key(), serve_opts()) :: Plug.Conn.t()
  @callback copy_out!(key(), Path.t()) :: :ok
  @callback replace_all!(Path.t()) :: :ok
  @callback exists?(key()) :: boolean()
end
