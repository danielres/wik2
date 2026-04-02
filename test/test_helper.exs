formatters =
  case System.get_env("FORMATTER") do
    "doc" -> [Qblog.Test.DocFormatter]
    "both" -> [ExUnit.CLIFormatter, Qblog.Test.DocFormatter]
    _ -> [ExUnit.CLIFormatter]
  end

ExUnit.start(formatters: formatters)
Ecto.Adapters.SQL.Sandbox.mode(Qblog.Repo, :manual)
