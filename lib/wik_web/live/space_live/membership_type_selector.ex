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
        <h3 class="text-xl">Change membership type</h3>
        <p class="text-sm opacity-70">
          Update the role for {@membership.user |> to_string()}.
        </p>
      </div>

      <.form for={@form} id="membership-type-form" phx-submit={@event_submit}>
        <fieldset class="space-y-2">
          <legend class="text-sm font-medium opacity-80 mb-2">Available roles</legend>

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
              class="radio radio-sm"
            />

            <span>{type |> Atom.to_string() |> String.capitalize()}</span>
          </label>
        </fieldset>

        <div class="mt-4 flex justify-end">
          <button type="submit" class="btn btn-primary btn-sm">
            Save
          </button>
        </div>
      </.form>
    </div>
    """
  end
end
