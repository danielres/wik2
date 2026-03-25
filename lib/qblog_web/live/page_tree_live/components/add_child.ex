defmodule QblogWeb.PageTreeLive.Components.AddChild do
  import QblogWeb.CoreComponents
  use Phoenix.Component

  attr :form, :any, required: true
  attr :parent_id, :map, default: nil
  attr :target, :any, required: true

  def dialog(assigns) do
    auto_slug = assigns.form[:title].value |> Utils.Slugify.generate()

    assigns =
      assigns
      |> assign(auto_slug: auto_slug)
      |> assign(form_errors: AshPhoenix.Form.errors(assigns.form))

    ~H"""
    <.form
      autocomplete="off"
      for={@form}
      phx-change="validate_child"
      phx-submit="add_child"
      phx-target={@target}
    >
      <div class="card bg-base-100">
        <div class="card-body [&_input]:bg-base-200">
          <.input
            field={@form[:parent_id]}
            type="hidden"
            value={@parent_id}
          />

          <.input field={@form[:title]} label="title" />

          <div class={[
            "flex items-baseline",
            "[&_._prepend]:w-2 [&_.alert]:-ml-2"
          ]}>
            <span
              :if={@form[:title].value}
              class={[
                "_prepend",
                "font-mono opacity-80"
              ]}
            >
              /
            </span>

            <.input hidden field={@form[:slug]} value={@auto_slug} />

            <div class={["flex-grow"]}>
              <div class={[
                "opacity-80",
                "font-mono",
                "w-full",
                "!bg-transparent"
              ]}>
                {@auto_slug}
              </div>
            </div>
          </div>

          <.error :for={{:nodes, msg} <- @form_errors}>{msg}</.error>

          <.button
            class="btn btn-primary"
            type="submit"
          >
            Add
          </.button>
        </div>
      </div>
    </.form>
    """
  end
end
