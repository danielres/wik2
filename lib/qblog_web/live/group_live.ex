defmodule QblogWeb.GroupLive do
  use QblogWeb, :live_view
  use QblogWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Qblog.Blocks
  alias QblogWeb.Components.Modal
  alias QblogWeb.Components

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}
  on_mount {QblogWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    group = socket.assigns.current_scope.tenant
    group = Ash.load!(group, [memberships: [:user]], scope: scope)
    orphan_blocks = Blocks.list_orphan_group_owned_blocks(group, scope: scope)

    socket =
      socket
      |> assign(form: nil)
      |> assign(orphan_blocks: orphan_blocks)
      |> assign(transfer_ownership_form: nil)
      |> assign(group: group)

    {:ok, socket}
  end

  defp init_form(group, scope) do
    group |> Form.for_update(:update, scope: scope) |> to_form()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group presences={@presences} scope={@current_scope}>
        <h1 class="text-xl font-[100] flex items-center justify-between gap-4 mb-0">
          <div>
            <span class="font-[400] opacity-70">
              {@current_scope.tenant.name |> String.capitalize()}
            </span>
          </div>

          <button
            :if={Ash.can?({@group, :update}, @current_scope)}
            class="opacity-70 hover:opacity-100 transition-opacity cursor-pointer"
            phx-click="update_group_start"
          >
            <.icon name="hero-pencil-mini" />
          </button>
        </h1>

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
            form={@form}
          />
        </Modal.render>

        <.page_section title="Members">
          <Modal.render
            cancel="transfer_ownership_cancel"
            cancel_testid="transfer-ownership-cancel"
            open?={@transfer_ownership_form != nil}
            testid="transfer-ownership-dialog"
          >
            <.new_owner_selector group={@group} />
          </Modal.render>

          <Components.Group.memberships
            scope={@current_scope}
            event_transfer_ownership_start="transfer_ownership_start"
            memberships={@group.memberships}
          />
        </.page_section>

        <.page_section
          :if={Ash.can?({@group, :update}, @current_scope)}
          title="Orphan blocks"
        >
          <p class="text-sm opacity-70">
            Group-owned blocks that currently have no placements.
          </p>

          <ul :if={@orphan_blocks != []} class="menu bg-base-200 rounded-box w-full p-2 mt-4">
            <li :for={block <- @orphan_blocks}>
              <div class="flex items-center justify-between gap-4">
                <span class="truncate">{block_summary(block)}</span>
                <span class="font-thin text-xs opacity-60">{block.id}</span>
              </div>
            </li>
          </ul>

          <div :if={@orphan_blocks == []} class="mt-4 text-sm opacity-60">
            No orphan blocks.
          </div>
        </.page_section>
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
    {:noreply, QblogWeb.Presence.track_in_liveview(socket, url)}
  end

  @impl true
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
    scope = socket.assigns.current_scope
    form = socket.assigns.transfer_ownership_form

    case Form.submit(form, params: %{target_membership_id: target_membership_id}) do
      {:ok, _membership} ->
        group = socket.assigns.group |> Ash.load!([memberships: [:user]], scope: scope)

        {:noreply,
         socket
         |> assign(group: group, transfer_ownership_form: nil)}

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
  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(params))}
  end

  @impl true
  def handle_event("submit", %{"form" => params}, socket) do
    prev_group = socket.assigns.group

    case socket.assigns.form |> Form.submit(params: params) do
      {:ok, group} ->
        if prev_group.name != group.name do
          {:noreply, socket |> Phoenix.LiveView.redirect(to: ~p"/#{group.name}")}
        else
          {:noreply, socket |> assign(group: group, form: nil)}
        end

      {:error, form} ->
        {:noreply,
         socket
         |> assign(form: form)}
    end
  end

  defp new_owner_selector(assigns) do
    ~H"""
    <div class="alert bg-error/50 text-error-content mb-4">
      <.icon name="hero-exclamation-circle-micro self-start" class="size-6 opacity-50" />

      <div class="leading-tight space-y-2">
        <p class="font-bold">This action will transfer ownership to the selected member.</p>
        <p>
          You will become administrator of the group, and won't be able to transfer ownership again unless the new owner transfers it back to you.
        </p>
      </div>
    </div>

    <h3 class="text-xl mb-2">Select new owner</h3>

    <ul class="space-y-0.5">
      <li :for={membership <- @group.memberships |> Enum.filter(&(&1.type != :owner))}>
        <button
          class={[
            "w-full",
            "opacity-80 hover:opacity-100 transition-all cursor-pointer",
            "flex items-center justify-between gap-1 flex-wrap",
            "rounded bg-base-300 hover:bg-info/20 px-3 py-2"
          ]}
          phx-click="transfer_ownership"
          phx-value-target_membership_id={membership.id}
        >
          <span>{membership.user |> to_string()}</span>

          <span class={[
            "flex flex-wrap gap-1",
            "text-sm opacity-70"
          ]}>
            <span class={["badge badge-sm px-2 bg-base-300"]}>
              {membership.type |> Atom.to_string() |> String.capitalize()}
            </span>
          </span>
        </button>
      </li>
    </ul>
    """
  end

  defp block_summary(%{type: :text, data: %{"text" => text}}) when is_binary(text) do
    text
    |> String.trim()
    |> case do
      "" -> "Empty text block"
      text -> text
    end
    |> String.slice(0, 80)
  end

  defp block_summary(block) do
    block.type
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end
