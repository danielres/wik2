# defmodule WikWeb.Cinder.Themes.Dense0 do
#   use Cinder.Theme

#   # extends :daisy_ui

#   set :controls_class, "p-0 mb-4"
#   set :filter_container_class, "bg-base-200/50 rounded-md"
#   set :filter_title_class, "font-bold"
#   set :filter_header_class, "px-4 py-2"

#   set :filter_label_class, "text-xs font-bold"

#   set :filter_inputs_class,
#       "p-4 pt-0 text grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-x-2 gap-y-2"

#   set :filter_text_input_class, "input input-sm w-full"
#   set :search_input_class, "input input-sm pl-10 w-full"
#   set :table_class, "table bg-base-200/50"
#   set :row_class, "hover:bg-base-300/40"

#   set :th_class,
#       "py-1 sm:py-2 px-2 sm:px-4 bg-base-300 [&:first-child]:rounded-tl-md [&:last-child]:rounded-tr-md text-xs uppercase tracking-wider"

#   set :td_class, "py-1 sm:py-2 px-2 sm:px-4 align-top"
#   set :loading_container_class, "hidden"
#   set :list_item_class, "bg-base-300 p-4 rounded-md"
#   set :container_class, "border-none"
#   # set :controls_class, ""

#   # set :button_class, "border"
#   # set :button_danger_class, ""
#   # set :button_disabled_class, ""
#   # set :button_primary_class, "border-8"
#   # set :button_secondary_class, ""
# end

