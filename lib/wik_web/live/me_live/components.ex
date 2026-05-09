defmodule WikWeb.MeLive.Components do
  use WikWeb, :live_view

  alias WikWeb.Components.TimezonePicker

  attr :current_user, :map, required: true
  attr :active_tz, :string, required: true

  def button_tz(assigns) do
    ~H"""
    <button
      class={[
        "badge badge-lg bg-base-200 text-base-content",
        "ml-auto cursor-pointer hover:bg-base-300 transition"
      ]}
      data-testid="me-timezone-button"
      phx-click="update_user_tz_start"
      type="button"
    >
      <span class="tooltip">
        <span class="text-sm">Timezone: {@active_tz}</span>
        <div class="tooltip-content max-w-[12rem] text-xs">
          {if @current_user.tz,
            do: "Saved in your account settings.",
            else: "Auto-detected from your browser settings."}
        </div>
      </span>
    </button>
    """
  end

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
            class="btn btn-ghost btn-sm mr-auto"
            data-testid="update-user-tz-auto-detect"
            phx-click="update_user_tz_auto_detect"
          >
            Auto-detect
          </button>

          <button
            type="button"
            class="btn btn-ghost btn-sm"
            data-testid="update-user-tz-dismiss"
            phx-click="update_user_tz_cancel"
          >
            Close
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
