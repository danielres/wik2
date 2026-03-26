defmodule QblogWeb.PageTreeEditorTestLive do
  use QblogWeb, :live_view

  alias Qblog.Wiki
  alias QblogWeb.PageTreeLive.PageTreeEditor

  @impl true
  def mount(_params, %{"tenant" => tenant}, socket) do
    current_scope = %{tenant: tenant}
    {:ok, page_tree} = Wiki.get_page_tree(scope: current_scope)

    {:ok,
     socket
     |> assign(current_scope: current_scope, page_tree: page_tree)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component
      module={PageTreeEditor}
      id="page_tree_editor"
      current_scope={@current_scope}
      editable?={true}
      page_tree={@page_tree}
    />
    """
  end

  @impl true
  def handle_info({:page_tree_updated, page_tree}, socket) do
    {:noreply, assign(socket, :page_tree, page_tree)}
  end
end
