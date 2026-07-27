defmodule WikWeb.PageLive.Components.Area do
  use WikWeb, :html

  alias WikWeb.Components

  def resolve_area(nil), do: :main
  def resolve_area(other), do: other

  def has_area?(page, area), do: Enum.any?(page.block_placements, &(&1.area == area))

  attr :area, :atom, required: true
  attr :class, :any, default: ""
  attr :editing?, :boolean, required: true
  attr :editing_block_id, :string, required: true
  attr :form_edit_block, :any, required: true
  attr :locks, :map, required: true
  attr :node, :map, required: true
  attr :page, :map, required: true
  attr :page_tree, :map, required: true
  attr :path, :string, required: true
  attr :scope, :map, required: true

  def render(assigns) do
    ~H"""
    <div class={[
      "flex flex-col gap-1",
      @class
    ]}>
      <div
        :for={placement <- @page.block_placements}
        :if={resolve_area(placement.area) == @area}
        :key={placement.id}
        class={[
          "w-full",
          "pb-4 last:pb-0"
        ]}
        id={"block-#{placement.block.id}"}
      >
        <div class="card-body py-0.5 px-0 ">
          <%= if @editing_block_id == placement.block.id do %>
            <Components.Block.form
              placement={placement}
              form={@form_edit_block}
              node={@node}
              page_tree={@page_tree}
              path={@path}
              scope={@scope}
              actions?={false}
            />
          <% else %>
            <Components.Block.render
              editing_block_id={@editing_block_id}
              editing?={@editing?}
              lock={@locks[placement.block.id]}
              placement={placement}
              node={@node}
              page_tree={@page_tree}
              path={@path}
              scope={@scope}
            />
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end
