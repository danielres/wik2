defmodule WikWeb.Layouts.Superadmin do
  use WikWeb, :html

  attr :scope, :map,
    default: %{actor: nil, tenant: nil},
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :view, :string, default: nil, doc: "the current view for active menu state"
  slot :inner_block, required: true

  def superadmin(assigns) do
    ~H"""
    <div class={[
      "flex flex-wrap items-center justify-between gap-4",
      "px-2 sm:px-4 lg:px-8",
      "mb-8"
    ]}>
      <menu class={[]}>
        <ul class="menu menu-horizontal gap-1">
          <li class={["bg-base-200 rounded", @view != "bot" and "opacity-40"]}>
            <.link patch={~p"/_"}>Bot</.link>
          </li>

          <li class={["bg-base-200 rounded", @view != "inbox" and "opacity-40"]}>
            <.link patch={~p"/_/inbox"}>Inbox</.link>
          </li>

          <li class={["bg-base-200 rounded", @view != "errors" and "opacity-40"]}>
            <.link patch={~p"/_/errors"}>Errors</.link>
          </li>
        </ul>
      </menu>
    </div>

    <WikWeb.Layouts.container>
      {render_slot(@inner_block)}
    </WikWeb.Layouts.container>
    """
  end
end
