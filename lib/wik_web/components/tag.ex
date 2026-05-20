defmodule WikWeb.Components.Tag do
  use Phoenix.Component
  use WikWeb, :live_view

  alias Wik.Tags.GraphQueries
  alias WikWeb.Components.UI
  alias WikWeb.TagGraphLive.Components.TagTree

  attr :editing?, :boolean, required: true
  attr :eligible_children, :list, required: true
  attr :eligible_parents, :list, required: true
  attr :graph, :map, required: true
  attr :group_slug, :string, required: true
  attr :selected_descendants, :list, required: true
  attr :selected_tag, :map, required: true
  attr :selected_tag_id, :string, required: true

  def detail(assigns) do
    assigns =
      assign(assigns,
        parents: GraphQueries.parents_for(assigns.graph, assigns.selected_tag),
        children: GraphQueries.children_for(assigns.graph, assigns.selected_tag)
      )

    ~H"""
    <div class="space-y-4" data-testid={"tag-detail-#{@selected_tag.id}"}>
      <div class="min-w-0">
        <UI.page_title class="text-lg font-[300]">
          {@selected_tag.name}
        </UI.page_title>

        <div class="mb-4 text-xs font-mono opacity-50">
          /{@selected_tag.slug}
        </div>

        <%= if @selected_tag.description in [nil, ""] do %>
          <span class="italic opacity-50">
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
      </div>

      <div class="grid gap-2 md:grid-cols-2">
        <.detail_list
          title="Parents"
          empty="No parents."
          items={@parents}
          target_tag_id={@selected_tag.id}
        />

        <.detail_list
          title="Children"
          empty="No children."
          items={@children}
          target_tag_id={@selected_tag.id}
        />
      </div>

      <div :if={@children != []} class="space-y-2">
        <h3 class="text-sm uppercase tracking-[0.18em] opacity-50">Descendants</h3>
        <TagTree.render
          editing?={false}
          group_slug={@group_slug}
          nodes={@selected_descendants}
          selected_tag_id={@selected_tag_id}
        />
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :empty, :string, required: true
  attr :items, :list, required: true
  attr :target_tag_id, :string, required: true

  defp detail_list(assigns) do
    ~H"""
    <div class="rounded-box border border-base-300 bg-base-100/70 p-3">
      <h3 class="mb-2 text-xs uppercase tracking-wider opacity-50">{@title}</h3>

      <div :if={@items == []} class="text-sm opacity-50">
        {@empty}
      </div>

      <div :if={@items != []} class="flex flex-wrap gap-1">
        <button
          :for={tag <- @items}
          class={[
            "rounded border px-2.5 py-1 text-xs transition text-left w-full",
            "cursor-pointer",
            tag.id == @target_tag_id && "border-accent bg-accent/10",
            tag.id != @target_tag_id && "border-base-300 bg-base-200/50 hover:border-accent"
          ]}
          data-testid={"tag-detail-jump-#{tag.id}"}
          phx-click="select_tag"
          phx-value-tag_id={tag.id}
        >
          {tag.name}
        </button>
      </div>
    </div>
    """
  end

  attr :action_label, :string, required: true
  attr :class, :string, default: ""
  attr :event_submit, :string, required: true
  attr :event_validate, :string, required: true
  attr :form, :any, required: true

  def form(assigns) do
    auto_slug = assigns.form[:name].value |> Utils.Slugify.generate()
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
            This tag name is not available.
          </.error>

          <.input field={@form[:description]} label="Description" type="textarea" />

          <div class="flex justify-end">
            <.button class="btn btn-sm btn-accent" data-testid="tag-form-submit" type="submit">
              {@action_label}
            </.button>
          </div>
        </div>
      </Phoenix.Component.form>
    </div>
    """
  end

  defp tag_autoslug_testid(""), do: "tag-autoslug-empty"
  defp tag_autoslug_testid(auto_slug), do: "tag-autoslug-#{auto_slug}"
end
