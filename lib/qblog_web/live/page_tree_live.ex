defmodule QblogWeb.PageTreeLive do
  use QblogWeb, :live_view
  alias QblogWeb.PageTreeLive.PageTreeEditor

  on_mount {QblogWeb.LiveUserAuth, :live_scope_required}

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} scope={@current_scope}>
      <Layouts.group scope={@current_scope}>
        <.live_component
          current_scope={@current_scope}
          editable?={true}
          id="page_tree_editor"
          module={PageTreeEditor}
        />
      </Layouts.group>
    </Layouts.app>
    """
  end
end
