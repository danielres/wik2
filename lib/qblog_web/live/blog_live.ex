defmodule QblogWeb.BlogLive do
  use QblogWeb, :live_view

  alias Qblog.Blog

  def mount(_params, _session, socket) do
    case Blog.list_posts() do
      {:ok, posts} ->
        {:ok, assign(socket, posts: posts)}

      {:error, _reason} ->
        {:ok, assign(socket, posts: [])}
    end
  end

  def render(assigns) do
    ~H"""
    <h1 class="text-2xl font-bold mb-4">Blog Posts</h1>
    <ul>
      <%= for post <- @posts do %>
        <li class="mb-2">
          <h2 class="text-xl font-semibold">{post.title}</h2>
          <p>{post.body}</p>
        </li>
      <% end %>
    </ul>
    """
  end
end
