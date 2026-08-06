defmodule WikWeb.PageLive.Components.PageTopics do
  use WikWeb, :html

  alias Wik.Tags.Dimensions
  alias Wik.Tags.TopicSummaries
  alias WikWeb.Components.DimensionsList
  alias WikWeb.Components.LevelMeter
  alias WikWeb.Components.RangeInput
  alias WikWeb.Components.UI
  alias WikWeb.Components.User

  attr :can_manage_page?, :boolean, required: true
  attr :current_scope, :map, required: true
  attr :editing?, :boolean, required: true
  attr :page_topic_edit_form, :any, default: nil
  attr :page_topic_edit_tagging_id, :string, default: nil
  attr :page_topic_form, :any, default: nil
  attr :page_topic_options, :list, required: true
  attr :page_topic_summaries, :list, required: true
  attr :layout, :string, default: "panel"

  def render(%{layout: "inline"} = assigns) do
    assigns =
      assign(
        assigns,
        :topic_edit_context,
        topic_edit_context(assigns.page_topic_summaries, assigns.page_topic_edit_tagging_id)
      )

    ~H"""
    <% relevancy_dimension = Dimensions.get!("page", "relevancy") %>

    <DimensionsList.render
      dimension={relevancy_dimension}
      empty_text=""
      item_id={& &1.tag.id}
      items={@page_topic_summaries}
      layout="inline"
      level={& &1.average_relevancy}
      list_testid="page-topic-list"
      navigate={&~p"/#{@current_scope.tenant.slug}/topics/#{&1.tag.slug}"}
      testid_prefix="page-topic"
    >
      <:title :let={summary}>
        <div class="truncate text-sm">{summary.tag.name}</div>
      </:title>
    </DimensionsList.render>

    <UI.modal id="page-topic-inline-modal" open?={@page_topic_form != nil}>
      <.topic_modal_index
        :if={is_nil(@topic_edit_context)}
        cancel_button_id="page-topic-inline-cancel"
        editing?={@editing?}
        form_id="page-topic-inline-form"
        modal_id="page-topic-inline-modal"
        page_topic_form={@page_topic_form}
        page_topic_options={@page_topic_options}
        page_topic_summaries={@page_topic_summaries}
        relevancy_dimension={relevancy_dimension}
        submit_button_id="page-topic-inline-submit"
      />

      <.topic_edit_preview
        :if={@topic_edit_context}
        context={@topic_edit_context}
        form={@page_topic_edit_form}
        id_prefix="page-topic-inline"
        relevancy_dimension={relevancy_dimension}
      />
    </UI.modal>
    """
  end

  def render(%{layout: "panel"} = assigns) do
    assigns =
      assign(
        assigns,
        :topic_edit_context,
        topic_edit_context(assigns.page_topic_summaries, assigns.page_topic_edit_tagging_id)
      )

    ~H"""
    <% relevancy_dimension = Dimensions.get!("page", "relevancy") %>

    <div class="mb-2 flex items-center justify-between gap-2">
      <UI.panel_title class="mb-0">
        <.icon name="hero-tag-micro" class="opacity-70 size-4" /> Topics
      </UI.panel_title>

      <UI.button_add
        :if={@can_manage_page? and @page_topic_options != []}
        data-testid="page-topic-add"
        data-tip="Add topic"
        phx-click={JS.push("page_topic:add_start") |> UI.modal_open("page-topic-panel-modal")}
      />
    </div>

    <DimensionsList.render
      dimension={relevancy_dimension}
      empty_text="No topics yet"
      item_id={& &1.tag.id}
      items={@page_topic_summaries}
      level={& &1.average_relevancy}
      list_testid="page-topic-list"
      navigate={&~p"/#{@current_scope.tenant.slug}/topics/#{&1.tag.slug}"}
      testid_prefix="page-topic"
    >
      <:title :let={summary}>
        <div class="truncate text-sm">{summary.tag.name}</div>
      </:title>

      <:action :let={summary} :if={@editing?}>
        <button
          :if={@editing? and summary.current_member_tagging}
          type="button"
          class={[
            "btn btn-xs btn-circle text-error btn-ghost",
            "opacity-80 hover:opacity-100 transition-opacity"
          ]}
          data-testid={"page-topic-remove-#{summary.tag.id}"}
          phx-click="page_topic:remove"
          phx-value-tag_id={summary.tag.id}
        >
          <span class="sr-only">Remove topic</span>
          <.icon name="hero-x-mark" class="size-3" />
        </button>
      </:action>
    </DimensionsList.render>

    <UI.modal id="page-topic-panel-modal" open?={@page_topic_form != nil}>
      <.topic_modal_index
        :if={is_nil(@topic_edit_context)}
        cancel_button_id="page-topic-panel-cancel"
        editing?={@editing?}
        form_id="page-topic-panel-form"
        modal_id="page-topic-panel-modal"
        page_topic_form={@page_topic_form}
        page_topic_options={@page_topic_options}
        page_topic_summaries={@page_topic_summaries}
        relevancy_dimension={relevancy_dimension}
        submit_button_id="page-topic-panel-submit"
      />

      <.topic_edit_preview
        :if={@topic_edit_context}
        context={@topic_edit_context}
        form={@page_topic_edit_form}
        id_prefix="page-topic-panel"
        relevancy_dimension={relevancy_dimension}
      />
    </UI.modal>
    """
  end

  attr :cancel_button_id, :string, required: true
  attr :editing?, :boolean, required: true
  attr :form_id, :string, required: true
  attr :modal_id, :string, required: true
  attr :page_topic_form, :any, required: true
  attr :page_topic_options, :list, required: true
  attr :page_topic_summaries, :list, required: true
  attr :relevancy_dimension, :map, required: true
  attr :submit_button_id, :string, required: true

  defp topic_modal_index(assigns) do
    ~H"""
    <div class="space-y-12" data-testid="page-topic-modal-index">
      <section>
        <UI.panel_title>Page topics</UI.panel_title>
        <div
          id={"#{@modal_id}-topics"}
          class=""
          data-testid="page-topic-modal-list"
        >
          <div :if={@page_topic_summaries == []} class="p-4 text-center text-sm opacity-50">
            No topics yet
          </div>

          <%= for summary <- @page_topic_summaries do %>
            <% tagging = List.first(summary.taggings) %>

            <div
              :if={summary.count == 1}
              id={"#{@modal_id}-topic-#{summary.tag.id}"}
              class="pl-4 pr-8 py-1 mb-1 bg-base-300/50 rounded-xl"
              data-testid={"page-topic-modal-topic-#{summary.tag.id}"}
            >
              <div class="grid grid-cols-[minmax(0,1fr)_auto] items-center gap-x-2 px-2 py-1 text-sm">
                <span class="truncate">{summary.tag.name}</span>
                <UI.editable_zone
                  editing?={@editing? and summary.current_member_tagging != nil}
                  data-testid={"page-topic-modal-edit-#{tagging.id}"}
                  phx-click="page_topic:edit_start"
                  phx-value-tagging_id={tagging.id}
                  title={"Edit your #{summary.tag.name} contribution"}
                >
                  <div class="grid grid-cols-[auto_auto] gap-2 mx-2 my-1">
                    <User.avatar
                      membership={tagging.tagged_by_membership}
                      size="xs"
                      tooltip?
                      tooltip_direction="top"
                    />
                    <LevelMeter.render
                      dimension={@relevancy_dimension}
                      label={@relevancy_dimension.label}
                      level={summary.average_relevancy || 0}
                      testid={"page-topic-modal-average-#{summary.tag.id}"}
                      width_class="w-14"
                    />
                  </div>
                </UI.editable_zone>
              </div>
            </div>

            <div
              :if={summary.count > 1}
              id={"#{@modal_id}-topic-#{summary.tag.id}"}
              class={[
                "pl-4 pt-1 mb-1 bg-base-300/50 rounded-xl",
                "collapse-arrow join-item collapse"
              ]}
              data-testid={"page-topic-modal-topic-#{summary.tag.id}"}
            >
              <input
                aria-label={"Toggle voter details for #{summary.tag.name}"}
                id={"#{@modal_id}-topic-toggle-#{summary.tag.id}"}
                type="checkbox"
              />

              <div class={[
                "collapse-title grid grid-cols-[minmax(0,1fr)_auto_auto] items-center gap-x-2 py-1 pl-2",
                "text-sm hover:bg-base-200/70 transition-colors",
                "cursor-pointer"
              ]}>
                <span class="truncate">{summary.tag.name}</span>

                <span data-testid={"page-topic-modal-voters-#{summary.tag.id}"}>
                  <UI.icon_user_with_count count={summary.taggings |> length()} />
                </span>

                <LevelMeter.render
                  dimension={@relevancy_dimension}
                  label={@relevancy_dimension.label}
                  level={summary.average_relevancy || 0}
                  testid={"page-topic-modal-average-#{summary.tag.id}"}
                  width_class="w-14"
                />
              </div>

              <div
                class="collapse-content pr-10 flex justify-end items-center gap-2"
                data-testid={"page-topic-modal-details-#{summary.tag.id}"}
              >
                <div :for={summary_tagging <- summary.taggings}>
                  <div
                    :if={
                      summary.current_member_tagging &&
                        summary_tagging.id == summary.current_member_tagging.id
                    }
                    class=""
                    data-testid={"page-topic-modal-contribution-#{summary_tagging.id}"}
                  >
                    <UI.editable_zone
                      editing?={@editing?}
                      data-testid={"page-topic-modal-edit-#{summary_tagging.id}"}
                      phx-click="page_topic:edit_start"
                      phx-value-tagging_id={summary_tagging.id}
                      title={"Edit your #{summary.tag.name} contribution"}
                    >
                      <div class="mx-2 my-1">
                        <.topic_contribution
                          dimension={@relevancy_dimension}
                          tagging={summary_tagging}
                        />
                      </div>
                    </UI.editable_zone>
                  </div>

                  <div
                    :if={
                      is_nil(summary.current_member_tagging) ||
                        summary_tagging.id != summary.current_member_tagging.id
                    }
                    class="flex items-center justify-end gap-2 rounded p-2"
                    data-testid={"page-topic-modal-contribution-#{summary_tagging.id}"}
                  >
                    <.topic_contribution
                      dimension={@relevancy_dimension}
                      tagging={summary_tagging}
                    />
                  </div>
                </div>
              </div>
            </div>
          <% end %>
        </div>
      </section>

      <section>
        <UI.panel_title>Add topic</UI.panel_title>

        <.form
          :if={@page_topic_form && @page_topic_options != []}
          for={@page_topic_form}
          id={@form_id}
          class="space-y-4 bg-base-300/50 p-4 rounded-xl"
          data-testid="page-topic-form"
          phx-change="page_topic:validate"
          phx-submit={JS.push("page_topic:submit") |> UI.modal_close(@modal_id)}
        >
          <.input
            field={@page_topic_form[:tag_id]}
            options={Enum.map(@page_topic_options, &{&1.name, &1.id})}
            prompt="Select a topic"
            type="select"
          />

          <RangeInput.render
            dimension={@relevancy_dimension}
            field={@page_topic_form[:relevancy_level]}
            label={@relevancy_dimension.label}
            max_level={@relevancy_dimension.max}
          />

          <div class="flex justify-between gap-2">
            <button
              id={@cancel_button_id}
              class="btn btn-soft btn-sm"
              data-testid="page-topic-cancel"
              phx-click={JS.push("page_topic:add_cancel") |> UI.modal_close(@modal_id)}
              type="button"
            >
              Cancel
            </button>
            <.button
              class="btn btn-accent btn-soft btn-sm"
              data-testid="page-topic-submit"
              id={@submit_button_id}
            >
              Save
            </.button>
          </div>
        </.form>

        <div
          :if={@page_topic_form && @page_topic_options == []}
          class="flex items-center justify-center gap-2 border-t border-base-300 pt-4 text-sm opacity-50"
        >
          <.icon name="hero-check-micro" class="size-4" />
          <span>All topics added</span>
        </div>
      </section>
    </div>
    """
  end

  attr :dimension, :map, required: true
  attr :tagging, :map, required: true

  defp topic_contribution(assigns) do
    ~H"""
    <div class="flex items-center gap-2">
      <User.identity
        avatar_size="xs"
        class="min-w-0 gap-2 text-sm"
        membership={@tagging.tagged_by_membership}
        name?={false}
      />
      <LevelMeter.render
        dimension={@dimension}
        label={@dimension.label}
        level={TopicSummaries.dimension_level(@tagging, "relevancy") || 0}
        testid={"page-topic-modal-contribution-level-#{@tagging.id}"}
        width_class="w-14"
      />
    </div>
    """
  end

  attr :context, :map, required: true
  attr :form, :any, required: true
  attr :id_prefix, :string, required: true
  attr :relevancy_dimension, :map, required: true

  defp topic_edit_preview(assigns) do
    ~H"""
    <.form
      for={@form}
      id={"#{@id_prefix}-edit-form"}
      class="space-y-6"
      data-testid="page-topic-edit-preview"
      phx-change="page_topic:edit_validate"
      phx-submit="page_topic:edit_submit"
    >
      <div class="flex items-center gap-3 pr-6">
        <button
          id={"#{@id_prefix}-edit-back"}
          type="button"
          class="btn btn-ghost btn-sm btn-square"
          aria-label="Back to topics"
          phx-click="page_topic:edit_cancel"
          title="Back to topics"
        >
          <.icon name="hero-arrow-left-micro" class="size-4" />
        </button>
        <UI.modal_title class="min-w-0 truncate">{@context.summary.tag.name}</UI.modal_title>
      </div>

      <div class="space-y-5 rounded border border-base-300 p-4">
        <User.identity
          avatar_size="sm"
          class="gap-2 text-sm"
          membership={@context.tagging.tagged_by_membership}
        />

        <div class="grid grid-cols-[2.75rem_minmax(0,1fr)] items-center gap-3">
          <span class="font-mono text-sm">
            {@form[:relevancy_level].value}/{@relevancy_dimension.max}
          </span>
          <input
            id={"#{@id_prefix}-edit-relevancy"}
            name={@form[:relevancy_level].name}
            type="range"
            min="1"
            max={@relevancy_dimension.max}
            value={@form[:relevancy_level].value}
            class="range range-xs w-full"
            style={"color: #{@relevancy_dimension.color};"}
          />
        </div>
      </div>

      <div class="flex justify-end gap-2">
        <button
          id={"#{@id_prefix}-edit-remove"}
          type="button"
          class="btn btn-ghost btn-sm btn-square text-error"
          aria-label="Remove topic contribution"
          phx-click="page_topic:edit_remove"
          title="Remove topic contribution"
        >
          <.icon name="hero-trash-micro" class="size-4" />
        </button>
        <button
          id={"#{@id_prefix}-edit-save"}
          type="submit"
          class="btn btn-accent btn-soft btn-sm btn-square"
          aria-label="Update topic contribution"
          title="Update topic contribution"
        >
          <.icon name="hero-check-micro" class="size-4" />
        </button>
      </div>
    </.form>
    """
  end

  defp topic_edit_context(_summaries, nil), do: nil

  defp topic_edit_context(summaries, tagging_id) do
    Enum.find_value(summaries, fn summary ->
      case Enum.find(summary.taggings, &(&1.id == tagging_id)) do
        nil -> nil
        tagging -> %{summary: summary, tagging: tagging}
      end
    end)
  end
end
