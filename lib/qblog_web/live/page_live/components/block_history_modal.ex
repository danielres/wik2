defmodule QblogWeb.PageLive.Components.BlockHistoryModal do
  use QblogWeb, :html

  alias QblogWeb.Components
  alias QblogWeb.Components.Block.Types.Markdown
  alias QblogWeb.Components.User

  attr :page_tree, :map, required: true
  attr :nav_target, :any, default: nil
  attr :placement, :map, required: true
  attr :scope, :map, required: true
  attr :selected_text, :string, required: true
  attr :selected_version, :map, required: true
  attr :total_versions, :integer, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign(:preview_block, %{id: "history-preview", data: %{"text" => assigns.selected_text}})

    ~H"""
    <Components.Modal.render
      cancel="hide_block_history"
      cancel_testid="block-history-cancel"
      open?={true}
      testid="block-history-dialog"
      full_height?
      bg_class="bg-base-100"
    >
      <:title>
        <div>
          <div class={["grid grid-cols-[1fr_auto_1fr] items-center"]}>
            <div
              data-testid="block-history-author"
              class={[
                "justify-self-start",
                "min-w-0",
                "flex items-center gap-2"
              ]}
            >
              <User.avatar tenant={@scope.tenant} user={@selected_version.author} size="md" />
              <span data-testid="block-history-author-name" class="truncate">
                {@selected_version.author |> to_string()}
              </span>
            </div>

            <div class={[
              "justify-self-center",
              "py-1 px-2 rounded-full bg-accent/80 text-accent-content",
              "flex items-center"
            ]}>
              <button
                data-testid="block-history-first"
                type="button"
                class={[
                  "btn btn-ghost hover:btn-accent btn-xs btn-circle",
                  @selected_version.revision == 1 && "btn-disabled opacity-40"
                ]}
                phx-click="navigate"
                phx-target={@nav_target}
                phx-value-direction="first"
              >
                <.icon name="hero-chevron-double-left-mini" />
              </button>

              <button
                data-testid="block-history-prev"
                type="button"
                class={[
                  "btn btn-ghost hover:btn-accent btn-xs btn-circle",
                  @selected_version.revision == 1 && "btn-disabled opacity-40"
                ]}
                phx-click="navigate"
                phx-target={@nav_target}
                phx-value-direction="prev"
              >
                <.icon name="hero-chevron-left-mini" />
              </button>

              <div
                data-testid="block-history-revision"
                class={["min-w-15 text-center text-sm font-medium"]}
              >
                <span>v.</span>
                <span class="font-bold">
                  {@selected_version.revision}/{@total_versions}
                </span>
              </div>

              <button
                data-testid="block-history-next"
                type="button"
                class={[
                  "btn btn-ghost hover:btn-accent btn-xs btn-circle",
                  @selected_version.revision == @total_versions && "btn-disabled opacity-40"
                ]}
                phx-click="navigate"
                phx-target={@nav_target}
                phx-value-direction="next"
              >
                <.icon name="hero-chevron-right-mini" />
              </button>

              <button
                data-testid="block-history-last"
                type="button"
                class={[
                  "btn btn-ghost hover:btn-accent btn-xs btn-circle",
                  @selected_version.revision == @total_versions && "btn-disabled opacity-40"
                ]}
                phx-click="navigate"
                phx-target={@nav_target}
                phx-value-direction="last"
              >
                <.icon name="hero-chevron-double-right-mini" />
              </button>
            </div>

            <span
              data-testid="block-history-timestamp"
              class={[
                "justify-self-end"
              ]}
            >
              <QblogWeb.Components.Time.relative_and_precise
                datetime={@selected_version.inserted_at}
                direction="left"
                bg_class="bg-base-300"
              />
            </span>
          </div>
        </div>

        <hr class="mt-4 border-base-content/20" />
      </:title>

      <div class={["rounded-box bg-base-100 p-4"]}>
        <div class={["min-h-40"]}>
          <Markdown.render
            block={@preview_block}
            page_tree={@page_tree}
            scope={@scope}
          />
        </div>
      </div>
    </Components.Modal.render>
    """
  end
end
