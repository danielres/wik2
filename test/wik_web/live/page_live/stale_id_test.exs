defmodule WikWeb.PageLive.StaleIdTest do
  use Wik.DataCase, async: true

  import Phoenix.Component, only: [assign: 2]

  alias Phoenix.LiveView.Socket
  alias Wik.Scope
  alias WikWeb.PageLive
  alias WikWeb.PageLive.BlockActions
  alias WikWeb.PageLive.PageState

  test "page state returns explicit not_found results for missing ids" do
    page = %{block_placements: []}

    assert {:error, :not_found} = PageState.get_block(page, "missing-block")
    assert {:error, :not_found} = PageState.get_placement(page, "missing-placement")
  end

  test "block actions keep the socket stable when block ids are stale" do
    socket =
      socket_fixture(
        editing?: true,
        editing_block_id: "stale-block",
        form_edit_block: %{source: :fake}
      )

    socket = BlockActions.start_edit(socket, "stale-block")

    assert flash(socket, :error) == "That block is no longer available"
    assert socket.assigns.editing_block_id == "stale-block"

    socket = BlockActions.save_edit(socket, "stale-block", %{"title" => "Ignored"})

    assert flash(socket, :error) == "That block is no longer available"
    assert socket.assigns.editing_block_id == nil
    assert socket.assigns.form_edit_block == nil
  end

  test "block placement actions keep the socket stable when placement ids are stale" do
    socket = socket_fixture(block_info_placement: %{id: "existing"})

    for action <- [
          &BlockActions.destroy/2,
          &BlockActions.move_up/2,
          &BlockActions.move_down/2,
          &BlockActions.toggle_aside/2
        ] do
      result_socket = action.(socket, "stale-placement")
      assert flash(result_socket, :error) == "That block is no longer available"
    end

    assert {:noreply, result_socket} =
             PageLive.handle_event(
               "block_info:show",
               %{"placement_id" => "stale-placement"},
               socket
             )

    assert flash(result_socket, :error) == "That block is no longer available"
    assert result_socket.assigns.block_info_placement == nil
  end

  defp socket_fixture(extra_assigns) do
    base_assigns = %{
      block_info_placement: nil,
      current_scope: %Scope{
        actor: %{id: "user-1"},
        tenant: %{id: "space-1", name: "space-1"}
      },
      editing?: false,
      editing_block_id: nil,
      form_edit_block: nil,
      locks: %{},
      page: %{block_placements: []},
      page_tree: %{nodes: []},
      presences: %{},
      tab_id: "tab-1"
    }

    %Socket{assigns: %{__changed__: %{}, flash: %{}}}
    |> assign(Map.merge(base_assigns, Map.new(extra_assigns)))
  end

  defp flash(socket, kind) do
    Phoenix.Flash.get(socket.assigns.flash, kind)
  end
end
