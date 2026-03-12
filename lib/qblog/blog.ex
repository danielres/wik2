defmodule Qblog.Blog do
  use Ash.Domain, otp_app: :qblog, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Qblog.Blog.Post do
      define :create_post, args: [:title, :body], action: :create
      define :list_posts, args: [], action: :read
    end
  end
end
