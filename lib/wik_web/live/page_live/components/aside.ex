defmodule WikWeb.PageLive.Components.Aside do
  use WikWeb, :html

  alias Wik.Tags.Dimensions
  alias WikWeb.Components
  alias WikWeb.Components.DimensionsList
  alias WikWeb.Components.RangeInput
  alias WikWeb.Components.UI

  attr :author_membership, :map, default: nil
  attr :can_manage_page?, :boolean, required: true
  attr :current_scope, :map, required: true
  attr :editing?, :boolean, required: true
  attr :node, :map, required: true
  attr :page, :map, required: true
  attr :page_topic_form, :any, default: nil
  attr :page_topic_options, :list, required: true
  attr :page_topic_summaries, :list, required: true
  attr :page_tree, :map, required: true

  def sections(assigns) do
    ~H"""
    <section data-testid="page-backlinks">
      <UI.panel_title>
        <.icon name="hero-book-open-micro" class="opacity-70 size-4" /> Backlinks
      </UI.panel_title>
      <Components.Block.Types.Backlinks.render
        block={%{data: %{"title" => "Backlinks"}, type: :backlinks}}
        node={@node}
        page_tree={@page_tree}
        scope={@current_scope}
      />
    </section>

    <section data-testid="page-topics">
      <.topics
        can_manage_page?={@can_manage_page?}
        current_scope={@current_scope}
        editing?={@editing?}
        page_topic_form={@page_topic_form}
        page_topic_options={@page_topic_options}
        page_topic_summaries={@page_topic_summaries}
      />
    </section>

    <section>
      <UI.panel_title>
        <.icon name="hero-information-circle-micro" class="opacity-70 size-4" /> Details
      </UI.panel_title>
      <div class={[
        "grid grid-cols-2 gap-x-4 gap-y-2 mt-0",
        "items-baseline",
        "text-sm"
      ]}>
        <div>
          Created:
        </div>
        <Components.Time.relative_and_precise datetime={@page.inserted_at} ago? />

        <div>
          By:
        </div>
        <div class="flex items-center gap-2">
          <Components.User.identity
            :if={@author_membership}
            avatar_size="xs"
            class="gap-2"
            link?={true}
            membership={@author_membership}
          />
        </div>
      </div>
    </section>
    """
  end

  attr :can_manage_page?, :boolean, required: true
  attr :current_scope, :map, required: true
  attr :editing?, :boolean, required: true
  attr :page_topic_form, :any, default: nil
  attr :page_topic_options, :list, required: true
  attr :page_topic_summaries, :list, required: true

  def topics(assigns) do
    ~H"""
    <% relevancy_dimension = Dimensions.get!("page", "relevancy") %>

    <div class="mb-2 flex items-center justify-between gap-2">
      <UI.panel_title class="mb-0">
        <.icon name="hero-tag-micro" class="opacity-70 size-4" /> Topics
      </UI.panel_title>

      <UI.button_add
        :if={@editing? and @can_manage_page? and @page_topic_options != []}
        data-testid="page-topic-add"
        data-tip="Add topic"
        phx-click={JS.push("page_topic_add_start") |> UI.modal_open("page-topic-modal")}
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
          phx-click="page_topic_remove"
          phx-value-tag_id={summary.tag.id}
        >
          <span class="sr-only">Remove topic</span>
          <.icon name="hero-x-mark" class="size-3" />
        </button>
      </:action>
    </DimensionsList.render>

    <UI.modal id="page-topic-modal" open?={@page_topic_form != nil}>
      <UI.modal_title>Add topic</UI.modal_title>

      <.form
        :if={@page_topic_form}
        for={@page_topic_form}
        id="page-topic-form"
        class="mt-4 space-y-4"
        data-testid="page-topic-form"
        phx-change="page_topic_validate"
        phx-submit={JS.push("page_topic_submit") |> UI.modal_close("page-topic-modal")}
      >
        <.input
          field={@page_topic_form[:tag_id]}
          label="Topic"
          options={Enum.map(@page_topic_options, &{&1.name, &1.id})}
          prompt="Select a topic"
          type="select"
        />

        <RangeInput.render
          field={@page_topic_form[:relevancy_level]}
          dimension={relevancy_dimension}
          label={relevancy_dimension.label}
          max_level={relevancy_dimension.max}
        />

        <div class="flex justify-end gap-2">
          <button
            type="button"
            class="btn btn-ghost btn-sm"
            data-testid="page-topic-cancel"
            phx-click={JS.push("page_topic_cancel") |> UI.modal_close("page-topic-modal")}
          >
            Cancel
          </button>
          <.button class="btn btn-accent btn-soft btn-sm" data-testid="page-topic-submit">
            Save
          </.button>
        </div>
      </.form>
    </UI.modal>
    """
  end
end
