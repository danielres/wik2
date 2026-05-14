defmodule WikWeb.Components.Group do
  use Phoenix.Component
  use WikWeb, :live_view

  alias WikWeb.Components.UI

  attr :action_type, :string, default: "create"
  attr :class, :string, default: ""
  attr :event_submit, :string, required: true
  attr :event_validate, :string, required: true
  attr :form, :any, required: true

  def form(assigns) do
    auto_slug = assigns.form[:name].value |> Utils.Slugify.generate()

    assigns =
      assigns
      |> assign(:auto_slug, auto_slug)
      |> assign(:form_errors, assigns.form.errors)

    ~H"""
    <div class={[@class]}>
      <Phoenix.Component.form
        autocomplete="off"
        for={@form}
        phx-change={@event_validate}
        phx-submit={@event_submit}
      >
        <.input field={@form[:name]} label="Name" phx-hook="CapitalizeFirstLetter" />

        <.input hidden field={@form[:slug]} value={@auto_slug} />

        <UI.Forms.autoslug_preview
          source_value={@form[:name].value}
          data-testid="group-name-autoslug"
        />

        <.error :for={{field, _message} <- @form_errors} :if={field == :slug and @auto_slug != ""}>
          This group name is not available.
        </.error>

        <.input field={@form[:description]} label="Description" type="textarea" />

        <.button type="submit" class="btn btn-accent btn-soft mt-3">
          {@action_type |> String.capitalize()} group
        </.button>
      </Phoenix.Component.form>
    </div>
    """
  end

  attr :groups, :list, required: true

  def list(assigns) do
    ~H"""
    <ul class="menu w-full">
      <li>
        <.link
          :for={group <- @groups}
          class="justify-between"
          navigate={~p"/#{group.slug}/wiki"}
        >
          {group.name}
          <span class="font-thin">{group.author |> to_string}</span>
        </.link>

        <span :if={@groups == []} class="opacity-70">
          You are not a member of any groups yet.
        </span>
      </li>
    </ul>
    """
  end
end
