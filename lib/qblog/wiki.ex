defmodule Qblog.Wiki do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  admin do
    show? true
  end

  resources do
    resource Qblog.Wiki.PageTree do
      define :get_page_tree, action: :get_or_create_page_tree, args: []
    end

    resource Qblog.Wiki.Page
  end
end
