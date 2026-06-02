defmodule WikWeb.Components.Event.FormState do
  alias AshPhoenix.Form
  alias Utils.Values
  alias Utils.Tz
  alias Wik.Events.Event
  alias WikWeb.CoreComponents

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

  def show_end_date?(form) do
    ends_on = Phoenix.HTML.Form.input_value(form, :ends_on) |> Values.blank_to_nil()
    starts_on = Phoenix.HTML.Form.input_value(form, :starts_on) |> Values.blank_to_nil()

    (not is_nil(ends_on) and ends_on != starts_on) or errors_for(form, :ends_at) != []
  end

  def collapse_end_date(form) do
    params = current_params(form)
    starts_on = Map.get(params, "starts_on")

    form
    |> validate(Map.put(params, "ends_on", starts_on))
  end

  def normalize_hidden_end_date_params(form, params, show_end_date?) do
    if show_end_date? do
      params
    else
      starts_on =
        Map.get(params, "starts_on") ||
          Phoenix.HTML.Form.input_value(form, :starts_on)

      Map.put(params, "ends_on", starts_on)
    end
  end

  defp default_create_params(user_tz) do
    local_now = local_now(user_tz) |> round_up_to_next_hour()
    local_end = NaiveDateTime.add(local_now, @default_duration_seconds, :second)

    %{
      "ends_at_time" => NaiveDateTime.to_time(local_end),
      "starts_on" => NaiveDateTime.to_date(local_now),
      "starts_at_time" => NaiveDateTime.to_time(local_now),
      "tz" => user_tz
    }
  end

  defp default_edit_params(event) do
    local_starts_at = utc_to_local_naive(event.starts_at, event.tz)
    local_ends_at = event.ends_at && utc_to_local_naive(event.ends_at, event.tz)

    schedule_params(local_starts_at, local_ends_at, local_ends_at || local_starts_at)
    |> Map.put("tz", event.tz)
  end

  defp schedule_params(local_starts_at, local_ends_at_naive, local_ends_on) do
    %{
      "ends_on" => NaiveDateTime.to_date(local_ends_on),
      "ends_at_time" => local_ends_at_naive && NaiveDateTime.to_time(local_ends_at_naive),
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

  defp current_params(form) do
    %{
      "all_day" => Phoenix.HTML.Form.input_value(form, :all_day),
      "description" => Phoenix.HTML.Form.input_value(form, :description),
      "ends_at_time" => Phoenix.HTML.Form.input_value(form, :ends_at_time),
      "ends_on" => Phoenix.HTML.Form.input_value(form, :ends_on),
      "location" => Phoenix.HTML.Form.input_value(form, :location),
      "relay_policy" => Phoenix.HTML.Form.input_value(form, :relay_policy),
      "starts_at_time" => Phoenix.HTML.Form.input_value(form, :starts_at_time),
      "starts_on" => Phoenix.HTML.Form.input_value(form, :starts_on),
      "status" => Phoenix.HTML.Form.input_value(form, :status),
      "title" => Phoenix.HTML.Form.input_value(form, :title),
      "tz" => Phoenix.HTML.Form.input_value(form, :tz)
    }
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Map.new()
  end

  defp errors_for(form, field) do
    form[field].errors
    |> Enum.map(&CoreComponents.translate_error/1)
  end
end
