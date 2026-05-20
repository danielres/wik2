defmodule WikWeb.Components.Tag do
  use Phoenix.Component
  use WikWeb, :live_view

  alias WikWeb.Components.UI

  attr :action_label, :string, required: true
  attr :class, :string, default: ""
  attr :event_submit, :string, required: true
  attr :event_validate, :string, required: true
  attr :form, :any, required: true

  def form(assigns) do
    auto_slug = assigns.form[:name].value |> Utils.Slugify.generate()
    form_errors = AshPhoenix.Form.errors(assigns.form)
    assigns = assign(assigns, auto_slug: auto_slug, form_errors: form_errors)

    ~H"""
    <div class={[@class]} data-testid="tag-form">
      <Phoenix.Component.form
        autocomplete="off"
        data-testid="tag-form-form"
        for={@form}
        phx-change={@event_validate}
        phx-submit={@event_submit}
      >
        <div class="space-y-3">
          <div>
            <.input field={@form[:name]} label="Name" phx-hook="CapitalizeFirstLetter" />
            <.input hidden field={@form[:slug]} value={@auto_slug} />

            <UI.Forms.autoslug_preview
              source_value={@form[:name].value}
              data-testid={tag_autoslug_testid(@auto_slug)}
            />
          </div>

          <.error :for={{field, _message} <- @form_errors} :if={field == :slug and @auto_slug != ""}>
            This tag name is not available.
          </.error>

          <.input field={@form[:description]} label="Description" type="textarea" />

          <div class="flex justify-end">
            <.button class="btn btn-sm btn-accent" data-testid="tag-form-submit" type="submit">
              {@action_label}
            </.button>
          </div>
        </div>
      </Phoenix.Component.form>
    </div>
    """
  end

  defp tag_autoslug_testid(""), do: "tag-autoslug-empty"
  defp tag_autoslug_testid(auto_slug), do: "tag-autoslug-#{auto_slug}"
end
