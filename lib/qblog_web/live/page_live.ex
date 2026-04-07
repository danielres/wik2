defmodule QblogWeb.PageLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki
  alias QblogWeb.Blocks

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(params, _session, socket) do
    path = params["path"] |> Enum.join("/")

    socket =
      socket
      |> assign(path: path)
      |> assign(editing_block_id: nil, form_edit_block: nil)
      |> assign(subscribed_block_ids: MapSet.new())
      |> reload_page()

    if connected?(socket) do
      QblogWeb.Endpoint.subscribe("block_placement:page:#{socket.assigns.page.id}")
    end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group scope={@current_scope} view="wiki">
        <section class="space-y-4">
          <header class="space-y-1">
            <h1 class="text-2xl">{@node.title}</h1>
            <div class="text-sm opacity-60">page author: {@page.author |> to_string()}</div>
            <div class="text-sm opacity-60">
              inserted_at: {@page.inserted_at |> Utils.Time.relative()}
            </div>
          </header>

          <div class="space-y-2">
            <div
              :for={placement <- @page.block_placements}
              class="card bg-base-200/50"
              id={"block-#{placement.block.id}"}
            >
              <div class="card-body">
                <%= if @editing_block_id == placement.block.id do %>
                  <.form
                    for={@form_edit_block}
                    id={"edit-block-form-#{placement.block.id}"}
                    phx-submit="edit_block_submit"
                    phx-value-block_id={placement.block.id}
                  >
                    <Blocks.Components.form
                      block={placement.block}
                      form={@form_edit_block}
                    />

                    <div class="flex justify-end gap-2">
                      <.button
                        class="btn btn-ghost"
                        phx-click="edit_block_cancel"
                        phx-value-block_id={placement.block.id}
                        type="button"
                      >
                        Cancel
                      </.button>

                      <.button class="btn btn-primary" type="submit">Save</.button>
                    </div>
                  </.form>
                <% else %>
                  <div class="absolute top-2 right-2 flex gap-1 opacity-50 hover:opacity-100 transition">
                    <.button
                      class="btn btn-ghost btn-circle"
                      phx-click="move_block_up"
                      phx-value-placement_id={placement.id}
                      type="button"
                    >
                      <.icon name="hero-chevron-up-mini" />
                    </.button>

                    <.button
                      class="btn btn-ghost btn-circle"
                      phx-click="move_block_down"
                      phx-value-placement_id={placement.id}
                      type="button"
                    >
                      <.icon name="hero-chevron-down-mini" />
                    </.button>

                    <.button
                      class="btn btn-ghost btn-circle"
                      phx-click="edit_block_start"
                      phx-value-block_id={placement.block.id}
                      type="button"
                    >
                      <.icon name="hero-pencil-mini" />
                    </.button>

                    <.button
                      class="btn btn-ghost btn-circle"
                      phx-click="destroy_block"
                      phx-value-placement_id={placement.id}
                      type="button"
                    >
                      <.icon name="hero-trash-mini" />
                    </.button>
                  </div>
                  <Blocks.Components.view block={placement.block} />
                <% end %>
              </div>
            </div>

            <div
              :if={Enum.empty?(@page.block_placements)}
              class="rounded bg-base-300/30 p-8 text-center"
            >
              No blocks yet
            </div>
          </div>

          <div class="flex justify-end join">
            <.button
              class="btn btn-sm btn-primary join-item"
              phx-click="add_block"
              phx-value-type="text"
            >
              Add block
            </.button>

            <.special_blocks_choice_button
              id="popover-special-blocks"
              class={[
                "btn btn-sm btn-primary join-item",
                "btn-square",
                "border-l border-base-300"
              ]}
            />
          </div>
        </section>
      </Layouts.group>
    </Layouts.app>
    """
  end

  attr :class, :any, default: ""
  attr :id, :string, required: true
  attr :open?, :boolean, default: false

  def special_blocks_choice_button(assigns) do
    ~H"""
    <.popover_special_blocks id={@id} open?={@open?} />

    <button
      class={@class}
      popovertarget="popover-special-blocks"
      style={ "anchor-name:--anchor-#{@id}" }
    >
      <.icon name="hero-ellipsis-horizontal-mini" />
    </button>
    """
  end

  attr :id, :string, required: true
  attr :open?, :boolean, default: false

  def popover_special_blocks(assigns) do
    ~H"""
    <div
      popover
      id={@id}
      style={ "position-anchor:--anchor-#{@id}" }
      class={[
        "dropdown dropdown-top dropdown-end",
        @open? and "dropdown-open",
        "bg-base-300 rounded",
        "p-2",
        "border-1 border-base-300",
        "mb-1"
      ]}
    >
      <div class={[
        "grid",
        "[&_button]:justify-start",
        "rounded",
        "space-y-[1px]"
      ]}>
        <.button_special_block
          :for={block_type <- Qblog.Blocks.types_available()}
          label={block_type.label}
          phx-click="add_block"
          phx-value-type={block_type.type}
        />
      </div>
    </div>
    """
  end

  attr :label, :string, required: true
  attr :rest, :global

  def button_special_block(assigns) do
    ~H"""
    <button
      {@rest}
      class="btn btn-primary btn-ghost btn-sm rounded-sm"
    >
      {@label}
    </button>
    """
  end

  @impl true
  def handle_event("add_block", %{"type" => type_param}, socket) do
    scope = socket.assigns.current_scope
    group = scope.tenant
    page = socket.assigns.page

    case type_param do
      "text" ->
        add_block(socket, group, page, :text, scope)

      "google_maps" ->
        add_block(socket, group, page, :google_maps, scope)

      _ ->
        {:noreply, socket |> put_flash(:error, "Unknown block type")}
    end
  end

  @impl true
  def handle_event("edit_block_start", %{"block_id" => block_id}, socket) do
    {:noreply,
     socket
     |> assign(editing_block_id: block_id)
     |> assign_form_edit_block(socket.assigns.page |> find_block_in_page(block_id))}
  end

  @impl true
  def handle_event("edit_block_cancel", %{"block_id" => block_id}, socket) do
    if socket.assigns.editing_block_id == block_id do
      {:noreply, socket |> assign(editing_block_id: nil, form_edit_block: nil)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_block_down", %{"placement_id" => placement_id}, socket) do
    scope = socket.assigns.current_scope
    placement = socket.assigns.page |> find_placement_in_page(placement_id)

    case placement |> Qblog.Blocks.move_placed_block_down(scope: scope) do
      {:ok, _placement} ->
        {:noreply, socket}

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "move_placed_block_down failed")
        {:noreply, socket |> put_flash(:error, "Could not move block")}
    end
  end

  @impl true
  def handle_event("move_block_up", %{"placement_id" => placement_id}, socket) do
    scope = socket.assigns.current_scope
    placement = socket.assigns.page |> find_placement_in_page(placement_id)

    case placement |> Qblog.Blocks.move_placed_block_up(scope: scope) do
      {:ok, _placement} ->
        {:noreply, socket}

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "move_placed_block_up failed")
        {:noreply, socket |> put_flash(:error, "Could not move block")}
    end
  end

  @impl true
  def handle_event("destroy_block", %{"placement_id" => placement_id}, socket) do
    scope = socket.assigns.current_scope
    placement = socket.assigns.page |> find_placement_in_page(placement_id)

    case placement |> Qblog.Blocks.destroy_placed_block(scope: scope) do
      :ok ->
        {:noreply, socket |> assign(editing_block_id: nil, form_edit_block: nil)}

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "destroy_placed_block failed")
        {:noreply, socket |> put_flash(:error, "Could not remove block")}
    end
  end

  @impl true
  def handle_event(
        "edit_block_submit",
        %{"block" => params, "block_id" => block_id},
        socket
      ) do
    socket
    |> save_block_edit(block_id, params)
  end

  defp save_block_edit(socket, block_id, params) do
    scope = socket.assigns.current_scope
    block = socket.assigns.page |> find_block_in_page(block_id)

    case block |> Qblog.Blocks.update_block(params, scope: scope) do
      {:ok, _block} ->
        {:noreply,
         socket
         |> assign(editing_block_id: nil, form_edit_block: nil)}

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "save block failed")

        {:noreply,
         socket
         |> put_flash(:error, "Could not save block")
         |> assign(editing_block_id: block_id)
         |> assign_form_edit_block(block, params)}
    end
  end

  @impl true
  def handle_info(%{topic: "block:" <> _block_id}, socket) do
    {:noreply, socket |> reload_page()}
  end

  @impl true
  def handle_info(%{topic: "block_placement:page:" <> _page_id}, socket) do
    {:noreply, socket |> reload_page()}
  end

  defp assign_form_edit_block(socket, block) do
    socket
    |> assign(form_edit_block: block |> Qblog.Blocks.block_to_form_params() |> to_form(as: :block))
  end

  defp assign_form_edit_block(socket, block, params) do
    socket
    |> assign(form_edit_block: block |> Qblog.Blocks.block_to_form_params(params) |> to_form(as: :block))
  end

  defp add_block(socket, group, page, type, scope) do
    case group |> Qblog.Blocks.create_group_owned_block_on_page(page, %{type: type}, scope: scope) do
      {:ok, block} ->
        {:noreply,
         socket
         |> assign(editing_block_id: block.id)
         |> assign_form_edit_block(block)}

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "create_group_owned_block_on_page failed")
        {:noreply, socket |> put_flash(:error, "Could not add block to page")}
    end
  end

  defp find_block_in_page(page, block_id) do
    page.block_placements
    |> Enum.find(&(&1.block.id == block_id))
    |> then(& &1.block)
  end

  defp find_placement_in_page(page, placement_id) do
    page.block_placements
    |> Enum.find(&(&1.id == placement_id))
  end

  defp reload_page(socket) do
    scope = socket.assigns.current_scope
    {node, page} = scope |> load_page_and_node_by_path(socket.assigns.path)

    socket
    |> sync_block_subscriptions(page)
    |> assign(node: node, page: page)
    |> maybe_clear_invalid_edit_state(page)
  end

  defp sync_block_subscriptions(socket, page) do
    if connected?(socket) do
      current_block_ids = page.block_placements |> Enum.map(& &1.block.id) |> MapSet.new()
      subscribed_block_ids = socket.assigns.subscribed_block_ids
      block_ids_to_subscribe = current_block_ids |> MapSet.difference(subscribed_block_ids)
      block_ids_to_unsubscribe = subscribed_block_ids |> MapSet.difference(current_block_ids)

      Enum.each(block_ids_to_subscribe, &QblogWeb.Endpoint.subscribe("block:#{&1}"))
      Enum.each(block_ids_to_unsubscribe, &QblogWeb.Endpoint.unsubscribe("block:#{&1}"))

      socket |> assign(subscribed_block_ids: current_block_ids)
    else
      socket
    end
  end

  defp maybe_clear_invalid_edit_state(socket, page) do
    editing_block_id = socket.assigns.editing_block_id
    editing_block? = page.block_placements |> Enum.any?(&(&1.block.id == editing_block_id))

    if editing_block? do
      socket
    else
      socket |> assign(editing_block_id: nil, form_edit_block: nil)
    end
  end

  defp load_page_and_node_by_path(scope, path) do
    path
    |> Wiki.ensure_node_and_page_at_path(
      scope: scope,
      load: [:author, block_placements: :block]
    )
  end
end
