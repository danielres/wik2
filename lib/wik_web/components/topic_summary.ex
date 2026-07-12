defmodule WikWeb.Components.TopicSummary do
  use WikWeb, :html

  alias WikWeb.Components.LevelMeter

  attr :current_scope, :map, default: nil
  attr :dimension, :map, required: true
  attr :empty_text, :string, default: "No topics yet"
  attr :list_testid, :string, required: true
  attr :summaries, :list, required: true
  attr :testid_prefix, :string, required: true

  slot :action do
    attr :summary, :map
  end

  def list(assigns) do
    ~H"""
    <div class="space-y-2" data-testid={@list_testid}>
      <div :if={@summaries == []} class="text-sm opacity-50">
        {@empty_text}
      </div>

      <div
        :for={summary <- @summaries}
        class="rounded-box bg-base-200 px-3 py-2"
        data-testid={"#{@testid_prefix}-#{summary.tag.id}"}
      >
        <div class="grid grid-cols-[1fr_auto] items-center gap-2">
          <.link
            :if={@current_scope}
            navigate={~p"/#{@current_scope.tenant.slug}/topics/#{summary.tag.slug}"}
            class="truncate text-sm hover:underline"
          >
            {summary.tag.name}
          </.link>

          <span :if={is_nil(@current_scope)} class="truncate text-sm">
            {summary.tag.name}
          </span>

          <div class="flex items-center gap-2">
            <span
              :if={summary.count > 1}
              class="badge badge-sm bg-base-300"
              data-testid={"#{@testid_prefix}-count-#{summary.tag.id}"}
            >
              {summary.count}
            </span>

            {render_slot(@action, summary)}
          </div>
        </div>

        <LevelMeter.render
          :if={summary.average_relevancy}
          dimension={@dimension}
          label={@dimension.label}
          level={summary.average_relevancy}
          testid={"#{@testid_prefix}-relevancy-#{summary.tag.id}"}
        />
      </div>
    </div>
    """
  end
end
