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
  alias WikWeb.Components.Tag, as: TagComponents
  alias WikWeb.Components.UI
  alias WikWeb.TagGraphLive.Components.TagTree
  alias WikWeb.PageTreeLive.Components.PageTree.ActionButtons

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    space = scope.tenant

    if connected?(socket) do
      :ok = WikWeb.Endpoint.subscribe(Tag.space_pub_sub_topic(space.id))
      :ok = WikWeb.Endpoint.subscribe(TagEdge.space_pub_sub_topic(space.id))
    end

    graph = Tags.load_tag_graph(scope)
    editable? = Ash.can?({Tag, :create}, scope)

    {:ok,
     socket
     |> assign(editing?: false)
     |> assign(editable?: editable?)
     |> assign(space: space)
     |> assign(tag_modal: new_tag_modal())
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
      <Layouts.space editing?={@editing?} presences={@presences} scope={@current_scope} view="tags">
        <:actions :if={@editable?}>
          <%= if @editing? do %>
            <UI.button_ok phx-click="toggle_edit_mode" data-testid="tag-edit-mode-ok" />
          <% else %>
            <UI.button_unlock
              phx-click="toggle_edit_mode"
              data-testid="tag-edit-mode-toggle"
            />
          <% end %>
        </:actions>

        <div class="space-y-4 pt-8" data-testid="tag-graph-page">
          <section class="space-y-4 relative max-w-[80ch]">
            <div :if={@editable? and @editing?} class="absolute right-0 -top-9">
              <ActionButtons.button
                data-tip="add root topic"
                icon="hero-plus-mini"
                data-testid="tag-add-root"
                phx-click="create_root_start"
              />
            </div>
            <TagTree.render
              editing?={@editing?}
              space_slug={@space.slug}
              nodes={@graph.root_tree}
              selected_tag_id={@selected_tag_id}
            />
          </section>
        </div>
      </Layouts.space>
    </Layouts.app>

    <Modal.render
      cancel="tag_modal_cancel"
      cancel_testid="tag-detail-cancel"
      open?={@tag_modal.mode != nil}
      testid="tag-detail-dialog"
    >
      <TagComponents.detail
        :if={@tag_modal.mode == :details and @selected_tag != nil}
        editing?={@editing?}
        eligible_children={@eligible_children}
        eligible_parents={@eligible_parents}
        graph={@graph}
        scope={@current_scope}
        selected_tag={@selected_tag}
      />
      <TagComponents.delete_confirm
        :if={@tag_modal.mode == :confirm_delete and @selected_tag != nil}
        tag={@selected_tag}
      />
      <TagComponents.form
        :if={@tag_modal.mode in [:create_root, :create_child, :edit] and @tag_modal.form != nil}
        action_label={tag_form_action_label(@tag_modal.mode)}
        cancel_testid="tag-form-cancel"
        event_submit="tag_submit"
        event_validate="tag_validate"
        event_cancel="tag_modal_cancel"
        form={@tag_modal.form}
        tag_id={@selected_tag && @selected_tag.id}
      />
      <.link_form
        :if={@tag_modal.mode in [:link_child, :link_parent] and @selected_tag}
        error={@tag_modal.error}
        form={@tag_modal.link_form}
        mode={@tag_modal.mode}
        options={link_options(@tag_modal.mode, @eligible_children, @eligible_parents)}
        tag={@selected_tag}
      />
    </Modal.render>
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
        <span :if={@mode == :link_child}>Link an existing child under </span>
        <span :if={@mode == :link_parent}>Link an existing parent above </span>
        <span class="font-bold">{@tag.name}</span>.
      </div>

      <.form for={@form} data-testid="tag-link-form-form" phx-submit="link_submit">
        <div class="space-y-3 rounded-box bg-base-100 p-4">
          <WikWeb.Components.Combobox.field
            field={@form[:target_tag_id]}
            id="tag-link-target-tag"
            label="Tag"
            options_json={link_options_json(@options)}
            placeholder="Search topics"
            testid="tag-link-target-tag"
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

    socket =
      socket
      |> refresh_graph(selected_tag_id)
      |> sync_modal_to_selected_tag(selected_tag_id)

    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_event("select_tag", %{"tag_id" => tag_id}, socket) do
    {:noreply, socket |> refresh_graph(tag_id) |> open_tag_modal(:details)}
  end

  def handle_event("toggle_edit_mode", _params, socket) do
    socket = assign(socket, editing?: !socket.assigns.editing?)

    socket =
      if socket.assigns.editing?,
        do: socket,
        else: socket |> close_tag_modal() |> refresh_graph(nil)

    {:noreply, socket}
  end

  def handle_event("create_root_start", _params, socket) do
    {:noreply,
     socket
     |> assign(
       tag_modal: new_tag_modal(:create_root, form: init_tag_form(socket.assigns.current_scope))
     )}
  end

  def handle_event("create_child_start", %{"parent_tag_id" => parent_tag_id}, socket) do
    {:noreply,
     socket
     |> refresh_graph(parent_tag_id)
     |> assign(
       tag_modal:
         new_tag_modal(:create_child,
           form: init_tag_form(socket.assigns.current_scope),
           parent_tag_id: parent_tag_id
         )
     )}
  end

  def handle_event("edit_tag_start", %{"tag_id" => tag_id}, socket) do
    {:noreply, socket |> refresh_graph(tag_id) |> open_tag_modal(:details)}
  end

  def handle_event("tag_edit_open", %{"tag_id" => tag_id}, socket) do
    {:noreply, socket |> refresh_graph(tag_id) |> open_tag_modal(:edit)}
  end

  def handle_event("tag_delete_confirm", %{"tag_id" => tag_id}, socket) do
    {:noreply, socket |> refresh_graph(tag_id) |> open_tag_modal(:confirm_delete)}
  end

  def handle_event("tag_modal_cancel", _params, socket) do
    {:noreply, cancel_tag_modal(socket)}
  end

  def handle_event("tag_validate", %{"form" => params}, socket) do
    {:noreply,
     update(socket, :tag_modal, fn modal ->
       %{modal | form: Form.validate(modal.form, tag_params(params))}
     end)}
  end

  def handle_event("tag_submit", %{"form" => params}, socket) do
    scope = socket.assigns.current_scope
    params = tag_params(params)

    case Form.submit(socket.assigns.tag_modal.form, params: params) do
      {:ok, %Tag{} = tag} ->
        link_result =
          maybe_link_new_tag(
            socket.assigns.tag_modal.mode,
            socket.assigns.tag_modal.parent_tag_id,
            tag,
            scope
          )

        if match?({:error, _error}, link_result) do
          {:error, error} = link_result
          Log.scoped_error(scope, error, "topic link after create failed")
        end

        {:noreply, handle_saved_tag(socket, tag)}

      {:error, form} ->
        {:noreply, update(socket, :tag_modal, &%{&1 | form: form})}
    end
  end

  def handle_event("delete_tag", %{"tag_id" => tag_id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      case Tags.destroy_tag(tag_id, scope: scope) do
        :ok ->
          socket
          |> close_tag_modal()
          |> refresh_graph(nil_if_selected(socket.assigns.selected_tag_id, tag_id))

        {:ok, _tag} ->
          socket
          |> close_tag_modal()
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
    {:noreply, socket |> refresh_graph(tag_id) |> open_tag_modal(:link_child)}
  end

  def handle_event("link_parent_start", %{"tag_id" => tag_id}, socket) do
    {:noreply, socket |> refresh_graph(tag_id) |> open_tag_modal(:link_parent)}
  end

  def handle_event("link_submit", %{"link" => %{"target_tag_id" => target_tag_id}}, socket) do
    scope = socket.assigns.current_scope
    current_tag = socket.assigns.selected_tag

    socket =
      case {current_tag, socket.assigns.tag_modal.mode, target_tag_id} do
        {nil, _mode, _target_tag_id} ->
          update(socket, :tag_modal, &%{&1 | error: "The selected tag is no longer available."})

        {_tag, _mode, ""} ->
          update(socket, :tag_modal, &%{&1 | error: "Please select a tag."})

        {%Tag{} = current_tag, :link_child, target_tag_id} ->
          submit_link(socket, current_tag.id, target_tag_id, current_tag.id, scope)

        {%Tag{} = current_tag, :link_parent, target_tag_id} ->
          submit_link(socket, target_tag_id, current_tag.id, current_tag.id, scope)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_info(%{topic: topic}, socket) do
    space = socket.assigns.space

    if topic in [Tag.space_pub_sub_topic(space.id), TagEdge.space_pub_sub_topic(space.id)] do
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

  defp open_tag_modal(socket, :details) do
    assign(socket, :tag_modal, new_tag_modal(:details))
  end

  defp open_tag_modal(socket, :confirm_delete) do
    assign(socket, :tag_modal, new_tag_modal(:confirm_delete))
  end

  defp open_tag_modal(socket, mode) when mode in [:link_child, :link_parent] do
    assign(
      socket,
      :tag_modal,
      new_tag_modal(mode, link_form: to_form(%{"target_tag_id" => ""}, as: :link))
    )
  end

  defp open_tag_modal(socket, :edit) do
    case socket.assigns.selected_tag do
      nil ->
        socket

      tag ->
        assign(
          socket,
          :tag_modal,
          new_tag_modal(:edit,
            form:
              tag |> Form.for_update(:update, scope: socket.assigns.current_scope) |> to_form()
          )
        )
    end
  end

  defp submit_link(socket, parent_tag_id, child_tag_id, selected_tag_id, scope) do
    case Tags.link_tags(parent_tag_id, child_tag_id, scope: scope) do
      {:ok, _edge} ->
        socket
        |> open_tag_modal(:details)
        |> refresh_graph(selected_tag_id)

      {:error, error} ->
        Log.scoped_error(scope, error, "tag link failed")
        update(socket, :tag_modal, &%{&1 | error: "Could not link those topics."})
    end
  end

  defp close_tag_modal(socket), do: assign(socket, :tag_modal, new_tag_modal())

  defp init_tag_form(scope) do
    Tag |> Form.for_create(:create, scope: scope) |> to_form()
  end

  defp maybe_link_new_tag(:create_root, nil, _tag, _scope), do: :ok

  defp maybe_link_new_tag(:create_child, parent_tag_id, tag, scope) do
    case Tags.link_tags(parent_tag_id, tag.id, scope: scope) do
      {:ok, _edge} -> :ok
      {:error, error} -> {:error, error}
    end
  end

  defp maybe_link_new_tag(:edit, _parent_tag_id, _tag, _scope), do: :ok
  defp maybe_link_new_tag(:details, _parent_tag_id, _tag, _scope), do: :ok

  defp link_options(:link_child, eligible_children, _eligible_parents), do: eligible_children
  defp link_options(:link_parent, _eligible_children, eligible_parents), do: eligible_parents
  defp link_options(_mode, _eligible_children, _eligible_parents), do: []

  defp tag_params(%{"name" => name} = params),
    do: Map.put(params, "slug", Utils.Slugify.generate(name))

  defp tag_params(params), do: params

  defp tag_form_action_label(:edit), do: "Update topic"
  defp tag_form_action_label(_mode), do: "Create topic"

  defp nil_if_selected(selected_tag_id, selected_tag_id), do: nil
  defp nil_if_selected(selected_tag_id, _deleted_tag_id), do: selected_tag_id

  defp cancel_tag_modal(%{assigns: %{tag_modal: %{mode: :details}}} = socket) do
    socket
    |> close_tag_modal()
    |> refresh_graph(nil)
  end

  defp cancel_tag_modal(%{assigns: %{tag_modal: %{mode: :create_root}}} = socket),
    do: close_tag_modal(socket)

  defp cancel_tag_modal(%{assigns: %{selected_tag_id: selected_tag_id}} = socket)
       when is_binary(selected_tag_id) do
    socket |> refresh_graph(selected_tag_id) |> open_tag_modal(:details)
  end

  defp cancel_tag_modal(socket), do: close_tag_modal(socket)

  defp sync_modal_to_selected_tag(socket, nil), do: close_tag_modal(socket)

  defp sync_modal_to_selected_tag(socket, selected_tag_id) do
    case {socket.assigns.tag_modal.mode,
          Map.get(socket.assigns.graph.tags_by_id, selected_tag_id)} do
      {_mode, nil} ->
        close_tag_modal(socket)

      {nil, %Tag{}} ->
        open_tag_modal(socket, :details)

      {_mode, %Tag{}} ->
        socket
    end
  end

  defp handle_saved_tag(socket, %Tag{} = tag) do
    case socket.assigns.tag_modal.mode do
      :create_root ->
        socket
        |> close_tag_modal()
        |> refresh_graph(socket.assigns.selected_tag_id)

      :create_child ->
        socket
        |> refresh_graph(socket.assigns.tag_modal.parent_tag_id)
        |> open_tag_modal(:details)

      :edit ->
        socket
        |> refresh_graph(tag.id)
        |> open_tag_modal(:details)

      _mode ->
        socket
        |> close_tag_modal()
        |> refresh_graph(socket.assigns.selected_tag_id)
    end
  end

  defp new_tag_modal(mode \\ nil, attrs \\ []) do
    %{
      error: Keyword.get(attrs, :error),
      form: Keyword.get(attrs, :form),
      link_form: Keyword.get(attrs, :link_form),
      mode: mode,
      parent_tag_id: Keyword.get(attrs, :parent_tag_id)
    }
  end

  defp link_options_json(options) do
    options
    |> Enum.map(fn tag ->
      %{
        label: tag.name,
        search: String.downcase(tag.name),
        value: tag.id
      }
    end)
    |> Jason.encode!()
  end
end
