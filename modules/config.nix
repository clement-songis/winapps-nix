{ lib, config, ... }:
let
  types = {
    inherit (lib.types)
      str
      submodule
      enum
      nullOr
      path
      ;

    positiveInt = lib.types.ints.positive;

    minInt = min: lib.types.addCheck lib.types.int (x: x >= min);
  };

  envLib = config.lib.envUtils;
  cfg = config.programs.winapps;
in
{
  imports = [
    ./env.nix
  ];

  options.programs.winapps.config = lib.mkOption {
    type = types.nullOr (
      types.submodule {
        options = {
          rdpUser = lib.mkOption {
            type = types.str;
            # default = "WinApps";
            example = "MyWindowsUser";
            description = "The Windows username to use for the RDP connection.";
          };

          # TODO: Add support for secrets files
          rdpPassword = lib.mkOption {
            type = types.str;
            # default = "WinApps";
            example = "MyWindowsPassword";
            description = "The Windows password to use for the RDP connection.";
          };

          rdpDomain = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "MyWindowsDomain";
            description = "The Windows domain to use for the RDP connection.";
          };

          rdpIp = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "127.0.0.1";
            description = ''
              The Windows IP V4 address to use for the RDP connection.

              Default values : 
              - 'docker': '127.0.0.1'
              - 'podman': '127.0.0.1'
              - 'libvirt': determined by WinApps at runtime
            '';
          };

          rdpScale = lib.mkOption {
            type = types.nullOr (
              types.enum [
                100
                140
                180
              ]
            );
            default = null;
            example = 100;
            description = "The display scaling factor to use for the RDP connection.";
          };

          rdpFlags = lib.mkOption {
            type = types.nullOr types.str;
            default = "/cert:tofu /sound /microphone +home-drive";
            example = "/cert:tofu /sound /microphone +home-drive";
            description = ''
              Additional FreeRDP flags and arguments to use for the RDP connection.

              Notes:
              - You can try adding /network:lan to these flags in order to increase performance, however, some users have faced issues with this.
              - If this does not work or if it does not work without the flag, you can try adding /nsc and /gfx.

              See https://github.com/awakecoding/FreeRDP-Manuals/blob/master/User/FreeRDP-User-Manual.markdown
            '';
          };

          vmName = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "RDPWindows";
            description = ''
              The VM name to use to determine VM IP and start the VM when using 'libvirt'.

              Default value: 'RDPWindows'
            '';
          };

          backend = lib.mkOption {
            type = types.nullOr (
              types.enum [
                "docker"
                "podman"
                "libvirt"
                "manual"
              ]
            );
            default = null;
            example = "docker";
            description = ''
              The backend to use for the RDP connection.

              Default value: 'docker'
            '';
          };

          removableMedia = lib.mkOption {
            type = types.nullOr types.str;
            default = "/run/media";
            example = "/mnt";
            description = ''
              The path to use for mounting removable devices.

              Notes:
              - By default, `udisks` (which you most likely have installed) uses /run/media for mounting removable devices.
                This improves compatibility with most desktop environments (DEs).
                ATTENTION: The Filesystem Hierarchy Standard (FHS) recommends /media instead. Verify your system's configuration.
              - To manually mount devices, you may optionally use /mnt.

              Reference: https://wiki.archlinux.org/title/Udisks#Mount_to_/media

              Default value: '/run/media'
            '';
          };

          debug = lib.mkOption {
            type = types.nullOr (types.enum [ false ]);
            default = null;
            example = false;
            description = ''
              Whether to create and append to ~/.local/share/winapps/winapps.log when running WinApps.

              Default value: true
            '';
          };

          autoPause = lib.mkOption {
            type = types.nullOr (types.minInt 20);
            default = null;
            example = 300;
            description = ''
              Automatically pause Windows when the RDP connection is closed after the duration of inactivity if not null.

              Notes:
              - This is currently INCOMPATIBLE with 'manual'.
              - The value must be specified in seconds (to the nearest 10 seconds e.g., '30', '40', '50', etc.).
              - For RemoteApp RDP sessions, there is a mandatory 20-second delay, so the minimum value that can be specified here is '20'.
              - Source: https://techcommunity.microsoft.com/t5/security-compliance-and-identity/terminal-services-remoteapp-8482-session-termination-logic/ba-p/246566
            '';
          };

          freerdpCommand = lib.mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "xfreerdp";
            description = ''
              The command required to run FreeRDPv3 on your system (e.g., 'xfreerdp', 'xfreerdp3', etc.).

              Notes:
              - By default WinApps will attempt to automatically detect the correct command to use for your system.
            '';
          };

          # [TIMEOUTS]
          # NOTES:
          # - These settings control various timeout durations within the WinApps setup.
          # - Increasing the timeouts is only necessary if the corresponding errors occur.
          # - Ensure you have followed all the Troubleshooting Tips in the error message first.

          portTimeout = lib.mkOption {
            type = types.nullOr types.positiveInt;
            default = null;
            example = 5;
            description = ''
              The maximum time (in seconds) to wait when checking if the RDP port on Windows is open.

              Corresponding error: "NETWORK CONFIGURATION ERROR" (exit status 13).

              Default value: 5
            '';
          };

          rdpTimeout = lib.mkOption {
            type = types.nullOr types.positiveInt;
            default = null;
            example = 30;
            description = ''
              The maximum time (in seconds) to wait when testing the initial RDP connection to Windows.

              Corresponding error: "REMOTE DESKTOP PROTOCOL FAILURE" (exit status 14).

              Default value: 30
            '';
          };

          appScanTimeout = lib.mkOption {
            type = types.nullOr types.positiveInt;
            default = null;
            example = 60;
            description = ''
              The maximum time (in seconds) to wait for the script that scans for installed applications on Windows to complete.

              Corresponding error: "APPLICATION QUERY FAILURE" (exit status 15).

              Default value: 60
            '';
          };

          bootTimeout = lib.mkOption {
            type = types.nullOr types.positiveInt;
            default = null;
            example = 120;
            description = ''
              The maximum time (in seconds) to wait for the Windows VM to boot if it is not running, before attempting to launch an application.

              Default value: 120
            '';
          };

          hidef = lib.mkOption {
            type = types.nullOr (types.enum [ false ]);
            default = null;
            example = false;
            description = ''
              This option controls the value of the 'hidef' option passed to the /app parameter of the FreeRDP command.
              Setting this option to 'false' may resolve window misalignment issues related to maximized windows.

              Default value: true
            '';
          };
        };
      }
    );
    default = null;
    example = {
      rdpUser = "WinApps";
      rdpPassword = "WinApps";
      debug = false;
      vmName = "WinApps";
      backend = "libvirt";
    };
    description = ''
      If this option is set to 'null' the flake don't manage the WinApps configuration.
      Otherwise, it will replace it content at each update.

      Default is null.
    '';
  };

  config = lib.mkIf (cfg.enable && cfg.config != null) {
    home.file = {
      ".config/winapps/winapps.conf".text =
        with cfg.config;
        envLib.fromAttrs {
          inherit
            rdpUser
            rdpDomain
            rdpIp
            vmName
            rdpScale
            removableMedia
            rdpFlags
            debug
            freerdpCommand
            portTimeout
            rdpTimeout
            appScanTimeout
            bootTimeout
            ;
          waflavor = backend;
          rdpPass = rdpPassword;
          autoPause = if autoPause == null then null else "on";
          autoPauseTime = autoPause;
          hidef = if hidef == null then null else "on";
        };
    };
  };
}
