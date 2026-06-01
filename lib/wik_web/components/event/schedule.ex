defmodule WikWeb.Components.Event.Schedule do
  use WikWeb, :html

  alias Utils.Tz

  attr :class, :string, default: nil
  attr :event, :map, required: true
  attr :grouped_date, :any, default: nil
  attr :user_tz, :string, required: true

  def render(assigns) do
    event_parts = schedule_parts(assigns.event, assigns.event.tz)
    user_parts = schedule_parts(assigns.event, assigns.user_tz)
    show_user_tz? = event_parts != user_parts

    rendered_parts =
      if show_user_tz? do
        [event_parts, user_parts]
      else
        [event_parts]
      end

    assigns =
      assigns
      |> assign(:event_parts, event_parts)
      |> assign(:user_parts, user_parts)
      |> assign(:show_user_tz?, show_user_tz?)
      |> assign(:show_dates?, show_schedule_dates?(rendered_parts, assigns.grouped_date))

    ~H"""
    <div class={["space-y-0.5", @class]}>
      <.schedule_row
        parts={@event_parts}
        show_date?={@show_dates?}
        tz={@event.tz}
        tz?={@show_user_tz?}
      />
      <.schedule_row
        :if={@show_user_tz?}
        parts={@user_parts}
        show_date?={@show_dates?}
        tz={@user_tz}
        secondary?
      />
    </div>
    """
  end

  attr :parts, :map, required: true
  attr :show_date?, :boolean, default: true
  attr :tz, :string, required: true
  attr :secondary?, :boolean, default: false
  attr :tz?, :boolean, default: true

  defp schedule_row(assigns) do
    ~H"""
    <div class={["flex flex-wrap items-center gap-x-1 gap-y-1 text-xs", @secondary? && "opacity-75"]}>
      <%= case {@parts.kind, Map.get(@parts, :same_day?)} do %>
        <% {:timed, true} -> %>
          <span :if={@show_date?}>{@parts.start_date}</span>
          <span>{@parts.start_time}</span>
          <span class="opacity-70">–</span>
          <span>{@parts.end_time}</span>
        <% {:timed, false} -> %>
          <span class="font-medium">{@parts.start_date}</span>
          <span>{@parts.start_time}</span>
          <span class="opacity-70">–</span>
          <span class="font-medium">{@parts.end_date}</span>
          <span>{@parts.end_time}</span>
        <% {:all_day_single, _} -> %>
          <span class="font-medium">{@parts.start_date}</span>
        <% {:all_day_range, _} -> %>
          <span class="font-medium">{@parts.start_date}</span>
          <span class="opacity-70">–</span>
          <span class="font-medium">{@parts.end_date}</span>
      <% end %>

      <span :if={@tz?} class="badge badge-xs bg-base-300">
        {@tz}
      </span>
    </div>
    """
  end

  defp schedule_parts(event, tz) do
    if event.all_day do
      all_day_schedule_parts(event, tz)
    else
      timed_schedule_parts(event, tz)
    end
  end

  defp timed_schedule_parts(event, tz) do
    starts_at = Tz.to_local!(event.starts_at, tz)
    ends_at = Tz.to_local!(event.ends_at, tz)
    start_date = DateTime.to_date(starts_at)
    end_date = DateTime.to_date(ends_at)

    %{
      kind: :timed,
      same_day?: Date.compare(start_date, end_date) == :eq,
      start_date_value: start_date,
      start_date: Calendar.strftime(starts_at, "%Y-%m-%d"),
      start_time: Calendar.strftime(starts_at, "%H:%M"),
      end_date_value: end_date,
      end_date: Calendar.strftime(ends_at, "%Y-%m-%d"),
      end_time: Calendar.strftime(ends_at, "%H:%M")
    }
  end

  defp all_day_schedule_parts(event, tz) do
    start_date = event.starts_at |> Tz.to_local!(tz) |> DateTime.to_date()

    end_date =
      case event.ends_at do
        nil -> nil
        ends_at -> ends_at |> Tz.to_local!(tz) |> DateTime.to_date()
      end

    if is_nil(end_date) or Date.compare(start_date, end_date) == :eq do
      %{
        kind: :all_day_single,
        start_date: Calendar.strftime(start_date, "%Y-%m-%d")
      }
    else
      %{
        kind: :all_day_range,
        start_date: Calendar.strftime(start_date, "%Y-%m-%d"),
        end_date: Calendar.strftime(end_date, "%Y-%m-%d")
      }
    end
  end

  defp show_schedule_dates?(_rendered_parts, nil), do: true

  defp show_schedule_dates?(rendered_parts, grouped_date) do
    not Enum.all?(rendered_parts, &same_grouped_day_timed_row?(&1, grouped_date))
  end

  defp same_grouped_day_timed_row?(
         %{kind: :timed, same_day?: true, start_date_value: date},
         grouped_date
       ),
       do: date == grouped_date

  defp same_grouped_day_timed_row?(_parts, _grouped_date), do: false
end
