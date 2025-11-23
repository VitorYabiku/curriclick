{ pkgs, lib, config, inputs, ... }:
let beam_pkgs = pkgs.beamMinimalPackages;

in {
  # https://devenv.sh/basics/
  # env.PORT = "4000"; # Phoenix uses port 4000 by default

  # https://devenv.sh/packages/
  packages =
    [ beam_pkgs.elixir-ls pkgs.inotify-tools pkgs.prettierd pkgs.watchman ];

  # https://devenv.sh/languages/
  languages = {
    elixir.enable = true;
    javascript = {
      enable = true;
      pnpm = {
        enable = true;
        install.enable = true;
      };
    };
    typescript.enable = true;
  };

  # https://devenv.sh/processes/
  # processes.cargo-watch.exec = "cargo-watch";

  # https://devenv.sh/services/
  services.postgres = {
    enable = true;
    initialDatabases = [{
      name = "curriclick_dev";
      pass = "postgres";
      user = "postgres";
    }];
    listen_addresses = "localhost";
    # extensions = extensions: [ extensions.pgvector ];
  };

  # https://devenv.sh/scripts/
  # scripts.hello.exec = ''
  #   echo hello from $GREET
  # '';

  # enterShell = ''
  # '';

  # https://devenv.sh/tasks/
  # tasks = {
  #   "myproj:setup".exec = "mytool build";
  #   "devenv:enterShell".after = [ "myproj:setup" ];
  # };

  # https://devenv.sh/tests/
  # enterTest = ''
  #   echo "Running tests"
  #   git --version | grep --color=auto "${pkgs.git.version}"
  # '';

  # https://devenv.sh/git-hooks/
  # git-hooks.hooks.shellcheck.enable = true;

  # See full reference at https://devenv.sh/reference/options/
}
