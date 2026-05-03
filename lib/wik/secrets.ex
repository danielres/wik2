defmodule Wik.Secrets do
  use AshAuthentication.Secret

  def secret_for(
        [:authentication, :tokens, :signing_secret],
        Wik.Accounts.User,
        _opts,
        _context
      ) do
    Application.fetch_env(:wik, :token_signing_secret)
  end
end
