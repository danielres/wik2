{ pkgs, lib, config, ... }:

{
  packages = with pkgs;
    [
      #
      git
      lefthook
      nodejs_24
      pgcli
      secretspec
    ] ++ lib.optionals pkgs.stdenv.isLinux [ inotify-tools libnotify ]
    ++ lib.optionals pkgs.stdenv.isDarwin [
      terminal-notifier
      darwin.apple_sdk.frameworks.CoreFoundation
      darwin.apple_sdk.frameworks.CoreServices
    ];

  languages.elixir = { enable = true; };

  services.adminer.enable = true;

  services.postgres = {
    enable = true;
    port = 5432;
    initialDatabases = [ { name = "wik_dev"; } { name = "wik_test"; } ];
    initialScript = ''
      CREATE ROLE postgres SUPERUSER LOGIN;  
    '';
  };

  processes.phx-server = {
    exec = "PORT=4000 mix phx.server";
    # if your Phoenix app is in a subdir, set cwd explicitly, e.g.:
    # cwd = "${config.git.root}/youmap";
  };

  process.manager.implementation = "overmind";

  # enable iex history
  env.ERL_AFLAGS = "-kernel shell_history enabled";
  #
  # env.REDIS_URL = config.secretspec.secrets.REDIS_URL;
}

