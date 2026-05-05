defmodule Wik.Events.Event.Changes.SetScheduleFromLocalFields do
  use Ash.Resource.Change

  alias Ash.Changeset
  alias Utils.Tz

  @impl true
  def change(changeset, _opts, _context) do
    all_day? = Changeset.get_attribute(changeset, :all_day)
    tz = Changeset.get_attribute(changeset, :tz)
    starts_at = Changeset.get_attribute(changeset, :starts_at)
    ends_at = Changeset.get_attribute(changeset, :ends_at)
    starts_on = Changeset.get_argument(changeset, :starts_on)
    ends_on = Changeset.get_argument(changeset, :ends_on)
    starts_at_time = Changeset.get_argument(changeset, :starts_at_time)
    ends_at_time = Changeset.get_argument(changeset, :ends_at_time)

    if local_schedule_submitted?(starts_on, ends_on, starts_at_time, ends_at_time) do
      changeset
      |> Changeset.force_change_attribute(
        :starts_at,
        starts_at_value(starts_on, starts_at_time, all_day?, tz)
      )
      |> Changeset.force_change_attribute(
        :ends_at,
        ends_at_value(ends_on, ends_at_time, all_day?, tz)
      )
    else
      changeset
      |> Changeset.force_change_attribute(:starts_at, starts_at)
      |> Changeset.force_change_attribute(:ends_at, ends_at)
    end
  end

  defp starts_at_value(nil, _starts_at_time, _all_day?, _tz), do: nil

  defp starts_at_value(starts_on, _starts_at_time, true, tz),
    do: Tz.from_local(starts_on, ~T[00:00:00], tz)

  defp starts_at_value(starts_on, starts_at_time, false, tz),
    do: Tz.from_local(starts_on, starts_at_time, tz)

  defp ends_at_value(nil, _ends_at_time, _all_day?, _tz), do: nil

  defp ends_at_value(ends_on, _ends_at_time, true, tz),
    do: Tz.from_local(ends_on, ~T[23:59:59], tz)

  defp ends_at_value(ends_on, ends_at_time, false, tz),
    do: Tz.from_local(ends_on, ends_at_time, tz)

  defp local_schedule_submitted?(starts_on, ends_on, starts_at_time, ends_at_time) do
    Enum.any?([starts_on, ends_on, starts_at_time, ends_at_time], &(not is_nil(&1)))
  end
end
