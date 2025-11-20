{
  config,
  lib,
  pkgs,
  winapps,
  ...
}:
let
  winappsPkgs = winapps.packages.${pkgs.stdenv.hostPlatform.system};

  cfg = config.programs.winapps;

  types = {
    inherit (lib.types)
      bool
      str
      nullOr
      submodule
      path
      listOf
      attrsOf
      either
      ;
  };

  infoLib = config.lib.winapps.infoUtils;

  appsWithDefault = lib.mapAttrs (appName: config: {
    info = if config.info != null then config.info else "${cfg.package}/src/apps/${appName}/info";
    icon = if config.icon != null then config.icon else "${cfg.package}/src/apps/${appName}/icon.svg";
  }) cfg.apps;

  generateBin = appName: {
    ".local/bin/${appName}" = {
      text = ''
        #!/usr/bin/env bash
        ${cfg.package}/bin/winapps ${appName}
      '';
      executable = true;
    };
  };
in
{
  imports = [
    ./config.nix
    ./info.nix
  ];

  options = {
    programs.winapps = {
      enable = lib.mkEnableOption "WinApps";
      package = lib.mkPackageOption winappsPkgs "winapps" { };
      officeProtocolHandler = lib.mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = "If this option is set to 'true' the flake will add an Office protocol handler.";
      };
      windowsShortcut = lib.mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = "If this option is set to 'true' the flake will create a shortcut to the entire Windows VM.";
      };
      apps = lib.mkOption {
        type = types.attrsOf (
          types.submodule {
            options = {
              info = lib.mkOption {
                type = types.nullOr (
                  types.either types.path (
                    types.submodule {
                      options = {
                        name = lib.mkOption {
                          type = types.str;
                          example = "My app";
                          description = "shortcut name";
                        };
                        fullName = lib.mkOption {
                          type = types.str;
                          example = "My own app";
                          description = "Used for descriptions and window class";
                        };
                        winExecutable = lib.mkOption {
                          type = types.str;
                          example = "C:\\Windows\\System32\\cmd.exe";
                          description = "The executable inside windows";
                        };
                        categories = lib.mkOption {
                          type = types.listOf types.str;
                          default = [ "X-WinApps" ];
                          example = [
                            "X-WinApps"
                            "X-Windows"
                          ];
                          description = "shortcut categories";
                        };
                        mimeTypes = lib.mkOption {
                          type = types.listOf types.str;
                          default = [ ];
                          example = [
                            "application/json"
                            "application/xml"
                          ];
                          description = "shortcut mime types to open files";
                        };
                        icon = lib.mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          example = "ms-powerpoint";
                          description = "System icon name";
                        };
                      };
                    }
                  )
                );
                default = null;
                example = {
                  name = "My app";
                  fullName = "My own app";
                  winExecutable = "C:\\Program Files\\My app\\MyApp.exe";
                };
                description = "App information, can be a path to an info file or a config with attributes. If not provided, WinApps will try to use a registered app from its package.";
              };
              icon = lib.mkOption {
                type = types.nullOr types.path;
                default = null;
                example = lib.literalExample "./path/to/icon.png";
                description = "App icon. If not provided, WinApps will try to use a registered app from its package.";
              };
            };
          }
        );
        default = { };
        example = {
          explorer = { };
          custom_app = {
            info = {
              name = "My app";
              fullName = "My own app";
              winExecutable = "C:\\Program Files\\My app\\MyApp.exe";
            };
            icon = lib.literalExample "./path/to/icon.png";
          };
        };
        description = ''
          An array of all the applications that will be used to create shortcuts.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    home.file =
      lib.concatMapAttrs (
        appName: config:
        {
          ".local/share/winapps/apps/${appName}/info" =
            if builtins.isAttrs config.info then
              { text = infoLib.toFile config.info; }
            else
              { source = config.info; };

          ".local/share/winapps/apps/${appName}/icon.svg".source = config.icon;
        }
        // generateBin appName
      ) appsWithDefault
      // lib.optionalAttrs cfg.windowsShortcut (generateBin "windows");

    xdg.desktopEntries =
      lib.mapAttrs (
        appName: config:
        let
          info = if builtins.isAttrs config.info then config.info else infoLib.fromFile config.info;
        in
        infoLib.toDesktopFile appName cfg.package info config.icon
      ) appsWithDefault
      // lib.optionalAttrs cfg.windowsShortcut {
        windows =
          let
            info = {
              name = "Windows";
              fullName = "Microsoft Windows RDP Session";
              categories = [ "X-Windows" ];
              mimeTypes = [ ];
            };
          in
          infoLib.toDesktopFile "windows" cfg.package info "${cfg.package}/src/install/windows.svg";
      };

    xdg.dataFile = lib.mkIf cfg.officeProtocolHandler {
      "applications/ms-office-protocol-handler.desktop".source =
        "${cfg.package}/src/apps/ms-office-protocol-handler.desktop";
    };

    home.sessionPath = [ "$HOME/.local/bin" ];
  };
}
