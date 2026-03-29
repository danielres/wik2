defmodule Qblog.Blog do
  use Ash.Domain,
    otp_app: :qblog,
    extensions: [
      AshAdmin.Domain,
      AshPhoenix
    ]

  admin do
    show? true
  end

  forms do
    form :create_post, args: [:title, :body]
  end

  resources do
    resource Qblog.Blog.Post do
      define :list_posts,
        args: [],
        action: :read,
        default_options: [
          load: [:author],
          query: [sort: [inserted_at: :desc]]
        ]

      define :create_post, action: :create, args: [:title, :body]
      define :destroy_post_by_id, action: :destroy, get_by: [:id]
    end
  end
end
