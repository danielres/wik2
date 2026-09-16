defmodule WikWeb.LibraryLive.Components.TypePermissions do
  use WikWeb, :html

  alias WikWeb.Components.UI

  attr :class, :any, default: nil
  attr :field, Phoenix.HTML.FormField, required: true
  attr :id, :string, required: true
  attr :required, :boolean, default: false

  def render(assigns) do
    ~H"""
    <section
      class={@class}
      data-testid="type-permissions"
      id={@id}
    >
      <UI.panel_title>Permissions</UI.panel_title>

      <p class="mt-1 text-sm text-base-content/80">Who can add entries?</p>

      <fieldset class="mt-4 grid gap-2 sm:grid-cols-2">
        <legend class="sr-only">Who can add entries?</legend>
        <label class={[
          "flex cursor-pointer items-center gap-3 rounded-box border p-3 transition-colors",
          if(to_string(@field.value) == "members",
            do: "border-accent/40 bg-accent/5",
            else: "border-base-content/10 hover:bg-base-200"
          )
        ]}>
          <input
            checked={to_string(@field.value) == "members"}
            class="radio radio-sm radio-accent"
            data-testid="entry-creation-permission-members"
            id={"#{@id}-members"}
            name={@field.name}
            required={@required}
            type="radio"
            value="members"
          />
          <span class="font-medium">Any member</span>
        </label>

        <label class={[
          "flex cursor-pointer items-center gap-3 rounded-box border p-3 transition-colors",
          if(to_string(@field.value) == "admins",
            do: "border-accent/40 bg-accent/5",
            else: "border-base-content/10 hover:bg-base-200"
          )
        ]}>
          <input
            checked={to_string(@field.value) == "admins"}
            class="radio radio-sm radio-accent"
            data-testid="entry-creation-permission-admins"
            id={"#{@id}-admins"}
            name={@field.name}
            type="radio"
            value="admins"
          />
          <span class="font-medium">Owner and admins</span>
        </label>
      </fieldset>
      <.error :for={message <- field_errors(@field)}>{message}</.error>
    </section>
    """
  end
end
