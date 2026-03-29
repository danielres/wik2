defmodule Qblog.Scope do
  defstruct [:actor, :tenant]

  defimpl Ash.Scope.ToOpts do
    def get_actor(%{actor: actor}), do: {:ok, actor}
    def get_tenant(%{tenant: tenant}), do: {:ok, tenant}
    # def get_context(%{locale: locale}), do: {:ok, %{shared: %{locale: locale}}}
    def get_context(%{}), do: {:ok, %{shared: %{}}}
    # You typically configure tracers in config files
    # so this will typically return :error
    def get_tracer(_), do: :error

    # This should likely always return :error
    # unless you want a way to bypass authorization configured in your scope
    def get_authorize?(_), do: :error
  end
end
