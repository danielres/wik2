defmodule WikWeb.Components.Block do
  use WikWeb, :html

  alias Wik.Blocks
  alias Wik.Blocks.Types
  alias Wik.Wiki.PageTree
  alias WikWeb.Components

  # Dispatchers per block type =================================================

  defp dispatch_render(assigns) do
    assigns.block.type |> type_to_module() |> then(& &1.render(assigns))
  end

  defp dispatch_form_fields(assigns) do
    assigns.block.type |> type_to_module() |> then(& &1.form_fields(assigns))
  end

  # Regular components =========================================================

  attr :block, :map, required: true
  attr :scope, :map, default: nil

  def preview(assigns) do
    ~H"""
    <div class="rounded bg-base-200/50 p-4">
      <.dispatch_render block={@block} page_tree={%PageTree{nodes: []}} scope={@scope} />
    </div>
    """
  end

  attr :lock, :map, default: nil
  attr :placement, :map, required: true
  attr :editing?, :boolean, default: false
  attr :editing_block_id, :string, default: nil
  attr :node, :map, default: nil
  attr :page_tree, :map, default: nil
  attr :path, :string, default: nil
  attr :scope, :map, default: nil

  def render(assigns) do
    block = assigns.placement.block

    assigns =
      assigns
      |> assign(:block_title, block_title(block))

    ~H"""
    <div class={[
      "relative",
      "@container/block",
      @lock && "ring-2 ring-warning/80 rounded p-1"
    ]}>
      <div :if={@lock} class="absolute left-0 top-0 z-10">
        <div class={[
          "absolute bottom-0",
          "rounded-t-md",
          "px-1 py-0.5",
          "bg-warning text-warning-content",
          "h-5 leading-none text-xs",
          "flex items-center gap-1"
        ]}>
          <WikWeb.Components.User.avatar
            membership={@lock[:membership]}
            tenant={@scope.tenant}
            size="xs"
          />
          <.icon name="hero-ellipsis-horizontal-mini" class="size-4 animate-pulse" />
        </div>
      </div>

      <div class="relative">
        <div
          :if={@editing_block_id == nil and @editing? and is_nil(@lock)}
          class={[
            "ACTION-BUTTONS",
            "w-full",
            "absolute bottom-0 z-10",
            "opacity-50 hover:opacity-100 transition-opacity",
            "text-accent"
          ]}
        >
          <Components.Block.ActionButtons.render placement={@placement} />
        </div>
      </div>

      <div
        class={[
          "BLOCK",
          "p-2",
          @editing? and @editing_block_id == nil and "ring-2 p-2 hover:ring-accent/70 cursor-pointer",
          @editing? and @editing_block_id != nil and "pointer-events-none opacity-50",
          "rounded ring-accent/20 transition",
          @editing? and "bg-accent/2 hover:bg-accent/8 transition",
          "space"
        ]}
        phx-click={@editing? and "block:edit_start"}
        phx-value-block_id={@placement.block.id}
      >
        <h2
          :if={@block_title != ""}
          class={[
            "text-xl font-bold mb-3"
          ]}
        >
          {@block_title}
        </h2>

        <div class={[
          @editing? and "pointer-events-none"
        ]}>
          <.dispatch_render
            block={@placement.block}
            node={@node}
            page_tree={@page_tree}
            path={@path}
            scope={@scope}
          />
        </div>
      </div>
    </div>
    """
  end

  # TODO: pass phx-submit and cancel_event (for phx-click) as attrs
  attr :form, :any, required: true
  attr :placement, :map, required: true
  attr :node, :map, default: nil
  attr :page_tree, :map, default: nil
  attr :path, :string, default: nil
  attr :scope, :map, default: nil
  attr :actions?, :boolean, default: true

  def form(assigns) do
    block = Map.get(assigns, :block, assigns.placement.block)

    assigns =
      assigns
      |> assign(:block, block)
      |> assign(:supports_title?, Blocks.Types.supports_title?(block.type))
      |> assign(:block_form_heading, block_form_heading(block.type))

    ~H"""
    <div
      class={["scroll-mt-20"]}
      id={"active-block-editor-#{@block.id}"}
    >
      <Phoenix.Component.form
        for={@form}
        id={"edit-block-form-#{@block.id}"}
        phx-submit="block:edit_submit"
        phx-value-block_id={@block.id}
        class={[
          "rounded-lg shadow-md space-y-4 ring-1 ring-opacity-5 ring-accent",
          "bg-accent/5",
          @block.type != :markdown && "p-4"
        ]}
      >
        <h3 :if={@block_form_heading} class="text-lg">
          {@block_form_heading}
        </h3>

        <.input
          :if={@supports_title?}
          field={@form[:title]}
          id={"edit-block-title-#{@block.id}"}
          label="Title (optional)"
          type="text"
        />

        <.dispatch_form_fields
          block={@block}
          form={@form}
          node={@node}
          page_tree={@page_tree}
          path={@path}
          scope={@scope}
        />

        <div class={[
          "sticky bottom-0",
          "bg-accent/7 backdrop-blur pt-4 rounded-b-box",
          "flex justify-between gap-2",
          @block.type == :markdown && "px-4 pb-4"
        ]}>
          <.button
            class="btn bg-base-300/40 hover:bg-error/50 backdrop-blur btn-sm"
            phx-click="block:edit_cancel"
            phx-value-block_id={@block.id}
            type="button"
          >
            Cancel
          </.button>

          <.button class="btn btn-accent btn-sm" type="submit">Save</.button>
        </div>
      </Phoenix.Component.form>
    </div>
    """
  end

  defp block_title(%{data: %{"title" => title}, type: type})
       when is_binary(title) and title != "" do
    if Blocks.Types.supports_title?(type), do: title, else: ""
  end

  defp block_title(_block), do: ""

  defp block_form_heading(type)
       when type in [:youtube, :soundcloud, :google_calendar, :google_maps] do
    "#{block_type_label(type)} block"
  end

  defp block_form_heading(_type), do: nil

  defp type_to_module(type) do
    Blocks.Types.modules()
    |> Enum.find_value(fn
      module ->
        if module.type() == type do
          type_name = module |> Module.split() |> List.last()
          Module.concat([Components.Block.Types, type_name])
        end
    end)
  end

  defp block_type_label(type) do
    case Types.available() |> Enum.find(&(&1.type == type)) do
      %{label: label} -> label
      nil -> type |> Atom.to_string() |> String.replace("_", " ") |> String.capitalize()
    end
  end
end
