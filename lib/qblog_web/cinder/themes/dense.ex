defmodule QblogWeb.Cinder.Themes.Dense do
  use Cinder.Theme

  extends :daisy_ui

  set :table_class, "table table-xs"
  set :th_class, "py-1 px-2"
  set :td_class, "py-1 px-2"
  set :loading_container_class, "hidden"
end
