defmodule QblogWeb.HomeLive do
  use QblogWeb, :live_view

  alias Qblog.Accounts

  on_mount {QblogWeb.LiveUserAuth, :live_user_required}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, groups} = Accounts.list_groups()
    socket = socket |> assign(groups: groups)
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <div class="card bg-base-100 shadow">
        <div class="card-body">
          <div class="card-title">Your groups</div>
          <div class="flex gap-2">
            <%= for group <- @groups do %>
              <.link navigate={~p"/#{group.name}/blog"} class="btn btn-soft">
                {group.name}
              </.link>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
