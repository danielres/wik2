defmodule WikWeb.SpaceAdminLive do
  use WikWeb, :live_view
  use WikWeb.Presence.Handlers

  alias AshPhoenix.Form
  alias Wik.Access
  alias Wik.Blocks
  alias WikWeb.Components
  alias WikWeb.Components.Modal
  alias WikWeb.Components.UI
  alias WikWeb.SpaceAdminLive.AccessSources
  alias WikWeb.SpaceLive.OrphanBlocks

  on_mount {WikWeb.LiveUserAuth, :live_scope_required}
  on_mount {WikWeb.LiveUserAuth, :admin_required}
  on_mount {WikWeb.LiveUserAuth, :subscribe_presence}

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    space = socket.assigns.current_scope.tenant |> load_space(scope)
    orphan_blocks = Blocks.list_orphan_space_owned_blocks(space, scope: scope)
    {:ok, access_sources} = Access.list_space_access_sources(space)
    {:ok, google_email_rules} = Access.list_space_google_email_rules(space)

    socket =
      socket
      |> assign(form: nil)
      |> assign(:google_email_rule_form, google_email_rule_form())
      |> assign(:google_email_rules, google_email_rules)
      |> assign(space: space)
      |> assign(editing?: false)
      |> assign(orphan_block_selected: nil)
      |> assign_access_sources(access_sources)
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

  defp assign_access_sources(socket, access_sources) do
    assign(socket, access_source_groups: AccessSources.prepare(access_sources))
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
            <UI.button_unlock phx-click="toggle_edit_mode" />
          <% end %>
        </:actions>

        <UI.page_head>
          <UI.page_title>Admin</UI.page_title>
        </UI.page_head>

        <div class="space-y-8">
          <section>
            <h2 class="text-xl">Space</h2>

            <UI.editable_zone
              editing?={@editing?}
              title="Edit space"
              phx-click="update_space_start"
            >
              <div class="bg-base-200 p-2 rounded-box">
                <table class="table table-sm">
                  <tr>
                    <th class="w-0">Name</th>
                    <td>{@current_scope.tenant |> to_string()}</td>
                  </tr>
                  <tr>
                    <th>URL</th>
                    <td>
                      <span class="font-mono text-base-content/70">
                        /{@space.slug}
                      </span>
                    </td>
                  </tr>
                  <tr>
                    <th>Description</th>
                    <td>
                      <div class="text-sm text-base-content/70">{@space.description}</div>
                    </td>
                  </tr>
                </table>
              </div>
            </UI.editable_zone>
          </section>

          <section>
            <h2 class="text-xl">Wiki</h2>
            <div class={[
              "border rounded-box p-4 border-base-content/20",
              "space-y-2"
            ]}>
              <h3>
                Orphan blocks
                <span
                  :if={@orphan_blocks |> length() > 0}
                  class={[
                    "badge badge-xs",
                    "badge-warning"
                  ]}
                >
                  {@orphan_blocks |> length()}
                </span>
              </h3>
              <div :if={@orphan_blocks |> length() == 0} class="flex items-center gap-2">
                <div class="bg-success inline-flex aspect-square rounded-full">
                  <.icon name="hero-check-micro" />
                </div>
                <span class="text-sm opacity-70">No orphan blocks</span>
              </div>
              <OrphanBlocks.render
                :if={@can_destroy_orphan_blocks?}
                event_orphan_block_destroy="orphan_block_destroy"
                event_preview_cancel="orphan_block_preview_cancel"
                event_preview_start="orphan_block_preview_start"
                orphan_block_selected={@orphan_block_selected}
                orphan_blocks={@orphan_blocks}
                scope={@current_scope}
              />
            </div>
          </section>

          <section>
            <h2 class="text-xl flex items-center gap-2">
              <.icon name="hero-key-micro" /> Access sources
            </h2>

            <div class={[
              "border rounded-box p-4 border-base-content/20",
              "space-y-2"
            ]}>
              <AccessSources.render groups={@access_source_groups} />
            </div>
          </section>

          <section>
            <h2 class="text-xl flex items-center gap-2">
              <.icon name="hero-envelope-micro" /> Google account access
            </h2>

            <div class={[
              "border rounded-box p-4 border-base-content/20",
              "space-y-4"
            ]}>
              <.form
                for={@google_email_rule_form}
                id="google-email-access-form"
                phx-submit="google_email_rule_add"
                class="grid gap-3 md:grid-cols-[1fr_auto_auto]"
              >
                <.input
                  field={@google_email_rule_form[:email]}
                  label="Email"
                  placeholder="person@example.com"
                  type="email"
                />
                <.input
                  field={@google_email_rule_form[:membership_type]}
                  label="Access"
                  options={[Member: "member", Admin: "admin"]}
                  type="select"
                />
                <button
                  id="google-email-access-add"
                  type="submit"
                  class={[
                    "btn btn-primary rounded",
                    "md:self-end"
                  ]}
                >
                  Add
                </button>
              </.form>

              <div
                id="google-email-access-list"
                data-testid="google-email-access-list"
                class="space-y-2"
              >
                <div
                  :if={@google_email_rules == []}
                  data-testid="google-email-access-empty"
                  class="text-sm opacity-70"
                >
                  No Google email access rules yet.
                </div>

                <div
                  :for={email_rule <- @google_email_rules}
                  id={"google-email-access-#{email_rule.id}"}
                  data-testid={"google-email-access-#{email_rule.id}"}
                  class={[
                    "flex flex-wrap items-center gap-3",
                    "rounded-box bg-base-200 px-3 py-2"
                  ]}
                >
                  <div class="min-w-0 flex-1">
                    <div class={[
                      "truncate font-mono text-sm",
                      email_rule.revoked_at && "line-through opacity-60"
                    ]}>
                      {email_rule.email}
                    </div>
                    <div class="text-xs opacity-60">
                      {email_rule.membership_type |> Atom.to_string()}
                    </div>
                  </div>

                  <span
                    :if={email_rule.revoked_at}
                    class="badge badge-sm badge-neutral"
                  >
                    revoked
                  </span>
                  <button
                    :if={is_nil(email_rule.revoked_at)}
                    id={"google-email-access-revoke-#{email_rule.id}"}
                    type="button"
                    phx-click="google_email_rule_revoke"
                    phx-value-id={email_rule.id}
                    class="btn btn-sm btn-ghost rounded"
                  >
                    Revoke
                  </button>
                </div>
              </div>
            </div>
          </section>
        </div>
      </Layouts.space>
    </Layouts.app>

    <Modal.render
      cancel="update_space_cancel"
      cancel_testid="update-space-cancel"
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
  def handle_event("google_email_rule_add", %{"google_email_rule" => params}, socket) do
    space = socket.assigns.space
    actor = socket.assigns.current_scope.actor

    case Access.google_upsert_email_rule(space, params, actor) do
      {:ok, _email_rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Google email access added")
         |> refresh_google_email_rules()
         |> refresh_access_sources()}

      {:error, error} ->
        Utils.Log.scoped_error(
          socket.assigns.current_scope,
          error,
          "google email access add failed"
        )

        {:noreply,
         socket
         |> put_flash(:error, "Could not add Google email access")}
    end
  end

  @impl true
  def handle_event("google_email_rule_revoke", %{"id" => id}, socket) do
    actor = socket.assigns.current_scope.actor

    case Access.google_revoke_email_rule(id, actor) do
      {:ok, _email_rule} ->
        {:noreply,
         socket
         |> put_flash(:info, "Google email access revoked")
         |> refresh_google_email_rules()
         |> refresh_access_sources()}

      {:error, error} ->
        Utils.Log.scoped_error(
          socket.assigns.current_scope,
          error,
          "google email access revoke failed"
        )

        {:noreply,
         socket
         |> put_flash(:error, "Could not revoke Google email access")}
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

  defp google_email_rule_form do
    to_form(%{"email" => "", "membership_type" => "member"}, as: :google_email_rule)
  end

  defp refresh_google_email_rules(socket) do
    {:ok, google_email_rules} = Access.list_space_google_email_rules(socket.assigns.space)

    socket
    |> assign(:google_email_rule_form, google_email_rule_form())
    |> assign(:google_email_rules, google_email_rules)
  end

  defp refresh_access_sources(socket) do
    {:ok, access_sources} = Access.list_space_access_sources(socket.assigns.space)

    assign_access_sources(socket, access_sources)
  end

  defp space_params(%{"name" => name} = params) do
    Map.put(params, "slug", Utils.Slugify.generate(name))
  end

  defp space_params(params), do: params
end
