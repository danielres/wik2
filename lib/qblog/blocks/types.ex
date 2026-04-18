defmodule Qblog.Blocks.Types do
  alias Qblog.Blocks.Types.ChildPages
  alias Qblog.Blocks.Types.GoogleCalendar
  alias Qblog.Blocks.Types.GoogleMaps
  alias Qblog.Blocks.Types.Markdown
  alias Qblog.Blocks.Types.Members
  alias Qblog.Blocks.Types.SoundCloud
  alias Qblog.Blocks.Types.Text
  alias Qblog.Blocks.Types.YouTube

  @modules [
    ChildPages,
    GoogleCalendar,
    GoogleMaps,
    Markdown,
    Members,
    SoundCloud,
    Text,
    YouTube
  ]

  def modules, do: @modules

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
