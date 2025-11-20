{ lib, ... }:
let
  isUpper = c: builtins.match "^[A-Z]$" c != null;
in
{
  config.lib.caseUtils = {
    screamingSnakeToCamel =
      s:
      let
        parts = lib.splitString "_" s;
        first = lib.toLower (builtins.elemAt parts 0);
        rest = builtins.tail parts;
        capitalize =
          str:
          lib.concatStrings [
            (builtins.substring 0 1 str)
            (lib.toLower (builtins.substring 1 (builtins.stringLength str - 1) str))
          ];
      in
      lib.concatStrings ([ first ] ++ map capitalize rest);

    camelToScreamingSnake =
      s:
      lib.concatStrings (
        lib.imap0 (i: c: if isUpper c then "_" + c else lib.toUpper c) (lib.stringToCharacters s)
      );
  };
}
