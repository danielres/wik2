defmodule WikWeb.Me.Components do
  use WikWeb, :live_view

  alias WikWeb.Components.TimezonePicker

  attr :saved_tz, :string, default: nil
  attr :active_tz, :string, required: true
  attr :form, :any, required: true

  def form_tz(assigns) do
    ~H"""
    <.form
      for={@form}
      id="update-user-tz-form"
      phx-change="update_user_tz_validate"
      phx-submit="update_user_tz_submit"
    >
      <div class="space-y-3">
        <TimezonePicker.field
          field={@form[:tz]}
          id="user-tz-picker"
          label="Your timezone"
          suggested_values={[@active_tz]}
          testid="user-tz-picker"
        />

        <div class="flex justify-end gap-2 pt-2">
          <button
            :if={@saved_tz}
            type="button"
            class="btn btn-soft hover:btn-accent btn-sm mr-auto"
            data-testid="update-user-tz-auto-detect"
            phx-click="update_user_tz_auto_detect"
          >
            <.icon name="hero-magnifying-glass-mini" /> Auto-detect
          </button>

          <button type="submit" class="btn btn-accent btn-sm" data-testid="update-user-tz-submit">
            Save
          </button>
        </div>
      </div>
    </.form>
    """
  end
end
