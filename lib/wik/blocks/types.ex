defmodule Wik.Blocks.Types do
  alias Wik.Blocks.Types.Backlinks
  alias Wik.Blocks.Types.ChildPages
  alias Wik.Blocks.Types.GoogleCalendar
  alias Wik.Blocks.Types.GoogleMaps
  alias Wik.Blocks.Types.Markdown
  alias Wik.Blocks.Types.Members
  alias Wik.Blocks.Types.Pages
  alias Wik.Blocks.Types.SoundCloud
  alias Wik.Blocks.Types.Text
  alias Wik.Blocks.Types.YouTube

  @modules [
    Backlinks,
    ChildPages,
    GoogleCalendar,
    GoogleMaps,
    Markdown,
    Members,
    Pages,
    SoundCloud,
    Text,
    YouTube
  ]

  def modules, do: @modules

  def supports_title?(type) do
    type |> type_to_module() |> then(& &1.supports_title?())
  end

  def supports_history?(type) do
    type |> type_to_module() |> then(& &1.supports_history?())
  end

  def available do
    @modules
    |> Enum.map(fn module ->
      %{label: module.label(), type: module.type()}
    end)
  end

  def default_data(type) do
    type |> type_to_module() |> then(& &1.default_data())
  end

  def block_to_form_params(block, params, page_tree) do
    block.type |> type_to_module() |> then(& &1.block_to_form_params(block, params, page_tree))
  end

  def update_block(block, params, opts) do
    block.type |> type_to_module() |> then(& &1.update_block(block, params, opts))
  end

  def create_initial_version(block, opts) do
    block.type |> type_to_module() |> then(& &1.create_initial_version(block, opts))
  end

  def version_to_text(block, version, opts) do
    block.type |> type_to_module() |> then(& &1.version_to_text(block, version, opts))
  end

  def validate_data(type, data) do
    case type_to_module(type) do
      nil -> {:error, field: :type, message: "unsupported block type"}
      module -> module.validate_data(data)
    end
  end

  defp type_to_module(type) do
    @modules
    |> Enum.find_value(fn
      module ->
        if module.type() == type, do: module
    end)
  end
end
