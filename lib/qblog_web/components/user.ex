defmodule QblogWeb.Components.User do
  use QblogWeb, :html

  attr :user, :map, required: true

  def avatar(assigns) do
    ~H"""
    <div class="avatar avatar-placeholder">
      <div class="bg-neutral text-neutral-content w-8 rounded-full">
        <span class="text-xs">
          {@user |> to_string() |> String.slice(0, 2) |> String.upcase()}
        </span>
      </div>
    </div>
    """
  end
end
