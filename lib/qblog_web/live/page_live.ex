# TODO: break this up, too much going on in this file.

defmodule QblogWeb.PageLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki
  alias QblogWeb.Components
  alias QblogWeb.Endpoint
  alias QblogWeb.PageLive.BlockActions
  alias QblogWeb.PageLive.BlockEdit
  alias QblogWeb.PageLive.Locks
  alias QblogWeb.PageLive.PageState
  alias QblogWeb.Presence

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}
  on_mount {QblogWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(params, _session, socket) do
    path = params["path"] |> Enum.join("/")
    scope = socket.assigns.current_scope
    {node, page} = scope |> PageState.load_page_and_node_by_path(path)

    page_exists? = page != nil

    if page_exists? or Ash.can?({Wiki.Page, :create}, scope) do
      socket =
        socket
        |> assign(path: path, node: node, page: page)
        |> assign(editing_block_id: nil, form_edit_block: nil, editing?: false)
        |> PageState.sync_block_subscriptions(page)
        |> Locks.assign_locks()

      if connected?(socket), do: Endpoint.subscribe("block_placement:page:#{page.id}")

      {:ok, socket}
    else
      socket = socket |> assign(not_found_path: path)
      {:ok, socket}
    end
  end

  def render(%{not_found_path: _not_found_path} = assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group presences={@presences} scope={@current_scope} view="wiki">
        <div class="card-body bg-base-200 rounded flex flex-col items-center gap-4 py-16">
          <div>Ooops...</div>
          <div class="font-bold">"{@not_found_path}"</div>
          <div>Could not be found</div>
        </div>
      </Layouts.group>
    </Layouts.app>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group presences={@presences} scope={@current_scope} view="wiki">
        <section class="space-y-8">
          <header class="space-y-1">
            <div class="flex justify-between gap-4">
              <h1 class="text-2xl">{@node.title}</h1>
              <button
                class={[
                  "btn btn-sm btn-square btn-xs",
                  "opacity-80 hover:opacity-100",
                  @editing? && "btn-primary",
                  !@editing? && "btn-ghost"
                ]}
                phx-click="toggle_edit_mode"
              >
                <.icon name="hero-pencil-square-mini" />
              </button>
            </div>
            <div class="text-sm opacity-60">page author: {@page.author |> to_string()}</div>
            <div class="text-sm opacity-60">
              inserted_at: {@page.inserted_at |> Utils.Time.relative()}
            </div>
          </header>

          <div class={[
            "grid gap-8 sm:grid-cols-2"
          ]}>
            <div
              :for={placement <- @page.block_placements}
              class={[
                "card rounded col-span-1",
                placement.width == "half" && "sm:col-span-1",
                placement.width == "full" && "sm:col-span-2"
              ]}
              id={"block-#{placement.block.id}"}
            >
              <div class="card-body py-0.5 px-0 ">
                <%= if @editing_block_id == placement.block.id do %>
                  <Components.Block.form placement={placement} form={@form_edit_block} />
                <% else %>
                  <Components.Block.render
                    editing?={@editing?}
                    lock={@locks[placement.block.id]}
                    placement={placement}
                  />
                <% end %>
              </div>
            </div>

            <div
              :if={Enum.empty?(@page.block_placements)}
              class={[
                "sm:col-span-2",
                "p-8",
                "rounded bg-base-300/30",
                "text-center"
              ]}
            >
              No blocks yet
            </div>
          </div>

          <div
            :if={@editing?}
            class="flex justify-end join"
          >
            <.button
              class="btn btn-sm btn-primary join-item"
              phx-click="add_block"
              phx-value-type="text"
            >
              Add block
            </.button>

            <Components.Block.AddBlockMenuButton.render
              id="popover-special-blocks"
              class={[
                "btn btn-sm btn-primary join-item",
                "btn-square",
                "border-l border-base-300"
              ]}
              open?={false}
            />
          </div>
        </section>
      </Layouts.group>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    # TODO: add Ash.can? check to only allow users with edit permissions to toggle edit mode
    socket = socket |> assign(editing?: !socket.assigns.editing?)
    socket = if socket.assigns.editing?, do: socket, else: socket |> BlockEdit.clear()
    {:noreply, socket}
  end

  @impl true
  def handle_event("add_block", %{"type" => type_param}, socket) do
    {:noreply, socket |> BlockActions.add(type_param)}
  end

  @impl true
  def handle_event("edit_block_start", %{"block_id" => block_id}, socket) do
    {:noreply, socket |> BlockActions.start_edit(block_id)}
  end

  @impl true
  def handle_event("edit_block_cancel", %{"block_id" => block_id}, socket) do
    if socket.assigns.editing_block_id == block_id do
      {:noreply, socket |> BlockEdit.clear()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("move_block_down", %{"placement_id" => placement_id}, socket) do
    {:noreply, socket |> BlockActions.move_down(placement_id)}
  end

  @impl true
  def handle_event("move_block_up", %{"placement_id" => placement_id}, socket) do
    {:noreply, socket |> BlockActions.move_up(placement_id)}
  end

  @impl true
  def handle_event("destroy_block", %{"placement_id" => placement_id}, socket) do
    {:noreply, socket |> BlockActions.destroy(placement_id)}
  end

  @impl true
  def handle_event("toggle_block_width", %{"placement_id" => placement_id}, socket) do
    {:noreply, socket |> BlockActions.toggle_width(placement_id)}
  end

  @impl true
  def handle_event(
        "edit_block_submit",
        %{"block" => params, "block_id" => block_id},
        socket
      ) do
    {:noreply, socket |> BlockActions.save_edit(block_id, params)}
  end

  @impl true
  def handle_info(%{topic: "block:" <> _block_id}, socket) do
    {:noreply, socket |> PageState.reload()}
  end

  @impl true
  def handle_info(%{topic: "block_placement:page:" <> _page_id}, socket) do
    {:noreply, socket |> PageState.reload()}
  end

  @impl true
  def handle_info({QblogWeb.Presence, {:join, _presence}}, socket) do
    {:noreply, socket |> Locks.refresh_presence()}
  end

  @impl true
  def handle_info({QblogWeb.Presence, {:leave, _presence}}, socket) do
    {:noreply, socket |> Locks.refresh_presence()}
  end

  @impl true
  def handle_info({QblogWeb.Presence, {:update, %{id: _id, meta: _meta}}}, socket) do
    {:noreply, socket |> Locks.refresh_presence()}
  end
end
