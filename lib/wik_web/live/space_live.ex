defmodule WikWeb.SpaceLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Wik.Accounts.Membership
  alias Wik.Blocks
  alias WikWeb.Components
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI
  alias WikWeb.SpaceLive.OrphanBlocks

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    space = socket.assigns.current_scope.tenant |> load_space(scope)
    orphan_blocks = Blocks.list_orphan_space_owned_blocks(space, scope: scope)

    if connected?(socket) do
      :ok = WikWeb.Endpoint.subscribe(Membership.space_pub_sub_topic(space.id))
    end

    socket =
      socket
      |> assign(form: nil)
      |> assign(space: space)
      |> assign(editing?: false)
      |> assign(orphan_block_selected: nil)
      |> assign_orphan_blocks(orphan_blocks)

    {:ok, socket}
  end

  defp init_form(space, scope) do
    space |> Form.for_update(:update, scope: scope) |> to_form()
  end

  defp assign_orphan_blocks(socket, orphan_blocks) do
    scope = socket.assigns.current_scope

    socket
    |> assign(orphan_blocks: orphan_blocks)
    |> assign(
      can_destroy_orphan_blocks?: Enum.any?(orphan_blocks, &Ash.can?({&1, :destroy}, scope))
    )
  end

  # socket.assigns.live_action #=> :page_tree
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      context={@context}
      flash={@flash}
      tenant_context={@tenant_context}
      scope={@current_scope}
    >
      <Layouts.space presences={@presences} scope={@current_scope} view="space">
        <:actions :if={Ash.can?({@space, :update}, @current_scope)}>
          <%= if @editing? do %>
            <UI.button_ok phx-click="toggle_edit_mode" />
          <% else %>
            <UI.button_edit phx-click="toggle_edit_mode" />
          <% end %>
        </:actions>

        <div class={[
          "stacked",
          "w-fit"
        ]}>
          <div class="space-y-8">
            <div>
              <UI.page_title>{@current_scope.tenant.name |> String.capitalize()}</UI.page_title>
              <span class="badge badge-xs badge-ghost font-mono text-base-content/50">
                /{@space.slug}
              </span>
            </div>

            <div>
              <span class="label font-bold">Description</span>
              <div class="opacity-50 text-sm bg-base-200 p-4 rounded">{@space.description}</div>
            </div>
          </div>

          <button
            :if={@editing?}
            phx-click="update_space_start"
            class={[
              "border",
              "relative",
              "cursor-pointer",
              "rounded",
              "p-4",
              "w-[calc(100%+1rem)] -ml-[.5rem]",
              "h-[calc(100%+1rem)] -mt-[.5rem]",
              "border-accent/70 hover:border-accent transition-colors",
              "bg-accent/5 hover:bg-accent/10"
            ]}
          >
          </button>
        </div>

        <div>
          <span class="badge badge-xs badge-info">{@space.memberships |> length()} members</span>
        </div>

        <Modal.render
          cancel="update_space_cancel"
          cancel_testid="up date-space-cancel"
          open?={@form != nil}
          testid="update-space-dialog"
        >
          <Components.Space.form
            :if={Ash.can?({@space, :update}, @current_scope)}
            action_type="update"
            event_submit="space_submit"
            event_validate="space_validate"
            form={@form}
          />
        </Modal.render>

        <.link patch={~p"/#{@space.slug}/orphans"}>
          <span class="badge badge-xs badge-warning mr-1">{@orphan_blocks |> length()}</span>
          Orphan blocks
        </.link>

        <OrphanBlocks.render
          :if={@can_destroy_orphan_blocks?}
          event_orphan_block_destroy="orphan_block_destroy"
          event_preview_cancel="orphan_block_preview_cancel"
          event_preview_start="orphan_block_preview_start"
          orphan_block_selected={@orphan_block_selected}
          orphan_blocks={@orphan_blocks}
          scope={@current_scope}
        />
      </Layouts.space>
    </Layouts.app>
    """
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_event("toggle_edit_mode", _params, socket) do
    socket = socket |> assign(editing?: !socket.assigns.editing?)
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_space_start", _params, socket) do
    space = socket.assigns.space
    scope = socket.assigns.current_scope
    socket = socket |> assign(form: init_form(space, scope))
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_space_cancel", _params, socket) do
    socket = socket |> assign(form: nil)
    {:noreply, socket}
  end

  @impl true
  def handle_event("orphan_block_preview_start", %{"block_id" => block_id}, socket) do
    orphan_block_selected =
      socket.assigns.orphan_blocks
      |> Enum.find(&(&1.id == block_id))

    {:noreply, socket |> assign(orphan_block_selected: orphan_block_selected)}
  end

  @impl true
  def handle_event("orphan_block_preview_cancel", _params, socket) do
    {:noreply, socket |> assign(orphan_block_selected: nil)}
  end

  @impl true
  def handle_event("orphan_block_destroy", %{"block_id" => block_id}, socket) do
    space = socket.assigns.space
    scope = socket.assigns.current_scope

    case Blocks.destroy_orphan_space_owned_block(space, block_id, scope: scope) do
      :ok ->
        orphan_blocks = Blocks.list_orphan_space_owned_blocks(space, scope: scope)

        orphan_block_selected =
          case socket.assigns.orphan_block_selected do
            %{id: ^block_id} -> nil
            orphan_block_selected -> orphan_block_selected
          end

        {:noreply,
         socket
         |> assign_orphan_blocks(orphan_blocks)
         |> assign(orphan_block_selected: orphan_block_selected)}

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "destroy_orphan_space_owned_block failed")
        orphan_blocks = Blocks.list_orphan_space_owned_blocks(space, scope: scope)

        {:noreply,
         socket
         |> assign_orphan_blocks(orphan_blocks)
         |> assign(orphan_block_selected: nil)}
    end
  end

  @impl true
  def handle_event("space_validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(space_params(params)))}
  end

  @impl true
  def handle_event("space_submit", %{"form" => params}, socket) do
    prev_space = socket.assigns.space

    case socket.assigns.form |> Form.submit(params: space_params(params)) do
      {:ok, space} ->
        if prev_space.slug != space.slug do
          {:noreply, socket |> Phoenix.LiveView.redirect(to: ~p"/#{space.slug}")}
        else
          {:noreply, socket |> assign(space: space, form: nil)}
        end

      {:error, form} ->
        {:noreply,
         socket
         |> assign(form: form)}
    end
  end

  defp load_space(space, scope) do
    Ash.load!(space, [memberships: [:user]], scope: scope)
  end

  defp space_params(%{"name" => name} = params) do
    Map.put(params, "slug", Utils.Slugify.generate(name))
  end

  defp space_params(params), do: params
end
