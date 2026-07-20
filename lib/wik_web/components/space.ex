defmodule WikWeb.Components.Space do
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
        class="space-y-8"
      >
        <div>
          <.input field={@form[:name]} label="Name" phx-hook="CapitalizeFirstLetter" />

          <.input hidden field={@form[:slug]} value={@auto_slug} />

          <UI.Forms.autoslug_preview
            source_value={@form[:name].value}
            data-testid="space-name-autoslug"
          />

          <.error :for={{field, _message} <- @form_errors} :if={field == :slug and @auto_slug != ""}>
            This space name is not available.
          </.error>
        </div>

        <.input field={@form[:description]} label="Description" type="textarea" />

        <div class="flex">
          <.button type="submit" class="btn btn-accent btn-soft mt-3 ml-auto">
            {@action_type |> String.capitalize()} space
          </.button>
        </div>
      </Phoenix.Component.form>
    </div>
    """
  end
end
