defmodule QblogWeb.BlogLive do
  use QblogWeb, :live_view

  alias Qblog.Blog
  alias Qblog.Blog.Post
  alias AshPhoenix.Form

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(form: init_form())
     |> assign(posts: list_posts())
     |> assign(fields: Ash.Resource.Info.action(Post, :create).accept)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="text-2xl">Blog Posts</h1>

      <div class="grid sm:grid-cols-2 gap-4">
        <ul class="space-y-2">
          <%= for post <- @posts do %>
            <li class="card bg-base-100 shadow">
              <div class="card-body">
                <div class="card-title">{post.title}</div>
                {post.body}
              </div>
            </li>
          <% end %>
        </ul>

        <.form for={@form} phx-change="validate" phx-submit="submit">
          <div class="card bg-base-100/50 shadow">
            <div class="card-body">
              <.input
                :for={field <- @fields}
                type={Post.field_type_for(field)}
                field={@form[field]}
                label={field |> Phoenix.Naming.humanize()}
              />
              <.button type="submit" class="btn btn-primary mt-3">Create post</.button>
            </div>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(params))}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    case socket.assigns.form |> Form.submit(params: params) do
      {:ok, _post} ->
        {:noreply,
         socket
         |> put_flash(:success, "Post created successfully")
         |> assign(posts: list_posts())
         |> assign(form: init_form())}

      {:error, form} ->
        {:noreply,
         socket
         |> put_flash(:error, "Something went wrong")
         |> assign(form: form)}
    end
  end

  defp init_form() do
    Post |> Form.for_create(:create) |> to_form()
  end

  defp list_posts() do
    case Blog.list_posts() do
      {:ok, posts} ->
        posts |> Enum.reverse()

      {:error, _reason} ->
        []
    end
  end
end
