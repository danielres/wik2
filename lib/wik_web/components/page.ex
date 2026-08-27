defmodule WikWeb.Components.Page do
  use WikWeb, :html

  alias Wik.Wiki.PageTree
  alias WikWeb.Components.UI

  attr :include_current?, :boolean, default: true
  attr :node, :map, required: true
  attr :page_tree, :map, required: true
  attr :scope, :map, required: true
  attr :trailing_separator?, :boolean, default: false
  attr :class, :any, default: ""

  def breadcrumbs(assigns) do
    path = breadcrumb_path(assigns.page_tree, assigns.node)

    assigns =
      assigns
      |> assign(:items, breadcrumb_items(assigns.page_tree, path, assigns.include_current?))

    ~H"""
    <div :if={@items != []} class={["flex items-center gap-1", @class]}>
      <nav class="breadcrumbs p-0">
        <ul>
          <li :for={item <- @items}>
            <.link
              class="opacity-60 hover:opacity-100 transition-opacity"
              navigate={build_page_path(@scope, item.path)}
            >
              {item.title}
            </.link>
          </li>

          <li :if={@trailing_separator?} class=""></li>
        </ul>
      </nav>
    </div>
    """
  end

  attr :action_label, :string, required: true
  attr :cancel_event, :string, default: nil
  attr :cancel_testid, :string, default: nil
  attr :event_submit, :string, required: true
  attr :event_validate, :string, required: true
  attr :form, :any, required: true
  attr :include_parent_id?, :boolean, default: false
  attr :parent_id, :integer, default: nil
  attr :target, :any, default: nil
  attr :testid_prefix, :string, required: true

  def node_title_form(assigns) do
    title_value = Phoenix.HTML.Form.input_value(assigns.form, :title) || ""
    auto_slug = Utils.Slugify.generate(title_value)

    assigns =
      assigns
      |> assign(:auto_slug, auto_slug)
      |> assign(:form_errors, AshPhoenix.Form.errors(assigns.form))
      |> assign(:title_value, title_value)

    ~H"""
    <Phoenix.Component.form
      autocomplete="off"
      data-testid={"#{@testid_prefix}-form"}
      for={@form}
      phx-change={@event_validate}
      phx-submit={@event_submit}
      phx-target={@target}
    >
      <div class="card bg-base-100">
        <div class="card-body [&_input]:bg-base-200">
          <.input
            :if={@include_parent_id?}
            data-testid={"#{@testid_prefix}-parent-id"}
            field={@form[:parent_id]}
            type="hidden"
            value={@parent_id}
          />

          <.input
            data-testid={"#{@testid_prefix}-title"}
            field={@form[:title]}
            label="Title"
            phx-hook="CapitalizeFirstLetter"
          />

          <.input hidden field={@form[:slug]} value={@auto_slug} />

          <UI.Forms.autoslug_preview
            data-testid={autoslug_testid(@testid_prefix, @auto_slug)}
            source_value={@title_value}
          />

          <div :for={{:nodes, message} <- @form_errors} data-testid={"#{@testid_prefix}-error-nodes"}>
            <.error>{message}</.error>
          </div>

          <div class="flex items-center justify-between gap-2">
            <button
              :if={@cancel_event != nil}
              class="btn btn-sm btn-soft"
              data-testid={@cancel_testid}
              id={"#{@testid_prefix}-cancel"}
              phx-click={@cancel_event}
              phx-target={@target}
              type="button"
            >
              Cancel
            </button>

            <.button
              class="btn btn-primary"
              data-testid={"#{@testid_prefix}-submit"}
              id={"#{@testid_prefix}-submit"}
              type="submit"
            >
              {@action_label}
            </.button>
          </div>
        </div>
      </div>
    </Phoenix.Component.form>
    """
  end

  def breadcrumb_items(page_tree, path, include_current? \\ true)
  def breadcrumb_items(%PageTree{}, nil, _include_current?), do: []

  def breadcrumb_items(%PageTree{nodes: nodes}, path, include_current?)
      when is_binary(path) do
    path
    |> path_prefixes()
    |> then(fn items ->
      if include_current?, do: items, else: Enum.drop(items, -1)
    end)
    |> Enum.map(fn prefix ->
      case PageTree.get_node_by_path(nodes, prefix) do
        {:ok, node} ->
          %{
            node_id: node.id,
            path: prefix,
            title: node.title
          }

        _ ->
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp build_page_path(%{tenant: tenant}, path) do
    "/" <> tenant.slug <> "/wiki" <> "/" <> path
  end

  defp autoslug_testid(prefix, ""), do: "#{prefix}-auto-slug-empty"
  defp autoslug_testid(prefix, auto_slug), do: "#{prefix}-auto-slug-#{auto_slug}"

  defp breadcrumb_path(%PageTree{}, %{path: path}) when is_binary(path), do: path

  defp breadcrumb_path(%PageTree{nodes: nodes}, %{id: id}),
    do: PageTree.get_node_path(nodes, id)

  defp breadcrumb_path(%PageTree{nodes: nodes}, %{node_id: node_id}),
    do: PageTree.get_node_path(nodes, node_id)

  defp path_prefixes(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.reduce({[], ""}, fn segment, {prefixes, current} ->
      prefix =
        case current do
          "" -> segment
          current -> current <> "/" <> segment
        end

      {prefixes ++ [prefix], prefix}
    end)
    |> elem(0)
  end
end
