defmodule WikWeb.LibraryPrototypeLive.Components.TypePicker do
  use WikWeb, :html

  attr :types, :list, required: true

  def render(assigns) do
    ~H"""
    <div class="autogrid [--autogrid-min:8rem] gap-2" data-testid="entry-type-picker">
      <button
        :for={type <- @types}
        class={[
          "group rounded-box",
          "px-2 py-4",
          "bg-base-300",
          "opacity-60 hover:opacity-100 transition",
          "cursor-pointer",
          "text-sm",
          "truncate"
        ]}
        data-testid={"entry-type-select-#{type.slug}"}
        phx-click="entry:type"
        phx-value-type_id={type.id}
        type="button"
      >
        <span class="font-semibold small-caps">{type.name}</span>
      </button>
    </div>
    """
  end
end
