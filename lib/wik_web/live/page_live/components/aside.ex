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

    <section :if={false} data-testid="page-topics">
      <WikWeb.PageLive.Components.PageTopics.render
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
end
