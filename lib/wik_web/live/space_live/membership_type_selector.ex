defmodule WikWeb.SpaceLive.MembershipTypeSelector do
  use WikWeb, :html

  attr :event_submit, :string, required: true
  attr :form, :any, required: true
  attr :membership, :map, required: true
  attr :type_options, :list, required: true

  def render(assigns) do
    ~H"""
    <div class="space-y-4">
      <div class="space-y-1">
        <p class="">
          <span class="label font-bold">Update the role for</span>

          <WikWeb.Components.User.identity
            membership={@membership}
            avatar_size="sm"
            class="gap-2 font-bold text-base-content inline-flex align-middle"
          />
        </p>
      </div>

      <.form for={@form} id="membership-type-form" phx-submit={@event_submit}>
        <fieldset class="space-y-2">
          <legend class="label font-bold">Available roles</legend>

          <label
            :for={type <- @type_options}
            class={[
              "flex items-center gap-3",
              "rounded-box border border-base-300 bg-base-200/60",
              "px-3 py-2",
              "cursor-pointer hover:bg-base-200 transition-colors"
            ]}
          >
            <input
              type="radio"
              name={@form[:type].name}
              value={type}
              checked={to_string(@form[:type].value) == Atom.to_string(type)}
              class="radio radio-xs"
            />

            <span class="text-sm">{type |> Atom.to_string() |> String.capitalize()}</span>
            <span :if={@membership.type == type} class="badge badge-sm bg-base-300 text-xs opacity-80">
              Current
            </span>
          </label>
        </fieldset>

        <div class="mt-4 flex justify-end">
          <button type="submit" class="btn btn-accent btn-sm">
            Update membership type
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
