defmodule Utils.Log do
  require Logger

  def scoped_error(scope, details, title \\ "") do
    error_id = short_error_id()

    meta = [
      error_id: error_id,
      details: details |> format_details(),
      scope: scope
    ]

    if error_logging_enabled?() do
      Logger.error("#{title} #{inspect(meta, pretty: true)}")
    end

    error_id
  end

  defp format_details({:error, err = %Ash.Error.Forbidden{}}) do
    "Ash.Error.Forbidden: #{err.bread_crumbs}"
  end

  defp format_details(other) do
    other
  end

  defp short_error_id do
    Base.encode16(:crypto.strong_rand_bytes(4), case: :lower)
  end

  defp error_logging_enabled? do
    Application.get_env(:qblog, __MODULE__, [])
    |> Keyword.get(:error_logging_enabled?, true)
  end
end
