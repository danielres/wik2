defmodule WikWeb.LibraryPrototypeLive.Components.TopicMatching do
  use WikWeb, :html

  alias WikWeb.Components.UI

  attr :automatic_topic_matching?, :boolean, required: true
  attr :expanded_topic_id, :string, default: nil
  attr :space_slug, :string, required: true
  attr :topic_views, :list, required: true

  def render(assigns) do
    ~H"""
    <div class="space-y-4" data-testid="topic-matching-page">
      <div class="flex items-center justify-between gap-3">
        <UI.page_title icon="hero-sparkles-micro">
          Smart topics
        </UI.page_title>

        <button
          aria-checked={to_string(@automatic_topic_matching?)}
          class={[
            "btn btn-xs rounded-full",
            @automatic_topic_matching? && "btn-primary",
            !@automatic_topic_matching? && "btn-ghost bg-base-200"
          ]}
          data-testid="topic-matching-toggle"
          phx-click="matching:toggle"
          role="switch"
          type="button"
        >
          {if(@automatic_topic_matching?, do: "On", else: "Off")}
        </button>
      </div>

      <div
        :if={@topic_views == []}
        class="rounded-box bg-base-200/55 px-4 py-6 text-center text-sm"
        data-testid="topic-matching-empty"
      >
        <.link class="link link-primary" navigate={~p"/#{@space_slug}/topics"}>Create a topic</.link>
      </div>

      <div class="divide-y divide-base-content/10 rounded-box bg-base-200/40 px-4">
        <div :for={view <- @topic_views} data-testid={"topic-matching-rule-#{view.topic.slug}"}>
          <div class="flex items-center gap-2 py-3">
            <button
              aria-expanded={to_string(@expanded_topic_id == view.topic.id)}
              class="flex min-w-0 flex-1 items-center gap-2 text-left"
              data-testid={"topic-matching-expand-#{view.topic.slug}"}
              phx-click="matching:expand"
              phx-value-topic_id={view.topic.id}
              type="button"
            >
              <.icon
                name={
                  if(@expanded_topic_id == view.topic.id,
                    do: "hero-chevron-down-micro",
                    else: "hero-chevron-right-micro"
                  )
                }
                class="size-3 opacity-40"
              />
              <span class="truncate text-sm font-medium">{view.topic.name}</span>
              <span class="badge badge-xs badge-ghost">{view.count}</span>
            </button>
            <button
              aria-checked={to_string(view.rule.enabled?)}
              class={[
                "btn btn-xs rounded-full",
                view.rule.enabled? && "btn-primary btn-soft",
                !view.rule.enabled? && "btn-ghost opacity-60"
              ]}
              data-testid={"topic-matching-rule-toggle-#{view.topic.slug}"}
              phx-click="matching:rule:toggle"
              phx-value-topic_id={view.topic.id}
              role="switch"
              type="button"
            >
              {if(view.rule.enabled?, do: "Enabled", else: "Disabled")}
            </button>
          </div>

          <div :if={@expanded_topic_id == view.topic.id} class="space-y-3 pb-4 pl-5">
            <div :if={view.rule.aliases != []} class="flex flex-wrap gap-1.5">
              <button
                :for={alias_value <- view.rule.aliases}
                class="badge badge-sm gap-1"
                data-testid={"topic-matching-alias-#{view.topic.slug}"}
                phx-click="matching:alias:remove"
                phx-value-alias={alias_value}
                phx-value-topic_id={view.topic.id}
                type="button"
              >
                {alias_value} <.icon name="hero-x-mark-micro" class="size-3" />
              </button>
            </div>
            <.form
              class="flex gap-2"
              data-testid={"topic-matching-alias-form-#{view.topic.slug}"}
              for={to_form(%{"value" => ""}, as: :topic_alias)}
              id={"topic-matching-alias-form-#{view.topic.id}"}
              phx-submit="matching:alias:add"
            >
              <input name="topic_id" type="hidden" value={view.topic.id} />
              <.input
                aria-label="Alias"
                class="input input-sm flex-1"
                field={to_form(%{"value" => ""}, as: :topic_alias)[:value]}
                placeholder="Alias"
              />
              <button class="btn btn-sm btn-ghost" type="submit">Add</button>
            </.form>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
