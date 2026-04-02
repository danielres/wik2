defmodule Qblog.Test.DocFormatter do
  use GenServer

  import ExUnit.Formatter,
    only: [format_test_all_failure: 5, format_test_failure: 5, format_times: 1]

  @default_colors [
    diff_delete: :red,
    diff_delete_whitespace: IO.ANSI.color_background(2, 0, 0),
    diff_insert: :green,
    diff_insert_whitespace: IO.ANSI.color_background(0, 2, 0),
    success: [:bright, :green],
    invalid: :yellow,
    skipped: :yellow,
    failure: :red,
    error_info: :red,
    extra_info: :cyan,
    location_info: [:bright, :black],
    module_info: [:bright, :cyan],
    describe_info: [:bright, :cyan]
  ]

  def init(opts) do
    {:ok,
     %{
       colors: colors(opts),
       excluded: 0,
       failed_modules: [],
       opts: opts,
       skipped: 0,
       tests: []
     }}
  end

  def handle_cast({:suite_started, _opts}, state) do
    {:noreply, state}
  end

  def handle_cast({:test_finished, %ExUnit.Test{} = test}, state) do
    state =
      state
      |> track_test(test)
      |> track_skipped(test)
      |> track_excluded(test)

    {:noreply, state}
  end

  def handle_cast(
        {:module_finished, %ExUnit.TestModule{state: {:failed, failures}} = test_module},
        state
      ) do
    failed_modules = [{test_module, failures} | state.failed_modules]
    {:noreply, %{state | failed_modules: failed_modules}}
  end

  def handle_cast({:module_finished, %ExUnit.TestModule{}}, state) do
    {:noreply, state}
  end

  def handle_cast({:suite_finished, times_us}, state) do
    IO.puts("")
    print_modules(state.tests, state)
    print_failures(state)
    print_summary(state, times_us)
    {:noreply, state}
  end

  def handle_cast(_, state) do
    {:noreply, state}
  end

  defp track_test(state, test) do
    %{state | tests: [test | state.tests]}
  end

  defp track_skipped(state, %ExUnit.Test{state: {:skipped, _reason}}) do
    %{state | skipped: state.skipped + 1}
  end

  defp track_skipped(state, _test), do: state

  defp track_excluded(state, %ExUnit.Test{state: {:excluded, _reason}}) do
    %{state | excluded: state.excluded + 1}
  end

  defp track_excluded(state, _test), do: state

  defp print_modules(tests, state) do
    tests
    |> Enum.sort_by(&{&1.tags.file, &1.tags.line, to_string(&1.name)})
    |> Enum.group_by(& &1.module)
    |> Enum.sort_by(fn {_module, [test | _]} -> {test.tags.file, inspect(test.module)} end)
    |> Enum.each(&print_module(&1, state))
  end

  defp print_module({_module, tests}, state) do
    [first_test | _] = tests
    file = Path.relative_to_cwd(first_test.tags.file)

    heading = inspect(first_test.module)
    suffix = " [#{file}]"

    IO.puts([
      colorize(:module_info, heading, state),
      colorize(:location_info, suffix, state)
    ])

    tests
    |> Enum.group_by(&describe_key/1)
    |> Enum.sort_by(fn {_describe, grouped_tests} -> group_sort_key(grouped_tests) end)
    |> Enum.each(&print_group(&1, state))

    IO.puts("")
  end

  defp print_group({nil, tests}, state) do
    tests
    |> Enum.sort_by(& &1.tags.line)
    |> Enum.each(fn test ->
      IO.puts("  · #{format_test_entry(test, state)}")
    end)
  end

  defp print_group({describe, tests}, state) do
    IO.puts("  " <> colorize(:describe_info, describe, state))

    tests
    |> Enum.sort_by(& &1.tags.line)
    |> Enum.each(fn test ->
      IO.puts("    · #{format_test_entry(test, state)}")
    end)
  end

  defp print_failures(state) do
    failed_tests =
      state.tests
      |> Enum.filter(&match?(%ExUnit.Test{state: {:failed, _}}, &1))
      |> Enum.sort_by(&{&1.tags.file, &1.tags.line, to_string(&1.name)})

    failed_modules =
      state.failed_modules
      |> Enum.sort_by(fn {test_module, _failures} ->
        {test_module.file, inspect(test_module.name)}
      end)

    if failed_tests != [] or failed_modules != [] do
      IO.puts(colorize(:failure, "Failures:", state))
      IO.puts("")

      {_formatted_tests, counter} =
        Enum.map_reduce(failed_tests, 1, fn %ExUnit.Test{state: {:failed, failures}} = test,
                                            counter ->
          IO.write(
            format_test_failure(test, failures, counter, 120, &formatter_callback(&1, &2, state))
          )

          {test, counter + 1}
        end)

      Enum.reduce(failed_modules, counter, fn
        {%ExUnit.TestModule{state: {:failed, failures}} = test_module, _stored_failures},
        counter ->
          IO.write(
            format_test_all_failure(
              test_module,
              failures,
              counter,
              120,
              &formatter_callback(&1, &2, state)
            )
          )

          counter + 1
      end)

      IO.puts("")
    end
  end

  defp print_summary(state, times_us) do
    tests = length(state.tests)

    failures =
      Enum.count(state.tests, &match?(%ExUnit.Test{state: {:failed, _}}, &1)) +
        length(state.failed_modules)

    invalid = Enum.count(state.tests, &match?(%ExUnit.Test{state: {:invalid, _}}, &1))

    IO.puts(colorize(summary_key(failures, invalid), format_times(times_us), state))
    IO.puts("")

    summary =
      [
        "#{tests} tests",
        "#{failures} failures",
        invalid > 0 && "#{invalid} invalid",
        state.skipped > 0 && "#{state.skipped} skipped",
        state.excluded > 0 && "#{state.excluded} excluded"
      ]
      |> Enum.reject(&is_boolean/1)
      |> Enum.join(", ")

    IO.puts(colorize(summary_key(failures, invalid), summary, state))
  end

  defp format_test_entry(test, state) do
    title =
      [test_leaf_name(test), status_suffix(test)]
      |> IO.iodata_to_binary()

    suffix =
      [" (#{format_ms(test.time)})", " [L##{test.tags.line}]"]
      |> IO.iodata_to_binary()

    [
      colorize(test_status_key(test), title, state),
      colorize(:location_info, suffix, state)
    ]
    |> IO.iodata_to_binary()
  end

  defp test_leaf_name(test) do
    full_name = test.name |> to_string() |> String.replace("\n", " ")

    prefix =
      case test.tags.describe do
        nil -> "#{test.tags.test_type} "
        describe -> "#{test.tags.test_type} #{describe} "
      end

    String.replace_prefix(full_name, prefix, "")
  end

  defp status_suffix(%ExUnit.Test{state: nil}), do: ""
  defp status_suffix(%ExUnit.Test{state: {:failed, _}}), do: " FAILED"
  defp status_suffix(%ExUnit.Test{state: {:invalid, _}}), do: " INVALID"
  defp status_suffix(%ExUnit.Test{state: {:skipped, _}}), do: " SKIPPED"
  defp status_suffix(%ExUnit.Test{state: {:excluded, _}}), do: " EXCLUDED"

  defp describe_key(%ExUnit.Test{tags: %{describe: describe}}), do: describe

  defp group_sort_key([test | _tests]) do
    {test.tags.describe_line || test.tags.line, test.tags.line}
  end

  defp format_ms(time_us) when is_integer(time_us) do
    time_us
    |> div(10)
    |> then(fn time_tenths_us ->
      if time_tenths_us < 10 do
        "0.0#{time_tenths_us}ms"
      else
        time_hundredths_ms = div(time_tenths_us, 10)
        "#{div(time_hundredths_ms, 10)}.#{rem(time_hundredths_ms, 10)}ms"
      end
    end)
  end

  defp colors(opts) do
    @default_colors
    |> Keyword.merge(opts[:colors] || [])
    |> Keyword.put_new(:enabled, IO.ANSI.enabled?())
  end

  defp colorize(key, string, %{colors: colors}) when is_binary(string) do
    if escape = colors[:enabled] && colors[key] do
      [escape, string, :reset]
      |> IO.ANSI.format_fragment(true)
      |> IO.iodata_to_binary()
    else
      string
    end
  end

  defp colorize(_key, string, _context), do: string

  defp summary_key(failures, _invalid) when failures > 0, do: :failure
  defp summary_key(_failures, invalid) when invalid > 0, do: :invalid
  defp summary_key(_failures, _invalid), do: :success

  defp test_status_key(%ExUnit.Test{state: nil}), do: :success
  defp test_status_key(%ExUnit.Test{state: {:failed, _}}), do: :failure
  defp test_status_key(%ExUnit.Test{state: {:invalid, _}}), do: :invalid
  defp test_status_key(%ExUnit.Test{state: {:skipped, _}}), do: :skipped
  defp test_status_key(%ExUnit.Test{state: {:excluded, _}}), do: :invalid

  defp formatter_callback(:diff_enabled?, value, _state), do: value
  defp formatter_callback(key, value, state), do: colorize(key, value, state)
end
