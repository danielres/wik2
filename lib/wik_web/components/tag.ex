defmodule WikWeb.Components.Tag do
  use Phoenix.Component
  use WikWeb, :live_view

  alias Wik.Tags
  alias Wik.Tags.GraphQueries
  alias Wik.Tags.Tag
  alias WikWeb.Components.UI
  alias WikWeb.TagGraphLive.Components.TagTree

  attr :class, :any, default: ""
  attr :render_root?, :boolean, default: false
  attr :render_self?, :boolean, default: false
  attr :scope, :map, required: true
  attr :tag, :map, required: true

  def breadcrumbs(assigns) do
    graph = Tags.load_tag_graph(assigns.scope)

    assigns =
      assigns
      |> assign(:space_slug, assigns.scope.tenant.slug)
      |> assign(:paths, breadcrumb_paths(graph, assigns.tag, assigns.render_self?))

    ~H"""
    <div :if={@paths != []} class={["space-y-1", @class]} data-testid="tag-breadcrumbs">
      <nav
        :for={{path, index} <- Enum.with_index(@paths)}
        class="breadcrumbs p-0 text-sm opacity-60"
        data-testid={"tag-breadcrumbs-path-#{index}"}
      >
        <ul class="leading-none space-y-0">
          <li :if={@render_root?}>
            <.link navigate={~p"/#{@space_slug}/topics"} class="hover:opacity-100 transition-opacity">
              Topics
            </.link>
          </li>

          <li :for={tag <- path}>
            <.link
              navigate={~p"/#{@space_slug}/topics/#{tag.slug}"}
              class="hover:opacity-100 transition-opacity"
            >
              {tag.name}
            </.link>
          </li>

          <li></li>
        </ul>
      </nav>
    </div>
    """
  end

  attr :editing?, :boolean, required: true
  attr :eligible_children, :list, required: true
  attr :eligible_parents, :list, required: true
  attr :graph, :map, required: true
  attr :scope, :map, required: true
  attr :selected_tag, :map, required: true

  def detail(assigns) do
    ~H"""
    <div class="space-y-4" data-testid={"tag-detail-#{@selected_tag.id}"}>
      <div class={[
        "stacked"
      ]}>
        <div class="p-2">
          <UI.page_title class="text-lg font-[300]">
            {@selected_tag.name}
          </UI.page_title>

          <div class="mb-4 text-xs font-mono opacity-50">
            /{@selected_tag.slug}
          </div>

          <%= if @selected_tag.description in [nil, ""] do %>
            <span class="italic opacity-50 text-sm">
              No description yet.
            </span>
          <% else %>
            <div class={[
              "max-h-30 overflow-y-auto rounded-box bg-base-100/70 p-3",
              "text-sm text-base-content/60 leading-tight"
            ]}>
              <div class="whitespace-pre-wrap">{@selected_tag.description}</div>
            </div>
          <% end %>
        </div>

        <button
          class={[
            "border",
            "cursor-pointer",
            "rounded",
            "border-accent/50 hover:border-accent transition-colors",
            "bg-accent/2 hover:bg-accent/10"
          ]}
          aria-label={"Edit topic #{@selected_tag.name}"}
          data-testid="tag-detail-edit"
          phx-click="tag_edit_open"
          phx-value-tag_id={@selected_tag.id}
          title={"Edit topic #{@selected_tag.name}"}
          type="button"
        >
          <span class="sr-only">Edit topic</span>
        </button>
      </div>

      <div :if={@editing?} class="flex flex-wrap gap-2 [&>*]:flex-grow">
        <button
          class="btn btn-xs btn-soft btn-accent"
          data-testid="tag-detail-add-child"
          phx-click="create_child_start"
          phx-value-parent_tag_id={@selected_tag.id}
        >
          <.icon name="hero-plus-mini" class="size-3" /> Add child
        </button>

        <button
          :if={@eligible_children != []}
          class="btn btn-xs btn-soft btn-accent"
          data-testid="tag-link-child-start"
          phx-click="link_child_start"
          phx-value-tag_id={@selected_tag.id}
        >
          <.icon name="hero-link-mini" class="size-3" /> Link child
        </button>

        <button
          :if={@eligible_parents != []}
          class="btn btn-xs btn-soft btn-accent"
          data-testid="tag-link-parent-start"
          phx-click="link_parent_start"
          phx-value-tag_id={@selected_tag.id}
        >
          <.icon name="hero-link-mini" class="size-3" /> Link parent
        </button>

        <button
          class="btn btn-xs btn-soft btn-error"
          data-testid="tag-detail-delete"
          phx-click="tag_delete_confirm"
          phx-value-tag_id={@selected_tag.id}
          type="button"
        >
          <.icon name="hero-trash-mini" class="size-3" /> Delete
        </button>
      </div>

      <div class="grid gap-2 md:grid-cols-2">
        <.parents
          graph={@graph}
          interaction={:select}
          item_testid_prefix="tag-detail-jump"
          scope={@scope}
          tag={@selected_tag}
        />

        <.children
          graph={@graph}
          interaction={:select}
          item_testid_prefix="tag-detail-jump"
          scope={@scope}
          tag={@selected_tag}
        />
      </div>

      <.descendants graph={@graph} scope={@scope} tag={@selected_tag} />
    </div>
    """
  end

  attr :graph, :map, default: nil
  attr :interaction, :atom, default: :navigate
  attr :item_testid_prefix, :string, default: "tag-parents-jump"
  attr :section_testid, :string, default: "tag-parents"
  attr :scope, :map, required: true
  attr :tag, :map, required: true

  def parents(assigns) do
    graph = graph_or_load(assigns.graph, assigns.scope)

    assigns =
      assigns
      |> assign(:items, GraphQueries.parents_for(graph, assigns.tag))
      |> assign(:space_slug, assigns.scope.tenant.slug)

    ~H"""
    <.relationship_list
      empty="No parents."
      interaction={@interaction}
      item_testid_prefix={@item_testid_prefix}
      items={@items}
      section_testid={@section_testid}
      space_slug={@space_slug}
      title="Tag parents"
    />
    """
  end

  attr :graph, :map, default: nil
  attr :interaction, :atom, default: :navigate
  attr :item_testid_prefix, :string, default: "tag-children-jump"
  attr :section_testid, :string, default: "tag-children"
  attr :scope, :map, required: true
  attr :tag, :map, required: true

  def children(assigns) do
    graph = graph_or_load(assigns.graph, assigns.scope)

    assigns =
      assigns
      |> assign(:items, GraphQueries.children_for(graph, assigns.tag))
      |> assign(:space_slug, assigns.scope.tenant.slug)

    ~H"""
    <.relationship_list
      empty="No children."
      interaction={@interaction}
      item_testid_prefix={@item_testid_prefix}
      items={@items}
      section_testid={@section_testid}
      space_slug={@space_slug}
      title="Tag children"
    />
    """
  end

  attr :graph, :map, default: nil
  attr :scope, :map, required: true
  attr :tag, :map, required: true

  def descendants(assigns) do
    graph = graph_or_load(assigns.graph, assigns.scope)
    nodes = GraphQueries.descendant_tree(graph, assigns.tag)

    assigns =
      assigns
      |> assign(:nodes, nodes)
      |> assign(:space_slug, assigns.scope.tenant.slug)

    ~H"""
    <div class="space-y-2" data-testid="tag-descendants">
      <UI.panel_title>Sub-topics</UI.panel_title>

      <div :if={@nodes == []} class="text-sm opacity-50">
        No sub-topics.
      </div>

      <TagTree.render
        :if={@nodes != []}
        editing?={false}
        nodes={@nodes}
        selected_tag_id={@tag.id}
        space_slug={@space_slug}
      />
    </div>
    """
  end

  attr :title, :string, required: true
  attr :empty, :string, required: true
  attr :interaction, :atom, required: true
  attr :item_testid_prefix, :string, required: true
  attr :items, :list, required: true
  attr :section_testid, :string, required: true
  attr :space_slug, :string, required: true

  defp relationship_list(assigns) do
    ~H"""
    <div class="" data-testid={@section_testid}>
      <UI.panel_title>{@title}</UI.panel_title>

      <div :if={@items == []} class="text-sm opacity-50">
        {@empty}
      </div>

      <div :if={@items != []} class="flex flex-wrap gap-1">
        <button
          :for={tag <- @items}
          :if={@interaction == :select}
          class={[
            "rounded border px-2.5 py-1 text-xs transition text-left w-full",
            "cursor-pointer",
            "border-base-300 bg-base-200/50 opacity-70 hover:opacity-100 transition"
          ]}
          data-testid={"#{@item_testid_prefix}-#{tag.id}"}
          phx-click="select_tag"
          phx-value-tag_id={tag.id}
        >
          {tag.name}
        </button>

        <.link
          :for={tag <- @items}
          :if={@interaction == :navigate}
          class={[
            "rounded border px-2.5 py-1 text-xs transition text-left w-full",
            "border-base-300 bg-base-300/60 opacity-70 hover:opacity-100 transition"
          ]}
          data-testid={"#{@item_testid_prefix}-#{tag.id}"}
          navigate={~p"/#{@space_slug}/topics/#{tag.slug}"}
        >
          {tag.name}
        </.link>
      </div>
    </div>
    """
  end

  attr :action_label, :string, required: true
  attr :class, :string, default: ""
  attr :cancel_testid, :string, default: nil
  attr :event_cancel, :string, default: nil
  attr :event_delete, :string, default: nil
  attr :event_submit, :string, required: true
  attr :event_validate, :string, required: true
  attr :form, :any, required: true
  attr :tag_id, :string, default: nil

  def form(assigns) do
    name_value = assigns.form[:name].value || ""
    auto_slug = Utils.Slugify.generate(name_value)
    form_errors = AshPhoenix.Form.errors(assigns.form)
    assigns = assign(assigns, auto_slug: auto_slug, form_errors: form_errors)

    ~H"""
    <div class={[@class]} data-testid="tag-form">
      <Phoenix.Component.form
        autocomplete="off"
        data-testid="tag-form-form"
        for={@form}
        phx-change={@event_validate}
        phx-submit={@event_submit}
      >
        <div class="space-y-3">
          <div>
            <.input field={@form[:name]} label="Name" phx-hook="CapitalizeFirstLetter" />
            <.input hidden field={@form[:slug]} value={@auto_slug} />

            <UI.Forms.autoslug_preview
              source_value={@form[:name].value}
              data-testid={tag_autoslug_testid(@auto_slug)}
            />
          </div>

          <.error :for={{field, _message} <- @form_errors} :if={field == :slug and @auto_slug != ""}>
            This topic name is not available.
          </.error>

          <.input field={@form[:description]} label="Description" type="textarea" />

          <div class="flex items-center justify-between gap-2">
            <button
              :if={@event_cancel != nil}
              class="btn btn-sm btn-soft"
              data-testid={@cancel_testid}
              phx-click={@event_cancel}
              type="button"
            >
              Cancel
            </button>

            <.button class="btn btn-sm btn-accent" data-testid="tag-form-submit" type="submit">
              {@action_label}
            </.button>
          </div>
        </div>
      </Phoenix.Component.form>
    </div>
    """
  end

  attr :tag, :map, required: true

  def delete_confirm(assigns) do
    ~H"""
    <div class="space-y-4" data-testid="tag-delete-confirm">
      <div class="space-y-2">
        <UI.page_title class="text-lg font-[300]">
          Delete topic?
        </UI.page_title>

        <p class="text-sm text-base-content/70">
          This will permanently delete <span class="font-semibold">{@tag.name}</span>.
        </p>
      </div>

      <div class="flex items-center justify-between gap-2">
        <button
          class="btn btn-sm btn-soft"
          data-testid="tag-delete-confirm-cancel"
          phx-click="tag_modal_cancel"
          type="button"
        >
          Cancel
        </button>

        <button
          class="btn btn-sm btn-error"
          data-testid="tag-delete-confirm-submit"
          phx-click="delete_tag"
          phx-value-tag_id={@tag.id}
          type="button"
        >
          <.icon name="hero-trash-mini" class="size-4" /> Delete topic
        </button>
      </div>
    </div>
    """
  end

  defp graph_or_load(nil, scope), do: Tags.load_tag_graph(scope)
  defp graph_or_load(graph, _scope), do: graph

  defp tag_autoslug_testid(""), do: "tag-autoslug-empty"
  defp tag_autoslug_testid(auto_slug), do: "tag-autoslug-#{auto_slug}"

  defp breadcrumb_paths(graph, %Tag{} = tag, render_self?) do
    graph
    |> breadcrumb_paths_for_tag(tag, MapSet.new())
    |> Enum.map(fn path ->
      if render_self?, do: path, else: Enum.drop(path, -1)
    end)
    |> Enum.reject(&(&1 == []))
    |> Enum.uniq_by(fn path -> Enum.map(path, & &1.id) end)
  end

  defp breadcrumb_paths_for_tag(graph, %Tag{} = tag, seen) do
    if MapSet.member?(seen, tag.id) do
      [[tag]]
    else
      case GraphQueries.parents_for(graph, tag) do
        [] ->
          [[tag]]

        parents ->
          seen = MapSet.put(seen, tag.id)

          Enum.flat_map(parents, fn parent ->
            graph
            |> breadcrumb_paths_for_tag(parent, seen)
            |> Enum.map(&(&1 ++ [tag]))
          end)
      end
    end
  end
end
