{ openarchiver-pkg }:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.openarchiver;
in
{
  options.services.openarchiver = {
    enable = lib.mkEnableOption "Open Archiver";
    package = lib.mkOption {
      type = lib.types.package;
      description = "Open-Archiver package to use";
      default = openarchiver-pkg;
    };
    configureTika = lib.mkEnableOption "Whether to configure Tika server";
    configureRedis = lib.mkEnableOption "Whether to configure Redis server";
    configurePostgres = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether to configure PostgreSQL server

        OpenArchiver is not able to connect via Unix Sockets, thus its still required to set a password for the database user e.G. imperative or via services.postgresql.initialScript
      '';
    };
    configureMelisearch = lib.mkEnableOption "Whether to configure Melisearch server";
    settings = lib.mkOption {
      description = ''
        see https://github.com/LogicLabs-OU/OpenArchiver/blob/main/.env.example for available options
      '';
      type = lib.types.submodule {
        freeformType = lib.types.attrsOf lib.types.str;
        options = {
          PORT_BACKEND = lib.mkOption {
            type = lib.types.port;
            apply = toString;
            default = 4000;
          };
          PORT_FRONTEND = lib.mkOption {
            type = lib.types.port;
            apply = toString;
            default = 3000;
          };
          STORAGE_TYPE = lib.mkOption {
            type = lib.types.enum [
              "local"
              "s3"
            ];
            default = "local";
          };
          STORAGE_LOCAL_ROOT_PATH = lib.mkOption {
            type = lib.types.path;
            default = "/var/lib/openarchiver";
          };
          JWT_EXPIRES_IN = lib.mkOption {
            type = lib.types.str;
            default = "7d";
          };
        };
      };
    };
    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Environment file, used to set any secret environment variables.";
    };
  };
  config = lib.mkIf cfg.enable {

    users.users.openarchiver = {
      group = "openarchiver";
      isSystemUser = true;
    };
    users.groups.openarchiver = { };

    services = {
      openarchiver.settings = {
        TIKA_URL = lib.mkIf cfg.configureTika "http://localhost:${toString config.services.tika.port}";
        MEILI_HOST = lib.mkIf cfg.configureMelisearch "http://localhost:${toString config.services.meilisearch.listenPort}";
      };

      redis.servers.openarchiver = lib.mkIf cfg.configureRedis {
        enable = true;
        port = lib.mkDefault 6379;
      };
      postgresql = lib.mkIf cfg.configurePostgres {
        enable = true;
        ensureDatabases = [ "openarchiver" ];
        ensureUsers = [
          {
            name = "openarchiver";
            ensureDBOwnership = true;
          }
        ];
      };
      meilisearch.enable = lib.mkIf cfg.configureMelisearch true;
      tika = lib.mkIf cfg.configureTika {
        enable = true;
        enableOcr = true;
      };
    };
    systemd = {
      tmpfiles.rules = lib.mkIf (cfg.settings.STORAGE_TYPE == "local") [
        "d ${cfg.settings.STORAGE_LOCAL_ROOT_PATH} 0750 openarchiver openarchiver"
      ];
      services.openarchiver = {
        wantedBy = [ "multi-user.target" ];
        environment = cfg.settings;
        path = [
          pkgs.bash
          pkgs.procps
        ];
        serviceConfig = {
          ExecStartPre = lib.getExe' cfg.package "openarchiver-migrate";
          ExecStart = lib.getExe cfg.package;
          User = "openarchiver";
          Group = "openarchiver";
          EnvironmentFile = lib.mkIf (cfg.environmentFile != null) [ cfg.environmentFile ];
          KillSignal = "SIGKILL"; # Open-Archiver does not fully stop on SIGTERM
        };
      };
    };
  };
}
