defmodule QblogWeb.Components.Block do
  use QblogWeb, :html

  alias Qblog.Blocks
  alias Qblog.Wiki.PageTree
  alias QblogWeb.Components

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
      "[&:has(>.ACTION-BUTTONS:hover)_.BLOCK]:ring-secondary/70",
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
          <QblogWeb.Components.User.avatar
            link?
            tenant={@scope.tenant}
            user={@lock.user}
            size="xs"
          />
          <.icon name="hero-ellipsis-horizontal-mini" class="size-4 animate-pulse" />
        </div>
      </div>

      <div
        :if={@editing? and is_nil(@lock)}
        class={[
          "ACTION-BUTTONS",
          "opacity-50 hover:opacity-100 transition-opacity",
          "mb-1"
        ]}
      >
        <Components.Block.ActionButtons.render placement={@placement} />
      </div>

      <div
        class={[
          "BLOCK",
          @editing? and "ring-2 p-2 hover:ring-secondary/70 cursor-pointer",
          @editing? and "[&>*]:pointer-events-none",
          "rounded ring-secondary/10 transition",
          "group"
        ]}
        phx-click={@editing? and "edit_block_start"}
        phx-value-block_id={@placement.block.id}
      >
        <h2
          :if={@block_title != ""}
          class={[
            "text-xl font-bold mb-3",
            "opacity-60 transition",
            "group-hover:opacity-90"
          ]}
        >
          {@block_title}
        </h2>

        <.dispatch_render
          block={@placement.block}
          node={@node}
          page_tree={@page_tree}
          path={@path}
          scope={@scope}
        />
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

  def form(assigns) do
    assigns =
      assigns
      |> assign_new(:block, fn -> assigns.placement.block end)
      |> assign(:supports_title?, Blocks.Types.supports_title?(assigns.placement.block.type))

    ~H"""
    <Phoenix.Component.form
      for={@form}
      id={"edit-block-form-#{@block.id}"}
      phx-submit="edit_block_submit"
      phx-value-block_id={@block.id}
      class={[
        "rounded-lg shadow-md space-y-4 ring-1 ring-opacity-5 ring-secondary",
        @block.type != :markdown && "bg-base-200 p-4"
      ]}
    >
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
        "flex justify-between gap-2",
        @block.type == :markdown && "px-4 pb-4"
      ]}>
        <.button
          class="btn btn-soft btn-sm"
          phx-click="edit_block_cancel"
          phx-value-block_id={@block.id}
          type="button"
        >
          Cancel
        </.button>

        <.button class="btn btn-primary btn-sm" type="submit">Save</.button>
      </div>
    </Phoenix.Component.form>
    """
  end

  defp block_title(%{data: %{"title" => title}, type: type})
       when is_binary(title) and title != "" do
    if Blocks.Types.supports_title?(type), do: title, else: ""
  end

  defp block_title(_block), do: ""

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
end
