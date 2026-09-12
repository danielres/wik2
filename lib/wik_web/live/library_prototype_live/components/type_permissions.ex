defmodule WikWeb.LibraryPrototypeLive.Components.TypePermissions do
  use WikWeb, :html

  attr :event, :string, default: nil
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :required, :boolean, default: false
  attr :selected, :any, default: nil

  def render(assigns) do
    ~H"""
    <section
      class="rounded-box border border-base-content/10 bg-base-200/35 p-5"
      data-testid="type-permissions"
      id={@id}
    >
      <h2 class="text-lg font-bold">Permissions</h2>
      <p class="mt-1 text-sm text-base-content/50">Who can add entries?</p>

      <fieldset class="mt-4 grid gap-2 sm:grid-cols-2">
        <legend class="sr-only">Who can add entries?</legend>
        <label class={[
          "flex cursor-pointer items-center gap-3 rounded-box border p-3 transition-colors",
          if(to_string(@selected) == "members",
            do: "border-accent/40 bg-accent/5",
            else: "border-base-content/10 hover:bg-base-200"
          )
        ]}>
          <input
            checked={to_string(@selected) == "members"}
            class="radio radio-sm radio-accent"
            data-testid="entry-creation-permission-members"
            id={"#{@id}-members"}
            name={@name}
            phx-click={@event}
            phx-value-permission="members"
            required={@required}
            type="radio"
            value="members"
          />
          <span class="font-medium">Any member</span>
        </label>

        <label class={[
          "flex cursor-pointer items-center gap-3 rounded-box border p-3 transition-colors",
          if(to_string(@selected) == "admins",
            do: "border-accent/40 bg-accent/5",
            else: "border-base-content/10 hover:bg-base-200"
          )
        ]}>
          <input
            checked={to_string(@selected) == "admins"}
            class="radio radio-sm radio-accent"
            data-testid="entry-creation-permission-admins"
            id={"#{@id}-admins"}
            name={@name}
            phx-click={@event}
            phx-value-permission="admins"
            type="radio"
            value="admins"
          />
          <span class="font-medium">Owner and admins</span>
        </label>
      </fieldset>
    </section>
    """
  end
end
