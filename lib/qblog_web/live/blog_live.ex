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

    if connected?(socket), do: QblogWeb.Endpoint.subscribe("post:created:#{scope.tenant}")

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
      <Layouts.group scope={@current_scope}>
        <h1 class="text-2xl font-[100]">Blog Posts</h1>
        <div class="grid sm:grid-cols-2 gap-4">
          <ul class="space-y-2">
            <%= for post <- @posts do %>
              <li
                id={"post-#{post.id}"}
                class={[
                  "card bg-base-100 shadow transition-opacity duration-900",
                  if(@new_post_id == post.id, do: "opacity-0", else: "opacity-100")
                ]}
              >
                <button
                  :if={Ash.can?({post, :destroy}, @current_scope)}
                  class={[
                    "absolute right-2 top-2",
                    "size-4 text-xs",
                    "cursor-pointer",
                    "opacity-50 hover:opacity-100 transition"
                  ]}
                  phx-click="destroy-post"
                  phx-value-post_id={post.id}
                >
                  ✕
                </button>

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
      </Layouts.group>
    </Layouts.app>
    """
  end

  def handle_event("validate", %{"form" => params}, socket) do
    {:noreply, socket |> assign(form: socket.assigns.form |> Form.validate(params))}
  end

  def handle_event("destroy-post", %{"post_id" => post_id}, socket) do
    scope = socket.assigns.current_scope

    socket =
      case Blog.destroy_post_by_id(post_id, scope: scope) do
        :ok ->
          socket |> assign(posts: scope |> list_posts())

        _ ->
          socket
      end

    {:noreply, socket}
  end

  def handle_event("submit", %{"form" => params}, socket) do
    case socket.assigns.form |> Form.submit(params: params) do
      {:ok, _post} ->
        scope = socket.assigns.current_scope
        {:noreply, socket |> assign(form: scope |> init_form())}

      {:error, form} ->
        Log.scoped_error(socket.assigns.current_scope, form.errors, "Post create failed")
        {:noreply, socket |> assign(form: form)}
    end
  end

  def handle_info(:clear_new_post_id, socket) do
    {:noreply, socket |> assign(:new_post_id, nil)}
  end

  def handle_info(%{topic: "post:created:" <> _tenant, payload: %{data: new_post}}, socket) do
    Process.send_after(self(), :clear_new_post_id, 200)
    scope = socket.assigns.current_scope

    socket =
      if Ash.can?({new_post, :read}, scope: scope) do
        socket
        |> assign(posts: socket.assigns.posts |> List.insert_at(0, new_post))
        |> assign(:new_post_id, new_post.id)
      else
        socket
      end

    {:noreply, socket}
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
