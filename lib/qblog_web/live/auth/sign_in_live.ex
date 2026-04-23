defmodule QblogWeb.Auth.SignInLive do
  use QblogWeb, :live_view

  @impl true
  def render(assigns) do
    ~H"""
    <div class="min-h-dvh grid place-items-center p-6" data-testid="sign-in-page">
      <QblogWeb.Components.Telegram.Widgets.login />
    </div>
    """
  end
end