defmodule WikWeb.Cinder.Themes.Dense do
  use Cinder.Theme

  # Table
  set :container_class, "card"
  set :controls_class, "mb-1"
  set :table_wrapper_class, "overflow-x-auto bg-base-200 rounded-box"
  set :table_class, "table table-zebra w-full"
  set :thead_class, ""
  set :tbody_class, ""
  set :header_row_class, ""
  set :row_class, ""

  set :th_class,
      [
        "py-1 sm:py-2 px-2 sm:px-4 bg-base-300 [&:first-child]:rounded-tl-md [&:last-child]:rounded-tr-md text-xs uppercase tracking-wider"
      ]

  set :td_class, ""
  set :empty_class, "text-xs opacity-50 text-center pt-4"
  set :error_container_class, "alert alert-error"
  set :error_message_class, ""

  # Filters
  set :filter_container_class, "card  mb-6"
  set :filter_header_class, "card-body pb-4 flex flex-row items-center justify-between"
  set :filter_title_class, "card-title"
  set :filter_count_class, "badge badge-primary badge-sm"
  set :filter_clear_all_class, "btn btn-ghost btn-xs"

  set :filter_inputs_class,
      "flex flex-wrap gap-4 px-6"

  set :filter_input_wrapper_class, "form-control"
  set :filter_label_class, "label whitespace-nowrap"

  set :filter_clear_button_class, "btn btn-ghost btn-xs ml-2"
  # Input styling
  set :filter_text_input_class, "input input-bordered w-full"
  set :filter_date_input_class, "input input-bordered w-40"

  set :filter_number_input_class,
      "input input-bordered w-20 [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none [-moz-appearance:textfield]"

  set :filter_select_input_class, "select select-bordered w-48"
  # Select filter (dropdown interface)
  set :filter_select_container_class, "relative"

  set :filter_select_dropdown_class,
      "absolute z-50 w-full mt-1  border border-base-300 rounded-box max-h-60 overflow-auto"

  set :filter_select_option_class,
      "px-4 py-2 hover:bg-base-200 border-b border-base-300 last:border-b-0 cursor-pointer"

  set :filter_select_label_class, "text-sm cursor-pointer select-none flex-1"
  set :filter_select_empty_class, "px-3 py-2 text-base-content/50 italic text-sm"
  set :filter_select_arrow_class, ""
  set :filter_select_placeholder_class, "text-base-content/40"
  # Radio space filter
  set :filter_radio_space_container_class, "flex space-x-4 h-10 items-center"
  set :filter_radio_space_option_class, "flex items-center space-x-2"
  set :filter_radio_space_radio_class, "radio radio-sm"
  set :filter_radio_space_label_class, "text-sm cursor-pointer"
  # Checkbox filter
  set :filter_checkbox_container_class, "flex items-center h-10"
  set :filter_checkbox_input_class, "checkbox checkbox-sm mr-2"
  set :filter_checkbox_label_class, "text-sm cursor-pointer"
  # Multi-select filter (dropdown interface)
  set :filter_multiselect_container_class, "relative"

  set :filter_multiselect_dropdown_class,
      "absolute z-50 w-full mt-1 bg-base-100 border border-base-300 rounded-box max-h-60 overflow-auto"

  set :filter_multiselect_option_class,
      "px-3 py-2 hover:bg-base-200 border-b border-base-300 last:border-b-0 cursor-pointer"

  set :filter_multiselect_checkbox_class, "checkbox checkbox-sm mr-2"
  set :filter_multiselect_label_class, "text-sm cursor-pointer select-none flex-1"
  set :filter_multiselect_empty_class, "px-3 py-2 text-base-content/50 italic text-sm"
  # Multi-checkboxes filter
  set :filter_multicheckboxes_container_class, "space-y-2"
  set :filter_multicheckboxes_option_class, "flex items-center gap-2"
  set :filter_multicheckboxes_checkbox_class, "checkbox checkbox-primary"
  set :filter_multicheckboxes_label_class, "label-text cursor-pointer"
  # Range filters
  set :filter_range_container_class, "flex items-center gap-2"
  set :filter_range_input_space_class, ""

  set :filter_range_separator_class,
      "flex items-center px-1 text-sm font-medium text-base-content/60"

  # Pagination
  set :pagination_wrapper_class, "p-4"
  set :pagination_container_class, "flex items-center justify-end"
  set :pagination_info_class, "text-base-content/70 text-sm hidden"
  set :pagination_count_class, "text-base-content/50 text-xs ml-2"
  set :pagination_nav_class, "flex items-center space-x-1"
  set :pagination_button_class, "btn btn-sm"
  set :pagination_current_class, "btn btn-primary btn-sm"
  set :page_size_container_class, "flex items-center space-x-2 hidden"
  set :page_size_label_class, "text-base-content/70 text-sm"
  set :page_size_dropdown_class, "btn btn-sm btn-outline flex items-center cursor-pointer"

  set :page_size_dropdown_container_class,
      "bg-base-100 border border-base-300 rounded-box"

  set :page_size_option_class,
      "w-full text-left px-3 py-2 text-sm hover:bg-base-200 cursor-pointer"

  set :page_size_selected_class, "bg-primary text-primary-content"

  # Search
  set :search_input_class,
      "input input-bordered w-full pl-10"

  set :search_icon_class, "w-4 h-4"

  # Sorting
  set :sort_indicator_class, "ml-1 inline-flex items-center align-baseline"
  set :sort_arrow_wrapper_class, "inline-flex items-center"

  # ------
  set :sort_asc_icon_name, "hero-chevron-up"
  set :sort_asc_icon_class, "w-3 h-3"
  set :sort_desc_icon_name, "hero-chevron-down"
  set :sort_desc_icon_class, "w-3 h-3"
  set :sort_none_icon_name, "hero-chevron-up-down"
  set :sort_none_icon_class, "w-3 h-3 opacity-50"
  # ------

  # Loading
  set :loading_overlay_class, "absolute top-4 right-4"
  set :loading_container_class, "flex items-center text-sm text-primary"
  set :loading_spinner_class, "loading loading-spinner loading-sm mr-2"
  set :loading_spinner_circle_class, ""
  set :loading_spinner_path_class, ""

  # List
  set :list_container_class, "space-y-1"
  set :list_item_class, ""
  set :list_item_clickable_class, ""

  set :sort_container_class, ""
  set :sort_controls_class, "py-0 flex flex-row items-center gap-3  justify-end "
  set :sort_controls_label_class, "text-sm hidden"
  set :sort_buttons_class, "flex gap-2"
  set :sort_button_class, "btn btn-sm"
  set :sort_button_active_class, "btn-neutral"
  set :sort_button_inactive_class, "btn-ghost"
  set :sort_icon_class, "font-bold"
  set :sort_asc_icon, "↑"
  set :sort_desc_icon, "↓"

  # Grid
  set :grid_container_class, "grid gap-1"
  # set :grid_item_class, "card card-body bg-base-300 text-base-content"
  set :grid_item_class, ""

  # set :grid_item_clickable_class, "cursor-pointer hover:shadow-lg transition-shadow"
  set :grid_item_clickable_class, ""

  # Selection
  set :selection_checkbox_class, "checkbox checkbox-sm"
  set :selected_row_class, "bg-primary/5 even:bg-primary/10"
  set :grid_selection_overlay_class, "mb-2"
  set :selected_item_class, "ring-2 ring-primary"
  set :list_selection_container_class, "mb-2"
  set :bulk_actions_container_class, "flex flex-row gap-2 justify-end py-3 px-4"

  # Buttons
  set :button_class, "btn"
  set :button_primary_class, "btn-primary"
  set :button_secondary_class, "btn-neutral"
  set :button_danger_class, "btn-error"
  set :button_disabled_class, "btn-disabled"
end

defmodule WikWeb.Cinder.Themes.DenseNoSortIcons do
  use Cinder.Theme

  extends WikWeb.Cinder.Themes.Dense

  set :sort_asc_icon_class, "hidden"
  set :sort_desc_icon_class, "hidden"
  set :sort_none_icon_class, "hidden"

  set :sort_icon_class, "hidden"
  set :sort_asc_icon, ""
  set :sort_desc_icon, ""

  set :sort_button_active_class,
      WikWeb.Cinder.Themes.Dense.resolve_theme().sort_button_active_class <>
        " pointer-events-none"
end
