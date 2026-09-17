defmodule Wik.Blocks.Types.LibraryEntry do
  @behaviour Wik.Blocks.Types.Behaviour

  def label, do: "Library entry"
  def type, do: :library_entry
  def supports_history?, do: false
  def supports_title?, do: false
  def default_data, do: %{}
  def create_initial_version(_block, _opts), do: :ok

  def block_to_form_params(_block, _params, _page_tree), do: %{}
  def update_block(_block, _params, _opts), do: {:error, :unsupported}

  def validate_data(data) when map_size(data) == 0, do: :ok

  def validate_data(_data),
    do: {:error, field: :data, message: "library entry blocks use a reference"}

  def version_to_text(_block, _version, _opts), do: {:error, :unsupported}
end
