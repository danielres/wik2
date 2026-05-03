formatters =
  case System.get_env("FORMATTER") do
    "doc" -> [Wik.Test.DocFormatter]
    "both" -> [ExUnit.CLIFormatter, Wik.Test.DocFormatter]
    _ -> [ExUnit.CLIFormatter]
  end

ExUnit.start(formatters: formatters)
Ecto.Adapters.SQL.Sandbox.mode(Wik.Repo, :manual)
