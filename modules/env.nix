{ lib, config, ... }:
let
  caseLib = config.lib.caseUtils;
in
{
  imports = [
    ./case.nix
  ];

  config.lib.envUtils = {
    toAttrs =
      file:
      let
        content = builtins.readFile file;

        lines = lib.splitString "\n" content;

        filteredLines = builtins.filter (l: l != "" && builtins.substring 0 1 l != "#") lines;
      in
      builtins.listToAttrs (
        map (
          line:
          let
            parts = lib.splitString "=" line;
          in
          if builtins.length parts == 2 then
            let
              rawName = builtins.elemAt parts 0;
              rawValue = builtins.elemAt parts 1;
            in
            {
              name = caseLib.screamingSnakeToCamel rawName;
              value = builtins.replaceStrings [ "\"" "'" ] [ "" "" ] rawValue;
            }
          else
            null
        ) filteredLines
      );

    fromAttrs =
      attrs:
      let
        filteredAttrs = lib.filterAttrs (name: value: value != null) attrs;
        lines = lib.mapAttrsToList (
          name: value:
          let
            strValue = if builtins.isBool value then (if value then "true" else "false") else toString value;
          in
          "${caseLib.camelToScreamingSnake name}=\"${strValue}\""
        ) filteredAttrs;
      in
      lib.concatStringsSep "\n" lines;
  };
}
