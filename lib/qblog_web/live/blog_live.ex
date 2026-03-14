defmodule QblogWeb.BlogLive do
  use QblogWeb, :live_view

  alias Qblog.Blog
  alias Qblog.Blog.Post
  alias AshPhoenix.Form
  alias Utils.Time
  alias Utils.Log

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(form: scope |> init_form())
     |> assign(posts: scope |> list_posts())
     |> assign(new_post_id: nil)
     |> assign(fields: Ash.Resource.Info.action(Post, :create).accept)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <h1 class="text-2xl font-[100]">Blog Posts</h1>
      <div class="grid sm:grid-cols-2 gap-4">
        <ul class="space-y-2">
          <%= for post <- @posts do %>
            <li
              id={"post-#{post.id}"}
              class={[
                "card bg-base-100 shadow transition-all duration-900 ",
                @new_post_id == post.id && "ring ring-primary"
              ]}
            >
              <div class="card-body">
                <h3 class="card-title items-baseline justify-between gap-1">
                  <div class="leading-tight">{post.title}</div>

                  <div class="text-sm font-thin opacity-80 text-end leading-tight">
                    <div>{post.author |> to_string()}</div>
                    <div>{Time.relative(post.inserted_at)}</div>
                  </div>
                </h3>

                {post.body}
              </div>
            </li>
          <% end %>
        </ul>

        <.form for={@form} phx-change="validate" phx-submit="submit">
          <div class="card bg-base-300">
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
      {:ok, post} ->
        Process.send_after(self(), :clear_new_post_id, 1000)

        scope = socket.assigns.current_scope

        {:noreply,
         socket
         |> assign(form: scope |> init_form())
         |> assign(posts: [post | socket.assigns.posts])
         |> assign(:new_post_id, post.id)}

      {:error, form} ->
        Log.scoped_error(socket.assigns.current_scope, form.errors, "Post create failed")
        {:noreply, socket |> assign(form: form)}
    end
  end

  def handle_info(:clear_new_post_id, socket) do
    {:noreply, socket |> assign(:new_post_id, nil)}
  end

  defp init_form(scope) do
    Post |> Form.for_create(:create, scope: scope) |> to_form()
  end

  defp list_posts(nil), do: []

  defp list_posts(scope) do
    with {:ok, posts} <- Blog.list_posts(scope: scope) do
      posts
    else
      err ->
        Log.scoped_error(scope, err, "list_posts failed")
        []
    end
  end
end
