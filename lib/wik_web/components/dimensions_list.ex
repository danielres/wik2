defmodule WikWeb.Components.DimensionsList do
  use WikWeb, :html

  alias WikWeb.Components.LevelMeter

  attr :dimension, :map, required: true
  attr :empty_text, :string, default: "No items yet"
  attr :item_id, :any, required: true
  attr :items, :list, required: true
  attr :level, :any, required: true
  attr :list_testid, :string, required: true
  attr :navigate, :any, default: nil
  attr :testid_prefix, :string, required: true

  slot :title, required: true do
    attr :item, :map
  end

  slot :action do
    attr :item, :map
  end

  def render(assigns) do
    ~H"""
    <div class="space-y-2" data-testid={@list_testid}>
      <div :if={@items == []} class="text-sm opacity-50">
        {@empty_text}
      </div>

      <%= for item <- @items do %>
        <% item_id = item_id(@item_id, item) %>
        <% item_level = level(@level, item) %>
        <% item_count = count(item) %>
        <% item_path = navigate(@navigate, item) %>

        <.link
          :if={item_path}
          navigate={item_path}
          class={[
            "block rounded-box bg-base-200 px-3 py-2",
            "opacity-80 hover:opacity-100 transition-opacity"
          ]}
          data-testid={"#{@testid_prefix}-#{item_id}"}
        >
          <.content
            action={@action}
            count={item_count}
            dimension={@dimension}
            item={item}
            item_id={item_id}
            level={item_level}
            testid_prefix={@testid_prefix}
            title={@title}
          />
        </.link>

        <div
          :if={is_nil(item_path)}
          class="rounded-box bg-base-200 px-3 py-2"
          data-testid={"#{@testid_prefix}-#{item_id}"}
        >
          <.content
            action={@action}
            count={item_count}
            dimension={@dimension}
            item={item}
            item_id={item_id}
            level={item_level}
            testid_prefix={@testid_prefix}
            title={@title}
          />
        </div>
      <% end %>
    </div>
    """
  end

  attr :action, :any, required: true
  attr :count, :integer, default: nil
  attr :dimension, :map, required: true
  attr :item, :any, required: true
  attr :item_id, :string, required: true
  attr :level, :integer, default: nil
  attr :testid_prefix, :string, required: true
  attr :title, :any, required: true

  defp content(assigns) do
    ~H"""
    <div class="grid grid-cols-[1fr_auto] items-center gap-2">
      {render_slot(@title, @item)}

      <div class="flex items-center gap-2">
        <span
          :if={@count && @count > 1}
          class="badge badge-sm bg-base-300"
          data-testid={"#{@testid_prefix}-count-#{@item_id}"}
        >
          {@count}
        </span>

        {render_slot(@action, @item)}
      </div>
    </div>

    <LevelMeter.render
      :if={@level}
      dimension={@dimension}
      label={@dimension.label}
      level={@level}
      testid={"#{@testid_prefix}-relevancy-#{@item_id}"}
    />
    """
  end

  defp item_id(fun, item) when is_function(fun, 1), do: fun.(item)
  defp item_id(field, item) when is_atom(field), do: Map.fetch!(item, field)

  defp level(fun, item) when is_function(fun, 1), do: fun.(item)
  defp level(field, item) when is_atom(field), do: Map.get(item, field)

  defp navigate(nil, _item), do: nil
  defp navigate(fun, item) when is_function(fun, 1), do: fun.(item)

  defp count(%{count: count}), do: count
  defp count(_item), do: nil
end
