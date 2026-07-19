defmodule WikWeb.Layouts.App do
  use WikWeb, :html

  alias WikWeb.Components
  alias WikWeb.Layouts
  alias WikWeb.TenantContext
  alias WikWeb.Components.UI

  embed_templates "layouts/*"

  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :context, :map, default: %{claimable_sources: []}
  attr :tenant_context, :map, default: nil

  attr :scope, :map, default: %{actor: nil, tenant: nil}

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <Layouts.flash_group flash={@flash} />

    <div class="grid grid-rows-[auto_1fr_auto] min-h-screen">
      <.app_header {assigns} />

      <div>{render_slot(@inner_block)}</div>

      <.app_footer scope={@scope} class="bg-base-300 py-4 border-t border-base-content/20" />
    </div>

    <Components.Modal.render
      :if={@tenant_context && @tenant_context[:membership_username_form] != nil}
      open?={true}
      testid="membership-username-dialog"
    >
      <Components.Membership.steps
        form={@tenant_context[:membership_username_form]}
        space={@scope.tenant}
      />
    </Components.Modal.render>
    """
  end

  def app_header(assigns) do
    ~H"""
    <header class={[
      "navbar bg-base-300/40 py-2 min-h-0 flex items-center",
      Layouts.container_class()
    ]}>
      <div class="flex-1 flex items-center">
        <.link navigate={~p"/"} class="opacity-30 hover:opacity-100 transition" aria-label="Home">
          <UI.icon_app />
        </.link>

        <.icon
          :if={@scope.tenant}
          name="hero-chevron-right-mini"
          class="size-4 opacity-20 mr-2 ml-0.5"
        />

        <div
          :if={@scope.tenant}
          class={[
            "max-w-[calc(100svw-9rem)] overflow-hidden truncate",
            "opacity-60 hover:opacity-100 transition text-sm"
          ]}
        >
          <.link navigate={~p"/#{@scope.tenant.slug}"}>
            {@scope.tenant |> to_string()}
          </.link>
        </div>
      </div>

      <div>
        <button
          class={[
            "opacity-80 hover:opacity-100 transition cursor-pointer",
            "relative"
          ]}
          popovertarget="popover-user-dropdown"
          style="anchor-name:--anchor-user-dropdown"
        >
          <Components.User.avatar
            membership={@tenant_context && @tenant_context[:current_membership]}
            tenant={@scope.tenant}
            size="sm"
          />

          <div
            :if={@context.claimable_sources != []}
            class={[
              "status status-accent animate-ping",
              "absolute top-0 left-0"
            ]}
          >
          </div>
        </button>

        <div
          class={[
            "min-w-36",
            "dropdown dropdown-end mt-1",
            "bg-base-300 dark:shadow-lg",
            "shadow",
            "border border-base-content/15",
            "rounded-box"
          ]}
          popover
          id="popover-user-dropdown"
          style="position-anchor:--anchor-user-dropdown"
        >
          <ul
            :if={@context.claimable_sources != []}
            class={[
              "menu w-full",
              "border-b-1 border-base-content/20"
            ]}
          >
            <li>
              <.link
                class="btn btn-sm btn-soft btn-accent border"
                navigate={~p"/auth/telegram"}
              >
                <span class="font-bold">New sources</span>
                <.icon name="hero-chevron-right-micro" />
              </.link>
            </li>
          </ul>

          <section
            :if={
              @scope.tenant && @tenant_context &&
                ((@tenant_context[:current_membership] &&
                    @tenant_context[:current_membership].username != nil) ||
                   TenantContext.space_admin?(@scope, @tenant_context))
            }
            class="p-4 border-b border-base-content/20"
          >
            <h3 class="uppercase tracking-wider text-xs opacity-50">Space</h3>
            <ul class={[
              "menu w-full"
            ]}>
              <li :if={
                @tenant_context[:current_membership] &&
                  @tenant_context[:current_membership].username != nil
              }>
                <.link navigate={
                  ~p"/#{@scope.tenant.slug}/wiki/members/#{@tenant_context[:current_membership].username}"
                }>
                  <Components.User.avatar
                    membership={@tenant_context && @tenant_context[:current_membership]}
                    tenant={@scope.tenant}
                    size="xs"
                  /> Profile
                </.link>
              </li>

              <li :if={TenantContext.space_admin?(@scope, @tenant_context)}>
                <.link navigate={~p"/#{@scope.tenant.slug}/admin"}>
                  <.icon name="hero-adjustments-horizontal-micro" class="" /> Admin
                </.link>
              </li>
            </ul>
          </section>

          <section class="p-4">
            <h3 class="uppercase tracking-wider text-xs opacity-50">App</h3>

            <ul class={[
              "menu w-full"
            ]}>
              <li>
                <.link navigate={~p"/sign-out"} class="">
                  <.icon name="hero-arrow-right-on-rectangle" /> Log out
                </.link>
              </li>

              <li>
                <.link navigate={~p"/me"} class="opacity-80 hover:opacity-100 transition">
                  <.icon name="hero-user" /> Account
                </.link>
              </li>
            </ul>

            <ul class={[]}>
              <li>
                <div class="w-min mx-auto">
                  <Layouts.theme_toggle />
                </div>
              </li>
            </ul>

            <ul
              :if={@scope.actor && @scope.actor.role == :superadmin}
              class={[
                "menu w-full"
              ]}
            >
              <li>
                <.link navigate={~p"/_"}>
                  <span class="badge badge-error">Superadmin</span>
                </.link>
              </li>
            </ul>
          </section>
        </div>
      </div>
    </header>
    """
  end

  attr :scope, :map, required: true
  attr :class, :string, default: ""

  def app_footer(assigns) do
    ~H"""
    <footer class={@class}>
      <div>
        <div class="hidden">
          <%= if @scope.actor do %>
            Privacy and moderation requests can be submitted <.link
              class="link link-hover font-medium"
              navigate={~p"/me/tickets/new"}
            >
                  in-app while logged in
                </.link>.
          <% else %>
            Privacy and moderation requests are handled in-app for logged-in users. If you cannot
            access your account, use the recovery path shared with your space operator.
          <% end %>
        </div>

        <div class={[
          "flex justify-center gap-6 text-xs",
          "[&_a]:flex [&_a]:items-center [&_a]:gap-1",
          "[&_a]:opacity-30 hover:[&_a]:opacity-70 [&_a:hover]:opacity-100 [&_a]:transition",
          "[&_.icon]:size-3"
        ]}>
          <.link :if={false} navigate={~p"/about"}>
            <.icon name="hero-information-circle-micro" />
            <span>about</span>
          </.link>

          <.link navigate={~p"/terms"}>
            <.icon name="hero-document-text-micro" />
            <span>terms</span>
          </.link>

          <.link navigate={~p"/privacy"}>
            <.icon name="hero-lock-closed-micro" />
            <span>privacy</span>
          </.link>

          <.link
            href="https://github.com/danielres/wik2"
            target="_blank"
            rel="noopener"
            class="space"
          >
            <.icon name="hero-code-bracket-micro" class="space-hover:hidden" />
            <.icon
              name="hero-arrow-top-right-on-square-micro"
              class="hidden space-hover:inline-block"
            />
            <span>github</span>
          </.link>
        </div>
      </div>
    </footer>
    """
  end
end
