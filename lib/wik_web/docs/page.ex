defmodule WikWeb.Docs.Page do
  @moduledoc false

  @callback slug() :: String.t()
  @callback title() :: String.t()
  @callback render(map()) :: Phoenix.LiveView.Rendered.t()

  defmacro __using__(_opts) do
    quote do
      use WikWeb, :html
      use MDEx, extension: [block_directive: true]

      @behaviour WikWeb.Docs.Page
    end
  end
end
