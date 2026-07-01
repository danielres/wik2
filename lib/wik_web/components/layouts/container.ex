defmodule WikWeb.Layouts.Container do
  use WikWeb, :html

  def container_class, do: "px-2 sm:pl-6 sm:pr-4 lg:pl-8 "

  attr :class, :string, default: ""
  slot :inner_block, required: true

  def container(assigns) do
    ~H"""
    <div class={container_class()}>
      <div class={[
        "max-md:mx-auto space-y-4",
        @class
      ]}>
        {render_slot(@inner_block)}
      </div>
    </div>
    """
  end
end
