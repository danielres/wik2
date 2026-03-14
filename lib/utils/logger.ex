defmodule Utils.Log do
  require Logger

  def scoped_error(scope, details, title \\ "") do
    error_id = short_error_id()

    meta = [
      error_id: error_id,
      details: details,
      scope: scope 
    ]

    Logger.error("#{title} #{inspect(meta, pretty: true)}")

    error_id
  end

  defp short_error_id do
    Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end
end
