defmodule WikWeb.Components.Event.FormState do
  alias AshPhoenix.Form
  alias Utils.Tz
  alias Wik.Events.Event

  @default_duration_seconds 7_200

  def new(scope, user_tz) do
    Event
    |> Form.for_create(:create, scope: scope)
    |> Form.validate(default_create_params(user_tz), errors: false)
    |> Phoenix.Component.to_form()
  end

  def edit(event, scope) do
    event
    |> Form.for_update(:update, scope: scope)
    |> Form.validate(default_edit_params(event), errors: false)
    |> Phoenix.Component.to_form()
  end

  def validate(form, params), do: Form.validate(form, params) |> Phoenix.Component.to_form()

  defp default_create_params(user_tz) do
    local_now = local_now(user_tz) |> round_up_to_next_hour()
    local_end = NaiveDateTime.add(local_now, @default_duration_seconds, :second)

    schedule_params(local_now, local_end) |> Map.put("tz", user_tz)
  end

  defp default_edit_params(event) do
    local_starts_at = utc_to_local_naive(event.starts_at, event.tz)
    local_ends_at = event.ends_at && utc_to_local_naive(event.ends_at, event.tz)

    schedule_params(local_starts_at, local_ends_at, local_ends_at || local_starts_at)
  end

  defp schedule_params(local_starts_at, local_ends_at),
    do: schedule_params(local_starts_at, local_ends_at, local_ends_at)

  defp schedule_params(local_starts_at, local_ends_at_time, local_ends_on) do
    %{
      "ends_on" => NaiveDateTime.to_date(local_ends_on),
      "ends_at_time" => local_ends_at_time && NaiveDateTime.to_time(local_ends_at_time),
      "starts_on" => NaiveDateTime.to_date(local_starts_at),
      "starts_at_time" => NaiveDateTime.to_time(local_starts_at)
    }
  end

  defp local_now(tz), do: DateTime.utc_now() |> utc_to_local_naive(tz)

  defp round_up_to_next_hour(%NaiveDateTime{} = naive) do
    rounded =
      naive
      |> NaiveDateTime.truncate(:second)
      |> then(&%{&1 | minute: 0, second: 0})

    if naive.minute == 0 and naive.second == 0 do
      rounded
    else
      NaiveDateTime.add(rounded, 3_600, :second)
    end
  end

  defp utc_to_local_naive(%DateTime{} = datetime, tz) do
    datetime
    |> Tz.to_local!(tz)
    |> DateTime.to_naive()
  end
end
