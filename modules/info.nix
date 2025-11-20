{ lib, config, ... }:
let
  envLib = config.lib.envUtils;

  mainCategories = [
    "AudioVideo"
    "Audio"
    "Video"
    "Development"
    "Education"
    "Game"
    "Graphics"
    "Network"
    "Office"
    "Science"
    "Settings"
    "System"
    "Utility"
  ];
in
{
  imports = [
    ./env.nix
  ];

  config.lib.winapps.infoUtils = {
    fromFile =
      file: with envLib.toAttrs file; {
        inherit
          name
          fullName
          winExecutable
          icon
          ;
        mimeTypes = lib.splitString ";" mimeTypes;
        categories = map (
          cat: if builtins.elem cat mainCategories || lib.hasPrefix "X-" cat then cat else "X-" + cat
        ) (lib.splitString ";" categories);
      };
    toFile =
      info:
      envLib.fromAttrs {
        inherit (info)
          name
          fullName
          winExecutable
          icon
          ;

        categories = lib.concatStringsSep ";" (
          map (
            cat:
            if builtins.elem cat mainCategories || !lib.hasPrefix "X-" cat then
              cat
            else
              builtins.substring 2 (builtins.stringLength cat) cat
          ) info.categories
        );
        mimeTypes = lib.concatStringsSep ";" info.mimeTypes;
      };

    toDesktopFile = appName: package: info: icon: {
      type = "Application";
      exec = "${package}/bin/winapps ${appName} %F";
      inherit icon;
      comment = info.fullName;
      terminal = false;
      inherit (info) name categories;
      mimeType = info.mimeTypes;
      settings = {
        StartupWMClass = info.fullName;
      };
    };
  };
}
