defmodule WikWeb.Layouts.Me do
  use WikWeb, :html

  attr :view, :string, default: nil, doc: "the current view for active menu state"
  slot :inner_block, required: true

  def me(assigns) do
    ~H"""
    <div class={[
      "flex flex-wrap items-center justify-between gap-4",
      "px-2 sm:px-4 lg:px-8",
      "mb-8"
    ]}>
      <menu class={[]}>
        <ul class="menu menu-horizontal gap-1">
          <.menu_item view={@view} target="me">Settings</.menu_item>
          <.menu_item view={@view} target="me/access">Access</.menu_item>
          <.menu_item view={@view} target="me/tickets">Tickets</.menu_item>
        </ul>
      </menu>
    </div>

    <WikWeb.Layouts.container>
      {render_slot(@inner_block)}
    </WikWeb.Layouts.container>
    """
  end

  def menu_item(assigns) do
    ~H"""
    <li class={[
      "bg-base-200 rounded",
      @view != @target and "opacity-40"
    ]}>
      <.link :if={assigns[:tenant]} patch={"/#{@tenant.slug}/#{@target}"}>
        {render_slot(@inner_block)}
      </.link>

      <.link :if={assigns[:tenant] == nil} patch={"/#{@target}"}>
        {render_slot(@inner_block)}
      </.link>
    </li>
    """
  end
end
