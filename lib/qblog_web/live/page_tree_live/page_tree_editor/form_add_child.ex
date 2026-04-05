defmodule QblogWeb.PageTreeLive.PageTreeEditor.FormAddChild do
  import QblogWeb.CoreComponents

  use QblogWeb, :live_component
  use Phoenix.Component

  alias QblogWeb.PageTreeLive.Helpers
  alias QblogWeb.PageTreeLive.PageTreeEditor
  alias QblogWeb.PageTreeLive.PageTreeEditor.FlowAddChild
  alias Utils.Log

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)}
  end

  attr(:current_scope, :any, required: true)
  attr(:editor_id, :string, required: true)
  attr(:flow, :map, required: true)
  attr(:page_tree, :map, required: true)

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} data-testid="add-child-modal">
      <h3 class="mb-2" data-testid="add-child-heading">
        <span>Add child under</span>
        <span class="font-bold" data-testid="add-child-parent-slug">
          "{Helpers.get_node_by_id(@page_tree.nodes, @flow.parent_id).slug}"
        </span>
      </h3>

      <.add_child_form
        form={@flow.form}
        parent_id={@flow.parent_id}
        target={@myself}
      />
    </div>
    """
  end

  @impl true
  def handle_event("add_child", %{"form" => params}, socket) do
    flow = socket.assigns.flow
    page_tree = socket.assigns.page_tree
    scope = socket.assigns.current_scope

    case flow |> FlowAddChild.submit(page_tree, %{"form" => params}, scope) do
      {:ok, flow, page_tree} ->
        send(self(), {:page_tree_updated, page_tree})

        send_update(
          PageTreeEditor,
          id: socket.assigns.editor_id,
          flow_add_child: flow
        )

        {:noreply,
         socket
         |> assign(flow: flow, page_tree: page_tree)}

      {:error, flow, err} ->
        Log.scoped_error(scope, err, "page_tree add_child failed")
        {:noreply, socket |> assign(flow: flow)}
    end
  end

  @impl true
  def handle_event("add_child_validate", %{"form" => params}, socket) do
    {:noreply,
     socket
     |> assign(flow: socket.assigns.flow |> FlowAddChild.validate(params))}
  end

  attr(:form, :any, required: true)
  attr(:parent_id, :map, default: nil)
  attr(:target, :any, required: true)

  defp add_child_form(assigns) do
    auto_slug = assigns.form[:title].value |> Utils.Slugify.generate()

    assigns =
      assigns
      |> assign(auto_slug: auto_slug)
      |> assign(form_errors: AshPhoenix.Form.errors(assigns.form))

    ~H"""
    <.form
      autocomplete="off"
      data-testid="add-child-form"
      for={@form}
      phx-change="add_child_validate"
      phx-submit="add_child"
      phx-target={@target}
    >
      <div class="card bg-base-100">
        <div class="card-body [&_input]:bg-base-200">
          <.input
            data-testid="add-child-parent-id"
            field={@form[:parent_id]}
            type="hidden"
            value={@parent_id}
          />

          <.input
            data-testid="add-child-title"
            field={@form[:title]}
            label="title"
            phx-hook="CapitalizeFirstLetter"
          />

          <div class={[
            "flex items-baseline",
            "[&_._prepend]:w-2 [&_.alert]:-ml-2"
          ]}>
            <span
              :if={@form[:title].value}
              class={[
                "_prepend",
                "font-mono opacity-80"
              ]}
            >
              /
            </span>

            <.input hidden field={@form[:slug]} value={@auto_slug} />

            <div class={["flex-grow"]}>
              <div
                class={[
                  "opacity-80",
                  "font-mono",
                  "w-full",
                  "!bg-transparent"
                ]}
                data-testid={data_auto_slug_testid(@auto_slug)}
              >
                {@auto_slug}
              </div>
            </div>
          </div>

          <div :for={{:nodes, msg} <- @form_errors} data-testid="add-child-error-nodes">
            <.error>{msg}</.error>
          </div>

          <.button
            class="btn btn-primary"
            data-testid="add-child-submit"
            type="submit"
          >
            Add
          </.button>
        </div>
      </div>
    </.form>
    """
  end

  defp data_auto_slug_testid(""), do: "add-child-auto-slug-empty"
  defp data_auto_slug_testid(auto_slug), do: "add-child-auto-slug-#{auto_slug}"
end
