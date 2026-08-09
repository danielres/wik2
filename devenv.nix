{
  pkgs,
  lib,
  config,
  ...
}:

{
  packages =
    with pkgs;
    [
      #
      beam27Packages.elixir-ls
      emmet-language-server
      git
      lefthook
      nodejs_24
      pnpm
      # pgcli
      # secretspec
    ]
    ++ lib.optionals pkgs.stdenv.isLinux [
      chromium
      inotify-tools
      libnotify
    ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      terminal-notifier
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.CoreServices
    ];

  dotenv.disableHint = true;

  languages.elixir = {
    enable = true;
  };

  # needed by elixir-ls:
  languages.erlang = {
    enable = true;
  };

  languages.typescript.enable = true;

  services.adminer.enable = true;

  services.postgres = {
    enable = true;
    port = 5432;
    initialDatabases = [
      { name = "wik_dev"; }
      { name = "wik_test"; }
    ];
    initialScript = ''
      CREATE ROLE postgres SUPERUSER LOGIN;  
    '';
  };

  # processes.phx-server = {
  #   exec = "PORT=4000 mix phx.server";
  #   # if your Phoenix app is in a subdir, set cwd explicitly, e.g.:
  #   # cwd = "${config.git.root}/youmap";
  # };

  process.manager.implementation = "overmind";

  # enable iex history
  env =
    {
      ERL_AFLAGS = "-kernel shell_history enabled";
    }
    // lib.optionalAttrs pkgs.stdenv.isLinux {
      PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH = lib.getExe pkgs.chromium;
    };
  #
  # env.REDIS_URL = config.secretspec.secrets.REDIS_URL;
}
