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
      define :get_page_tree, action: :read, get_by: [:group_id]
    end
  end
end
