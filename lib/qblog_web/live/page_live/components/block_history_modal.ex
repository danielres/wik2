defmodule QblogWeb.PageLive.Components.BlockHistoryModal do
  use QblogWeb, :html

  alias QblogWeb.Components
  alias QblogWeb.Components.Block.Types.Markdown
  alias QblogWeb.Components.User

  attr :page_tree, :map, required: true
  attr :placement, :map, required: true
  attr :scope, :map, required: true
  attr :selected_text, :string, required: true
  attr :selected_version_id, :string, default: nil
  attr :versions, :list, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign(
        :selected_index,
        Enum.find_index(assigns.versions, &(&1.id == assigns.selected_version_id)) || 0
      )
      |> assign(
        :selected_version,
        Enum.find(assigns.versions, &(&1.id == assigns.selected_version_id))
      )
      |> assign(:total_versions, length(assigns.versions))
      |> assign(:preview_block, %{id: "history-preview", data: %{"text" => assigns.selected_text}})

    ~H"""
    <Components.Modal.render
      cancel="hide_block_history"
      cancel_testid="block-history-cancel"
      open?={true}
      testid="block-history-dialog"
      full_height?
      bg_class="bg-base-300"
    >
      <div class={["grid h-full grid-rows-[auto_1fr] gap-3"]}>
        <div class={["space-y-3"]}>
          <div class={["flex items-center justify-center gap-1 badge bg-accent/80 badge-lg mx-auto"]}>
            <button
              data-testid="block-history-first"
              type="button"
              class={[
                "btn btn-ghost hover:btn-accent btn-xs btn-circle",
                @selected_index == @total_versions - 1 && "btn-disabled opacity-40"
              ]}
              phx-click="navigate_block_history"
              phx-value-direction="first"
            >
              <.icon name="hero-chevron-double-left-mini" />
            </button>

            <button
              data-testid="block-history-prev"
              type="button"
              class={[
                "btn btn-ghost hover:btn-accent btn-xs btn-circle",
                @selected_index == @total_versions - 1 && "btn-disabled opacity-40"
              ]}
              phx-click="navigate_block_history"
              phx-value-direction="prev"
            >
              <.icon name="hero-chevron-left-mini" />
            </button>

            <div data-testid="block-history-revision" class={["min-w-15 text-center text-sm font-medium"]}>
              <span>v.</span>
              <span class="font-bold text-base-content">
                {@selected_version.revision}/{@total_versions}
              </span>
            </div>

            <button
              data-testid="block-history-next"
              type="button"
              class={[
                "btn btn-ghost hover:btn-accent btn-xs btn-circle",
                @selected_index == 0 && "btn-disabled opacity-40"
              ]}
              phx-click="navigate_block_history"
              phx-value-direction="next"
            >
              <.icon name="hero-chevron-right-mini" />
            </button>

            <button
              data-testid="block-history-last"
              type="button"
              class={[
                "btn btn-ghost hover:btn-accent btn-xs btn-circle",
                @selected_index == 0 && "btn-disabled opacity-40"
              ]}
              phx-click="navigate_block_history"
              phx-value-direction="last"
            >
              <.icon name="hero-chevron-double-right-mini" />
            </button>
          </div>

          <div :if={@selected_version} class={["text-sm"]}>
            <div data-testid="block-history-metadata" class={["flex items-center justify-between gap-2"]}>
              <span data-testid="block-history-author" class={["flex items-center gap-2"]}>
                <User.avatar tenant={@scope.tenant} user={@selected_version.author} size="md" />
                {@selected_version.author |> to_string()}
              </span>

              <span>
                <QblogWeb.Components.Time.relative_and_precise
                  datetime={@selected_version.inserted_at}
                  direction="left"
                  bg_class="bg-base-100"
                  tooltip_variant_class="tooltip-accent"
                />
              </span>
            </div>
          </div>
        </div>

        <div class={["overflow-y-auto pr-1 rounded-box bg-base-100 p-4 "]}>
          <div class={["min-h-40"]}>
            <Markdown.render
              block={@preview_block}
              page_tree={@page_tree}
              scope={@scope}
            />
          </div>
        </div>
      </div>
    </Components.Modal.render>
    """
  end
end
