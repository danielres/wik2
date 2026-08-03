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
  attr :layout, :string, default: "panel"

  slot :title, required: true do
    attr :item, :map
  end

  slot :action do
    attr :item, :map
  end

  slot :append, required: false

  def render(assigns) do
    ~H"""
    <div
      class={[
        @layout == "panel" && "space-y-1",
        @layout == "inline" && "flex flex-wrap gap-x-2 gap-y-2"
      ]}
      data-testid={@list_testid}
    >
      <div :if={@items == []} class="text-sm opacity-50">
        {@empty_text}
      </div>

      <.item
        :for={item <- @items}
        action={@action}
        dimension={@dimension}
        item={item}
        item_id={@item_id}
        layout={@layout}
        level={@level}
        navigate={@navigate}
        testid_prefix={@testid_prefix}
        title={@title}
      />
      {render_slot(@append)}
    </div>
    """
  end

  attr :action, :any, default: []
  attr :dimension, :map, required: true
  attr :item, :any, required: true
  attr :item_id, :any, required: true
  attr :layout, :string, required: true
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
    <div class={[
      @action != [] && "grid grid-cols-[1fr_auto] gap-2 items-center",
      @layout == "inline" && "bg-base-200 badge"
    ]}>
      <.link
        navigate={@path}
        class={[
          "opacity-60 hover:opacity-100 transition-opacity",
          "grid",
          @layout == "panel" && "grid-cols-[4fr_1fr]",
          @layout == "inline" && "grid-cols-[4fr_auto]"
        ]}
        data-testid={"#{@testid_prefix}-#{@resolved_item_id}"}
      >
        <div class="grid grid-cols-[1fr_auto] items-center gap-2">
          {render_slot(@title, @item)}

          <div :if={@layout == "panel"} class="flex items-center gap-2">
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
          width_class={@layout == "inline" && "w-8"}
        />
      </.link>

      <div :if={@action != []}>
        {render_slot(@action, @item)}
      </div>
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
