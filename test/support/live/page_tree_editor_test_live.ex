defmodule WikWeb.PageTreeEditorTestLive do
  use WikWeb, :live_view

  alias Wik.Accounts
  alias Wik.Accounts.User
  alias Wik.Wiki.PageTree
  alias WikWeb.PageTreeLive.PageTreeEditor

  @impl true
  def mount(_params, %{"actor_id" => actor_id, "tenant" => tenant_slug} = session, socket) do
    {:ok, actor} = Ash.get(User, actor_id, authorize?: false, domain: Wik.Accounts)
    {:ok, tenant} = Accounts.get_space_by_slug(tenant_slug, authorize?: false)
    current_scope = %{actor: actor, tenant: tenant}
    {:ok, page_tree} = PageTree.ensure(scope: current_scope)
    editable? = Map.get(session, "editable?", Map.get(session, :editable?, true))

    {:ok,
     socket
     |> assign(current_scope: current_scope, page_tree: page_tree, editable?: editable?)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={PageTreeEditor}
      id="page_tree_editor"
      current_scope={@current_scope}
      editable?={@editable?}
      page_tree={@page_tree}
    />
    """
  end

  @impl true
  def handle_info({:page_tree_updated, page_tree}, socket) do
    {:noreply, assign(socket, :page_tree, page_tree)}
  end
end
