defmodule WikWeb.Components.Calendar do
  @moduledoc """
  A simple calendar component that allows users to navigate between months and select a date.

  ## Examples

  <.live_component
    id="calendar"
    module={WikWeb.Components.Calendar}
  />
  """

  use Phoenix.LiveComponent
  use WikWeb, :html

  @week_start_at :monday

  def next_prev_class do
    [
      "btn btn-sm"
    ]
  end

  def render(assigns) do
    ~H"""
    <div class="max-w-md mx-auto">
      <div>
        <div class={[
          "flex justify-between gap-2 items-center",
          "mb-1"
        ]}>
          <button class={next_prev_class()} type="button" phx-target={@myself} phx-click="prev-month">
            <.icon name="hero-chevron-left-mini" /> Prev
          </button>

          <h3 class={[
            "font-bold"
          ]}>
            {Calendar.strftime(@current_date, "%B %Y")}
          </h3>

          <button class={next_prev_class()} type="button" phx-target={@myself} phx-click="next-month">
            Next <.icon name="hero-chevron-right-mini" />
          </button>
        </div>
      </div>

      <table class={[
        "table table-compact",
        "bg-base-200",
        "[&_th]:text-center",
        "[&_*]:border-base-content/10",
        "[&_th]:border",
        "[&_td]:w-1/7",
        "[&_td]:border",
        "[&_td]:text-xs"
      ]}>
        <thead>
          <tr>
            <th :for={week_day <- List.first(@week_rows)}>
              {Calendar.strftime(week_day, "%a")}
            </th>
          </tr>
        </thead>

        <tbody>
          <tr :for={week <- @week_rows}>
            <td
              :for={day <- week}
              class={[
                "text-center",
                today?(day) && "bg-primary/20",
                other_month?(day, @current_date) && "opacity-30",
                selected_date?(day, @selected_date) && "!bg-warning",
                "hover:bg-warning/50",
                "cursor-pointer"
              ]}
              phx-target={@myself}
              phx-click="pick-date"
              phx-value-date={Calendar.strftime(day, "%Y-%m-%d")}
            >
              <time datetime={Calendar.strftime(day, "%Y-%m-%d")}>
                {Calendar.strftime(day, "%d")}
              </time>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  def mount(socket) do
    current_date = Date.utc_today()

    assigns = [
      current_date: current_date,
      selected_date: nil,
      week_rows: week_rows(current_date)
    ]

    {:ok, assign(socket, assigns)}
  end

  defp week_rows(current_date) do
    first =
      current_date
      |> Date.beginning_of_month()
      |> Date.beginning_of_week(@week_start_at)

    last =
      current_date
      |> Date.end_of_month()
      |> Date.end_of_week(@week_start_at)

    Date.range(first, last)
    |> Enum.to_list()
    |> Enum.chunk_every(7)
  end

  def handle_event("prev-month", _, socket) do
    new_date = socket.assigns.current_date |> Date.beginning_of_month() |> Date.add(-1)

    assigns = [
      current_date: new_date,
      week_rows: week_rows(new_date)
    ]

    {:noreply, assign(socket, assigns)}
  end

  def handle_event("next-month", _, socket) do
    new_date = socket.assigns.current_date |> Date.end_of_month() |> Date.add(1)

    assigns = [
      current_date: new_date,
      week_rows: week_rows(new_date)
    ]

    {:noreply, assign(socket, assigns)}
  end

  def handle_event("pick-date", %{"date" => date}, socket) do
    {:noreply, assign(socket, :selected_date, Date.from_iso8601!(date))}
  end

  defp selected_date?(day, selected_date), do: day == selected_date

  defp today?(day), do: day == Date.utc_today()

  defp other_month?(day, current_date),
    do: Date.beginning_of_month(day) != Date.beginning_of_month(current_date)
end
