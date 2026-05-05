defmodule WikWeb.EventsLive.EventForm do
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

  def submit(form, params, scope) do
    case Form.submit(form,
           params: params,
           action_opts: [scope: scope, return_notifications?: true]
         ) do
      {:ok, event, notifications} ->
        Ash.Notifier.notify(notifications)
        {:ok, event}

      {:ok, event} ->
        {:ok, event}

      {:error, form} ->
        {:error, form}
    end
  end

  def mode(%Phoenix.HTML.Form{source: %{type: :create}}), do: :create
  def mode(%Phoenix.HTML.Form{source: %{type: :update}}), do: :edit

  def all_day?(%Phoenix.HTML.Form{} = form) do
    form
    |> value("all_day", "false")
    |> truthy?()
  end

  def value(%Phoenix.HTML.Form{} = form, key, default \\ "") do
    form
    |> params()
    |> Map.get(key, default)
    |> normalize_value()
  end

  defp default_create_params(user_tz) do
    local_now = local_now(user_tz) |> round_up_to_hour()
    local_end = NaiveDateTime.add(local_now, @default_duration_seconds, :second)

    %{
      "all_day" => "false",
      "description" => "",
      "ends_on" => format_date(NaiveDateTime.to_date(local_end)),
      "ends_at_time" => format_time(NaiveDateTime.to_time(local_end)),
      "location" => "",
      "provenance_policy" => "visible",
      "relay_policy" => "internal_only",
      "starts_on" => format_date(NaiveDateTime.to_date(local_now)),
      "starts_at_time" => format_time(NaiveDateTime.to_time(local_now)),
      "tz" => user_tz,
      "title" => ""
    }
  end

  defp default_edit_params(event) do
    local_starts_at = utc_to_local_naive(event.starts_at, event.tz)
    local_ends_at = event.ends_at && utc_to_local_naive(event.ends_at, event.tz)

    %{
      "all_day" => to_string(event.all_day),
      "description" => event.description,
      "ends_on" => format_date(NaiveDateTime.to_date(local_ends_at || local_starts_at)),
      "ends_at_time" => format_time(local_ends_at && NaiveDateTime.to_time(local_ends_at)),
      "location" => event.location,
      "provenance_policy" => to_string(event.provenance_policy),
      "relay_policy" => to_string(event.relay_policy),
      "starts_on" => format_date(NaiveDateTime.to_date(local_starts_at)),
      "starts_at_time" => format_time(NaiveDateTime.to_time(local_starts_at)),
      "status" => to_string(event.status),
      "tz" => event.tz,
      "title" => event.title
    }
  end

  defp local_now(tz) do
    DateTime.utc_now()
    |> utc_to_local_naive(tz)
  end

  defp round_up_to_hour(%NaiveDateTime{} = naive) do
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

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  defp format_time(nil), do: ""
  defp format_time(%Time{} = time), do: Calendar.strftime(time, "%H:%M")

  defp params(%Phoenix.HTML.Form{source: %{raw_params: params}}) when is_map(params), do: params
  defp params(%Phoenix.HTML.Form{params: params}) when is_map(params), do: params
  defp params(_form), do: %{}

  defp normalize_value(%Date{} = date), do: format_date(date)
  defp normalize_value(%Time{} = time), do: format_time(time)

  defp normalize_value(%NaiveDateTime{} = datetime),
    do: format_time(NaiveDateTime.to_time(datetime))

  defp normalize_value(%DateTime{} = datetime), do: format_time(DateTime.to_time(datetime))
  defp normalize_value(value), do: value

  defp truthy?(value), do: value in [true, "true", 1, "1", "on"]
end
