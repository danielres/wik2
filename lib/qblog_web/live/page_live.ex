defmodule QblogWeb.PageLive do
  use QblogWeb, :live_view

  alias Qblog.Blocks
  alias Qblog.Wiki

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  @impl true
  def mount(params, _session, socket) do
    path = Enum.join(params["path"], "/")
    {node, page} = path |> load_page_and_node(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(node: node, page: page, path: path)
     |> assign(editing_block_id: nil, form_edit_block: nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group scope={@current_scope}>
        <section class="space-y-4">
          <header class="space-y-1">
            <h1 class="text-2xl">{@node.title}</h1>
            <div class="text-sm opacity-60">page author: {@page.author |> to_string()}</div>
            <div class="text-sm opacity-60">
              inserted_at: {@page.inserted_at |> Utils.Time.relative()}
            </div>
          </header>

          <div class="space-y-2">
            <div
              :for={placement <- @page.block_placements}
              class="card bg-base-100"
              id={"block-#{placement.block.id}"}
            >
              <div class="card-body">
                <%= if @editing_block_id == placement.block.id do %>
                  <.form
                    for={@form_edit_block}
                    id={"edit-block-form-#{placement.block.id}"}
                    phx-submit="edit_block_submit"
                    phx-value-block_id={placement.block.id}
                  >
                    <.input
                      field={@form_edit_block[:text]}
                      id={"edit-block-text-#{placement.block.id}"}
                      type="textarea"
                    />

                    <div class="absolute bottom-2 right-2">
                      <.button class="btn btn-primary" type="submit">Save</.button>
                    </div>
                  </.form>
                <% else %>
                  <div class="absolute top-2 right-2 opacity-50 hover:opacity-100 transition">
                    <.button
                      class="btn btn-ghost btn-circle"
                      phx-click="edit_block_start"
                      phx-value-block_id={placement.block.id}
                      type="button"
                    >
                      <.icon name="hero-pencil-mini" />
                    </.button>
                  </div>
                  <div class="whitespace-pre-line">
                    {placement.block.data |> block_text() || "Empty block"}
                  </div>
                <% end %>
              </div>
            </div>

            <div
              :if={Enum.empty?(@page.block_placements)}
              class="rounded bg-base-300/30 p-8 text-center"
            >
              No blocks yet
            </div>
          </div>

          <div class="flex justify-end">
            <.button
              id="add-block"
              class="btn btn-primary"
              phx-click="add_block"
              type="button"
            >
              Add block
            </.button>
          </div>
        </section>
      </Layouts.group>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("add_block", _params, socket) do
    scope = socket.assigns.current_scope
    group = scope.tenant
    page = socket.assigns.page

    case group |> Blocks.create_group_owned_block_on_page(page, %{type: :text}, scope: scope) do
      {:ok, block} ->
        {node, page} = socket.assigns.path |> load_page_and_node(scope)

        {:noreply,
         socket
         |> assign(node: node, page: page)
         |> assign_edit_block(block.id)}

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "create_group_owned_block_on_page failed")
        {:noreply, socket |> put_flash(:error, "Could not add block to page")}
    end
  end

  @impl true
  def handle_event("edit_block_start", %{"block_id" => block_id}, socket) do
    {:noreply, socket |> assign_edit_block(block_id)}
  end

  @impl true
  def handle_event(
        "edit_block_submit",
        %{"block" => %{"text" => text}, "block_id" => block_id},
        socket
      ) do
    scope = socket.assigns.current_scope
    block = socket.assigns.page |> find_block(block_id)

    case block |> Blocks.update_block_text(text, scope: scope) do
      {:ok, _block} ->
        {node, page} = socket.assigns.path |> load_page_and_node(scope)

        {:noreply,
         socket
         |> assign(node: node, page: page, editing_block_id: nil, form_edit_block: nil)}

      {:error, error} ->
        Utils.Log.scoped_error(scope, error, "update_block_text failed")

        {:noreply,
         socket
         |> put_flash(:error, "Could not save block")
         |> assign(editing_block_id: block_id)
         |> assign_form_edit_block(text)}
    end
  end

  defp assign_edit_block(socket, block_id) do
    block = socket.assigns.page |> find_block(block_id)
    text = block.data |> block_text() || ""

    socket
    |> assign(editing_block_id: block_id)
    |> assign_form_edit_block(text)
  end

  defp assign_form_edit_block(socket, text) do
    socket |> assign(form_edit_block: %{"text" => text} |> to_form(as: :block))
  end

  defp block_text(%{"text" => text}) when is_binary(text), do: text
  defp block_text(_), do: nil

  defp find_block(page, block_id) do
    page.block_placements
    |> Enum.find(&(&1.block.id == block_id))
    |> then(& &1.block)
  end

  defp load_page_and_node(path, scope) do
    path
    |> Wiki.ensure_node_and_page_at_path(
      scope: scope,
      load: [:author, block_placements: :block]
    )
  end
end
