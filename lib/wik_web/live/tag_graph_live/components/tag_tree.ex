defmodule WikWeb.TagGraphLive.Components.TagTree do
  use WikWeb, :html

  use Phoenix.Component

  alias WikWeb.PageTreeLive.Components.PageTree.ActionButtons
  alias WikWeb.Components.UI

  attr :editing?, :boolean, default: false
  attr :space_slug, :string, required: true
  attr :nodes, :list, required: true
  attr :selected_tag_id, :string, default: nil

  def render(assigns) do
    ~H"""
    <%= if @nodes == [] do %>
      <div class="card bg-base-200/50">
        <div class="card-body">
          No tags yet.
        </div>
      </div>
    <% else %>
      <.tag_nodes
        editing?={@editing?}
        space_slug={@space_slug}
        nodes={@nodes}
        selected_tag_id={@selected_tag_id}
        depth={0}
      />
    <% end %>
    """
  end

  attr :depth, :integer, required: true
  attr :editing?, :boolean, default: false
  attr :space_slug, :string, required: true
  attr :nodes, :list, required: true
  attr :selected_tag_id, :string, default: nil

  defp tag_nodes(assigns) do
    ~H"""
    <ul class={[@depth == 0 and "space-y-3"]}>
      <li :for={node <- @nodes} class={["card", @depth == 0 and "bg-base-300/50"]}>
        <.tag_node
          depth={@depth + 1}
          editing?={@editing?}
          space_slug={@space_slug}
          node={node}
          selected_tag_id={@selected_tag_id}
        />
      </li>
    </ul>
    """
  end

  attr :depth, :integer, required: true
  attr :editing?, :boolean, default: false
  attr :space_slug, :string, required: true
  attr :node, :map, required: true
  attr :selected_tag_id, :string, default: nil

  defp tag_node(assigns) do
    selected? = assigns.selected_tag_id == assigns.node.tag.id
    tagging_count = assigns.node.tag.membership_tagging_count || 0
    average_interest = format_average(assigns.node.tag.membership_interest_average)
    average_skill = format_average(assigns.node.tag.membership_skill_average)

    assigns =
      assigns
      |> assign(:selected?, selected?)
      |> assign(:tagging_count, tagging_count)
      |> assign(:average_interest, average_interest)
      |> assign(:average_skill, average_skill)

    ~H"""
    <div
      class={[
        "card-body pl-4",
        @depth > 1 and "pb-1 pt-0 pr-0",
        @node.children != [] and "pb-2"
      ]}
      data-testid={"tag-branch-#{@node.dom_id}"}
      style="--size-field: 0.22rem;"
    >
      <div class="group flex justify-between gap-2">
        <div
          :if={@editing?}
          class={[
            "flex min-w-0 flex-1 items-center gap-0 text-left transition",
            @selected? && "opacity-100",
            !@selected? && "opacity-80"
          ]}
        >
          <.icon
            name="hero-chevron-right-mini"
            class={[
              "opacity-30 transition",
              @selected? && "rotate-0 opacity-100",
              !@selected? && "rotate-135 group-hover:rotate-0 group-hover:opacity-100"
            ]}
          />

          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <span class="truncate">{@node.tag.name}</span>
              <span
                class="badge badge-xs badge-ghost shrink-0"
                data-testid={"tag-count-#{@node.dom_id}"}
              >
                {@tagging_count}
              </span>
            </div>
          </div>
        </div>

        <.link
          :if={not @editing?}
          navigate={~p"/#{@space_slug}/tags/#{@node.tag.slug}"}
          class={[
            "flex min-w-0 flex-1 items-center gap-0 text-left transition",
            "cursor-pointer",
            @selected? && "opacity-100",
            !@selected? && "opacity-80 hover:opacity-100"
          ]}
          data-testid={"tag-select-#{@node.dom_id}"}
        >
          <.icon
            name="hero-chevron-right-mini"
            class={[
              "opacity-30 transition",
              @selected? && "rotate-0 opacity-100",
              !@selected? && "rotate-135 group-hover:rotate-0 group-hover:opacity-100"
            ]}
          />

          <div class="min-w-0">
            <div class="flex items-center gap-2">
              <span class="truncate">{@node.tag.name}</span>
            </div>
          </div>
        </.link>

        <.button
          :if={not @editing? and @tagging_count > 0}
          class={[
            "ml-auto",
            "opacity-60 group-hover:opacity-80 hover:opacity-100 transition-opacity",
            "cursor-pointer"
          ]}
          data-testid={"tag-count-#{@node.dom_id}"}
          phx-click={UI.modal_open("#{@node.dom_id}-members-count-details-modal")}
        >
          <div class="indicator p-1">
            <.icon name="hero-user-micro" class="opacity-50" />
            <span class="indicator-item font-bold text-xs top-2 left-3">{@tagging_count}</span>
          </div>
        </.button>

        <UI.modal
          :if={not @editing? and @tagging_count > 0}
          id={"#{@node.dom_id}-members-count-details-modal"}
        >
          <div class={["space-y-4"]}>
            <h2 class="text-xl">{@node.tag.name}</h2>
            <div>Members tagged with this tag: {@tagging_count}</div>
            <dl class={[
              "grid grid-cols-[auto_1fr]",
              "[&>dt]:after:content-[':'] [&>dt]:font-semibold [&>dd]:pl-2",
              "p-2 bg-base-200 rounded"
            ]}>
              <dt>Average interest</dt>
              <dd>{@average_interest}</dd>

              <dt>Average skill</dt>
              <dd>{@average_skill}</dd>
            </dl>
          </div>
        </UI.modal>

        <ActionButtons.wrapper :if={@editing?}>
          <ActionButtons.button
            :if={@node.parent}
            data-tip="detach"
            data-testid={"tag-detach-#{@node.dom_id}"}
            icon="hero-link-slash-mini"
            phx-click="detach_tag"
            phx-value-child_tag_id={@node.tag.id}
            phx-value-parent_tag_id={@node.parent.id}
            variant="error"
          />

          <ActionButtons.button
            data-tip="add child"
            data-testid={"tag-add-child-#{@node.dom_id}"}
            icon="hero-plus-mini"
            phx-click="create_child_start"
            phx-value-parent_tag_id={@node.tag.id}
          />

          <ActionButtons.button
            data-tip="edit"
            data-testid={"tag-edit-#{@node.dom_id}"}
            icon="hero-pencil-mini"
            phx-click="edit_tag_start"
            phx-value-tag_id={@node.tag.id}
          />
        </ActionButtons.wrapper>
      </div>

      <.tag_nodes
        :if={@node.children != []}
        depth={@depth}
        editing?={@editing?}
        space_slug={@space_slug}
        nodes={@node.children}
        selected_tag_id={@selected_tag_id}
      />
    </div>
    """
  end

  defp format_average(nil), do: "n/a"

  defp format_average(value) do
    value
    |> Decimal.round(1)
    |> Decimal.to_string(:normal)
  end
end
