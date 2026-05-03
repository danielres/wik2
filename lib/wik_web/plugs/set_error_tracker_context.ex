defmodule WikWeb.Plugs.SetErrorTrackerContext do
  @behaviour Plug

  alias WikWeb.ErrorTrackerContext

  def init(opts), do: opts

  def call(conn, _opts) do
    ErrorTrackerContext.set(conn)
  end
end
