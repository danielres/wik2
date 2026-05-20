defmodule WikWeb.TagGraphLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Utils.Log
  alias Wik.Tags
  alias Wik.Tags.GraphQueries
  alias Wik.Tags.Tag
  alias Wik.Tags.TagEdge
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI
  alias WikWeb.TagGraphLive.Components.TagTree
  alias WikWeb.PageTreeLive.Components.PageTree.ActionButtons

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    group = scope.tenant

    if connected?(socket) do
      :ok = WikWeb.Endpoint.subscribe(Tag.group_pub_sub_topic(group.id))
      :ok = WikWeb.Endpoint.subscribe(TagEdge.group_pub_sub_topic(group.id))
    end

    graph = Tags.load_tag_graph(scope)
    editable? = Ash.can?({Tag, :create}, scope)

    {:ok,
     socket
     |> assign(editing?: false)
     |> assign(editable?: editable?)
     |> assign(group: group)
     |> assign(tag_form: nil)
     |> assign(tag_form_mode: nil)
     |> assign(tag_form_parent_id: nil)
     |> assign(tag_form_tag_id: nil)
     |> assign(link_form: nil)
     |> assign(link_form_mode: nil)
     |> assign(link_form_tag_id: nil)
     |> assign(link_form_error: nil)
     |> assign_graph_state(graph, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.group presences={@presences} scope={@current_scope} view="tags">
        <UI.page_title>Tags</UI.page_title>

        <div class="space-y-4" data-testid="tag-graph-page">
          <section class="space-y-4">
            <div :if={@editable?} class="mb-2 flex items-center justify-end gap-2">
              <%= if @editing? do %>
                <ActionButtons.button
                  data-tip="add root tag"
                  icon="hero-plus-mini"
                  data-testid="tag-add-root"
                  phx-click="create_root_start"
                />

                <UI.button_ok phx-click="toggle_edit_mode" data-testid="tag-edit-mode-ok" />
              <% else %>
                <UI.button_edit
                  phx-click="toggle_edit_mode"
                  data-testid="tag-edit-mode-toggle"
                />
              <% end %>
            </div>

            <TagTree.render
              editing?={@editing?}
              nodes={@graph.root_tree}
              selected_tag_id={@selected_tag_id}
            />
          </section>
        </div>

        <Modal.render
          cancel="tag_detail_close"
          cancel_testid="tag-detail-cancel"
          open?={@selected_tag != nil}
          testid="tag-detail-dialog"
        >
          <.tag_detail
            :if={@selected_tag != nil}
            editing?={@editing?}
            eligible_children={@eligible_children}
            eligible_parents={@eligible_parents}
            graph={@graph}
            selected_descendants={@selected_descendants}
            selected_tag={@selected_tag}
            selected_tag_id={@selected_tag_id}
          />
        </Modal.render>

        <Modal.render
          cancel="tag_form_cancel"
          cancel_testid="tag-form-cancel"
          open?={@tag_form != nil}
          testid="tag-form-dialog"
        >
          <.tag_form
            :if={@tag_form != nil}
            action_label={tag_form_action_label(@tag_form_mode)}
            form={@tag_form}
          />
        </Modal.render>

        <Modal.render
          cancel="link_form_cancel"
          cancel_testid="tag-link-cancel"
          open?={@link_form != nil}
          testid="tag-link-dialog"
        >
          <.link_form
            :if={@link_form != nil and @selected_tag}
            error={@link_form_error}
            form={@link_form}
            mode={@link_form_mode}
            options={link_options(@link_form_mode, @eligible_children, @eligible_parents)}
            tag={@selected_tag}
          />
        </Modal.render>
      </Layouts.group>
    </Layouts.app>
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

  attr :editing?, :boolean, required: true
  attr :eligible_children, :list, required: true
  attr :eligible_parents, :list, required: true
  attr :graph, :map, required: true
  attr :selected_descendants, :list, required: true
  attr :selected_tag, :map, required: true
  attr :selected_tag_id, :string, required: true

  defp tag_detail(assigns) do
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
          nodes={@selected_descendants}
          selected_tag_id={@selected_tag_id}
        />
      </div>
    </div>
    """
  end

  attr :action_label, :string, required: true
  attr :form, :any, required: true

  defp tag_form(assigns) do
    auto_slug = assigns.form[:name].value |> Utils.Slugify.generate()
    form_errors = AshPhoenix.Form.errors(assigns.form)
    assigns = assign(assigns, auto_slug: auto_slug, form_errors: form_errors)

    ~H"""
    <div data-testid="tag-form">
      <.form
        autocomplete="off"
        data-testid="tag-form-form"
        for={@form}
        phx-change="tag_validate"
        phx-submit="tag_submit"
      >
        <div class="space-y-3 rounded-box bg-base-100 p-4">
          <.input field={@form[:name]} label="Name" phx-hook="CapitalizeFirstLetter" />
          <.input hidden field={@form[:slug]} value={@auto_slug} />

          <UI.Forms.autoslug_preview
            source_value={@form[:name].value}
            data-testid={tag_autoslug_testid(@auto_slug)}
          />

          <.error :for={{field, _message} <- @form_errors} :if={field == :slug and @auto_slug != ""}>
            This tag name is not available.
          </.error>

          <.input field={@form[:description]} label="Description" type="textarea" />

          <.button class="btn btn-primary" data-testid="tag-form-submit" type="submit">
            {@action_label}
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  attr :error, :string, default: nil
  attr :form, :any, required: true
  attr :mode, :atom, required: true
  attr :options, :list, required: true
  attr :tag, :map, required: true

  defp link_form(assigns) do
    ~H"""
    <div data-testid="tag-link-form">
      <div class="mb-3 text-sm opacity-70">
        <span :if={@mode == :child}>Link an existing child under </span>
        <span :if={@mode == :parent}>Link an existing parent above </span>
        <span class="font-bold">{@tag.name}</span>.
      </div>

      <.form for={@form} data-testid="tag-link-form-form" phx-submit="link_submit">
        <div class="space-y-3 rounded-box bg-base-100 p-4">
          <.input
            field={@form[:target_tag_id]}
            label="Tag"
            options={Enum.map(@options, &{&1.name, &1.id})}
            prompt="Select a tag"
            type="select"
          />

          <.error :if={@error != nil}>{@error}</.error>

          <.button class="btn btn-primary" data-testid="tag-link-submit" type="submit">
            Link tag
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_params(params, url, socket) do
    selected_tag_id = params["tag"]
    socket = refresh_graph(socket, selected_tag_id)
    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_event("select_tag", %{"tag_id" => tag_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/#{socket.assigns.group.slug}/tags?#{%{tag: tag_id}}")}
  end

  def handle_event("toggle_edit_mode", _params, socket) do
    socket = assign(socket, editing?: !socket.assigns.editing?)

    socket =
      if socket.assigns.editing?,
        do: socket,
        else: socket |> close_tag_form() |> close_link_form()

    {:noreply, socket}
  end

  def handle_event("tag_detail_close", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/#{socket.assigns.group.slug}/tags")}
  end

  def handle_event("create_root_start", _params, socket) do
    {:noreply,
     socket
     |> assign(tag_form: init_tag_form(socket.assigns.current_scope))
     |> assign(tag_form_mode: :create)
     |> assign(tag_form_parent_id: nil)
     |> assign(tag_form_tag_id: nil)}
  end

  def handle_event("create_child_start", %{"parent_tag_id" => parent_tag_id}, socket) do
    {:noreply,
     socket
     |> assign(tag_form: init_tag_form(socket.assigns.current_scope))
     |> assign(tag_form_mode: :create)
     |> assign(tag_form_parent_id: parent_tag_id)
     |> assign(tag_form_tag_id: nil)}
  end

  def handle_event("edit_tag_start", %{"tag_id" => tag_id}, socket) do
    case Map.get(socket.assigns.graph.tags_by_id, tag_id) do
      nil ->
        {:noreply, socket}

      tag ->
        {:noreply,
         socket
         |> assign(
           tag_form:
             tag |> Form.for_update(:update, scope: socket.assigns.current_scope) |> to_form()
         )
         |> assign(tag_form_mode: :edit)
         |> assign(tag_form_parent_id: nil)
         |> assign(tag_form_tag_id: tag.id)}
    end
  end

  def handle_event("tag_form_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(tag_form: nil)
     |> assign(tag_form_mode: nil)
     |> assign(tag_form_parent_id: nil)
     |> assign(tag_form_tag_id: nil)}
  end

  def handle_event("tag_validate", %{"form" => params}, socket) do
    {:noreply,
     assign(socket, tag_form: Form.validate(socket.assigns.tag_form, tag_params(params)))}
  end

  def handle_event("tag_submit", %{"form" => params}, socket) do
    scope = socket.assigns.current_scope
    params = tag_params(params)

    case Form.submit(socket.assigns.tag_form, params: params) do
      {:ok, %Tag{} = tag} ->
        case maybe_link_new_tag(
               socket.assigns.tag_form_mode,
               socket.assigns.tag_form_parent_id,
               tag,
               scope
             ) do
          :ok ->
            {:noreply,
             socket
             |> close_tag_form()
             |> refresh_graph(tag.id)}

          {:error, error} ->
            Log.scoped_error(scope, error, "tag link after create failed")
            {:noreply, socket |> close_tag_form() |> refresh_graph(tag.id)}
        end

      {:error, form} ->
        {:noreply, assign(socket, tag_form: form)}
    end
  end

  def handle_event("delete_tag", %{"tag_id" => tag_id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      case Tags.destroy_tag(tag_id, scope: scope) do
        :ok ->
          socket
          |> refresh_graph(nil_if_selected(socket.assigns.selected_tag_id, tag_id))

        {:ok, _tag} ->
          socket
          |> refresh_graph(nil_if_selected(socket.assigns.selected_tag_id, tag_id))

        {:error, error} ->
          Log.scoped_error(scope, error, "tag destroy failed")
          socket
      end

    {:noreply, socket}
  end

  def handle_event(
        "detach_tag",
        %{"parent_tag_id" => parent_tag_id, "child_tag_id" => child_tag_id},
        socket
      ) do
    scope = socket.assigns.current_scope

    socket =
      case Tags.unlink_tags(parent_tag_id, child_tag_id, scope: scope) do
        {:ok, _edge} ->
          refresh_graph(socket, socket.assigns.selected_tag_id)

        {:error, error} ->
          Log.scoped_error(scope, error, "tag unlink failed")
          socket
      end

    {:noreply, socket}
  end

  def handle_event("link_child_start", %{"tag_id" => tag_id}, socket) do
    {:noreply, open_link_form(socket, :child, tag_id)}
  end

  def handle_event("link_parent_start", %{"tag_id" => tag_id}, socket) do
    {:noreply, open_link_form(socket, :parent, tag_id)}
  end

  def handle_event("link_form_cancel", _params, socket) do
    {:noreply, close_link_form(socket)}
  end

  def handle_event("link_submit", %{"link" => %{"target_tag_id" => target_tag_id}}, socket) do
    scope = socket.assigns.current_scope
    current_tag = socket.assigns.selected_tag

    {parent_tag_id, child_tag_id} =
      case socket.assigns.link_form_mode do
        :child -> {current_tag.id, target_tag_id}
        :parent -> {target_tag_id, current_tag.id}
      end

    socket =
      case Tags.link_tags(parent_tag_id, child_tag_id, scope: scope) do
        {:ok, _edge} ->
          socket
          |> close_link_form()
          |> refresh_graph(current_tag.id)

        {:error, error} ->
          Log.scoped_error(scope, error, "tag link failed")
          assign(socket, link_form_error: "Could not link those tags.")
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: topic}, socket) do
    group = socket.assigns.group

    if topic in [Tag.group_pub_sub_topic(group.id), TagEdge.group_pub_sub_topic(group.id)] do
      {:noreply, refresh_graph(socket, socket.assigns.selected_tag_id)}
    else
      {:noreply, socket}
    end
  end

  defp refresh_graph(socket, selected_tag_id) do
    graph = Tags.load_tag_graph(socket.assigns.current_scope)
    assign_graph_state(socket, graph, selected_tag_id)
  end

  defp assign_graph_state(socket, graph, selected_tag_id) do
    selected_tag = selected_tag_id && Map.get(graph.tags_by_id, selected_tag_id)

    {selected_descendants, eligible_children, eligible_parents} =
      case selected_tag do
        nil ->
          {[], [], []}

        tag ->
          {
            GraphQueries.descendant_tree(graph, tag),
            GraphQueries.eligible_child_tags(graph, tag),
            GraphQueries.eligible_parent_tags(graph, tag)
          }
      end

    socket
    |> assign(graph: graph)
    |> assign(selected_tag_id: selected_tag && selected_tag.id)
    |> assign(selected_tag: selected_tag)
    |> assign(selected_descendants: selected_descendants)
    |> assign(eligible_children: eligible_children)
    |> assign(eligible_parents: eligible_parents)
  end

  defp open_link_form(socket, mode, tag_id) do
    socket
    |> assign(link_form: to_form(%{"target_tag_id" => ""}, as: :link))
    |> assign(link_form_mode: mode)
    |> assign(link_form_tag_id: tag_id)
    |> assign(link_form_error: nil)
    |> refresh_graph(tag_id)
  end

  defp close_link_form(socket) do
    socket
    |> assign(link_form: nil)
    |> assign(link_form_mode: nil)
    |> assign(link_form_tag_id: nil)
    |> assign(link_form_error: nil)
  end

  defp close_tag_form(socket) do
    socket
    |> assign(tag_form: nil)
    |> assign(tag_form_mode: nil)
    |> assign(tag_form_parent_id: nil)
    |> assign(tag_form_tag_id: nil)
  end

  defp init_tag_form(scope) do
    Tag |> Form.for_create(:create, scope: scope) |> to_form()
  end

  defp maybe_link_new_tag(:create, nil, _tag, _scope), do: :ok

  defp maybe_link_new_tag(:create, parent_tag_id, tag, scope) do
    case Tags.link_tags(parent_tag_id, tag.id, scope: scope) do
      {:ok, _edge} -> :ok
      :ok -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp maybe_link_new_tag(:edit, _parent_tag_id, _tag, _scope), do: :ok

  defp link_options(:child, eligible_children, _eligible_parents), do: eligible_children
  defp link_options(:parent, _eligible_children, eligible_parents), do: eligible_parents

  defp tag_params(%{"name" => name} = params),
    do: Map.put(params, "slug", Utils.Slugify.generate(name))

  defp tag_params(params), do: params

  defp tag_form_action_label(:edit), do: "Update tag"
  defp tag_form_action_label(_mode), do: "Create tag"

  defp tag_autoslug_testid(""), do: "tag-autoslug-empty"
  defp tag_autoslug_testid(auto_slug), do: "tag-autoslug-#{auto_slug}"

  defp nil_if_selected(selected_tag_id, selected_tag_id), do: nil
  defp nil_if_selected(selected_tag_id, _deleted_tag_id), do: selected_tag_id
end
