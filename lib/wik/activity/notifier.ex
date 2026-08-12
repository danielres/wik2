defmodule Wik.Activity.Notifier do
  use Ash.Notifier

  require Logger

  alias Wik.Activity.NotificationMapper
  alias Wik.Activity.Recorder

  @impl true
  def notify(notification) do
    notification
    |> NotificationMapper.map()
    |> Enum.each(fn attrs ->
      case Recorder.record(attrs) do
        {:ok, _entry} ->
          :ok

        {:error, error} ->
          Logger.error("Activity recording failed: #{inspect(error)}")
      end
    end)
  rescue
    error ->
      Logger.error(Exception.format(:error, error, __STACKTRACE__))
      :ok
  end

  @impl true
  def requires_original_data?(Wik.Wiki.PageTree, _action), do: true
  def requires_original_data?(_resource, _action), do: false
end
