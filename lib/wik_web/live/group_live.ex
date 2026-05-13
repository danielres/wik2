defmodule WikWeb.GroupLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Wik.Accounts.GroupUserRelation
  alias Wik.Blocks
  alias WikWeb.Components
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI
  alias WikWeb.GroupLive.MembershipTypeSelector
  alias WikWeb.GroupLive.NewOwnerSelector
  alias WikWeb.GroupLive.OrphanBlocks

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    group = socket.assigns.current_scope.tenant |> load_group(scope)
    orphan_blocks = Blocks.list_orphan_group_owned_blocks(group, scope: scope)

    if connected?(socket) do
      :ok = WikWeb.Endpoint.subscribe(GroupUserRelation.group_pub_sub_topic(group.id))
    end

    socket =
      socket
      |> assign(form: nil)
      |> assign(group: group)
      |> assign(orphan_block_selected: nil)
      |> assign(selected_membership: nil)
      |> assign(membership_type_form: nil)
      |> assign(transfer_ownership_form: nil)
      |> assign_orphan_blocks(orphan_blocks)

    {:ok, socket}
  end

  defp init_form(group, scope) do
    group |> Form.for_update(:update, scope: scope) |> to_form()
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
      <Layouts.group presences={@presences} scope={@current_scope}>
        <UI.page_title class="text-xl font-[100] flex items-center justify-between gap-4 mb-0">
          {@current_scope.tenant.name |> String.capitalize()}

          <button
            :if={Ash.can?({@group, :update}, @current_scope)}
            class="opacity-70 hover:opacity-100 transition-opacity cursor-pointer"
            phx-click="update_group_start"
          >
            <.icon name="hero-pencil-mini" />
          </button>
        </UI.page_title>

        <div class="opacity-50 text-sm">{@group.description}</div>

        <Modal.render
          cancel="update_group_cancel"
          cancel_testid="update-group-cancel"
          open?={@form != nil}
          testid="update-group-dialog"
        >
          <Components.Group.form
            :if={Ash.can?({@group, :update}, @current_scope)}
            action_type="update"
            event_submit="group_submit"
            event_validate="group_validate"
            form={@form}
          />
        </Modal.render>

        <div class="rounded-box border-4 border-base-200 bg-base-300">
          <div role="tablist" class="tabs tabs-box p-0 pb-0.5 bg-base-300">
            <Components.Tabs.tab
              active?={@live_action == :members}
              patch={~p"/#{@group.slug}/members"}
            >
              <span class="badge badge-xs bg-base-200 mr-1">{@group.memberships |> length()}</span>
              Members
            </Components.Tabs.tab>

            <Components.Tabs.tab
              :if={@can_destroy_orphan_blocks?}
              active?={@live_action == :orphans}
              patch={~p"/#{@group.slug}/orphans"}
            >
              <span class="badge badge-xs badge-warning mr-1">{@orphan_blocks |> length()}</span>
              Orphan blocks
            </Components.Tabs.tab>

            <Components.Tabs.tab
              active?={@live_action == :page_tree}
              navigate={~p"/#{@group.slug}/tree"}
            >
              Page tree <.icon name="hero-arrow-up-right-micro" class="ml-1" />
            </Components.Tabs.tab>
          </div>

          <Components.Tabs.tab_content active?={@live_action == :members}>
            <Modal.render
              cancel="membership_type_change_cancel"
              cancel_testid="membership-type-change-cancel"
              open?={@membership_type_form != nil}
              testid="membership-type-change-dialog"
            >
              <MembershipTypeSelector.render
                :if={@membership_type_form != nil and @selected_membership != nil}
                event_submit="membership_type_change_submit"
                form={@membership_type_form}
                membership={@selected_membership}
                type_options={GroupUserRelation.updatable_types()}
              />
            </Modal.render>

            <Modal.render
              cancel="transfer_ownership_cancel"
              cancel_testid="transfer-ownership-cancel"
              open?={@transfer_ownership_form != nil}
              testid="transfer-ownership-dialog"
            >
              <NewOwnerSelector.render
                event_transfer_ownership="transfer_ownership"
                memberships={@group.memberships}
              />
            </Modal.render>

            <Components.Block.Types.Members.render
              event_membership_type_change_start="membership_type_change_start"
              event_transfer_ownership_start="transfer_ownership_start"
              scope={@current_scope}
              block={%{id: "members-block"}}
              actions?
            />
          </Components.Tabs.tab_content>

          <Components.Tabs.tab_content active?={@live_action == :orphans}>
            <OrphanBlocks.render
              event_orphan_block_destroy="orphan_block_destroy"
              event_preview_cancel="orphan_block_preview_cancel"
              event_preview_start="orphan_block_preview_start"
              orphan_block_selected={@orphan_block_selected}
              orphan_blocks={@orphan_blocks}
              scope={@current_scope}
            />
          </Components.Tabs.tab_content>
        </div>
      </Layouts.group>
    </Layouts.app>
    """
  end

  attr :title, :string, required: true
  slot :inner_block, required: true

  def page_section(assigns) do
    ~H"""
    <div class="card card-sm bg-base-200">
      <div class="card-body">
        <h2 class="text-xl">{@title}</h2>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end

  @impl true
  def handle_params(_params, url, socket) do
    {:noreply, WikWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
  def handle_info(%{topic: topic}, socket) do
    group = socket.assigns.group

    if topic == GroupUserRelation.group_pub_sub_topic(group.id) do
      {:noreply, refresh_group_memberships(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("membership_type_change_start", params, socket) do
    group = socket.assigns.group
    scope = socket.assigns.current_scope
    membership_id = params["membership_id"]

    case Enum.find(group.memberships, &(&1.id == membership_id and &1.type != :owner)) do
      nil ->
        {:noreply, socket}

      membership ->
        form = membership |> Form.for_update(:update_membership_type, scope: scope) |> to_form()

        {:noreply,
         socket
         |> assign(membership_type_form: form)
         |> assign(selected_membership: membership)}
    end
  end

  def handle_event("membership_type_change_cancel", _params, socket) do
    {:noreply,
     socket
     |> assign(membership_type_form: nil)
     |> assign(selected_membership: nil)}
  end

  def handle_event("membership_type_change_submit", %{"form" => params}, socket) do
    form = socket.assigns.membership_type_form

    case Form.submit(form, params: params) do
      {:ok, _membership} ->
        {:noreply,
         socket
         |> assign(membership_type_form: nil)
         |> assign(selected_membership: nil)}

      {:error, form} ->
        {:noreply, socket |> assign(membership_type_form: form)}
    end
  end

  def handle_event("transfer_ownership_start", params, socket) do
    group = socket.assigns.group
    scope = socket.assigns.current_scope
    membership_id = params["membership_id"]

    case Enum.find(group.memberships, &(&1.id == membership_id)) do
      nil ->
        {:noreply, socket}

      membership ->
        form = membership |> Form.for_update(:transfer_ownership, scope: scope) |> to_form()
        socket = socket |> assign(transfer_ownership_form: form)
        {:noreply, socket}
    end
  end

  def handle_event("transfer_ownership_cancel", _params, socket) do
    socket = socket |> assign(transfer_ownership_form: nil)
    {:noreply, socket}
  end

  def handle_event(
        "transfer_ownership",
        %{"target_membership_id" => target_membership_id},
        socket
      ) do
    form = socket.assigns.transfer_ownership_form

    case Form.submit(form, params: %{target_membership_id: target_membership_id}) do
      {:ok, _membership} ->
        {:noreply, socket |> assign(transfer_ownership_form: nil)}

      {:error, form} ->
        {:noreply, socket |> assign(transfer_ownership_form: form)}
    end
  end

  @impl true
  def handle_event("update_group_start", _params, socket) do
    group = socket.assigns.group
    scope = socket.assigns.current_scope
    socket = socket |> assign(form: init_form(group, scope))
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_group_cancel", _params, socket) do
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
    group = socket.assigns.group
    scope = socket.assigns.current_scope

    case Blocks.destroy_orphan_group_owned_block(group, block_id, scope: scope) do
      :ok ->
        orphan_blocks = Blocks.list_orphan_group_owned_blocks(group, scope: scope)

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
        Utils.Log.scoped_error(scope, error, "destroy_orphan_group_owned_block failed")
        orphan_blocks = Blocks.list_orphan_group_owned_blocks(group, scope: scope)

        {:noreply,
         socket
         |> assign_orphan_blocks(orphan_blocks)
         |> assign(orphan_block_selected: nil)}
    end
  end

  @impl true
  def handle_event("group_validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(group_params(params)))}
  end

  @impl true
  def handle_event("group_submit", %{"form" => params}, socket) do
    prev_group = socket.assigns.group

    case socket.assigns.form |> Form.submit(params: group_params(params)) do
      {:ok, group} ->
        if prev_group.slug != group.slug do
          {:noreply, socket |> Phoenix.LiveView.redirect(to: ~p"/#{group.slug}")}
        else
          {:noreply, socket |> assign(group: group, form: nil)}
        end

      {:error, form} ->
        {:noreply,
         socket
         |> assign(form: form)}
    end
  end

  defp load_group(group, scope) do
    Ash.load!(group, [memberships: [:user]], scope: scope)
  end

  defp refresh_group_memberships(socket) do
    scope = socket.assigns.current_scope
    group = socket.assigns.group |> load_group(scope)

    socket
    |> assign(group: group)
    |> assign_membership_type_form(group.memberships)
  end

  defp assign_membership_type_form(socket, memberships) do
    case socket.assigns.selected_membership do
      nil ->
        socket

      membership ->
        membership = Enum.find(memberships, &(&1.id == membership.id and &1.type != :owner))

        case membership do
          nil ->
            socket
            |> assign(selected_membership: nil)
            |> assign(membership_type_form: nil)

          membership ->
            socket
            |> assign(selected_membership: membership)
            |> assign(
              membership_type_form:
                membership
                |> Form.for_update(:update_membership_type, scope: socket.assigns.current_scope)
                |> to_form()
            )
        end
    end
  end

  defp group_params(%{"name" => name} = params) do
    Map.put(params, "slug", Utils.Slugify.generate(name))
  end

  defp group_params(params), do: params
end
