defmodule WikWeb.Components.DimensionsList do
  use WikWeb, :html

  alias WikWeb.Components.LevelMeter

  attr :dimension, :map, required: true
  attr :empty_text, :string, default: "No items yet"
  attr :item_id, :any, required: true
  attr :items, :list, required: true
  attr :level, :any, required: true
  attr :list_testid, :string, required: true
  attr :navigate, :any, required: true
  attr :testid_prefix, :string, required: true

  slot :title, required: true do
    attr :item, :map
  end

  slot :action do
    attr :item, :map
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-1" data-testid={@list_testid}>
      <div :if={@items == []} class="text-sm opacity-50">
        {@empty_text}
      </div>

      <.item
        :for={item <- @items}
        action={@action}
        dimension={@dimension}
        item={item}
        item_id={@item_id}
        level={@level}
        navigate={@navigate}
        testid_prefix={@testid_prefix}
        title={@title}
      />
    </div>
    """
  end

  attr :action, :any, default: []
  attr :dimension, :map, required: true
  attr :item, :any, required: true
  attr :item_id, :any, required: true
  attr :level, :any, required: true
  attr :navigate, :any, required: true
  attr :testid_prefix, :string, required: true
  attr :title, :any, required: true

  defp item(assigns) do
    assigns =
      assigns
      |> assign(:resolved_item_id, item_id(assigns.item_id, assigns.item))
      |> assign(:resolved_level, level(assigns.level, assigns.item))
      |> assign(:count, count(assigns.item))
      |> assign(:path, navigate(assigns.navigate, assigns.item))

    ~H"""
    <div class="grid grid-cols-[1fr_auto]">
      <.link
        navigate={@path}
        class={[
          "grid grid-cols-[4fr_1fr]",
          "opacity-60 hover:opacity-100 transition-opacity"
        ]}
        data-testid={"#{@testid_prefix}-#{@resolved_item_id}"}
      >
        <div class="grid grid-cols-[1fr_auto] items-center gap-2">
          {render_slot(@title, @item)}

          <div class="flex items-center gap-2">
            <span
              :if={@count && @count > 1}
              class="badge badge-sm bg-base-300"
              data-testid={"#{@testid_prefix}-count-#{@resolved_item_id}"}
            >
              {@count}
            </span>
          </div>
        </div>

        <LevelMeter.render
          :if={@resolved_level}
          dimension={@dimension}
          label={@dimension.label}
          level={@resolved_level}
          testid={"#{@testid_prefix}-relevancy-#{@resolved_item_id}"}
          width_class=""
        />
      </.link>

      <div>{render_slot(@action, @item)}</div>
    </div>
    """
  end

  defp item_id(fun, item) when is_function(fun, 1), do: fun.(item)
  defp item_id(field, item) when is_atom(field), do: Map.fetch!(item, field)

  defp level(fun, item) when is_function(fun, 1), do: fun.(item)
  defp level(field, item) when is_atom(field), do: Map.get(item, field)

  defp navigate(fun, item) when is_function(fun, 1), do: fun.(item)

  defp count(%{count: count}), do: count
  defp count(_item), do: nil
end
