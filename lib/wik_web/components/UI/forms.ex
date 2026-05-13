defmodule WikWeb.Components.UI.Forms do
  use WikWeb, :html

  attr :source_value, :any, required: true
  attr :rest, :global, include: ~w(data-testid)

  def autoslug_preview(assigns) do
    auto_slug = assigns.source_value |> Utils.Slugify.generate()
    assigns = assigns |> assign(auto_slug: auto_slug)

    ~H"""
    <div class={[
      "flex items-baseline",
      "[&_._prepend]:w-2 [&_.alert]:-ml-2"
    ]}>
      <span
        :if={@source_value}
        class={["_prepend", "font-mono opacity-80"]}
      >
        /
      </span>

      <div class={["flex-grow"]}>
        <div
          class={[
            "opacity-80",
            "font-mono",
            "w-full",
            "!bg-transparent"
          ]}
          data-testid={@rest["data-testid"]}
        >
          {@auto_slug}
        </div>
      </div>
    </div>
    """
  end
end
