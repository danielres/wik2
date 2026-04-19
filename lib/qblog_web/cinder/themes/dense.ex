defmodule QblogWeb.Cinder.Themes.Dense do
  use Cinder.Theme

  extends :daisy_ui

  set :table_class, "table"
  set :th_class, "py-1 sm:py-2 px-2 sm:px-4"
  set :td_class, "py-1 sm:py-2 px-2 sm:px-4"
  set :loading_container_class, "hidden"
end
