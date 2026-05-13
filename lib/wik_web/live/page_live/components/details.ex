defmodule WikWeb.PageLive.Components.Details do
  @moduledoc """
  Renders a date and time in a human-friendly format.
  """
  use WikWeb, :html
  alias WikWeb.Components

  attr :tenant_context, :map, default: nil
  attr :scope, :map, required: true
  attr :node, :map, required: true
  attr :page, :map, required: true
  attr :open?, :boolean, default: false

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <details class="group" open={@open?}>
      <summary class={[
        "list-none cursor-pointer mr-12",
        "flex items-center gap-1"
      ]}>
        {render_slot(@inner_block)}
        <.icon
          name="hero-chevron-down-micro"
          class={[
            "opacity-20 group-hover:opacity-60 transition-transform duration-200",
            "group-open:-scale-y-100"
          ]}
        />
      </summary>

      <div class={[
        "grid grid-cols-[auto_1fr] gap-x-4 gap-y-2 mt-0",
        "bg-base-200/50 rounded-lg px-6 py-4",
        "text-xs text-base-content/70",
        "items-baseline",
        "w-fit"
      ]}>
        <div class="font-bold">
          Created:
        </div>
        <Components.Time.relative_and_precise datetime={@page.inserted_at} ago? />

        <div class="font-bold">By:</div>
        <div class="flex items-center gap-2">
          <Components.User.avatar
            membership={@tenant_context && @tenant_context[:current_membership]}
            tenant={@scope.tenant}
            size="sm"
            link?
          />
          <span>{@page.author |> to_string()}</span>
        </div>
      </div>
    </details>
    """
  end
end
