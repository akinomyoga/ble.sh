<!---------------------------------------------------------------------------->
# ble-0.4.0-devel2

2020-01-12 -- (#D1215... ) c74abc5...

## New features

- complete: support `bleopt complete_auto_wordbreaks` (suggestion by dylankb) `#D1219` c294e31
- main: check `~/.config/blesh/init.sh` `#D1224` a82f961
- progcolor: support programmable highlighting `#D1218` 0770234 `#D1244` 9cb3583 `#D1245` 8e8a296 `#D1247` 154f638 `#D1269` fa0036c
- decode/kbd: support <kbd>U+XXXX</kbd>, <kbd>@ESC</kbd> and <kbd>@NUL</kbd> for keynames `#D1251` 441117c ef23ad1
- syntax: support `coproc` `#D1252` 7ff68d2
- vi/nmap: support readline widgets for <kbd>M-left</kbd>, <kbd>M-right</kbd>, <kbd>C-delete</kbd>, <kbd>#</kbd> and <kbd>&</kbd> `#D1258` 846e0be
- complete: add `compopt -o quote/default` for `fzf` (motivated by dylankb) `#D1275` 58e1be4
- util (`ble-import`): support an option `-d` (`--delay`) `#D1285` 9673e4e
- syntax: support parameter expansion of the form `${var/#pat}`, `${var/%pat}` `#D1286` e2f4809
- edit: support `bleopt editor line_limit_{type,length} history_limit_length` `#D1295` 2f9a000
- edit: support widgets `{vi,emacs}-editing-mode` `#D1301` 0c6c76e
- syntax: allow unquoted `[!` and `[^` in `simple-word` (reported by cmplstofB) `#D1303` 0000000

## Fix

- util (ble/builtin/trap): fix argument analysis for the form `trap INT` (reported by dylankb) `#D1221` db8b0c2
- main: fix an error message on ristricted shells `#D1220` b726225
- edit: fix a bug that the shell hangs with `source ble.sh --noattach && ble-attach` (reported by dylankb) `#D1223` 59c1ce4 3031007
- edit: fix a bug that the textarea state is not properly saved (reported by cmplstofB) `#D1227` 06ae2b1
- syntax: support hexadecimal literals for arithmetic expression (reported by cmplstofB) `#D1228` 90e4f35
- history: fix a bug that history append does not work with `set -C` (reported by cmplstofB) `#D1229` 604bb8b
- decode (`ble/builtin/bind`): fix widget mapping for `default_keymap=safe` `#D1234` 750a9f5
- main (ble-update): fix a bug that the check of `make` does not work in Bash 3.2 `#D1236` 08ced81
- syntax: fix a infinite loop for variable assignments and parameter expansions `#D1239` 327661f
- complete: clear menu on history move `#D1248` 06cc7de
- syntax: fix a bug that arguments of `eval` are not highlighted `#D1254` 5046d14
- decode: fix error message `command=${[key]-}` for mouse input `#D1263` 09bb274
- [ble-0.3] reload: fix a bug that the state is broken by `ble-reload` `#D1266` f2f30d1
- decode (`ble/builtin/bind`): remove comment from bind argument `#D1267` 880bb2c
- decode: use `BRE` instead of `ERE` for `POSIX sed` (reported by dylankb) `#D1283` 2184739
- decode: fix strange behaviors after `fzf` (convert <kbd>DEL</kbd> to <kbd>C-?</kbd>) `#D1281` 744c8e8
- edit: work around Bash rebinding on `TERM` change `#D1287` ac7ab55 7a99bf3
- term: work around terminfo/termcap entry collisions in `tput` (reported by killermoehre) `#D1289` f8c54ef
- complete: clear menu on discard-line (reported by animecyc) `#D1290` fb794b3
- vi (vi-command/nth-column): fix a bug in arithmetic expansion (reported by andychu) `#D1292` da6cc47
- complete: fix a bug that insert-word does not for with ambiguous candidates `#D1295` 2f9a000
- complete: fix a bug that menu-filter is only partially turned off by `complete_menu_filter` `#D1298` b3654e2
- decode: fix error messages for unsupported readline functions `#D1301` 91bdb64
- global: work around `shopt -s assoc_expand_once` `#D1305` 31908e1
- global: work around `TMOUT` for `builtin read` `#D1306` 1c22a9d
- syntax: fix failglob errors of heredocs of the form `<<$(echo A)` `#D1308` 3212fd2
- decode (`ble-bind`): fix an error message `#D1311` c868b6d
- util (`bleopt`): fix a bug that a new setting is not defined with `name:=` `#D1312` c757b92

## Changes

- highlight: highlight symlink directories as symlinks `#D1249` 25e8a72
- auto-complete: bind `insert-on-end` to `C-e` `#D1250` 90b45eb
- edit (`widget/shell-expand-line`): not quote expanded results by default `#D1255` a9b7810
- decode: refactor
  - decode: delay bind until keymap initialization `#D1258` 0beac33
  - decode: read user settings from `bind -Xsp` `#D1259` eef14d0
  - decode: fix a bug of `ble-bind` with uninitialized cmap `#D1260` 5d98210
  - decode: fix error messages of BSD `sed` rejecting unencoded bytes from `bind -p` (reported by dylankb) `#D1277` 0cc9160
- edit: provide proper `$BASH_COMMAND` and `$_` for PS1, PROMPT_COMMAND, PRECMD, etc. `#D1276` 7db48dc
- edit (quoted-insert): insert literal key sequence `#D1291` 420c933
- decode: support `decode_abort_char` for `modifyOtherKeys` `#D1293` ad98416
- edit (edit-and-execute): disable highlighting of old command line content `#D1295` 2f9a000

## Compatibility

- main: work around cygwin uninitialized environment `#D1225` `#D1226` b9278bc
- global: work around Bash 3.2 bug of array initialization with <kbd>SOH</kbd>/<kbd>DEL</kbd> `#D1238` defdbd4 `#D1241` 1720ec0
- term: support `TERM=minix` `#D1262` ae0b80f
- msys2: support2 MSYS (motivated by SUCHMOKUO) `#D1264` 47e2863
  - edit: support `\$` in `PS1` for MSYS2 `#D1265` f6f8956
  - msys2: work around MSYS2 Bash bug of missing <kbd>CR</kbd> `#D1270` 71f3498
  - cygwin, msys2: support widget `paste-from-clipboard` `#D1271` cd26c65
- msys1: support MSYS1 `#D1272` 630d659
  - msys1: work around missing named pipes in MSYS1 `#D1273` 6f6c2e5
- term: support contra `SPD` `#D1288` 1e65f2c

## Internal changes and fixes

- util: merge `ble/util/{save,restore}-{arrs => vars}` `#D1217` 6acb9a3
- internal: merge subdir `test` into `memo` `#D1230` f0c38b6
- ble-measure: improve calibration `DD1231` d3a7a52
- vi_test: fix a bug that test fails to restore the original state `#D1232` 4b882fb
- decode (ble/builtin/bind): skip checking stdin in parsing the keyseq `#D1235` 5f949e8
- syntax: delay load of `ble/syntax/parse` for syntax highlighting `#D1237` bb31b11
- memo: split `memo.txt` -> `note.txt`, `done.txt` and `ChangeLog.md` `#D1243` 31bc9aa 8b0fe34 419155e
- global: check isolated identifiers and leak variables `#D1246` 19cc99d 2e74b6d
- util: add `ble/function#{advice,push,pop}` to patch functions (motivated by dylankb) `#D1275` fbe531a
- util (`ble/util/stackdump`): output to `stdout` instead of `stderr` `#D1279` 9d3c50d
- complete (`ble-sabbrev`): delay initialization `#D1282` dfc4f66
- test: update `lib/test-{core => util}.sh` (reported by andychu) `#D1294` e835b0d
- edit: improve performance of bracketed-paste `#D1296` 0a45596 `#D1300` 3f33dab `#D1302` 5ee06c8 10ad274
- decode: improve performance of `ble-decode-char` `#D1297` 0d9d867
- ext: update `mwg_pp.awk` (for branch osh) 978ea32
- test: add `lib/core-test.sh` `#D1309` 68f8077
- global: do not use `local -i` `#D1310` f9f0f9b
- global: normalize calls of builtins `#D1313` 0000000

<!---------------------------------------------------------------------------->
# ble-0.4.0-devel1

2019-03-21 -- 2020-01-12 (#D1015...#D1215) df4feaa...c74abc5

## New features

- emacs: support widgets `forward-byte` and `backward-byte` `#D1017` b2951ef
- emacs: support arguments of word wise operations `#D1020` 719092c
- emacs: support widgets `{capitalize,downcase,upcase}-xword` `#D1019` 719092c
- emacs: support widgets `alias-expand-line` and `history-and-alias-expand-line` `#D1024` fdaf579
- emacs: support keyboard macros `#D1028` 284668a
  - decode: workaround recursive charlog/keylog `#D1030` ea421a3
- complete: define `menu` keymap `#D1033` abfd060
- emacs: support widgets `kill{,-graphical,-logical}-line` `#D1037` 3bb3d33
- emacs: support a widget `re-read-init-file` `#D1038` ebe2928
- emacs: support widgets `readline-dump-{functions,macros,variables}` `#D1039` 49256a9
- emacs: support widgets `character-search-{for,back}ward` and `delete-forward-char-or-list` `#D1040` 2b20c88
- emacs: support widgets `insert-comment` and `do-lowercase-version` `#D1041` 7aae37b
- main: support options `--version` and `--help` `#D1042` b5ab789
- main: read `.inputrc` as `ble.sh` settings `#D1042` b5ab789
  - decode: fix a bug of error messages on reading `.inputrc` `#D1062` e163b9a
- complete: support widget `menu-complete insert_braces` `#D1043` 3d29c8d
  - complete (insert_braces): reimplement range contraction `#D1044` dc586da
  - complete (insert_braces): remove empty quotations `#D1045` `#D1046` dc586da
  - complete (insert_braces): fix support of replacement of existing part `#D1047` dc586da
- complete: support `complete context=dynamic-history` `#D1048` 4f7b284
- emacs: support a widget `edit-and-execute-command` `#D1050` ca5fe08
- emacs: support widgets `insert-{last,nth}-argument` `#D1051` 24458be
- complete: support `menu-complete backward` `#D1052` 2b0c7e8
- emacs: `history-nsearch-{for,back}ward-again` `#D1053` 60dde2c
- emacs: support widgets `tab-insert`, `tilde-expand` and `shell-expand-line` `#D1054` 156b76e
- emacs: support a widget `transpose-{c,u,s,f,e}words` `#D1055` d72c2d4
- emacs: support `bleopt decode_error_cseq_{abell,vbell,discard}` `#D1056` ab1b8b0
  - decode: fix a bug that cmap cache update is not triggered for `#D1073` f1e7674
- emacs: support a widget `universal-arg` `#D1057` 8b1dd07
- emacs: support kill ring and a widget `yank-pop` `#D1059` 8c9b6e8
- highlight: support job names by `auto_resume` `#D1065` ce46024
- decode: add support for `S8C1T` key sequences `#D1083` 9b7939b
- history: support `bleopt history_share` `#D1100` `#D1099` 305b89f `#D1193` 4838a46
- history: support full multiline history `#D1120` 8cf17f7
  - history: do not synchronize multiline resolution on "history -p" `#D1121` 9e56b7b
  - history.mlfix: suppress errors on Bash 3 `#D1122` 4fe7a0c
  - history: suppress error messages trying to kill background worker on reattach `#D1125` f045fec
- highlight: support dirname colors with pathname expansion, failglob and command names `#D1134` edaf495
- util: introduce `blehook` `#D1139` d1a78fb
  - blehook: support `blehook PRECMD PREEXEC POSTEXEC CHPWD ADDHISTORY` `#D1142` bedc2ba
  - blehook: add `blehook/eval-after-load` `#D1145` c1f7aa9
  - blehook: fix a bug that the definition of specified hooks are not printed `#D1146` a4a7cbc
- highlight: highlight word with the form of URL `#D1150` f48f2d7
- syntax: support syntax/globpat in param expansions `#D1157` `#D1158` 051222e `#D1160` 57b42ba
  - syntax: fix attr of nested extglob in param expansions `#D1159` 2d019f0
- decode: support `ble-bind -T kspecs timeout` for timeout and `lib/vim-arpeggio.sh` (request by divramod) `#D1174` 272344e
- complete: use `WORD*` pathname expansion for candidates on failglob with `WORD` `#D1177` c1b0532
- edit: support `bleopt accept_line_threshold` `#D1178` a3385f6 82a1e0b
- complete: support `bleopt complete_allow_reduction` `#D1181` 03040b7
- edit: support `bleopt exec_errexit_mark` `#D1182` 6adc2df
- color: support true colors `#D1184` bd631ce 5dd6b03
- color (`ble-color-setface`): support reference to another face (reported by cmplstofB) `#D1188` 1885b54 `#D1206` 7e31ad3
- edit: support `shopt -u promptvars` `#D1189` 269ba09
- highlight: highlight variable names and numbers according to its state `#D1210` `#D1211` 93dab7b
- highlight: support `${var@op}` (for bash 4.4) `#D1212` a85bdb8

## Changes

- edit: erase in page on `SIGWINCH` `#D1016` 7625ebe
- edit: the widgets `{kill,copy,delete}-region-or` now receives widgets as arguments `#D1021` bbbd155
- edit: disable aliases for builtins and keywords `#D1023` 61da093
- edit: disable `rps1` in secondary textareas `#D1027` b86709a
- edit: support `$?` in `PROMPT_COMMAND` and `PS1` evaluation `#D1074` 43f2967
- main: change default attach strategy to `--attach=prompt` `#D1076` 197f752
- main: change exit status of `ble-update` when it is already up to date `#D1081` d94f691
- progcomp: improve treatment of `COMP_WORDBREAKS` `#D1094` f6740b5 `#D1098` 6c6bae5
- history: replace builtin `history` `#D1101` 655d73e
  - history: synchronize undo/mark/dirty data with history changes `#D1102` `#D1103` `#D1104` 5367360
  - history: improve performance of `history -r` `#D1105` `#D1106` f204bc7
  - history: fix a problem that history file is doubled with `history -cr` in `PROMPT_COMMAND` `#D1110` e64edb7
  - history: suppress errors on new history file `#D1111` e64edb7 `#D1113` 91f07b6
  - history: fix a problem that `_ble_edit_history` is not synchronized with `history -r` `#D1112` e64edb7
  - history: do not process `_ble_edit_history` in detached state `#D1115` bf3b014
  - history: move history item on delete of current item with `history -d` `#D1114` bf3b014
  - history: fix a problem that history before load of ble.sh is lost `#D1126` 37cd154
  - history: fix problems of history output after `ble-reload` `#D1129` 9c8d858
- history: improve performance of `erasedups` `#D1107` 518e2ee
- history: correctly handle `HISTSIZE` overflow `#D1108` 7be255c
- sabbrev: support sabbrev expansion in wider contexts (reported by cmplstofB) `#D1117` ca6e03d
- main: change loading point of `.inputrc` `#D1127` af758e5
- highlight: do not split command names with `:` and `=` `#D1133` 8a1bd8f
- decode: support DA1 responses sent by some terminals (reported by miba072) `#D1135` 362ab05
- highlight: make brace expansions active for RHS of variable-assignment-form arguments `#D1138` 93cc8da
- main: adjust readline variables for `ble.sh` `#D1148` 36312f7
- edit: update prompt after execution of command through `ble-bind` `#D1151` 27208ea
- blehook: replace builtin `trap` `#D1152` d6c555e 7d4fd03
  - blehook: suppress extra `DEBUG` trap calls `#D1155` 25c3e19
- syntax: allow `},fi,done,esac,then,...` after subshell `()` `#D1165` fdb49f3
- edit: support options `--help` for `read` and `exit` `#D1173` faccc6b
- color (`ble-color-{set,def}face`): list faces without arguments `#D1180` 50327c3
- complete: search completion settings through alias expansion `#D1187` c472809
- history (`ble/builtin/history`): support an option `--help` `#D1192` d4c26c5

## Fixes

- decode: workaround Poderosa that returns `DSR` instead of `CPR` in reply to `DSR(6)` `#D1018` 8e22c17
- isearch: fix a bug to match with the old content of the current line `#D1025` 605dcd0
- vi: fix a bug that quoted-insert is not properly recorded with `qx...q` `#D1026` 06698a4
- decode: fix a bug that chars from nested widgets are not processed immediately `#D1028` c79d89b
- menu: fix a bug that fails to retrieve menu item description `#D1031` c936db8
- menu: fix a bug that menu item color is disabled `#D1032` c936db8
- vbell: fix a bug that persistent vbell is not erased before next vbell `#D1034` a3af6c0
- menu-complete: fix a bug that candidates from menu only contained visible ones `#D1036` 275779f
- menu-complete: fix a bug that original texts were lost on cancel `#D1049` 3bbfef6
- edit: fix a bug that rendering is caused twice `#D1053` c7599a2
- color (layer:region): fix a bug that highlighting is cleared without dirty ranges `#D1053` 23796bc
- edit (nsearch): fix a bug that the search range is narrowed after fail `#D1053` 3b2237e
- edit (nsearch): fix a bug of messages on search fail `#D1053` 3b2237e
- util: fix a bug that SGR of visible-bell remains 799f6d3
- decode: fix a bug of infinite loops on `ble-reload` `#D1077` 0f01bcf `#D1079` fee22b1
- decode: workaround a bash-5.0 bug of `bind -p` `#D1078` b52da28
- complete: workaround slow command candidates generation in Cygwin `#D1080` 376bfe7
- syntax: fix false error highlighting of commands after `}`, `fi`, `done` or `esac` `#D1082` 4ce2753
- decode: fix a bug that modifyOtherKeys did not work at all 1666ec2
- edit: fix a problem that status line vanishes on window resize `#D1085` 467b7a4
  - edit: recalculate prompts after resize `#D1088` b29f248
  - edit: fix the position of cursor after resize `#D1089` b29f248
- decode: fix a bug that `ble-update` breaks keymap cache `#D1086` ab8dad2
- edit (`ble/builtin/read`): suppress noisy job messages and delay caused by vbell `#D1087` 309b9e4
- edit (`ble/builtin/read`): workaround failglob crash on vbell inside `read` `#D1090` 2e6f44c
- edit: workaround a bash bug that history entries are removed by `history -p` `#D1091` 146f9e7
- edit (self-insert): workaround Bash-3.0 bug that ^? cannot be handled properly `#D1093` e09c7b5
- highlight: fix a bug that quoted tilde expansions are processed for filename highlighting `#D1095` 3f1f472
- menu-complete: fix a bug that word is expanded on cancel `#D1097` 001b914
- highlight: fix a problem that empty arguments are highlighted as errors `#D1116` 64ae8ce
- sabbrev: fix a bug that menu-filter is not canceled on some sabbrev expansion `#D1118` 30cc31c
- main: fix a bug that `source ble.sh --noattach` in `ble.sh` sessions hangs `#D1130` d35682a caa46c2 `#D1199`
- syntax: workaround bashbug 3.1/3.2 that `eval` ending with <kbd>\ + LF</kbd> causes error messages `#D1132` a4b7e00
- term: workaround `cygwin` console glitches `#D1143` b79c35f `#D1144` ef19d17
- main: fix a bug that error messages for unsupported shells are not printed `#D1149` 34bd6f8
- main: workaround `set -ex` `#D1153` 06ebf9f
- main: workaround shell variable `FUNCNEST` `#D1154` fa2aa47
- highlight: fix error messages on the command line `a=[` `#D1156` b159ea2
- util: fix a bug of "ble/builtin/trap" not recognizing "-" `#D1161` 11fddba
- init-bind: workaround a bash-5.0 bug that `bind '"\C-\\": ...'` does not work `#D1162` 80edf44
- init-bind: do not use workaround of `C-x` in vi mode `#D1163` e6a3d33
- vi_test: fix test for the macro playing `#D1164` 636517c
- exec: fix a problem that the shell hangs with failglob in pipe `#D1166` ac8ba6e
- complete: fix a problem of delay with path `//` in Cygwin `#D1168` 2cf8cc7
- prompt: fix the expansion of `\w` and `\W` in `PS1` for working directories with double slashes `#D1169` d1288dd
- exec: workaround termination of command execution on syntax error in array subscripts `#D1170` 4f442d0
- history: fix a bug that garbage `__ble_edt__` is added in front of history entries 61f4bd1
- decode: remove debug messages for `ble-bind -s` 64a17c3
- syntax: fix highlighting of `${!var@}` `#D1176` 161ed80
- term: fix `Ss` (`DECSCUSR`) 0c773da
- term: workaround linux console <kbd>CSI \></kbd>, <kbd>CSI M</kbd>, <kbd>CSI L</kbd> `#D1213` `#D1214` 0ec6f0c
- edit: fix exit status of Bash by key binding <kbd>C-d</kbd> `#D1215` a9756e9

## Support macOS, FreeBSD, Arch Linux, Solaris, Haiku, Minix

- util: fix the error message "usage: sleep seconds" on macOS bash 3.2 `#D1194` (reported by dylankb) 6ff4d2b
- decode: recover the terminal states after failing the default keymap initialization `#D1195` (reported by dylankb) 846f284
- main (`ble-update`): use shallow clone `#D1196` 2a20d9c
- main (`$_ble_base_cache`): use different directories for different ble versions `#D1197` 55951d1
- edit (`ble/builtin/read`): fix argument analysis with user-provided `IFS` in Bash 3.2 (reported by dylankb) `#D1198` 7411f06
- global: fix subshell detection in Bash 3.2 `#D1200` ca8df8a
- syntax: workaround Bash-4.1 arithmetic bug `#D1201` f248c52
- Makefile: fix "install" for BSD sed `#D1202` 32c2e1a
- term: support "tput" based on termcap `#D1203` `#D1204` 161af07
- global: adjust for FreeBSD and Arch Linux `#D1205` 6ac5b8c
- global: workaround Solaris awk `#D1207` 74d438d
- util: support Haiku `#D1208` e3de373
  - ble/util/msleep: do not use `read -t time` for Haiku
  - ble/term/stty: check available character settings
  - init-cmap: check termcap settings for <kbd>home</kbd>
- util: support Minix `#D1209` 49e6457
  - ble/util/msleep: do not use `read -t time -u FD` in Minix
  - ble-edit/prompt: does not abbreviate IPv4 address for `\h`
  - Makefile: create directory `dist` for `make dist`

## Internal changes

- complete: isolate menu related codes `#D1029` 43bb074
- global: use `builtin echo` explicitly `#D1035` a6232c2
- decode: re-implement rlfunc2widget without fork `#D1063` d2e7dbe
- blerc: add descriptions `#D1064` d61b6af
- decode: decode mouse events `#D1084` 51fae67
- history: move history related codes to `src/history.sh` `#D1119` 1bfc8eb e5b1980
  - history: move codes related to history prefixes and history searches to `history.sh` `#D1136` 1cda6ff 20024d2
  - history: use common "_ble_history_onleave" for different histories `#D1137` ec19d51
- keymap/vi: deal with textarea local data properly `#D1123` 2ea7cfd
- edit: remove `ble-edit/exec:exec` `#D1131` 0cb9c6d
- global: distinguish exit status 147 and 148 `#D1141` d1a78fb
- global: follow bash syntactic changes on arithmetic command 16e0f0e
- decode: check `bind -X` first to store the original bindings `#D1179` 4057ff0
- complete: resolve collision of flag chars with `shopt -s nocaseglob` `#D1186` 550fb14
- color: change return variable of `ble/color/{,i}face2{g,sgr}` to `ret` `#D1188` 1885b54
- global: workaround `shopt -s xpg_echo` `#D1191` e46f9a3

<!---------------------------------------------------------------------------->
# 2019-03-21

2019-02-09..2019-03-21 (#D0915...#D1015) 949e9a8...df4feaa

## New features

- auto-complete: support <kbd>end</kbd> at the end of line a374635
- decode: replace builtin `bind` for `ble.sh` settings `#D0915`  90ca3be `#D0918` e0cdd15
  - decode: update mapping of rl-functions and widgets for vi_imap and vi_nmap `#D1012` 7fec4b6
  - decode: support `bind [-psPSX] [-quf arg]` `#D1013` 9265f8a
- edit: support <kbd>C-x C-g</kbd>, <kbd>C-M-g</kbd> for `bell` and `cancel` `#D0919` 2e83120
- syntax: support `set +B` `#D0931` 12f80dd
- syntax: support aliased keywords `#D0936` 7054e28
- complete: support `ble-sabbrev -m key=function` `#D0942` bcdf843
- complete: support description of candidates `#D0945` `#D0946` 0fa73bf `#D0977` 96fe498
  - canvas: use ... instead of … when unicode is not available `#D0979` 51e600a
  - canvas (`ble/canvas/trace`): support `opts=truncate:confine` `#D0981` 79916d2
- complete: support insertion of ambiguous common part `#D0947` 3644a8e
- complete: support three levels of ambiguous matching `#D0948` 3644a8e
- complete: support menu item highlight of ambiguous matching `#D0949` 3644a8e
- complete: support menu pages `#D0958` ff43e01 a488e01 `#D0990` 32aeef0
  - menu-complete: show page numbers with `visible-bell` `#D0980` 6297e65
  - menu-complete: fix a bug that height of `menu` is too large (<= bash-4.1) `#D0983` 129a1f0
- edit: support `bleopt rps1=` for the right prompt `#D0959` 90a8915 `#D0964` fa2a874 `#D0970` 87c8348
  - rps1: fix coordinate calculations for rps1 `#D0982` 129a1f0
  - canvas (`ble/canvas/trace`): fix a bug that `measure-bbox` does not work (<= bash-3.1) `#D0988` 7f880de
  - canvas (`ble/canvas/trace`): fix a bug that `x1` and `y1` is not properly updated `#D0988` 7f880de
  - edit: support `bleopt rps1_transient` `#D0993` 44edd38
  - edit: fix a bug that `rps1` is cleared on execution of the command `#D1003` 5780154
  - edit: erase trailing spaces after newlines when `rps1_transient` is enabled `#D1004` 5780154
  - edit: support multiline `rps1` (Note: still restricted to fit in lines of `PS1`) `#D1005` 5780154
- complete: support "bleopt complete_menu_style=desc-raw" `#D0965` 1fd7a3e
- complete: support <kbd>prior</kbd>, <kbd>next</kbd>, <kbd>home</kbd>, <kbd>end</kbd> in `menu_complete` keymap `#D0966` b729d23
- edit: support `bleopt prompt_eol_mark=$'\e[94m[ble: EOF]\e[m'` `#D0968` 6c8b52a
- complete: highlight active ranges of `menu-filter` `#D0969` 500f702 `#D0971` aae8b26
  - menu-filter: cancel `menu-filter` when the word ends `#D0974` 6ce2ad2
  - menu-filter: improve highlight `#D0975` b89f39f
- isearch: show progress bar using unicode chars `#D0978` 51e600a
- main: support `ble-reload` ef51490
- complete: support `source:sabbrev` `#D0994` 5c9e579
- complete: clear menu on <kbd>C-g</kbd> `#D0995` e0f93a2
- vi_imap: support `bleopt keymap_vi_imap_undo=more` `#D0996` 50f8ad2
- util: support `bleopt vbell_align` and `ble-color-setface vbell{,_flash,_erase}` for vbell `#D0997` 325883e
  - vbell: fix a bug that garbages remain on short messages just after longer messages `#D1010` 3e9ff85
- decode: support "bleopt decode_abort_char=28" `#D0998` b110cb9
- complete: support `visible-stats` and `mark-directories` `#D1006` b389b3b
- complete: support `mark-symlinked-directories`, `match-hidden-files` and `menu-complete-display-prefix` `#D1007` fd66194
- canvas: support `bleopt char_width_mode=auto` `#D1011` 3978df3

## Changes

- prompt: support correct handling of escapes `#D0923` 22f9b56
- util (`ble/util/sleep`): adjust delay `#D0934` `#D0935` 5fd5cd6 ad1208b 188cd98
- complete: use candidates in menu if present `#D0939` 52eaf01
  - complete: fix a bug that menu-complete is disabled after `menu-filter` `#D0951` 08cba07
  - complete: fix a bug that wrong action is performed after `menu-filter` `#D0952` 08cba07
  - complete: fix a bug that extra <kbd>TAB</kbd> is needed to enter `menu-complete` `#D0956` aa6bd73
  - complete: fix a bug that candidates are not regenerated on function name completions `#D0961` bbea72e
  - complete: fix a problem that the menu style is reset on `menu-complete` `#D0972` 47c28ff
  - menu-filter: explicitly call `ble/complete/menu-filter` (<= bash-3.2) `#D0986` 1b14b11
- syntax: allow variable assignment in arguments of `eval` `#D0941` 2f2f0eb
- highlight: do not highlight overwrite modes when mark is active `#D0950` 4efe1a9
  - highlight: disable `layer:menu_filter` (<= bash-3.2) `#D0987` 1b14b11
- complete: disable `auto-complete` inside the active range of `menu-filter` `#D0957`
- util (visible-bell): truncate long messages to fit into a line `#D0973` e55ff86
- edit: render prompt immediately on newline `#D0991` cdb8acb `#D1003` 5780154
- syntax: detect syntax errors of `CTX_CMDX1` immediately followed by terminating keywords `#D1001` 7ea02b7
- complete: improve support of `bind 'completion-ignore-case on'` `#D1002` 25ebc55
- complete: preserve original path specifications on ambiguous completion `#D1014` a39d1ac
- complete: append `,` instead of ` ` after completion in brace expansions `#D1015` df4feaa

## Fixes

- main: workaround `set -evx` `#D0930` 698517d
- edit (widget `delete-horizontal-space`): fix a bug that spaces before the cursor is not removed `#D0932` 9290adb
- bleopt: fix a bug that false error messages are output on reload when `failglob` is set `#D0933` 64cdcba c62db26
- decode: fix a bug that <kbd>\\</kbd> cannot be input after reattach `#D0937` a46ada0
- reload: fix a bug that `PS1` is lost on reload with `--attach=prompt` `#D0938` 1107ca8
- main (`--attach=prompt`): workaround rewrite of `PROMPT_COMMAND` `#D0940` 863fd7b
- vi_nmap (`/`, `?`, `n`, `N`): fix search progress `#D0944` f20f840
- complete: fix a problem of slow ambiguous filename matching in nested directories `#D0960` 7b3ee55
- util: improve performance of `ble/{util/{mapfile,assign-array},string#split-lines}` (<= bash-3.2) `#D0985` ae176b2 `#D0989` 36b9a8f f199215
- sabbrev: fix a bug that sabbrev is disabled (<= bash-3.2) `#D0985` 840af29
- util (ble/util/msleep): suppress warnings from `usleep` `#D0984` 8e4180c
- util: fix a problem that <kbd>C-d</kbd> cannot be input in nested Bash 3.1 `#D0992` 88a1b0f
- edit: fix a bug of a redundant newline on `read -e` `#D0999` 700bc91

## Internal changes

- [refactor] info: rename info type `raw` -> `esc` `#D0954` ac86f10
- [refactor] do not use brace expansions for `VARNAMES` `#D0955` 711e7df
- [refactor] `ble-{highlight,complete,syntax}` -> `ble/*` 7aaa660 ae6be66 8ea903c
- [refactor] `ble-edit/info/.construct-text` -> `ble/canvas/trace-text` `#D0973` e55ff86
- rename `ble/complete/action:*/getg` -> `ble/complete/action:*/init-menu-item` `#D1006` b389b3b

<!---------------------------------------------------------------------------->
# 2019-02-09

2018-10-05 -- 2019-02-09 (#D0858..#D0914) 6ed51e7..949e9a8

## New features

- color (`ble-color-setface`): support various spec such as SGR params `#D0860` 82fe96d `#D0861` 257c16d `#D0864` 2eaf2a9
- syntax: `bleopt filename_ls_colors` に対応 `#D0862` c7ff302 `#D0863` 3c5bacf ec31aab
- vi_omap: support <kbd>v</kbd>, <kbd>V</kbd>, <kbd>C-v</kbd> `#D0865` 54942e0 `#D0866` a9a1638 `#D0867` d3d8ea3 `#D0868` eb848dc
- main: improve support of `[[ -o posix ]]` `#D0871` 07ae3cc `#D0872` 513c543
- main: do not load ble.sh when bash is started by `bash -i -c command` `#D0873` fc23a6d
- main: support `ble-update` `#D0874` fc45be6 `#D0875` 0b50974 `#D0891` d010300 `#D0910` 4743c00 2dc3a3f
- vi_nmap: support <kbd>C-d</kbd>, <kbd>C-u</kbd>, <kbd>C-e</kbd>, <kbd>C-y</kbd>, <kbd>C-f</kbd>, <kbd>next</kbd>, <kbd>C-b</kbd>, <kbd>prior</kbd> `#D0886`
- isearch: use previous needle for empty string search `#D0889` 362fce3
- vi_imap: add a function `ble-decode/keymap:vi_imap/define-meta-bindings` `#D0892` a21d22f
- progcomp: support `complete -I` for Bash 5.0 `#D0895` `#D0896`
- progcomp: support candidates which replace the original text before the cursor `#D0897` 41b8cbb
- progcomp: support `compopt -o nosort|noquote|plusdirs` `#D0898` cc48539
- edit: support <kbd>M-*</kbd> `#D0899` 3fd7d6e
- edit: support <kbd>M-g</kbd>, <kbd>C-x *</kbd>, <kbd>C-x g</kbd> `#D0902` 41797c6
- progcomp: support `COMP_WORDBREAKS` `#D0903` 7cfe425
- complete: support completion of tilde expansion `#D0907` b4fc40c `#D0908` 9fafdb3
- main: support `BLE_VERSION` and `BLE_VERSINFO` (suggested by cmplstofB) `#D0909`
- global: support `--help` for public functions `ble-*` (suggested by cmplstofB) `#D0911` 77d459d f4d03f6 1d191c7 1209ac6 `#D0913` 92d9038

## Changes

- edit: change cursor position after <kbd>u</kbd> `#D0877` 9d5c945
- edit: handle panel layouts `#D0878`--`D0882` 6a26894 `#D0888` c8e0d28
- vi_nmap: support <kbd>z z</kbd>, <kbd>z t</kbd>, <kbd>z b</kbd>, <kbd>z .</kbd>, <kbd>z RET</kbd>, <kbd>z C-m</kbd>, <kbd>z +</kbd>, <kbd>z -</kbd> `#D0886`
- emacs: change M-m M-S-m from `beginning-of-line` to `non-space-beginning-of-line` f77f1aa
- bleopt: rename internal settings to `internal_{ignore_trap,suppress_bash_output,exec_type,stackdump_enabled}` fd042d8
- vi_nmap: change the behavior of <kbd>C-home</kbd>, <kbd>C-end</kbd> to match with those of vim 8682f98
- util (`ble/util/unlocal`): add workaround for Bash-5.0 `localvar_unset` `#D0904` 8677a71
- sabbrev: quote key in printing definitions by `ble-sabbrev` `#D0912` 2994d80

### Fixes

- info: fix a bug that coordinates calculation breaks with Japanese text `#D0858` 67c77dc
- syntax (`extract-command`): fix a bug that extraction of nested commands always fails `#D0859` c3270f6
- complete: fix a bug that the settings `complete -c` does not work `#D0870` 1ca5386 82bb154
- main: fix a bug that the determination of `_ble_base` fails when loaded as `source ble.sh` without specifying the directory of `ble.sh` 201deae
- util: `ble/util/assign` が正しい戻り値を返さないバグの修正 bd14982
- util: `ble/util/assign-array` の入れ子の呼び出しで内容が混ざり合う問題の修正 bd14982
- progcomp: fix a bug that bash-completion does not work properly due to wrong `COMP_POINT` `#D0897` 41b8cbb
- global: fix leak variables `#D0900` 244f965 `#D0906` b8dcbfe 9892d63
- progcomp: fix a problem that completion functions can consume stdin `#D0903` 7cfe425

## Internal changes

- global: properly quote rhs of `[[ lhs == rhs ]]` f1c56ab
- syntax: rename variables `BLE_{ATTR,CTX,SYNTAX}_*` -> `_ble_{attr,ctx,syntax}_*` 1fbcd8b (ref #D0909)

<!---------------------------------------------------------------------------->
# 2018-10-05

2018-09-24 -- 2018-10-05 (#D0825..#D0857 6ed51e7)

## 新機能
  - highlight: 変数代入の右辺及び配列要素の着色に対応 `#D0839` 854c3b4
  - nsearch: (非インクリメンタル)履歴検索に対応 <kbd>C-x {C-,}{p,n}</kbd> `history-{,substring-,n}search-{for,back}ward` `#D0843` e3b7d8b 0d31cd9 253b52e
  - isearch: 検索前に選択状態でがあれば検索後に復元する `#D0845` 93f3a0f
  - decode: 貼り付け時など大量の入力があった時に処理の進行状況を表示 `#D0848` c2d6100
  - decode: 貼り付け時などの高速化の為に一括の文字列挿入に対応 (`batch-insert`) `#D0849` 48eeb03
  - decode: `bleopt decode_isolated_esc=auto` でキーマップに応じて単独 <kbd>ESC</kbd> の取扱を切り替え `#D0852` 9b20b45 edd481c
  - complete: `bleopt complete_{auto_complete,menu_filter}=` で自動補完・候補絞り込みの無効化に対応 `#D0852` 4425d12
  - vi: テキストオブジェクト単語の再実装 (reported by cmplstofB) `#D0855` 9f2a973 ad308ae 3a5c456 6ebcb35
  - vi: オペレータ `d` の特殊ルールに対応 `#D0855` fa0d3d3

## バグ・問題修正
  - decode: `ble-bind -d` に於いて `-c` 及び `-x` の引数の引用符が二重になっている問題の修正 `#D0850`
  - auto-complete: 構文エラーが自動補完により解決される時 <kbd>RET</kbd> でコマンド実行が抑止されない問題の修正 `#D0827` daf360e
  - highlight: `shopt -s failglob` で配列の指示初期化子がエラー着色される問題の修正 (reported by cmplstofB) `#D0838` d6fe413
  - complete: プログラム補完に対して曖昧補完が効かない時の対策 `#D0841` 713e95d
  - isearch: ユーザ入力による割り込みで検索位置の記録に失敗していたバグの修正 `#D0843`
  - isearch: キャンセル時に位置とマークが正確に復元されない問題の修正 `#D0847`
  - isearch, dabbrev: 検索処理中にユーザが何か入力するまで現在行が更新されない問題の修正 `#D0847`
  - decode: 未ロードのキーマップに対して `ble-bind -m -P` `ble-bind -m kmap -f kspecs -` が使えない問題の修正 66e202a
  - auto-complete: <kbd>C-j</kbd> が単なる "確定" になっていたのを "確定して実行" に修正 `#D0852` 01476a7
  - edit: <kbd>M-S-f</kbd>, <kbd>M-S-b</kbd> を束縛するべきところ <kbd>M-C-f</kbd>, <kbd>M-C-b</kbd> を束縛している箇所を修正 `#D0852` c68e7d7
  - color: Bash 3.0 で算術式内の `<()` がプロセス置換と解釈される問題の対策 `#D0853` 520184d
  - syntax: コメント上の単語が何故か除去されないバグの修正 (reported by cmplstofB) `#D0854` 641583f
  - vi: Bash 3.1 及び 3.2 で <kbd>C-d</kbd> 受信の為のリダイレクトに失敗する問題の修正 `#D0857` d4b39b3

## 動作変更
  - sabbrev, vi_imap: `sabbrev-expand` を <kbd>C-x '</kbd> ではなく <kbd>C-]</kbd> から束縛 `#D0825` e5969b7
  - core: `bleopt` に設定名を指定子て設定内容を表示させる時、設定名の存在を確認する `#D0850` 725d09c
  - isearch: <kbd>C-d</kbd> で現在の選択範囲を削除する様に変更 `#D0826` c3bb69e `#D0852` db28f74
  - isearch: <kbd>C-m</kbd> (<kbd>RET</kbd>) で確定した時は選択範囲を解除する様に変更 `#D0826` c3bb69e
  - decode: `ble-bind` のオプションを再構成 `#D0850` f7f1ec8 64ad962
  - decode: 組み込みコマンド `bind` を上書きして `ble.sh` の動作が阻害されない様に引数をチェックして実行 `#D0850`
  - complete: autoload `ble-sabbrev` (`core-complete.sh`), `ble-syntax:bash/is-complete` (`core-syntax.sh`) `#D0842` df0b769
  - isearch: 編集関数 `isearch/accept-line` が <kbd>RET</kbd> 以外から束縛されていても <kbd>RET</kbd> を実行する様に変更 `#D0843`
  - vi, [in]search: mark 名を整理 (`char`/`line`/`block`/`search` に接頭辞 `vi_` 付加し、新しい mark 名を `search` とする) `#D0843`
  - edit: 関数名変更 `ble/widget/accept-single-line-or/accepts` → `ble-edit/is-single-complete-line` `#D0844`
  - isearch: 空文字列で検索した時の振る舞いを再考 `#D0847` d05705e
  - decode: 入力のキー復号の各種調整 `#D0850` dc013ad
  - dabbrev: <kbd>C-m</kbd>, <kbd>RET</kbd> で展開終了、<kbd>C-j</kbd>, <kbd>C-RET</kbd> でコマンド実行 `#D0852` 01476a7

## 内部的変更
  - isearch, dabbrev: `ble/util/fiberchain` による再実装 `#D0843`, `#D0846` 2c695cf bdf8072 95268c1
  - edit, vi: 選択範囲の種類を表す mark 名を整理 a1a6272
  - edit: 関数名変更 `ble/widget/accept-single-line-or/accepts` → `ble-edit/is-single-complete-line` `#D0844` 63ec9fe
  - refactor: ファイルの整理 5e07e7f 1a03da2 673bd1d 55c4224 9ce944c 9a47c57 25487a7 5679ffc b7291a7
  - refactor: 関数名・変数名の整理 `#D0851` d1b780c 9129c47 4d1181a

<!---------------------------------------------------------------------------->
# 2018-09-23

2018-09-03 -- 2018-09-23 (#D0766..#D0824 8584e82)

### 補完: 新機能
  - complete: 自動補完において履歴からの検索に対応 `#D0766`, `#D0769` `#D0784` (fix)
  - complete: 自動補完時の <kbd>M-f</kbd> <kbd>C-f</kbd> 等に対応 `#D0767`
  - complete: `"$hello"` などの引用符中のパラメータ展開がある場合でも補完に対応 `#D0768`
  - complete: 配列要素代入の右辺での補完に対応 `#D0773`
  - complete: ブレース展開の途中での補完に対応 `#D0774`
  - auto-complete: `ble/widget/auto_complete/accept-and-execute` 対応 `#D0811`
  - complete: 補完関係の設定をする為の load hook の追加 `#D0812`
  - complete: 種類を指定した補完に対応 `#D0820` `#D0819` (fix)
  - complete: 静的略語展開に対応 (`ble-sabbrev key=value` で設定) `#D0820`
  - complete: 動的略語展開に対応 `#D0820`

## 補完: バグ・問題点修正
  - complete: 一意確定した直後の補完ですぐにメニュー補完に入るバグの修正 `#D0771`
  - complete: `function fun [` 直後の補完で `[\[` が挿入される問題の修正 `#D0772`
  - complete: 曖昧補完で補完を実行しようとすると入力済みの部分が削除されるバグの修正 `#D0775`
  - complete: 自動補完が起動しなくなっているバグの修正 `#D0776`
  - complete: プログラム補完関数が `failglob` で失敗するとシェルが終了する問題の対策 (reported by cmplstofB) `#D0781`
  - complete: `failglob` の時コマンド補完候補に `*` が含まれてしまう問題の修正 (reported by cmplstofB) `#D0783`
  - complete: 候補一覧にて入力済み範囲の強調が絞り込みにより無効化されるバグの修正 `#D0790`
  - complete: 自動補完を抜けた後のマーク位置が誤っているバグの修正 `#D0798`
  - complete: `for a in @` や `do @` の位置の補完でエラーメッセージが表示されるバグの修正 `#D0810`

## 補完: 動作変更
  - complete: 入力済み部分の評価方法の内部変更 `#D0777`
  - complete: 自動補完の着色の変更 `#D0780` `#D0792`
  - complete: プログラム補完で提供するコマンドライン (`COMP_*`) にて、補完開始点に単語の切れ目を入れる様に変更 `#D0793`
  - auto-complete: <kbd>C-RET</kbd> で補完を確定してコマンド実行 `#D0822`

## 他: 新機能
  - edit: `IGNOREEOF` に対応 `#D0787`
  - edit: コマンド `exit` にて、ジョブが残っている場合はユーザに尋ねて終了 `#D0789`, `#D0805` (bugfix)
  - term: 256色対応のない端末での減色の実装 `#D0824`

## 他: バグ・問題点修正
  - isearch: 非同期検索ができなくなっていたバグの修正
  - color: `ble-color-setface` の遅延初期化順序のバグを修正 (reported by cmplstofB) `#D0779`
  - decode: CentOS 7 で `LC_ALL=C.UTF-8` に対してエラーメッセージが出る問題の対策 `#D0785`
  - edit: ジョブがある時の終了 <kbd>C-d</kbd> について `bleopt allow_exit_with_jobs` 対応 (request by cmplstofB) `#D0786`
  - edit: Bash 3.* で <kbd>C-d</kbd> によるプログラム実行 (`ble-edit/exec:gexec`) が遅延するバグの修正
  - syntax: Bash 3.2--4.1 の算術式バグによる関数定義の構文解析に失敗する問題の対策 `#D0788`
  - highlight: `region` レイヤーの着色範囲が改行を跨ぐ場合に既定の着色になるバグの修正 `#D0791`
  - isearch: 空の検索文字列による一致に <kbd>C-h</kbd> で戻った時に全体が選択されるバグの修正 `#D0794`
  - decode: `failglob` の時 `ble-bind -d` に失敗する問題の修正 `#D0795`
  - edit: `command-help` のコマンド名抽出に失敗するバグの修正 (reported by cmplstofB) `#D0799`
  - syntax: 履歴展開の置換指示子の解析が正確でない問題の修正 (report by cmplstofB) `#D0800`
  - edit: Bash 3.0 で履歴展開 `:&` が使えない問題の修正 `#D0801`
  - idle: 負の `sleep` を試みてエラーメッセージが出る問題の修正 `#D0802`
  - bind: `ble-detach` 時に、Bash 3.0 の <kbd>"</kbd> のバインディングを破壊するバグの修正 `#D0803`
  - edit: `ble-detach` 直後にコマンドラインに設定される `stty sane` が表示されない問題の対策 `#D0804`
  - core: Bash-3.0 で補完候補がない場合にエラーメッセージが表示されるバグの修正 `#D0807`
  - edit: コマンド実行中にウィンドウサイズが変更された時にプロンプトが表示されてしまう問題の解消 `#D0809`
  - edit: widget 内で `read -e` を使用した時・`read -e` がタイムアウトした時に表示が乱れる問題の解消 `#D0809`
  - edit: `read -e` でタイムアウトが効かないバグの修正 `#D0809`
  - term: 16色の端末で色が化けるバグの修正 `#D0823`

## 他: 動作変更
  - edit: `read -e` がキャンセル・タイムアウトによって終了した時に入力文字列を灰色で再表示 `#D0809`
  - decode: キーマップの既定の初期化を最初の `ble-bind` 時に確認する様に変更 `#D0813`
  - core: `ble/util/clock` 導入 `#D0814`
  - edit: `ble-edit/read -e -t timeout` において、タイムアウトをより高精度で処理 (`ble/util/clock`) `#D0814`
  - color: `face` が定義されていない時のエラーメッセージの表示方法を変更 `#D0815`
  - edit: コマンド実行時に現在のカーソル位置より下に表示されている端末の内容を上書きする様に変更 `#D0816`
  - edit: `accept-line` において、ちらつき防止の為、実際のコマンド実行が伴わない時は info の再描画を行わない `#D0816`
  - edit: `ble/widget/history-expand-line` は <kbd>C-RET</kbd> ではなく <kbd>M-^</kbd> から束縛される様に変更 `#D0820`
  - edit: `ble/widget/magic-space` で履歴展開が行われなかった時、現在位置で静的略語展開を試みる様に変更 `#D0820`
  - isearch: <kbd>RET</kbd> でコマンド実行ではなく検索を終了するだけに変更。<kbd>C-RET</kbd> でコマンド実行 `#D0822`

## 他
  - Makefile: 依存ファイルを `.PHONY` target として出力 `#D0778`
  - core: `ble/util/assign` をリエントラントに修正 `#D0782`
  - 議論 complete: `#D0770` edit: `#D0796` vi: `#D0796`
  - `blerc` の更新

## 以下は widget 名変更の一覧
  - `menu_complete/accept`              → `menu_complete/exit`
  - `auto_complete/accept`              → `auto_complete/insert`
  - `auto_complete/accept-on-end`       → `auto_complete/insert-on-end`
  - `auto_complete/accept-word`         → `auto_complete/insert-word`
  - `auto_complete/accept-and-execute`  → `auto_complete/accept-line`
  - `isearch/accept`                    → `isearch/accept-line`

<!---------------------------------------------------------------------------->
# 2018-09-02

2018-07-29 - 2018-09-02 (#D0684..#D0765 0c28ed9)

## 補完: 新機能
  - complete: 曖昧補完 `#D0707` `#D0708` `#D0710` `#D0713` `#D0743` (fix)
  - complete: Readline 設定 `completion-ignore-case` に対応 `#D0709` `#D0710`
  - complete: `ble/cmdinfo/complete:$command_name` 対応 `#D0711`
  - complete: `path:...` などと入力した時の続きの補完に対応 `#D0715`
  - complete: 引用符内のエスケープなどを適切に処理する `#D0717`
  - complete: 自動補完に対応 `#D0724`, `#D0728`, `#D0734` & `#D0735` (vim-mode), `#D0766` (history)
  - complete: カーソルの右側に補完結果の一部が含まれる時にスキップする機能 (`bind set skip-completed-text`) `#D0736`
  - complete: 引用符の中で補完した時に引用符を閉じる機能 `#D0738`
  - complete: 算術式内部での変数名の補完に対応 `#D0742`
  - complete: 候補一覧表示の整列と着色 `#D0746` `#D0747` `#D0762` `#D0765`
  - complete: menu-completion (メニュー補完) 対応 `#D0749` `#D0757` `#D0764`
  - complete: menu-filter (候補絞り込み) 対応 `#D0751`
  - complete: vi_cmap に於ける補完 `#D0761`

## 補完: バグ修正・対策
  - complete: Cygwin でのコマンド名補完に於いて `.exe` の途中まで入力した時に正しく補完できない問題の修正 `#D0703`
  - complete: `complete` によって登録されたプログラム補完に対して変数 `COMP_*` が正しく設定されない問題の修正 `#D0711`
  - complete: `"` や `'` を含むファイル名の補完が正しくできない問題の修正 `#D0712` `#D0714`
  - complete: 補完中に特殊キーを入力しても中断しない問題の解消 `#D0729`
  - complete: クォートを認識しないプログラム補完関数に対する対策 `#D0739`
  - complete: 引数の途中からのプログラム補完の不整合の修正 `#D0742` `#D0744`
  - complete: パラメータ展開 `${var}` 直後からの補完が正しく実行できる様に修正 `#D0742`

## 補完: 動作変更
  - complete: 補完候補生成直前の `shopt -s force_fignore` を参照して候補を制限する様に変更 `#D0704`
  - complete: `FIGNORE` はエスケープされた挿入文字列に対してではなくて、候補文字列に対して判定する様に変更 `#D0704`
  - complete: 関数名補完を `/` で区切られた単位で行う `#D0706` `#D0724` (曖昧一致の時は抑制)
  - complete: パラメータ展開で厳密一致で一意確定の時は他の補完文脈を使うように変更 `#D0740`
  - complete: パラメータ展開の補完後に挿入する文字を文脈に依存して変更 `#D0741`
  - complete: パラメータ展開の直後に補完で挿入する際のエスケープを文脈に依存して変更
  - complete: プログラム補完による生成候補でディレクトリ名を省略 `#D0755`

## 他: 新機能
  - edit (`RET`): 文法的に不完全のときに改行を挿入 `#D0684`
  - core (`ble/util/idle`): 簡易タスクスケジューラの実装 `#D0721`
  - core: add a function `ble/function#try` `#D0725`
  - idle: `ble/util/idle` でバックグラウンドジョブ待ち機能を実装 `#D0731` `#D0745` (history bugfix)
  - base: `--attach=prompt` 対応 `#D0737`
  - base: 初回初期化時の順序の変更と過程の info による表示
  - decode: modifyOtherKeys 対応の改善 `#D0752` `#D0756` `#D0758` `#D0759`
  - core (`ble/util/assing`): 第3引数以降にコマンドに対する引数を指定できるように変更 `#D763`

## 他: バグ修正・対策
  - highlight: 単語着色が乱れるバグの修正 `#D0686`
  - syntax: bash-3.2 以下で `_ble_syntax_attr: bad array subscript` のエラーが出るバグの修正 `#D0687`
  - prompt: PS1 で \v が空文字列になるバグの修正 `#D0688`
  - highlight: 上書きモードにおいてコマンドをキャンセルしても `disabled` レイヤーの着色が無視されるバグの修正 `#D0689`
  - core (ble/term/visible-bell): 横幅の計算を誤っているバグの修正 `#D0690`
  - decode: "set -o vi/emacs" で編集モードを切り替えた直後に "stty" が変になる問題の修正 `D0691`
  - core: LANG=C とすると動かなくなる問題の対処 `#D0698` `#D0699` `#D0700`
  - history: Cygwin で履歴の初期化に時間がかかる問題の対策 `#D0701`
  - history: bashrc 読み込み直後に謎の待ち時間が発生する問題の対策 `#D0702`
  - emacs: 貼り付け (bracketed paste) で文字列が二重に挿入されるバグの修正 `#D0720`
  - main: POSIXLY_CORRECT が設定されている時の対策 `#D0722` `#D0726` `#D0727`
  - edit: POSIXLY_CORRECT を用いた組み込みコマンド上書き対策 `#D0722`
  - decode: 連想配列に依る実装のバグを修正し bash-4.0, 4.1 においても連想配列を使用 '#D0730'
  - decode: `ble-bind -c` でシェルの特殊文字を含むコマンドが正しく実行できないバグの修正
  - edit: 履歴項目の数が倍増するバグの修正 `#D0732`
  - vi: キーボードマクロで特殊キーが再生されないバグの修正 `#D0733`
  - isearch: 現在位置の表示時の 0 除算のバグの修正
  - vi: `!!` をキャンセルしても操作範囲を示す着色が消えないバグの修正 `#D0760`

## 他
  - refactor: `#D0725` `#D0750` `#D0753` `#D0754`
  - bash-bug: Bash に対するバグ報告 `#D0692` `D0695` `D0697`

<!---------------------------------------------------------------------------->
# 2018-03-15

2018-03-15 (#D0644..#D0683 7d365d5)

## 新機能
  - undo: vi-mode `u` `<C-r>` `U` (`#D0644` `#D0648`); emacs `#D0649`; `#D0662`
  - vi-mode (nmap/xmap): `f1` で `command-help` 呼び出し
  - vi-mode (nmap): `C-a` `C-x` 対応 (nmap `#D0650`, xmap `#D0661`)
  - vi-mode (operator): 各種オペレータ対応 `#D0655` (`gq`, `gw` `#D0652`; `!` `#D0653`; `g@` `#D0654`)
  - vi-mode (operator): 追加入力のあるオペレータで作用対象を着色 `#D0656`
  - vi-mode (registers): registers `"[0-9%:-]` `#D0666` `#D0668`, `:reg` `#D0665`
  - vi-mode (smap): 選択モード `#D0672`
  - emacs: 主要なコマンドで引数に対応 `#D0646`
  - emacs: 複数行モードの時にモード名を表示。引数も表示。 `#D0683`
  - edit: `safe` keymap
  - edit: 絵文字の文字幅 `bleopt emoji_width=2` `#D0645`
  - core: 誤った `PATH` に対する対策 `#D0651`

## 動作修正
  - vi-mode (nmap/xmap/omap `<paste>`): 引数を無視するように変更
  - vi-mode (map `/` `?` `n` `N`): 検索の一致の仕方を vim と同様のものに変更 `#D0658`
  - vi-mode (omap): `g~?` で検索して一致した範囲まで大文字・小文字を切り替えるように変更 `#D0659`
  - vi-mode (map): 最終行付近で `+` `_` `g_` などを呼び出したときの振る舞いを vim と同様のものに変更 `#D0663`
  - vi-mode (xmap): テキストオブジェクト `[ia]['"]` の xmap での正しい振る舞い `#D0670`
  - vi-mode (nmap): `Y` で行頭に動かないように変更 `#D0673`
  - vi-mode (xmap): 矩形範囲抽出の効率化 `#D0677`
  - core: `ble.sh` ロード時間の改善 `#D0675`, `#D0682`, (遅延読込 `#D0678` `#D0679` `#D0680`, 裏で履歴読込 `#D0681`)

## バグ修正
  - vi-mode (omap): `cw` や `y?` が動かなくなっていたバグの修正
  - vi-mode: マクロで記録される内容に空白が挿入されるバグの修正 `#D0667` (テスト追加 `#D0669`)
  - vi-mode: 行指向の貼り付けが動かなくなっていたバグの修正 `#D0674`
  - complete: コマンド名によって第一引数の補完が正しく実行されないことがあるバグの修正 `#D0664`
  - syntax: ヒアストリングで $ret を指定するとエラーメッセージが現れたバグの修正 `#D0660`
  - syntax: bash-3.0 でコマンドの着色が常にエラーになっていたバグの修正 `#D0676`
  - decode: ble-decode-unkbd があらゆる文字について ESC を返す様になっていたバグの修正 `#D0657`
  - Makefile: 削除したファイル isearch.sh が要求されるバグの修正
  - Makefile: 最新の gawk で動かないバグの修正

<!---------------------------------------------------------------------------->
# 2017-12-03

## 新機能
  - edit, vi-mode: bracketed paste mode に対応 `#D0639`

## 動作修正
  - core: 端末の状態設定・復元とカーソル形状の内部管理 `#D0638`
    - 外部コマンドを呼び出すときに既定のカーソル形状にする
    - 外部コマンドから戻ったときにカーソル形状を復元する
  - syntax (extract-command): より下の構文階層にいてもコマンドを見つけられるように修正 `#D0635`
    これによりリダイレクトの単語などの上でも `command-help` (nmap `K`, emacs `f1`) が動くように。
  - syntax (チルダ展開): 変数代入の形式を持つ通常単語内部でのチルダ展開に対応 `#D0636`
  - syntax: [...] 内部でチルダ展開が起こったとき [...] は意味を失う `#D0637`
  - vi-mode (cmap `<C-w>`): imap `<C-w>` と同様に vim の動きに変更

## バグ修正
  - complete: 補完候補がない時に空文字列で確定するバグの修正 `#D0631`
  - complete, highlight: `failglob` 周りのバグの修正 (3) `#D0633` `#D0634`
  - vi-mode: `ret` グローバル変数が汚染されていたバグの修正 `#D0632`
  - highlight: 読み取り専用の変数名を入力するとエラーメッセージが出るバグの修正
  - decode: `__defchar__` から呼び出された widget が 125 を返したとき
    `__default__` から呼び出された widget にキー列が渡されないバグの修正
  - core: set -u にすると全く動かないバグの修正 `#D0642`
  - edit: ble.sh ロード中に `read -e` が動かないバグの修正 `#D0643`

<!---------------------------------------------------------------------------->
# 2017-11-26

## バグ修正
  - general: failglob で問題が生じるバグの修正 `#D0630`
  - keymap/vi (nmap q): bash-3.0 で動かなかったバグの修正
  - keymap/vi (cmap): C-d で終了してしまうバグを修正 `#D0629`
  - edit (ble/widget/command-help): エイリアスの上でヘルプを実行しようとすると無限ループになるバグを修正
  - edit (ble/util/type): "-" で始まる名前のコマンドの種類の判定に失敗し着色されなかったバグの修正
  - complete: 変数代入の右辺やリダイレクト先で補完できないことがあるバグの修正 `#D0627`
  - complete: 補完する単語にパラメータ展開が含まれるとき ble.sh のローカル変数の値を参照している問題の修正 `#D0628`

## 動作変更
  - bind/decode: 孤立 ESC の読み取り方法を変更。<C-q><C-[> で単体 <C-[> が入力されるように修正
  - bind/decode: input_encoding=C の時の孤立 ESC および C-@ の読み取りに対応
  - complete: 重複して列挙される候補を統合する `#D0606`
  - complete: 厳密一致するディレクトリ名が何故かコマンド候補に現れる問題の修正 `#D0608`
  - edit (command-help): 幾つかの組み込みコマンド・予約語について man bash の正しい位置に移動するように修正 `#D0609`
  - edit (command-help): クォートなどを除去してからコマンドのヘルプを探索するように変更 `#D0610`
  - core: 条件コマンドの比較で右辺をクォートし忘れていた箇所を修正 `#D0618`
  - highlight: `shopt -s failglob` の時、失敗する単語にエラー着色をする `#D0630`

## 構文解析変更
  - syntax: `> a.txt; echo` は構文エラーではないことに対応 `#D0591`
  - syntax: 変数代入・リダイレクトの後では予約語は意味を失いコマンドとして扱われることに対応 `#D0592`
  - syntax: `time` や `time -p` は構文的に正しいことに対応 `#D0593`
  - syntax: `echo $(echo > )` などの `>` の引数がない構文エラーにより `$()` が閉じず別の構文エラーを引き起こしていたのを抑制 `#D0601`
  - syntax: `function hello (())` は bash-4.2 未満では構文エラーとして扱うように変更 `#D0603`
  - syntax: `time -p -- command` を独立した文脈で解析するように変更 `#D0604`
    - complete: これにより `time` の引数のコマンド補完ができなかった問題は解消した `#D0605`
  - syntax: extglob 内部のプロセス置換 `@(<(echo))` に対応 `#D0611`
  - syntax: `[...]` によるパターンの解析に対応 `#D0612`
  - syntax: 変数代入の右辺にある不活性になった extglob の入れ子 `@(@())` も不活性にする `#D0613`
  - syntax: `shopt -u extglob` の時でも `*` や `?` を着色する `#D0616`
  - syntax: ブレース展開の着色に対応 `#D0622`
  - syntax: チルダ展開の着色に対応 `#D0626`
  - syntax: `for var in args...` の `args` におけるリダイレクトの禁止 `#D0623`
  - highlight: ヒアストリングの場合はパス名展開・ブレース展開を行わない `#D0624`
  - highlight: リダイレクト先ファイル名が複数語に展開されたらエラー着色 `#D0625`

## 構文解析修正
  - syntax: `$({ echo; })` や `$(while false; do :; done)` において `}`, `done` 等の後にコマンドがないと構文エラーになっていたバグの修正 `#D0593`
  - syntax: `-` で始まる名前のコマンド・関数名が正しく着色されないバグの修正 `#D0595`
  - syntax: `if :; then :; fi $(echo)` などの構文エラー着色が実行されないバグの修正 `#D0597`
  - syntax: 先読みによる不整合が起こるバグの修正・先読みの枠組みの整備 `#D0601`
    - プロセス置換周りで部分更新により不整合が生じるバグを修正
    - `function hello (())` としておいて `) (` を挿入して `function hello () (())` にすると不整合が生じるバグを修正 `#D0602`
  - syntax: 途中で `shopt -u extglob` にしても `_ble_syntax_bashc` が更新されないバグの修正 `#D0615`

<!---------------------------------------------------------------------------->
# 2017-11-09

## 新機能
  - vi-mode (nmap): `*` `#` `qx...q` `@x`
  - vi-mode (cmap): 履歴
  - core: bleopt 変数 `pager` (既定値 `''`) に対応。`ble.sh` の使うページャとして `${bleopt_pager:-${PAGER:-適当に探索}}` を使用する。
  - vi-mode (nmap `K`): `ble/cmdinfo/help:$cmd`, `ble/cmdinfo/help` に対応。

## バグ修正
  - vi-mode (cmap `<C-[>`): コマンドラインモードをキャンセルするキーマップが `bell` で上書きされていたバグの修正
  - decode: `shopt -s failglob`, `shopt -s nullglob` で `unset` が正しく動かないバグの修正
  - vi-mode (nmap `K`): `MANOPT=-a` で操作できなくなるバグの修正

## 動作変更
  - edit (`ble/widget/command-help`), vi-mode (nmap `K`): カーソル位置のコマンドの `man` を表示するように変更
  - base: キャッシュディレクトリ・一時ディレクトリの決定で、それぞれ `XDG_CACHE_HOME`, `XDG_RUNTIME_DIR` を参照するように変更
  - Makefile: インストール先ディレクトリで、`XDG_DATA_DIR` を参照するように変更
  - isearch: 実際に必要になるまでコマンド履歴のロードを遅延するように変更
  - vi-mode (nmap `K`): 組み込みコマンド・キーワードは `man bash` を表示する。
  - vi-mode (nmap `K`): シェル関数は関数定義を表示する。

<!---------------------------------------------------------------------------->
# 2017-11-05

## 新機能
  - vi-mode (exclusive motion): `:help exclusive-linewise` 特別規則 (exclusive -> inclusive, exclusive -> linewise) に対応
  - vi-mode (omap): `C-c` `C-[` で明示的にキャンセル
  - vi-mode: keymap/vi_test.sh 追加。regression が酷いので vi-mode の動作テストを自動化
  - complete: bleopt 変数 `complete_stdin_frequency` (既定値 `50`) 追加

## 動作変更
  - vi-mode (nmap `e`, `E`): 移動先が最終行の最後の文字の空白のとき、omap なら bell を鳴らさないように変更
  - vi-mode (omap/xmap `<space>`, `<back>`, `<C-h>`): 改行の数え方を変更
  - vi-mode (nmap `cw`, `cW`): 単語の最後の文字、および空白の上にいるときの振る舞いの変更
  - decode (ble-bind): `ble-bind -D` でキーマップの内部状態も出力するように変更
  - term: `_ble_term_SS` の既定値を空文字列に変更
  - complete: `shopt -s no_empty_cmd_completion` では補完を (コマンドの補完以外も) 全く行わないように変更
  - edit (ble/widget/exit): 編集中の文字列が残っているとき、灰色で再描画してから exit するように変更

<!---------------------------------------------------------------------------->
# 2017-11-03

## 破壊的変更
  - vi-mode (widget): 名称変更 blw/widget/vi-insert/* → ble/widget/vi_imap/*
  - vi-mode (bleopt 変数): 名称変更 bleopt keymap_vi_normal_mode_name → keymap_vi_nmap_name
  - vi-mode (imap): vi-insert/magic-space 廃止。代わりに magic-space を直接用いる。

## 新機能
  - vi-mode (xmap): `o` `O`
  - vi-mode (nmap): `.` 取り敢えず完成?
  - vi-mode (xmap/nmap): `gv`

## バグ修正
  - vi-mode (mark `` `x `` `'x`): オペレータが呼び出されないバグの修正
  - vi-mode (txtobj `[ia]w`): 英数字と _ の連続ではなく英字と _ だけの連続を単語としていたバグの修正
  - vi-mode (imap): `{count}i...<C-[>` において `<C-q>x` `<C-v>x` が正しく繰り返されなかったバグの修正
  - vi-mode (imap): `{count}i...<C-c>` において繰り返しが有効になっていたバグの修正
  - vi-mode (nmap `{N}%`): 目的の行に移動しなくなっていたバグの修正
  - vi-mode (nmap `_`): `d_` 及び `d1_` が linewise になっていないバグの修正
  - vi-mode (xmap `I` `A`): 動かなくなっていたバグの修正
  - vi-mode (xmap `I` `A`): 実行後のカーソル位置がずれていたバグの修正
  - vi-mode (xmap `I` `A` `c` `s` `C`): 矩形挿入の後の編集範囲 `` `[`] `` から1行目が抜けているバグの修正
  - vi-mode (xmap `?`): 検索 `?` が operator `g?` になっているバグの修正
  - vi-mode (xmap `/` `?` `n` `N`): ビジュアルモードの選択範囲が検索の一致範囲で上書きされるバグの修正
  - vi-mode (xmap `/` `?` `n` `N`): 現在の履歴項目の中で一致しない時、別の履歴項目にビジュアルモードのまま移動するバグの修正
  - lib/vim-surround (nmap `cs` `cS`): nmap `.` 対応時に引数とレジスタが効かなくなっていたバグの修正
  - lib/vim-surround (xmap `S`): `v` によるビジュアルモードで改行が前後に挿入されていたバグの修正

## 動作変更
  - vi-mode (imap `<C-w>`): vim の単語区切り (`w`) による削除に変更
  - vi-mode (nmap `[rRfFtT]x`): `<C-[>` でキャンセルするように変更
  - vi-mode (nmap `w` `b` `e` `ge`): 非英数字 ASCII の連続と、Unicode 文字の連続 をそれぞれ別の単語と扱うように変更
  - vi-mode (xmap `c` `s` `C`): `I`, `A` と同様の矩形挿入に対応

<!---------------------------------------------------------------------------->
# 2017-10-30

## 破壊的変更
  - vi-mode: キーマップの名称変更 vi_command -> vi_nmap, vi_insert -> vi_imap
  - vi-mode: 一部の widget の名称変更
    - ble/widget/{no,}marked -> ble/widget/@{no,}marked
    - ble/widget/vi-command/* (一部) -> ble/widget/vi_nmap/*
  - vi-mode: ble/widget/vi-insert/@norepeat 廃止。別の方法 (_ble_keymap_vi_imap_white_list) を用いる。

## 新しい機能
  - vi-mode (nmap): . は実装途中 (現状 nmap/omap におけるオペレータ経由の変更のみ記録)
  - vi-mode (mode): bleopt 変数 `term_vi_[inoxc]map`
  - decode: 孤立 ESC のタイムアウトに対応
  - edit: shopt -s histverify, shopt -s histreedit に対応 #D0548

## バグ修正
  - vi-mode (xmap): `p`, `P` が正しく動作しないバグを修正
  - vi-mode (imap): 挿入モードに入るときに指定した引数 (繰り返し回数) が常にキャンセルされていたバグの修正
  - vi-mode (txtobj; nmap `gg`, `G`): レジスター指定が消失していたバグの修正
  - lib/vim-surround (nmap ds): 引数が内部使用のオペレータ `y`, `d` に正しく渡っていなかったバグの修正
  - prompt: `PROMPT_COMMAND` で設定された `PS1` が永続化されていなかったバグの修正
  - decode: bind -x で曖昧な登録があって bash_execute_unix_command エラーになっていた問題の修正 #D0545
  - decode: `vi.sh`, `emacs.sh` において `default.sh` が多重に呼び出されていた無駄の修正 #D0546
  - core: bash-3.0 において ble/util/assign が壊れていたバグの修正

## 動作変更
  - vi-mode (nmap `x`, `<delete>`, `s`, `X`, `C`, `D`): support registers
  - source ble.sh において無事にロードされたときに終了ステータス 0 を返すことを保証
  - widget marked, nomarked を @marked, @nomarked に改名。元の widget は非推奨 (削除予定)
  - ble.sh: Linux 以外でも (`readlink -f` が動かないときも) シンボリックリンクを通したロードに対応 #D0544

<!---------------------------------------------------------------------------->
# 2017-10-22

## 新機能
  - vi-mode (mark): `mx` <code>`x</code> <code>'x</code> (`x` = <code>[][<>`'a-zA-Z"^.]</code>)
  - vi-mode (nmap): `gi` `<C-d>` (空文字列のとき exit) `"x` (registers)
  - vi-mode (xmap): `I` `A` `p` `P` `J` `gJ` `aw` `iw`
  - lib/vim-surround.sh: nmap `yS` `ySS` `ySs` `cS`, xmap `S` `gS`
  - タブ・インデントの制御
    - bleopt tab_width= (タブの表示幅)
    - bleopt indent_offset=4 (`>` や `<` のインデントの幅)
    - bleopt indent_tabs=1 (`>` や `<` のインデントにタブを用いるかどうか)
    - 既定のインデントの幅は 8 から 4 に変更

## バグ修正
  - vi-mode: 挿入モードに繰り返し回数を指定したとき `ESC ?` も一緒に繰り返されていたバグの修正
  - vi-mode: オペレータ `g?` が動かなくなっていたのを修正
  - vi-mode (nmap `/` `?`): 検索対象の入力中に `C-c` してもキャンセルされないバグの修正
  - vi-mode (xmap `r` (visual char/line)): 全体を置換したものが選択範囲に挿入されていたバグの修正
  - vi-mode (xmap `$`): 行末で `$` をしたときに表示が更新されないバグの修正
  - vi-mode (motion `0`): オペレータを認識していなかったバグを修正
  - isearch: 一度一致したら同じものに一致し続けるバグを前回の `/` `?` `n` `N` 対応の際に埋め込んでいたので修正
  - complete: `complete -F something -D` で登録されている補完関数が正しく実行されていなかったのを修正
  - prompt: PROMPT_COMMAND によって設定された PS1 を拾っていなかったバグを修正
  - textarea: 端末の下部で複数行編集時に `C-z` (`fz`) すると描画高さを正しく確保できていないバグの修正

## 動作変更
  - vi-mode (operator `<` `>`): Visual block での正しい振る舞い
  - vi-mode (nmap `:` `/` `?`): 文字列入力中に空文字列で DEL or C-h することでキャンセルできるように修正
  - vi-mode (nmap `J`, `gJ`): 引数に対応
  - vi-mode (nmap `p`): 最後の行で挿入するときに余分な行が入らないように修正
  - vi-mode (xmap `Y` `D` `R`): 記録するビジュアルモードの種類を修正
  - lib/vim-surround.sh: タグ名入力中に '>' で確定するように修正
  - widget (.SHELL_COMMAND): 実行しないコマンドに色がついているのはややこしいのでグレーアウトする様に変更

## 他の変更
  - magic-space: 空白を挿入してから履歴展開していた順番を逆転

----

# 2015-03-06..2017-10-09 (Git Commit Log)

## 2017-10-09
* keymap/vi: support specialized handling of keys for cmap
  - vi (nmap / ?): treatment of C-h and DEL on input of search targets
  - vim-surround.sh (nmap ys cs): treatment of > on input of tag names

## 2017-10-07
* keymap/vi_xmap: add tentative text object implementation
* lib/vim-surround: accept user input of tag names with the replacement being t, T, <
* keymap/vi_command: support search / ? n N

## 2017-10-05
* keymap/vi_command: fix behavior of yy, dd, D, etc. on the last line with count arg
* keymap/vi_xmap: support x <delete> C D X R Y
* keymap/vi_xmap: support r s
* keymap/vi-command: support : and few commands
* ble-core: fix a bug that conditions for assotiative arrays are inverted

## 2017-10-04
* [refactor] ble-edit (ble-edit/render -> ble/textarea): support "ble/textarea#{save,restore,clear}-state"
* [refactor] ble-edit (text/update/positions -> ble/textmap): support any time updates of text positions
* keymap/vi_command: support _ g0 g<home> g^ g$ g<end> gm go g_ ge gE
* check: fix "local lines=()" in vi_digraph.sh and update "check"
* (ble-highlight-layer:region): fix a bug that the "region" face is sometimes applied to intervals between selections

## 2017-10-03
* keymap/vi (visual mode): support previous selections
* keymap/vi (nmap p, P for block): convert HTs under inserting points to spaces
* (ble-decode-key/dump): fix a bug that pathname expansions internally occurred
* ble-core: add ble/string#split-lines
* keymap/vi (visual block): improve performance of block extraction
* keymap/vi_command (linewise operator d): go to the previous line on deleting the last line
* keymap/vi (operator d c g~ gu gU g?): support block
* keymap/vi (nmap p, operator y): support block

## 2017-10-02
* keymap/vi_xmap: support count arg for operators
* keymap/vi_command: fix a bug that linewise < > operators produce an error
* keymap/vi_command: perform EOL fix on history traveling with normal mode
* keymap/vi_xmap: support block selection

## 2017-10-01
* keymap/vi_xmap: support visual mode swithing
* keymap/vi: support visual mode

## 2017-09-28
* ble-edit: add a condition to accept-single-line-or
* keymap/vi_command: support gj gk

## 2017-09-27
* ble-edit: restore BASH_REMATCH
* ble-edit: do not execute pasted multiline texts
* ble-edit: support scrolling
* bleopt: implement value checking on assignment

## 2017-09-24
* ilb/vim-surround.sh: do not refer bleopt "vim_surruond_{char}" for digit replacement char
* keymap/vi: show configurable string (defaulted to be ~) on the normal mode
* keymap/vi_command: support % N%
* keymap/vi_command: support indentation for o O
* keymap/vi_command: reimplement text object is as
* keymap/vi (linewise-range.impl): fix a bug that the line ranges are reverted, fix behavior to go to nol

## 2017-09-23
* keymap/vi_command: support text object ip ap
* keymap/vi_command: support text object is as
* keymap/vi_insert: support indentation for C-m, C-h, DEL
* ble-edit: erase garbage input echo during initialization of ble.sh
* ble-edit (bleopt char_width=emacs): fix a bug that U+2000 - U+2600 are always treated as width 1
* keymap/vi: fix a bug that selection is not cleared on entering the normal mode during isearch

## 2017-09-22
* keymap/vi_command (r, gr): highlight on waiting replacement
* keymap/vi_command: support text object it at

## 2017-09-20
* ble-edit/exec: fix handling of $? and $_ and add a workaround for "set -o verbose"

## 2017-09-18
* lib/vim-surround: support configurable replacements with bleopt vi_surround_45:=tmpl vi_surround_q:=tmpl
* (bleopt): support the form "var:=value" which skips existence checks of variables
* lib/vim-surround: support ds cs
* ble-decode: fix stty settings for command execution
* keymap/vi_omap: fix mode transition from vi_omap to vi_insert
* [m] lib/vim-surround: remove redundant codes

## 2017-09-17
* keymap/vi (text object i[bB]): exclude newlines around the range and transform to linewise
* [m] keymap/vi (text object i"): behave the same as a" with arg >= 2 specified
* [m] keymap/vi: rename functions
* keymap/vi_insert: change the default of C-k to kill-forward-line
* keymap/vi_command: support digraphs for arg of f, F, t, T, r, gr
* keymap/vi: support digraph
* (ble-bind): support "ble-bind -@f kspec command"
* (ble-decode-kbd): fix a bug that keys "*" and "?" cannot be properly encoded

## 2017-09-16
* keymap/vi_command (operators): fix a bug that arg is cleared before the use
* lib/vim-surround: support b B r a C-] C-} as replacements
* keymap/vi: rename operator flag for < and >
* (ble/widget/self-insert): explicitly return 0
* ble-decode (ble-decode-key/.invoke-command): propagate exit status of widgets
* keymap/vi_omap: decompose M-*
* add ilb/vim-surround.sh, support operator "ys" and "yss"
* keymap/vi: add new keymap "vi_omap"

## 2017-09-15
* keymap/vi_command: support operators < >
* keymap/vi_command: support g~~ guu gUU g??
* keymap/vi_command: handle meta flags of input keys
* keymap/vi_command: support ~
* keymap/vi_command: fix the text object "aw"
* keymap/vi_command: rename widgets

## 2017-09-13
* ble-edit/info: fix cursor position calculations in rendering
* (ble-form/panel#set-height-and-clear.draw): fix to add lines on an increased height
* keymap/vi_command: support text objects [ia][][{}()<>bBwW'"`]

## 2017-09-12
* add ble-form.sh and introduce ble-form/panel
* ble-edit: rename functions
* keymap/vi_command: support text object iw
* ble-edit/info: show default contents at the end of bind
* ble.pp: fix PATH if standard utilities are not found on load
* keymap/vi_command: add operators g~ gu gU g?
* keymap/vi_command: refactor ydc operators
* ble-decode (ble-bind): fix check of redundant "ble/widget" prefix

## 2017-09-11
* ble-edit (ble/widget/clear-screen): show info after the clear
* keymap/vi_command (C-o): fix cusor positions after first-non-space commands
* keymap/vi: fix the initial position of "-- INSERT --"
* keymap/vi_command: support C-o
* ble-core: add string functions
* keymap/vi_insert: change mode names on "insert"
* keymap/vi: show current modes in the info area
* ble-edit: support ble-edit/info/set-default
* ble-edit: clear info on exit
* memo.txt: add comments from @B-bar
* ble-decode: check existence of keymaps

## 2017-09-10
* keymap/vi_command: fix C D
* keymap/vi_command: support arg for insert modes
* ble-decode: fix ble-decode-key and support __before_command__ and __after_command__
* keymap/vi_command: update bindings and support z{char} clear screens

## 2017-09-09
* keymap/vi_command: fix R and support gR
* keymap/vi_command: support f F t T ; ,
* ble-edit: suppress unnecessary history loads on history-next
* ble.pp: support loading ble.sh from inside of functions
* keymap/vi_command: support J gJ o O
* fix leak variables
* keymap/vi_command: support r gr

## 2017-09-08
* keymap/vi_command: fix mode change widgets and support gI
* keymap/vi_command: support G H L gg
* keymap/vi_command: fix behavior of [dcy][-+jk]
* keymap/vi_command: update memo.txt and support K
* keymap/vi_command (RET, C-m): fix to behave as + if the line contains LF
* keymap/vi_command: support w W b B e E

## 2017-09-07
* keymap/vi_command: support s S
* ble-edit: rename ble-edit/text/getxy -> ble-edit/text/getxy.out
* keymap/vi_command: support C-h DEL SP
* (ble/widget/vi-command/{forward,backward}-line): fix
* keymap/vi_command: return to insert mode on accept-line
* keymap/vi_command: support |
* keymap/vi_command: clear arg on mode changes
* keymap/vi_command: support I
* keymap/vi_command: support Y D C
* keymap/vi_command: support x X
* keymap/vi_command: support p P
* keymap/vi_command: check unknown flags
* keymap/vi_command: support A
* keymap/vi_command: add basic bash operations
* keymap/vi_command (+ -): travel history
* keymap/vi_command: support ^ + - $
* keymap/vi_command: fix behavior of "yh" and "yl"
* keymap/vi_command: support dd yy cc 0
* ble-edit: partial revert 35098f0 where necessary ble-edit/history/load calls were removed
* ble-edit (ble/widget/{for,back}ward-line, etc): fix a bug that the destination cursor pos was based on possible old layout
* keymap/vi.sh: support hjkl
* ble-edit: remove redundant ble-edit/history/load calls
* (ble/widget/.bell): fix exit status

## 2017-09-06
* check: add check codes for bashbug workarounds
* (ble-edit/text/get*): check if the cached text positions are up to date

## 2017-09-05
* keymap/vi: support mode switching
* (ble/widget/.goto-char): simplify
* (ble-edit/load-keymap-definition): workaround for bash-3.0
* (ble-decode-key): accept multiple keys
* ble-edit: support the value bleopt_default_keymap=vi

## 2017-09-04
* add keymap/vi.sh and switch keymap on editing mode change
* ble-decode: split and refactor external settings
* ble-decode: support bleopt_default_keymap=auto

## 2017-09-03
* ble.pp: remove the check enforcing "set -o emacs"
* ble-decode (ble-decode-{attach,detach}): support attached editing modes
* ble-decode: update spacing of an awk script
* ble.pp: fix "set -o emacs" checks
* ble-syntax: fix a bug that here strings are interpreted as here documents
* complete.sh: suppress error messages on internal compgen calls

## 2017-08-30
* ble-edit: check editing mode

## 2017-08-19
* cmap/default.sh: disable modifier keys "CAN @ ?" which is ambiguous with "C-x C-x"
* ble-edit: support "bleopt delete_selection_mode=1"

## 2017-06-09
* ble-syntax: workaround for the bash-4.2 arithmetic bug resulting in segfaults

## 2017-05-20
* ble.pp: guard double ble-attach

## 2017-04-21
* bind.sh: bash-4.4 workaroud: fix a bug C-x ? is not bound

## 2017-03-17
* README: update color settings and translate tips
* README: add a hint on editing multiline commands

## 2017-03-16
* (ble-color-gspec2g): change to recognize 0 padded color indices as decimal numbers
* README: bump release 0.1.7

## 2017-03-15
* README: update heading syntax of GitHub flavored markdown

## 2017-03-13
* suppress error messages caused by incorrect user LC_*/LANG values

## 2017-03-06
* complete: fix a bug that backquotes, newlines and tabs in completed words were not escaped

## 2017-03-05
* ble.pp ($_ble_init_original_IFS): \minor, fix unset
* ble-core.sh ($ble_util_upvar_setup): add "local ret" declartion
* (ble-syntax:bash/ctx-heredoc-word): use ctx-redirect to read keyword of here documents
* ble-color: move deprecated "ble-highlight-layer:adapter" codes to layer/adapter.sh as a sample
* save/restore IFS to protect ble functions from user's IFS
* memo.txt: assign numbers of the form "#D????" to old items
* (ble-syntax:bash): :new: support "select var in ..."
* (ble-syntax:bash): fix a recent bug that semicolons after "for (())" was not allowed
* (ble-syntax:bash): :new: support here documents

## 2017-03-04
* (ble-syntax:bash): fix a bug that semicolons are not allowed after "}", "fi", "done", etc.
* (ble-syntax:bash): support the construct with the form "for name do ...; done"
* (ble-syntax:bash): accept "do" immediately after "for (())" without semicolons
* Makefile: add a prerequisite "install"
* (ble-edit-attach): output CR before showing prompt

## 2017-03-02
* (ble-syntax:bash): allow `then, elif, else, do' after `}, etc.'
* (ble-syntax:bash): improve checks of quotes in parameter expansion and arithmetic expansion
  - change so that quotes are processed always in the syntax level
  - introduce new nest-types, ntype='$((' and ntype='$[', for CTX_EXPR (arithmetic expressions)
  - introduce a new nest-type ntype='NQ(' to support nesting in quote-removal-less contexts
  - fix so that quotes '...' in parameter expansions such as `${var#text}' are always enabled
* \clean: format memo.txt and document comments, etc.
* (ble-syntax:bash): add a work around of a bash-4.2 bug in arithmetic expressions

## 2017-03-01
* (ble-edit/info/draw-text): change to truncate overflow contents
* ble-edit: fix bugs that line representation is broken at the last line of terminals
  - \fix, use IND to ensure size of the edit area
  - \fix, clear _ble_line_{beg,end}{x,y} on newline
  - ble-edit.sh: add a function ble-edit/draw/put.ind
  - ble-edit.sh: add a function ble/widget/.insert-newline
  - (ble/widget/redraw-line): \clean, 無駄な _ble_line_cur 初期化を削除。ble-edit/render/invalidate を呼び出すだけで充分。
  - (ble-edit/exec/.adjust-eol): \clean, 無駄な _ble_line_x=0 _ble_line_y=0 を消去。元からそうなっている前提である。
  - (ble-edit/exec/.adjust-eol): \fix, 直接 stderr に出力していたのを ble/util/buffer に出す様に変更。
* (ble-syntax:bash): support `} }', etc.
* (ble-syntax:bash): :new: support `for ((;;)) { ... }'
* (ble-syntax:bash): support `((echo)>/dev/null)' and `$((echo)>/dev/null)'
* complete: support completion of "in" keywords for "for var in"/"case arg in"
* (ble-syntax:bash): :new: support `for var in ...' and `case arg in'
* (ble-syntax:bash/ctx-command): [refactor] split into functions, use arrays for ctx settings
* (ble-syntax:bash): fix a bug that redirection accepted comments
* (ble-highlight-layer:syntax): fix a bug that causes error on a word beginning with #
  - Note: words beginning with '#' can be formed when `shopt -u interactive_comments'
* (ble-syntax:bash): fix a bug that beginning of process substitutions splitted words

## 2017-02-28
* ble-edit: [refact] rename ble/edit/prompt/update/update-cache_wd -> ble-edit/prompt/update/update-cache_wd
* ble-edit: [refact] rename ble/widget functions
* ble-edit: [refact] rename ble-edit functions
* ble-edit: use ble/util/buffer to suppress flicker
* ble-core: add variable "ble_util_upvar{,_setup}"

## 2017-02-25
* (ble-syntax/parse/shift): fix a bug that caused duplicated shifts
* (ble-syntax/print-status/.dump-arrays): add consistency checks

## 2017-02-14
* ble-syntax.sh: fix a bug that attempts "continue" out side of loop

## 2017-02-13
* ble-edit (ble/widget/isearch): fix a bug that isearch does not work in bash-4.4

## 2016-12-21
* ble-edit (exec): default value of the parameter "$_" is "$BASH"
* ble-edit (exec): support parameter "$_"

## 2016-12-06
* ble-core (ble/string#split): add a work around for "shopt -s nullglob"

## 2016-11-08
* Makefile: detect correct path of gawk for mwg_pp.awk

## 2016-11-07
* ble-core.sh: add a work around of bashbug to accept inputs of hankaku kana

## 2016-09-20
* (ble/util/sleep in Cygwin): check parent processes of blocking process substitutions

## 2016-09-16
* README: update
* (ble/util/upvar): fixed a bug that array elements cannot be exported

## 2016-09-14
* ble-core: add a function ble/util/upvar
* _ble_edit_str.replace: improve error correction of _ble_edit_ind and _ble_edit_mark

## 2016-09-11
* (ble/widget/isearch/cancel): return to the original position, i.e. restore _ble_edit_{ind,mark}
* (ble-syntax:bash/check-dollar): fixed a bug that isolated dollars generate syntax errors
* (ble/widget/accept-and-next): fixed a bug that the next line is not loaded on accepting the last histentry
* ble.sh (ble-edit/history/add): fixed a bug that erasedups is performed even if a new entry is rejected by ignorespace
* isearch: fixed a bug that words in the current line is not matched incrementally

## 2016-08-24
* complete.sh: recognize dangling symbolic links in completion and syntax-highlighting

## 2016-08-08
* term.sh: fixed a bug that xenl cap was always disabled.

## 2016-08-07
* ble-edit/prompt: improved admin privileges checks on Cygwin

## 2016-08-05
* (ble-edit/history/add): fixed a bug that history entries are not registered after certain operations.
* syntax: fixed a bug that causes an fatal error for param expansions with offset in quotes like "${v:1}"
* (ble/util/sleep): do not use /dev/tcp which generates error messages on Win10 Cygwin.

## 2016-07-16
* (ble/util/array-push): \refactor, rename, support multiple elements to append.
  - rename ble/util/array-push -> ble/array#push
  - rename ble/util/array-reverse -> ble/array#reverse

## 2016-07-15
* complete: enable completion of variable names in "..." and ${...}.
* complete.sh: insert '=' after the completion of variable name of assignment.
  - (ble/widget/complete):
    completion-context にて source の引数をコロン区切で指定できるように拡張する。
  - ble-complete/source/variable:
    引数に応じて確定時に挿入する接尾辞を選択する様に変更する。
  - ble-syntax.sh (ble-syntax/completion-context):
    文脈に応じて variable 候補源に引数 '=' を指定して、補完確定時に何を挿入するべきか指定する。
* complete.sh: fixes and clean up; a new fn ble/string#split.
  - ble-core.sh: a new function ble/string#split to replace "GLOBIGNORE=* IFS=... eval 'arr=(...)'".
  - complete.sh: (ble-complete/.fignore/filter): fixed a bug that local variable pat was leaked.
  - complete.sh: (ble/widget/complete): fixed a bug that "shopt -s force_fignore" was ineffective.

## 2016-07-14
* (ble/util/sleep): add fallbacks to sleepenh and usleep for bash-3.*.
* isearch: fixed a bug that a new range overlapped with the current match cannot be matched incrementally.
* (bleopt): fixed a bug in printing variables.

## 2016-07-09
* (ble/history/add): work around for bash-3.0 to add history entries to bash command history.
* (ble/history/add): fixed a bug that command history was always disabled under bash-3.2.

## 2016-07-08
* ble-syntax.sh, complete.sh (shopt -q autocd): fixed a bug that error messages were output to stderr on completions in bash-3.*.
* ble-edit (prompt): :new: support shell variable PROMPT_DIRTRIM for PS1 instantiation.
* ble-edit: Now, the history index \! in PS1 is the index of the editted line.
  - isearch: also, the position shown while isearch is changed to the history index.

## 2016-07-07
* README: move language options to the top. add icons of the languages.
* update README and LICENSE
* ble-edit.sh (ble-edit/isearch/backward): improve the performance (work around for slow bash arrays).

## 2016-07-06
* ble-edit.sh (_ble_edit_history_edit): changed to hold the whole editted history data.
* ble-syntax: glob patterns are not active in variable assignments.
* ble-edit.sh: 修正: ジョブ状態の変更を標準出力に確実に出力
  - fixed a bug that job state changes are not output when PS1 contains '\j'.
  - fixed a bug that the changes are not output immediately.
* minor fixes in visible-bell and check-stderr.
  - ble-core.sh (ble-term/visible-bell): fixed a bug in subsecond treatment.
  - ble-edit.sh (.ble-edit/stdout/check-stderr): fixed a bug that lines without LF were not processed.

* (ble/util/joblist): use ble/util/joblist for internal usage of jobs.
  - ble-core.sh (ble/util/joblist): bugfix:
    誤って _ble_util_joblist_jobs を _ble_util_joblist_list として使用している箇所が 4 箇所。
  - ble-core.sh (ble/util/joblist): bugfix:
    - (直前のジョブ) や - (一つ前のジョブ) の変化も変化として検知していた。
    - これはジョブ状態の本質的な変化とは言いがたいので無視する。
  - ble-core.sh (ble/util/joblist): bugfix: add ble/util/joblist.clear
    bash 自身によってジョブ状態の変化が報告された後に、
    二重に状態変化が報告される場合があるので、その様な場合にはキャッシュを消去する。
  - ble-edit.sh の各 jobs を呼び出すところで、ble/util/joblist を代わりに呼び出す。
  - ble-syntax.sh, ble-color.sh で jobs を使用してジョブの存在確認している箇所では、
    先に ble/util/joblist を呼び出してジョブの状態変更を確認してから目的の jobs 呼び出しを行う。
* ble-core.sh: add a new function ble/util/joblist.

## 2016-07-05
* ble-core: add option bleopt_stackdump_enabled
  - bleopt_stackdump_enabled が非零の値に設定されている時にだけ
    stackdump を出力する様にする。既定では 0 (出力しない) とする。

## 2016-07-04
* ble-decode.sh (ble-decode-attach): fixed a bug that makes C-{u,v,w,?} ineffective after the second ble-attach.
  - 2回目以降の ble-attach でも ble-decode-bind/uvw が動作する様に
    ble-decode-attach で source "～.bind" した直後に _ble_decode_bind__uvwflag をクリアする。

## 2016-06-27
* ble-core.sh ($_ble_base/cache): move to _ble_base_cache="$_ble_base/cache.d/$UID" for user separation.
* ble-core.sh ($_ble_base_tmp): change to use /tmp/blesh/$UID if it is available.
  - 今迄は ble.sh と同じディレクトリに一時ファイルを配置していた。
    しかし、ble_util_assign.tmp などのファイルは速度を考えれば tmpfs (RAM上) に配置したい。
    従って、一時ファイルは /tmp の上に配置するように変更する。
* ble-core.sh: add ble/util/sleep to provide subsecond sleep.

## 2016-06-25
* ble-edit.sh (_ble_edit_str.replace debug codes): resume from wrong state.

## 2016-06-23
* ble-core.sh (ble/util/array-reverse): improve performance.

## 2016-06-22
* ble-edit/isearch: show progress of search.

## 2016-06-19
* ble-edit/isearch: ble/widget/isearch/prev cancel a task in que, ble/widget/isearch/accept is not effective while a search.
  - ble/widget/isearch/prev: 現在実行中のタスク (_ble_edit_isearch_que) がある場合には一つずつキャンセルする。
  - ble/widget/isearch/accept: 現在実行中のタスクがある場合には bell を鳴らすだけで動作をスキップする。
  - ble-edit/isearch/.goto-match: 一致があった場合には is-stdin-ready でも強制的に描画を実行する。
* ble-edit/isearch: check is-stdin-ready on history search to suspend.

## 2016-05-21
* update README.md for v0.1.5
* ble-edit.sh: bugfix, incorrect _ble_edit_ind caused by the inconsistensy of history/isearch targets.
  - _ble_edit_history を履歴検索して _ble_edit_history_edit をロードしていた事による _ble_edit_ind 不整合
    これにより、dirty-range の不整合が生じエラーが発生していた。長年の謎のバグがこれで潰れたと思われる。

## 2016-04-07
* ble-syntax.sh (ble-syntax/parse/shift.impl2): bugfix 制御構造の欠陥による shift 漏れ。

## 2016-01-24
* ble-syntax.sh: \debug add debug codes for dirty-range bug
  - ble-edit.sh: dirty range checks
  - ble-syntax.sh (ble-syntax/parse): remove readonly flag of `beg' and `end' for dirty-range bug

## 2015-12-30
* modify README: use -O option for curl; release v0.1.4.

## 2015-12-26
* (ble-color/faces): preserve orders of addhook-onload, and ble-color-{def,set}face.
  - ble-color/faces 初期化前に呼び出した ble-color/faces/addhook-onload,
    ble-color-defface, ble-color-setface を独立に記録していた為、
    実際に呼び出された順序と異なる順序で処理が実行されてしまっていた。
    記録を一つの配列 _ble_faces_lazy_loader にまとめ、順序が保存される様にした。

## 2015-12-25
* (ble-color) \change ble-color-{def,set}face の処理も遅延する。
* functions/getopt.sh: \add description.

## 2015-12-24
* (ble-syntax:bash): :new:, support option `-p` for keyword `time`.
* (ble-syntax:bash): \new, support `a=([key]=value)` and `a+=([key]+=delta)`.
  * (ble-syntax): \new local variable `parse_suppressNextStat` in ble-syntax/parse.
  * (ble-syntax:bash): \bugfix, correct resume for `var+`, `arr[...]+` -> `var+=`, `arr[...]+=`.
  * (ble-syntax:bash): \new, support `a=([key]=value)` and `a+=([key]+=delta)`.
* (ble-syntax:bash): \new context CTX_CASE.
* (ble-syntax:bash): \new CTX_COND{X,I}; \change unexpected '(' is treated as extglob '@(' instead of sub-shell '(';
  * ble-syntax.sh: `CTX_VAL{X,I}` から `CTX_COND{X,I}` を分離。
  * ble-syntax.sh: コマンド中に現れる '(' を extglob の括弧として取り扱う事にする。
    今迄は暫定的に sub-shell として取り扱っていたが、
    エラーが多く出てうるさいのでエラーの少ない extglob 括弧として取り扱う事にする。
* ble-edit.sh: \bugfix histexpand condition [[ -o histexpand ]] inverted.
  * \bugfix 履歴展開が効かなくなっていた。
    条件判定の誤りだった: [[ -o histexpand ]] → [[ ! -o histexpand ]]
  * \bugfix 履歴展開に失敗した時に : が実行される。
    履歴展開が失敗すると history -p は標準出力に何も出力しないためであった。
    失敗した時は echo "$BASH_COMMAND" により手動で出力する。
* (ble-syntax:bash): \support shopt -s extglob; \bugfix error on {delimiter after redirect,'<' redirect};
  * extglob 対応: `CTX_GLOB`, `ATTR_GLOB`, `ctx-glob`, `check-glob` 追加。
  * \bugfix redirect 直後に redirect/delimiter があった時に解析データ書き込み違反。
  * \cleanup: 共通の正規表現の整理:
    `$_ble_syntax_bash_rex_spaces`,
    `$_ble_syntax_bash_rex_IFSs`,
    `$_ble_syntax_bash_rex_delimiters`.
  * \bugfix `$_ble_syntax_bash_rex_redirect`: < が抜けていた。

## 2015-12-23
* (ble-syntax:bash): special treatment of arguments of `declare`.
  * (ble-syntax:bash): declare, typeset, local, export, alias コマンドの引数を文法的に特別に扱う。特に配列構文 =() を許容する。
    その為に新しい文脈値 `CTX_ARGVX`, `CTX_ARGVI` を追加する。
  * (ble-syntax:bash): `CTX_ARGVI` に対する補完候補は変数名。等号 '=' 以降の部分についてはファイル名の補完候補を列挙する。
  * (ble-syntax:bash): 通常の代入構文における配列構文の動作を変更。
    今迄は a=(1 2 3)echo などとすると a=(1 2 3) を配列代入と解釈し echo の部分をコマンドと解釈する様にしていた。
    その為に配列構文の nest-pop 時にすぐに単語を抜けて cxt==CTX_CMDXV になる様に構成していた。
    しかし、実際の bash の動作を確認してみると、a=(1 2 3)echo は a='(1 2 3)echo' の様に、全体が代入文の右辺と解釈される様である。
    実際の bash の動作に合わせて、nest-pop 時に特別な動作を特にしない様に変更した。

## 2015-12-21
* (ble-syntax:bash): 算術式終了条件修正、bash-3.0 で += 無効; (completion-context): a+= 直後の補完候補生成。
  * ble-syntax.sh (ble-syntax:bash): 算術式の終了条件を修正する。
    $((...)) ((...)) の中では '(', ')' を数えて終了判定を行う。
    $[...]、${arr[...]} arr[...]= の中では '[', ']' を数えて終了判定を行う。
    ${var:...:...} では '}' が来たらすぐに終了する。
  * ble-syntax.sh (completion-context): a+= の直後でも補完候補生成を行う。
  * ble-syntax.sh (ble-syntax:bash): disable += under bash-3.1.
* ble-edit.sh: bugfix failure of catch C-d in bash-3.0.

## 2015-12-20
* (ble-highlight-layer:syntax): color of special files, permission of files in redirection.
  - ble-syntax.sh: bugfix of assertion test in ble-syntax/parse/tree-append.
  - ble-syntax.sh (ble-highlight-layer:syntax): color filenames of block device, character device, pipe, and socket.
  - ble-syntax.sh (ble-highlight-layer:syntax): redirection: check permissions.
* (ble-syntax:bash): bugfix, tree-structure corruption on edit of array subscripts in array-element assignment.
  - ble-syntax.sh: 配列添字の書き換え時に解析木の破壊が起こる。
    配列添字の終了 ']=' において nest-pop を先頭位置で行っていた。
    これが為に、過去の解析結果を書き換えている事になっていた為に、
    shift の際に設置した情報が消滅したりしていた。
* ble-edit.sh: add support `set +o history`; ble-syntax.sh: check file existence on '<' redirection.
  - ble-edit.sh: add support `set +o history`
  - ble-syntax.sh (ble-highlight-layer:syntax): check filename of `<` redirections.
  - ble-syntax.sh (constants): refact,
    definition of `local rex_redirect` -> global `_ble_syntax_bash_rex_redirect`.
    rename `_BLE_SYNTAX_CSPACE` -> `_ble_syntax_bash_cspace`.
  - ble-edit.sh: refact, rename functions `.ble-edit[./]history[./]*` -> `ble-edit/history/*`.
* complete: 候補生成箇所の追加・修正、コマンド補完候補としてサブディレクトリも列挙
  - ble-syntax.sh (complete): bugfix, 単語の間の空白で complete を実行しようとしても候補が生成されなかった。
  - ble-syntax.sh (complete): generate filenames after `VAR='.
  - ble-syntax.sh (complete): generate filenames just after the redirection.
  - complete.sh: コマンドの補完候補として現在のディレクトリのサブディレクトリも列挙する様に修正する。
    サブディレクトリにある実行属性のファイルを実行したい場合がある為である。

## 2015-12-19
* complete.sh: support `FIGNORE`, `shopt -s force_fignore`.
  - Makefile: bugfix, remove `ble-getopt.sh` from the required files to generate ble.sh.
  - complete.sh: support `FIGNORE` and `shopt -s force_fignore`.
* functions/*: move unused file ble-getopt.sh to `functions/`. Add new impl of getopt.
* ble-syntax.sh (ble-syntax:bash): redirections: bugfix '<<<', support '>|', overwrite check of files, etc.
  - ble-syntax.sh (ble-highlight-layer:syntax): Support `set -o noclobber`; Check overwrites of target files of redirections for '>', '&>', and '<>' redirect.
  - ble-{core,decode,edit}.sh, bind.sh, term.sh, emacs.sh: change redirection '>' -> '>|' for the case of the noclobber option on.
  - ble-syntax.sh (ble-syntax:bash): support the redirect using `>|`.
  - ble-syntax.sh (ble-syntax:bash): bugfix false syntax error of `<<<`.
  - ble-syntax.sh (ble-syntax:bash): bugfix redundant skip on unexpected termination of redirect by an end of command or another redirection.
  - ble-syntax.sh (ble-syntax:bash): bugfix, do not allow newline after the redirection introducers.
* ble.pp, ble-core.sh: Check and modify dependencies on external commands.
  - ble.pp (ble/.check-environment): Remove tput (POSIX UP option) which is not necessarily required.
  - ble-core.sh (ble-term/visible-bell): Add a function `ble/util/getmtime` to get modified time of files in a compativble way.
  - ble-edit.sh (ble/widget/command-help): Select available pager from any of $PAGER, less, more, and cat.
* ble-syntax.sh: syntax: quotations in words in parameter expansion (shopt -u extquote, etc.).
  - ble-syntax.sh: support single quotation in parameter expansion.
  - ble-syntax.sh: support shopt -u extquote.
* clean up & minor behavior change: Check bash opts --{posix,noediting,restricted}, Unset mark on accept-line.
  * bug fix
    - ble-syntax.sh (ble-syntax:bash/extract-command/.construct-proc): remove a debug code which prints the message "clear words".
  * minor behavior change
    - ble-edit.sh (ble/widget/accept-line): redraw without mark.
    - ble.pp (startup check): do not load ble.sh for bash --posix, --noediting, or --restricted.
  * clean up
    - ble-decode.sh (ble-decode-byte:bind/EPILOGUE): use ble/util/is-stdin-ready instead of the direct use of `read`.
    - ble-core.sh (ble/util/is-stdin-ready): use LANG instead of LC_ALL.
    - ble-edit.sh, ble-syntax.sh: use [[ -o histexpand ]] rather than [[ $- == *H* ]].
    - ble-syntax.sh (test): remove unused functions `.ble-shopt-extglob-push`, and `.ble-shopt-extglob-pop` for test.
    - ble-edit.sh: remove old complete functions:
      - .ble-edit-comp.initialize-vars
      - .ble-edit-comp.common-part
      - .ble-edit-comp.complete-filename
      - ble/widget/complete
      - ble/widget/complete-F
    - ble-syntax.sh, complete.sh: no need of redirection for `shopt -q optname`.

## 2015-12-09
* Refactoring ble-edit.sh/ble-line-prompt.
  * .ble-line-prompt -> ble-edit/prompt.
  * `_ble_cursor_prompt`, `_ble_line_prompt` -> `_ble_edit_prompt`.
* Refactoring ble-core.sh, ble-color.sh, cmap/xterm.sh.
  * ble-core.sh: .ble-text.* -> ble/util/*.
  * ble-color.sh: .ble-color.* -> ble-color/.*.
  * cmap/xterm.sh: .ble-bind.function-key.* -> ble-bind/cmap:xterm/*.
* Refactoring ble-decode.sh.
  * ble-core.sh: .ble-term.{visible,audible}-bell -> ble-term/{visible,audible}-bell.
  * ble-decode.sh: .ble-stty.* -> ble-stty/*.
  * ble-decode.sh: .ble-decode-* -> 適切な名称に変更。
* Refactoring and clean up.
  * ble-edit.sh, etc: 'ble-edit+' -> 'ble/widget/.
  * 'ble-edit.sh: ble-edit/exec 関数名整理。
  * ble-decode.sh: ble-decode-byte 関数名整理、ble-edit 依存性分離。
  * README-ja_JP.md: 日本語説明修正。
  * README.md: 英語修正。
  * ble-syntax.sh: コードコメント @fn -> 関数 に統一。

## 2015-12-06
* ble-core.sh: Add function ble/util/cat to replace /bin/cat.
  - ble-core.sh: 関数 ble/util/cat。command cat の単純な呼出と同じ機能を builtin read で実装。
  - ble-decode.sh (ble-bind --help): 外部コマンドの cat を呼び出していたが、bash の組込コマンドで実現できるので置き換え。
  - README.md: gmake/make について説明を追加。
* Update README-ja_JP.md
* ble-bind: New option `-L, --list-functions`, ble-color.sh bugfix initialization of faces:region,disabled,overwrite_mode.
  - ble-color.sh: bugfix, 色初期化 (region disabled overwrite_mode) 遅延ロードに登録していなかった。
  - ble-decode.sh (ble-bind): New option `-L, --list-functions` to list edit functions.

## 2015-12-03
* Changed default value of bleopt_char_width_mode from `emacs` to `east`.
* Update README-ja_JP.md.
* Add README-ja_JP.md. 日本語の説明。
* optimization: lazy init of faces (ble-{syntax,color}.sh), removal of temporary files (ble-core.sh).
  * ble-syntax.sh, ble-core.sh: lazy initialization of `_ble_faces_*`.
  * minor: modify messgese: initialization message, the header of the script ble.sh.
  * ble.pp: Add pp switch `measure_load_time` to identify the initialization bottle neck.
  * ble-core.sh (`_ble_base_tmp.wipe`): optimization, use parameter expansion instead of regex captures.
* Support here string, shopt -q progcomp; Bugfix ble-syntax/parse/nest-equals.
  * ble-syntax.sh: support here string.
  * ble.htm: comment out outdated descriptions.
  * ble-syntax.sh (ble-syntax/parse/nest-equals): bugfix, 前回の bugfix で onest[3]<0 の場合を考えていなかった。
  * complete.sh: shopt -q progcomp によるプログラム補完の有効・無効の切り替え。
* update version numbers.
* ble-syntax.sh (ble-syntax/parse/nest-equals): fatal bugfix, misjudge on nest equality test causing nest structure corruption.
  * Note: _ble_syntax_nest の要素に含まれている nest 開始位置は相対位置で記録されているにも拘わらず、絶対位置の変数に直接代入していた事が原因であった。
  * 他 ble-syntax.sh, ble-color.sh: compatibility fix., fgrep to command grep -F.
* README.md: correct download links.
* `*.sh`: Add `command` for external command execution.
* (ble-edit/stderr for bash-3.0): Add ignoreeof-message.txt for C-d message i18n.
* `*.sh`: New marker `__ENCODING__` for 文字コード依存部分

## 2015-11-30
* complete.sh (ble-complete/source/argument): minor bugfix, default behavior using comp_opts exported by func .../.compgen.
  * 他 ble.pp: check chmod.
* Makefile: a phony target `dist`.
* memo.txt: todo 整理.
* complete.sh: bugfix, completion doesn't work on an argument without complete -D spec.
* ble-edit.sh (ble-edit+isearch/next): bugfix, didn't match locally on self-insert of forward isearch.
* ble-decode.sh (generate-source-to-unbind-default): bugfix, need of LANG=C.
  * LANG=C を設定しないと bind -sp の出力に変なバイトが含まれている為に解釈に失敗する。
    (utf-8 の様な ASCII 文字を含まない様な文字コード体系の場合にはこれで問題ないが。
    memo.txt に Note(2015-11-30) として追加する。)
* Update README.md
* ble-edit.sh: remove dependency on GNU awk.
  * ble.pp: 念の為 gawk に戻す事ができる様に use_gawk (PP変数) を用意する。
  * ble.pp (ble/.check-environment): check awk.
  * ble-core.sh (ble/util/array-reverse):(awk scripts):
    + uninitialized variable `decl` を初期化する。
    + locale dependent な /[a-z]/ の類を POSIX 括弧 (/[[:alpha:]]/, /[[:alnum:]]/) に置き換え。
  * ble-edit.sh (.ble-edit/history/generate-source-to-load-history):(awk scripts): uninitialized variable `n`.
  * ble-decode.sh (.ble-decode-bind/generate-source-to-unbind-default):(awk scripts):
    + 引数名と大域変数が被らない様にする。
    + gawk 特有の機能 (/\y/, match 第三引数) を使わない。
    + bugfix, gsub の対象の変数が指定されていない箇所があった。
  * それぞれ gawk --lint 及び nawk でも動作を確認した。

## 2015-11-29
* ble-edit/isearch: 現在のコマンド内も検索対象に。
  * 旧来の履歴項目検索機能を改名:
    - ble-edit+isearch/forward -> ble-edit+isearch/history-forward,
    - ble-edit+isearch/backward -> ble-edit+isearch/history-backward,
    - ble-edit+isearch/self-insert -> ble-edit+isearch/history-self-insert.
  * 検索履歴 (_ble_edit_isearch_arr) に一致範囲も記録する様に変更
  * 現在の位置からコマンド内を検索する関数を追加・旧関数を置換:
    - ble-edit+isearch/forward,
    - ble-edit+isearch/backward,
    - ble-edit+isearch/self-insert.
* ble-edit.sh (+isearch/next): 一致範囲を囲む。
  * ble-edit.sh (+isearch/next), set region to matched range.
  * ble-edit.sh: pattern matching using [[ text == pattern ]] instead of case statement.
  * ble-color.sh (ble-syntax-layer:region/update): bugfix, PREV_UMIN/PREV_UMAX out of range due to the shift failure of omin/omax.
* ble-core.sh: full support for bleopt_input_encoding=C
  * ble-core.sh: Add functions: ble-text-b2c+C, and ble-text-c2b+C.
  * ble-core.sh (.ble-text.c2bc): rename .ble-text.c2bc -> ble-text-c2bc.
  * .gitignore: 古い物を整理。/wiki 追加。

## 2015-11-28
* Update README.md
* ble-decode.sh, ble-edit.sh: support `bind -xf`.
  * ble-core.sh: Add functions ble/string#common-{prefix,suffix}.
  * ble-decode.sh, ble-edit.sh: support `bind -xf COMMAND`.
  * ble-edit.sh:714: ^M が直接埋め込まれていると GitHub が改行位置を勘違いする様なので $'\r' に修正する。
  * complete.sh: embedded sed scripts, POSIX compliance.
* ble-color.sh: Add a function ble-color-show.
* README.md: Add animation gif.
* README.md: settings for syntax highlighting.
* README.md: Add some description of settings.

## 2015-11-27
* Create LICENSE.md
* Update README.md

## 2015-11-24
* ble-edit.sh (+magic-space): bugfix, 現在のカーソル位置よりも前の部分に対して履歴展開する。
* complete.sh: behavior of source/argument, compopt -o/+o, bugfix.
  - complete.sh (ble-complete/source/argument): complete -o ..., compopt -o option +o option の読み取り。
  - complete.sh (ble-complete/util/escape-regexchars): bugfix.
  - complete.sh: Add action/plain, action/argument, action/argument-nospace.
  - complete.sh: Add source/dir.
  - complete.sh (ble-complete/source/argument): support -o nospace, -o dirnames.
* complete.sh (ble-complete/source/argument): bugfixes.
  * ble-complete/source/argument/.compgen-helper-prog: Export `COMP_LINE` `COMP_POINT` `COMP_KEY` `COMP_TYPE`
  * ble-complete/source/argument/.compgen-helper-{prog,func}: Pass arguments `command`, `cur`, and `prev` for program/function.
  * ble-complete/source/argument: Fix option -F, -C interruption failure.
  * ble-complete/source/argument: Fix -F <-> -C miss arrangement.
  * ble-complete/source/argument: Correct IFS when compgen is called.
  * ble-complete/source/argument: `return 1` if no candidates are generated.
  * ble-complete/source/argument: Evaluate `compgen` in the original shell (i.e., not in a sub-shell).
  * ble-complete/source/argument: Filter and modify candidates generated by `compgen` using `sed`.

## 2015-11-23
* ble-edit.sh (ble-decode): show the message to run "stty sane" after "ble-detach".
* ble-syntax (ble-syntax:bash/extract-command): bugfix, 出力用の変数が local 指定になっていたのを削除。
  - 他: complete.sh: compgen -F prog -C cmd の際に compgen が警告を出すので compgen 2>/dev/null とする。
* complete.sh: complete -p による補完の基本実装。
  * ble-core.sh: Create function ble/util/array-reverse.
  * ble-decode.sh (.ble-decode-keys, .ble-decode-key/invoke-command): bash-3.0 workaround, local -a keys=(), local -a KEYS=() を2行に分ける。
  * ble-syntax.sh: complete 用の整備。
    * 関数追加 ble-syntax/tree-enumerate-break: "((tprev=-1))" は意図が分かりにくいので。
    * 関数追加 ble-syntax:bash/extract-command:
    * ble-syntax/tree-enumerate: シェル変数 iN の既定値を _ble_syntax_text の末端に。
    * ble-syntax/completion-context: CTX_VALI, CTX_VALX に対応。
    * ble-syntax/completion-context: 一部の補完文脈を file から argument に変更。
  * complete.sh: complete -p 設定に基づく補完。
    * ble-complete/source/argument: 追加
    
## 2015-11-22
* ble-syntax.sh: bash 文法関連の関数名整理。
  * ble-decode.sh (ble-bind): error message に . を追加。古いコメントを削除。
  * ble-syntax.sh (ble-syntax/parse/{check,ctx}-*): bash 文法特有の関数の名称を整理。

## 2015-11-21
* cmap/cmap+*.sh: Update for current ble-decode.sh.
* ble-edit.sh (ble-edit+magic-space): Add edit function magic-space.

## 2015-11-19
* Support of PROMPT_COMMAND, and function bleopt.
  * ble-edit.sh: easy support of PROMT_COMMAND.
  * ble-core.sh: bleopt 関数追加。
  * ble-decode.sh (.ble-decode-initialize-cmap): POSIX sed BRE does not support the quantifiers: \+, \?.
* ble-syntax.sh: 履歴展開をより正確に。
  * histchars に応じた履歴展開の解析
  * extglob が設定されている時は !( は履歴展開と解釈しない
  * 文字列 "～" 中の履歴展開は " の直前で終わる
* ble-core.sh: workaround for bash-3.0 regex in _ble_base_tmp.wipe.

## 2015-11-17
* `ext/mwg_pp.awk`: Include mwg_pp.awk in ext; Makefile (listf): renamed to list-functions and modified.
* ble-syntax.sh (ble-syntax/parse/nest-equals): bugfix (operater associativity), incorrect break of loops.

## 2015-11-09
* ble-core.sh (_ble_base_tmp.wipe): bugfix, correct iteration of old tmp files.

## 2015-11-08
* complete.sh: ユーザ入力があった時の候補列挙の中断に対応 (bash-4.0 以降); ble-syntax.sh: コメント判定の修正。
  * ble-core.sh (ble/util/is-stdin-ready): 関数追加。標準入力に未処理の文字が残っているかどうかを判定。ユーザの入力が待ち状態になっているかどうかを判定する為の物。
  * ble-syntax.sh (ble-syntax/parse/check-comment): コマンドライン解析時 shopt -u interactive_comments の時にはコメントは無効とする。
  * ble-syntax.sh (ble-syntax/parse/check-comment): bugfix コメント開始判定(単語頭)。単語開始の判定が単語頭ではなく「単語頭または単語内部の解析開始点の位置」という事になっていた。
  * complete.sh (ble-complete/source/command/gen, ble-edit+complete): コマンド候補の列挙・一致判定には時間が掛かるので ble/util/is-stdin-ready を用いて中断の判定を実行する。

## 2015-11-07
* Update README.md
* ble.pp: check environment for required commands, ble-edit.sh: 'M-\'.
  * ble.pp: check required commands.
  * ble-core.sh: remove dependencies on `touch' command.
  * ble-edit.sh, keymap/emacs.sh: Add edit function: delete-horizontal-space ('M-\').

## 2015-11-06
* ble-syntax.sh: cleanup debug codes.
* ble-syntax.sh (ble-syntax/parse/shift.nest): bugfix, parse error by shift failure of _ble_syntax_nest.

## 2015-11-25
* Create README.md

## 2015-08-25
* m, bugfixes.
  * PS1 の '!' の処理、
  * PS1 の \w の処理、
  * (bash-3.0) history '!1' &>/dev/null によるチェックでエラーメッセージが漏れていた。
* bugfix, specify explicit collation order for regs and globs.
  * Character ranges in regular expressions and glob patterns are dependent on collation order.
  * To obtain the desired results for ascii characters, `local LC_COLLATE=C' should be explicitly specified.

## 2015-08-24
* ble-edit.sh (.ble-edit.history-add): bugfix, handling of HISTCONTROL.

## 2015-08-19
* bin/ble-edit.sh: bugfix for bash-3.0, history -s が正しく動作しないので修正。

## 2015-08-18
* bugfix and cleanups.
  * ble-core.sh (ble-assert): bugfix, correct return value.
  * ble-edit.sh, ble-synta.sh: bash-3.0 bugfix, `local arr=(...)' form cannot be used in bash-3.0.
  * ble-edit.sh (hist_expanded.initialize): renamed to `ble-edit/hist_expanded.initialize'.

## 2015-08-16
* 消滅単語に対する色解除の対策(暫定)。
  * ble-syntax.sh (ble-syntax/parse): 消滅単語の範囲集計。
  * ble-syntax.sh: 範囲更新・並進の整理。関数 ble/util/[uw]range#{update,shift} の追加。
* 表示系統 bug fixes.
  * ble-edit.sh (ble-edit/dirty-range/update): bugfix, endA0 の読み出しに誤り、変数名 delta/del に誤り。
  * ble-syntax.sh (ble-highlight-layer:syntax/update-attribute-table): bugfix in umin/umax update, umax の更新に使う変数名を誤っていた。
* 組込コマンド上書き対策。ble-syntax shift bufgix for bash-4.2 算術式。
  * ble-syntax.sh (bash-4.2): bugfix, ble-syntax/parse/shift.{tree1,nest} の算術式で bash-4.2 をクラッシュされる形式の物が見付かった。
  * ble-core.sh: ble/util/set 関数を追加。
  * ble-edit.sh: builtin 上書きを防ぐ為に unset -f builtin を実行 (builtin, unset 両方上書きされると駄目だが)。
  * ble-edit.sh: return/break/continue も上書きを禁止する。
  * ble-*.sh: test の代わりに [[ ]] を使用。
* 貼付時の再描画抑制 (read -t 0 による判定)。\x80-\x9F を M-^? で表示。
  * ble-edit.sh: 編集文字列内の \x80-\x9F の表示を M-^? に。表示が乱れていた。
  * ble-edit.sh (ble-decode-byte:bind): 次の文字が来ている時に再描画を抑制。
  * ble-edit.sh: exec/gexec 周りの関数名を整理。
  * ble-edit.sh: 関数削除 .ble-edit-isearch.create-visible-text

## 2015-08-14
* 構文 function ... に対応、履歴展開 bugfix.
  * ble/src: .srcoption 追加。
  * ble-syntax.sh: defface 関数の色の変更。
  * ble-syntax.sh: 構文 `function ...` に対応。
  * ble-syntax.sh: `function ...`, `hoge ()` の直後に来るコマンドを compound-commands に制限。
  * ble-edit.sh: bugfix, set +H の時も履歴展開が有効になっていた。history -p は set +H と関係なく展開を行う。
  * ble-edit.sh: bugfix, 関数 echo を定義するとコマンドがそれ以上実行できなくなる。echo/printf を builtin を介して呼び出す様に変更。
* ble/util/assign cleanup, ble/util/type add, .ble-line-prompt/update bugfix.
  * ble-core.sh (ble/util/assign): cleanup, ble/util/sprintf, ble/util/type, ble/util/isfunction でも仕様,
  * ble-core.sh: ble/util/type 追加。$(type -t) はこれを用いて処理する様に変更,
  * ble-edit.sh (.ble-line-prompt/update): bugfix, 地の文の '$' や '`' が escape されてしまい展開されない.
* ble-edit.sh: プロンプト更新最適化。
* ble-core.sh (ble/util/assign): $(...) 高速化用関数。
* shift 高速化、入れ子構造を考慮に入れた単語着色に対応。
  * ble-syntax.sh (ble-syntax/parse/shift): 入れ子構造を考慮に入れた shift,
  * ble-syntax.sh (_ble_syntax_tree): 単語毎の着色情報をデータ配列内に保持するように変更,
  * ble-syntax.sh (ble-highlight-layer:syntax/update-word-table): 入れ子構造を考慮に入れた着色.
* leak variables: g cs
* cleanup, leak variables 処置.
* ble-syntax.sh: 終端していない節も列挙対象に含める。他整理。
  * ble-syntax.sh (ble-syntax/print-status): prints unterminated nodes.
  * ble-syntax.sh: add new functions ble-syntax/tree-enumerate, ble-syntax/tree-enumerate-children.
  * ble-syntax.sh: rename shell variable: _ble_syntax_word -> _ble_syntax_tree.
  * ble-syntax.sh: cleanup.

## 2015-08-13
* ble-syntax.sh: clenup, print-status/dump-tree.
* ble-sytanx.sh (_ble_syntax_stat): 解析状態に tchild, tprev (兄・子へのoffset情報) を追加。
* ble-sytanx.sh (_ble_syntax_word): 形式変更。兄・子へのoffset情報はその場で計算する暫定方式。

## 2015-08-12
* memo.txt: _ble_syntax_word 形式変更の計画, ble-syntax.sh: clean up

## 2015-08-11
* ble-syntax.sh (`_ble_syntax_nest[]`): 形式変更 → "ctx wlen wtype nlen type"
* ble-syntax.sh (`_ble_syntax_stat[]`): 形式の変更 → "ctx wlen wtype nlen"
* ble-syntax.sh (`_ble_syntax_word[i]`): 要素の形式を wtype wbegin から wtype wlen に変更
* ble-edit.sh (.ble-line-info.draw): 制御文字も入れられる様に,
* ble-syntax.sh (ble-syntax/print-status): Added,
* ble.pp: 二重起動対策,
* ble-edit.sh: history load.

## 2015-08-08
* ble-syntex.sh (ble-syntax/completion-context/check-prefix): completion at redirect filenames.

## 2015-07-10
* memo.txt: Added todos.

## 2015-06-15
* modified complete.sh

## 2015-03-22
* ble-decode.sh: bugfix, bash-4.1 でも ESC [ を翻訳しないと駄目
* ble-decode.sh: bugfix, bash-4.1 でも ESC * に登録しないと駄目
* ble-core.sh, etc.: 一時ファイルを tmp/$UID に置く事にする。

## 2015-03-12
* ble-syntax.sh (ble-syntax/parse): stat の設定されていない箇所に word があり、shift されていなかった。

## 2015-03-08
* ble-edit.sh (ble-edit/draw/trace): bugfix, LC_COLLATE を設定して正規表現を使用する様に修正。
* bashbug related bugfix: 幾つかの bugfix, 全て bash のバグが関係していた…。
  - `<bug>` bash-4.1 以下でカーソルの表示位置がずれている。
  - `<bug>` bash-4.2, 4.0, 3.2, 不完全な編集内容に対してエラーが出る
  - `<bug>` bash-4.0, 4.1 でプロンプトが表示されない
  - `<bug>` bash-4.1 以下でプロンプトの色が着かない
* ble-decode.sh (.ble-decode-char): control/alter/meta/shift/super/hyper prefix が、
  その場で自身に適用されて出力されていた。
* ble-core.sh (ble/util/declare-print-definitions): 連想配列に対応
* ble-decode.sh, 他: オプション名 ble_opt を bleopt に統一
* ble-decode.sh: .ble-decode-char 再実装
  - 修飾機能を send-modified-key (旧 sendkey-mod) に合流
  - C-x @ S 等、ESC 以外の修飾にも対応
  - .ble-decode-char/csi/* による CSI sequence の解釈
  - 新実装に対応する様に cmap/default.sh を書き直し

## 2015-03-06
* ble-decode.sh (stty): -icanon の設定。
* ble-edit.sh (PS1): bugfix, job count, 時刻その他の更新。
* ble-edit.sh (.ble-line-text/update/postion)
  - bugfix: ascii printable characters の行末で \n を付加した時 ichg に登録していなかった。
  - bugfix: _ble_util_string_prototype の長さ指定に 0 を指定していた
  - bugfix, 行末付近での tab の取り扱い
  - 制御文字も追い出しの対象に。
  - xenl の時、行末で必ず \n を追加する (追い出しの場合なども含め)。
  - 追い出しがあった場合にそれを記録する。
* ble-edit.sh (.ble-line-text/getxy.cur): カーソル位置を取得する為の getxy を新規作成。
* ble-edit.sh (ble-edit/draw/trace): 描画属性
  - term.sh: 描画属性について terminfo から読み取る様に。
  - ble-color.sh: 描画属性の点滅、不可視、イタリック、打ち消し線に対応。
  - ble-color.sh: sgr 構築で term.sh の結果を利用する様に変更。
  - ble-edit.sh (.ble-line-prompt): ble-color-g2sgr で端末に依存しない PS1 を書ける様に変更。
* ble-decode.sh (ble-decode-kbd): bugfix, 複数キーがある場合に正しく処理できていなかった
* overwrite-mode に対応
* ble-syntax.sh, ble-color.sh: layer:syntax による色付けを face を介した物に変更。
* ble-decode.sh, ble-edit.sh: 条件コマンドの統一。test や [ 等を [[ に統一。

----

<!---------------------------------------------------------------------------->
# Old ChangeLog

## 2015-03-03

  * ble-edit.sh, ble-edit.color: discard-line の際に着色
  * ble-edit.sh, ble-core.sh, etc: echo を builtin echo に。
  * ble-edit.sh: bugfix, 複数行で上に行けない
  * ble-edit.sh: bugfix, 複数行なのに空行の accept-line でのずれ量が1行になっている
  * プロンプト再実装
    - ble-edit.sh (ble-edit/draw/trace): escape sequences が含まれている文字列の位置追跡。
    - ble-edit.sh (.ble-line-prompt/update): プロンプトの構築を再実装。$() がある場合なども正しい計算。
  * ble-complete.sh (source/command): shopt -s autocd の時にディレクトリ名も候補として列挙。
  * ble-complete.sh: 補完候補の選択の方法を変更。より近くの開始点の物を優先。

## 2015-03-01

  * ble-edit.sh: .ble-edit-draw.goto-xy, .ble-edit-draw.put 廃止
  * complete.sh: 関数名に / が入っていると compgen -c で列挙されないので、別に列挙する。

## 2015-02-28

  * 初期化の最適化
    - ble-decode.sh: ble-decode-kbd 書き直し、ble-bind 書き直し
    - ble-getopt.sh: 多少最適化
    - ble-decode.sh: bash-4.3 でも ESC [ を utf-8 2-byte code で受信する様に変更。
    - ble-decode.sh (.ble-decode-bind/generate-source-to-unbind-default): awk 呼出を一回に統合。
    - ble-decode.sh (.ble-decode-key.bind/unbind): [[ ]] による書き換え、bugfix。
    - ble-decode.sh, bind.sh: bind -x を生成する為のコードを bind.sh に分離。
    - ble-edit.sh, keymap.emacs.sh: keymap 初期化部分の分離、キャッシュ化。
    - ble-edit.sh: history 遅延ロード対応
  * ble-core.sh, ble-color.sh: .ble-shopt-extglob-push/pop/pop-all 廃止
  * ble-edit.sh: bugfix, .ble-line-info.clear で位置がずれる
  * ble-edit.sh: ble-edit/draw/put.il, ble-edit/draw/put.dl
  * ble-color.sh (ble-highlight-layer/update/shift): 長さが変わらない場合でも shift する。
  * ble.pp (include ble-getopt.sh): 現在使っている所がないので取り敢えず外す。
  * ble-syntax.sh (completion-context): 簡単なパラメータ展開に対する対応。

## 2015-02-27

  * [bug] TAB 等の変更文字があった場合に文字列が表示されなくなる
  * bash-3.0, 3.1 対応
    "[bug] bash-3.1 日本語の色付け・描画が変だ"
    - ble-edit.sh, 他: @bash-3.1 bashbug workaround, ${param//%d/x} などは効かないので %d を '' で囲む。
    - ble-syntax.sh, 他: @bash-3.1 bashbug workaround, x${#arr[n]} はバイト数を返す様なので一旦通常変数に入れて ${#var} とする。
    - *.sh: @bash-3.0: += 演算子の置き換え、配列宣言の修正。
    - term.sh: @bash-3.0: bashbug workaround, declare -p で出力すると誤った物になる。
  * ble-edit.sh (.ble-line-text/update/slice): bugfix, 変更文字がある時にもう存在しないローカル変数を参照していた。
  * ble-core.sh: ble-load, ble-autoload
  * complete.sh:, ble-syntax.sh, ble-edit.sh: 文脈依存補完の実装

## 2015-02-26

  * ble-syntax.sh: a+=( a=( に対応

## 2015-02-25

  * ble/term.sh: TERM 依存の部分を分離。キャッシュ化。完全移行ではないが徐々に。
  * ble-decode.sh:
    - [bug] $_ble_base/cache の代わりに $_ble_bash/cache を作成していた
    - [bug] accept-single-line-or-newline が二回目以降常に accept
  * ble-edit.sh:
    - [bug] 複数行の編集時に履歴移動をすると表示が乱れる
    - printf %()T を用いた実装の導入、PS1 \D{...} に対応
    - [bug] 表示の属性の更新がうまく行かない事がある。
    - [bug] 編集文字列の行数が変わった時に info.draw の内容がずれる
  * カーソル移動
    - ble-edit: 複数行編集と項目内でのカーソル移動に対応
    - ble-edit.sh: 複数行コマンドの履歴に対応。
  * ble-syntax.sh: ble-syntax-highlight+syntax を ble-highlight-layer:syntax に書き換え
  * ble-syntax.sh:
    - 関数定義 func() の形式に対応、
    - 条件式 [[ ... ]] と配列初期化子内の文脈に対応。
    - コメントに対応。
    - $[...] の形式に対応 (何故か bash の説明には一切載っていないが使える)。
    - [bug] invalid nest " $()" の先頭に for を挿入した時

## 2015-02-24

  * ble-edit.sh 出力の部分更新に対応 (描画ちらつき対策)
  * ble-syntax.sh: _ble_syntax_word, _ble_syntax_stat の形式の変更
  * ble-syntax.sh: 今迄行っていた dirty-range 拡大の方法を止めて、単に stat の削除を行う。
  * ble-syntax.sh: 及び上記の変更に伴う数々の bugfix
    - [bug] 文字削除時 invalid nest の assertion に引っかかる。
    - [bug] 編集内容が零文字になった瞬間に改行が起こって表示が消える。
    - [bug] 改行しても先頭がコマンドになっていない
    - [bug] _ble_region_highlight_table で空欄になっている箇所がある。
    - [bug] 単語の属性適用が後ろに続く単語にも続いている。
    - [bug] _ble_syntax_attr の中に "BLE_ATTR_ERR" の文字列が混入している。
    - 残っている dirty 拡大と _ble_syntax_word[] の廃止された形式に対する処理の
      コメントアウトされた部分を削除。dirty 拡大の変更に伴う効率化の確認と、
      shift が遅いという事の ToDo 項目の追加。
  * ble-decode.sh: [bug] $_ble_base/cache の代わりに $_ble_bash/cache を作成していた
  * ble-edit.sh: ble-edit+delete-backward-xword の類の動作を変更。

## 2015-02-23

  * ble-core.sh: ble-stackdump, ble-assert
  * [bug] update-positions で dend-dbeg が負になると警告が出る
  * [bug] info.draw で特殊文字が改行に跨っている時の座標計算

## 2015-02-22

  * ble-edit.sh: [bug] .ble-line-info.draw を使った時行がずれる
  * ble-syntax.sh: [bug] for や do に色が着かない?
  * レイヤー化
    - ble-color.sh: レイヤーの仕組み、レイヤ region, adapter, plain + RandomColor
    - ble-edit.sh: レイヤーに対応した表示文字列構築関数。古い構築関数の削除。出力関数の変更。
    - ble-syntax.sh: 多少の変更。

## 2015-02-21

  * 描画の高速化
    - ble-syntax.sh: 属性値の変更範囲に応じて適用を行い、変更範囲を LAYER_MIN, LAYER_MAX に返す様に。
    - ble-edit.sh: 表示用の文字列の構築部分を書き直して部分更新に対応。
    - ble-syntax.sh: 内容に変化のあった word の範囲も記録する様に変更。
    - ble-syntax.sh (parse): _ble_syntax_attr_umin (属性値の変更範囲),
      _ble_syntax_word_umin (word の変更範囲) の累積に対応する為に、これらについても shift を実行する。

## 2015-02-20

  * ble-decode.sh: bind 周り
    - bash-4.3 C-@ を utf-8 2-byte code で受信する様に変更
    - bash-3.1 ESC [ を utf-8 2-byte code で受信する様に変更
    - bugfix, \C-\\ \C-_ \C-^ \C-] に bind できなくなっていた。
    - bind の version 分岐について整理。
    - 既存の bind を ESC に関係なく bind -r する。
  * ble-decode.sh: .ble-decode-key 部分一致探索の処理の再実装。変な動作だった。
  * ble-decode.sh: bugfix, 8bit 文字を正しく bind できていない。c2s で8bit文字が符号化されていた。
  * ble-syntax.sh: 履歴展開は $- に H がある時のみ有効に。
  * ble-syntax.sh: bugfix, bash-4.2 のバグの work around。配列を参照する算術式の書き換え。
  * ble-core.sh: c2s を bash の機能だけで実装できたので fallback を replace。
  * ble-core.sh: bash-4.0 で .ble-text.s2c を連想配列でメモ化
  * ble-edit.sh: bugfix, bash-4.0 で ret に予め特定の値が入っていると c2w に失敗する。
  * ble-edit.sh: bugfix, bind -x 直前のプロンプトの取り扱いは bash-4.0 では bash-3 系と同じ。
  * ble-edit.sh (.ble-line-text.construct 周り): lc lg を後で計算する様に変更。一区切り。一旦 commit する。

## 2015-02-19
  * ble-syntax.sh: 履歴展開に対応。
  * ble-decode.sh: bugfix, bind -X から bind -x を生成するコード。
    bind -X の出力する形式は再利用不可能な形式でエスケープされているのでこれを変換。
  * ble.pp, etc: noattach 引数に対応。ble-attach/ble-detach 関数の定義。detach の bugfix。
  * ble-edit.sh: bug, bleopt_suppress_bash_output= にした時にプロンプトが二重になる

## 2015-02-18

  * ble.pp, ...: ディレクトリの構成を変更
  * ble-syntax.sh: 文法の対応
    - プロセス置換を単語として扱う様に変更
    - リダイレクトの後の引数に対応
    - リダイレクトの前の fd 部分に対応
  * bash-3.1 対応
    - ble-edit.sh: bash-3.1 で C-d を捕捉できる様に(結構無理のある方法だが)。
    - ble-edit.sh, ble-decode.sh: bugfix, bash-3 でカーソルキーの類が動かない。履歴が読み込まれていない。
    - ble-edis.sh: bash-3.1, bleopt_suppress_bash_output=1 の方が安定して動いているのでこちらで行く。
    - ble-edit.sh: bash-3.1, カーソルキーが効かない。例によって ESC [ ... に関係するコマンドで
      keymap が見付からないエラーになっている。これは ESC [ を CSI (utf-8) に変換してから読み取る事にした。
    - ble-syntax.sh: bash-3.2.48 のバグの work-around, (()) 内で配列要素を参照すると制御が無条件に其処に跳ぶ。

## 2015-02-17
  * ble-edit.sh (ble-edit/dirty-range): 範囲更新の仕組みを追加。
      _ble_edit_dirty はプロンプト再描画の判定も兼ねているので取り敢えず残す。
  * ble-edit.sh: 変数リーク (グローバル変数の汚染) の修正。line i
  * ble-syntax.sh (ctx-command/check-word-end): 単語終了判定の処理タイミングを変更。
  * ble-syntax.sh: context の追加。CTX_CMDXF CTX_CMDX1 CTX_CMDXV CTX_ARGX0
    より正確な文脈判定・エラー検知。
  * ble-syntax.sh: 他にも多くの修正がある。未だ修正が続きそうなので一旦 commit する。

  * ble-edit.sh (accept-line): bug, - で始まるコマンドを実行できない。
  * ble-color.sh: [bug] bg=black を設定しても反映されない。
    "未設定" と "黒" を区別する様に修正。
  * ble-syntax (ble-syntax-highlight+syntax): 入れ子エラーの色の範囲
  * ble-syntax: m, ;& は ;; ;;& 等と同じ取り扱い
  * ble-syntax, etc: bash-3 正規表現対策。bash-3/4 の正規表現の違いに依存しない書き方に変更。

## 2015-02-16
  * ble-syntax.sh: bugfix, incremental に更新した時に word の長さが更新されない。
    _ble_syntax_word への格納の際に失敗していた。

## 2015-02-15
  * ble-synatax.sh: bash の文法に従った incremental な解析と色付け。

## 2015-02-14
  * ble-edit.sh (.ble-line-info.draw): 表示が遅いので修正。
    ASCII 文字は特別扱いする様に改良。劇的に速くなった。

## 2015-02-13
  * ble-edit.sh (keymap emacs): 既定の keymap に emacs の名を付与。
  * ble-edit.sh (accept-line.exec): bugfix, C-c で再帰呼び出しのループから抜けられない。
    trap DEBUG を用いて再帰呼び出しから抜けられる様に exec 周りを整理・実装し直し。
  * ble-edit.sh: オプション名の変更、各オプションの整理・説明の追加。
  * ble-edit.sh (.ble-edit/gexec): グローバルな文脈でコマンドを実行する仕組み。
    再帰呼出に対する C-c にも対応。bleopt_exec_type で実行の方法を切り替えられる様に。
    exec が従来の方法で gexec がこの新しい方法。

## 2015-02-12
  * ble-decode.sh: bugfix, exit 後に stty が壊れているのを修正
    これに伴って ble の detach 機能の実装も行った。
  * ble-decode.sh: bugfix, bash-4.3 で三文字以上のシーケンスが悉く聞かない。
    keymap が見付からないエラーになってしまうので全てのシーケンスについて bind -x する事にした。
  * ble-core.sh: bugfix, builtin printf \U.... の使えない環境で command printf fallback が働かない。
    printf のパスを修正。また ASCII に対しては printf は使わない様に変更。
  * ble-color.sh (ble-syntax-highlight+default):
    追加・修正。また選択範囲の反転を ble-syntax-highlight+region として実装し、それを呼び出す形に。
  * ble.pp: 起動時に interactive モードかどうかのチェックを行う様に。

## 2015-02-11
  * ble-edit.sh (_ble_edit_io_*): ちらつきを抑える為に stdout/stderr を切り替える事にした。
    ちらつくのは bash の既定の出力によって ble の表示がクリアされ、bash の表示したい物が表示されるから。
    これに対抗して ble は bash の出力の直後に上書き再描画して何とか表示していた。
    bash の既定の出力を抑える為に、exec で出力先を切り替える事にした。
    bash の出力はファイルに書き込まれる様にし向ける。出力先ファイルを逐次確認して、
    エラーが出力されていれば visible-bell で表示する事にした。
    `bleopt_suppress_bash_output=1` の時にこの新しい方法を実験的に用いる。
    `bleopt_suppress_bash_output=` の時は従来のちらつく方法。

## 2015-02-10
  * ble-edit.sh (accept-line.exec): bash-4.3 で内部からグローバル変数を定義できる様に
    declare 及び typeset を上書きして -g オプションを指定する様に変更。
    また、これに関係する注意点を ble.htm に記述。
  * ble-edit.sh (history): ロードに時間が掛かるので最適化。
  * 全般: bugfix, 文字列分割で GLOBIGNORE='*' を設定していないとパス名展開されて危険
  * ble-color.sh (ble-syntax-highlight+default): より良い色づけ。
  * ble-edit.sh (accept-line.exec): ble-bind -cf で bind されたコマンドの実行コンテキストを変更。
    accept-line で実行されるのと同じコンテキストで実行する。
  * ble-edit.sh (keymap default): C-z M-z を fg に bind。

## 2015-02-09
  * git repos
  * ble-edit: bugfix, locate-xword マクロが展開されていなかった
  * ble-decode: bash-4.3 に対応する為に色々変更
    - bind 指定の場合分けを整理
    - bugfix, ESC ?, ESC [ ? に対して全て bind
    - bugfix, 場合によって全く bind -r できていない
      →"bind -sp | fgrep" が "バイナリ" という結果になる事がある様だ。
        fgrep に -a を指定する。
    - bugfix, 日本語が入力できない。8bit 文字が認識されない。
      →8bit 文字はエスケープシーケンスで bind に指定する様に変更。

## 2013-06-12
  * ble-edit: history-beginning, history-end, accept-and-next

## 2013-06-12
  * ble-edit:
    kill-forward-fword, kill-backward-fword, kill-fword,
    copy-forward-fword, copy-backward-fword, copy-fword,
    delete-forward-fword, delete-backward-fword, delete-fword,
    forward-fword, backward-fword
  * ble-edit: history-expand-line, display-shell-version

## 2013-06-10
  * ble-edit:
    kill-forward-uword, kill-backward-uword, kill-uword, kill-region-or-uword,
    copy-forward-uword, copy-backward-uword, copy-uword, copy-region-or-uword,
    forward-uword, backward-uword

  * ble-edit:
    delete-forward-uword, delete-backward-uword, delete-uword, delete-region-or-uword,
    delete-forward-sword, delete-backward-sword, delete-sword, delete-region-or-sword,
    delete-forward-cword, delete-backward-cword, delete-cword, delete-region-or-cword

  * ble-edit:
    以下の編集関数を廃止:
      delete-region-or-uword, kill-region-or-uword, copy-region-or-uword,
      delete-region-or-sword, kill-region-or-sword, copy-region-or-sword,
      delete-region-or-cword, kill-region-or-cword, copy-region-or-cword.
    代わりに以下の編集関数を用いる:
      delete-region-or type, kill-region-or type, copy-region-or type.

## 2013-06-09
  * ble-edit: kill-region, copy-region
  * ble-edit:
    kill-forward-sword, kill-backward-sword, kill-sword, kill-region-or-sword,
    copy-forward-sword, copy-backward-sword, copy-sword, copy-region-or-sword
  * ble-edit:
    kill-forward-cword, kill-backward-cword, kill-cword, kill-region-or-cword,
    copy-forward-cword, copy-backward-cword, copy-cword, copy-region-or-cword
  * ble-edit: forward-sword, backward-sword, forward-cword, backward-cword

## 2013-06-06
  * ble-edit-bind: 全ての文字・キーが入力可能に。
  * complete: 候補一覧の表示 (簡易版)
  * ble-color.sh: 色付け機能を highlight.sh から移植

## 2013-06-05
  * ble-edit: history-isearch-backward, history-isearch-forward,
    isearch/self-insert,
    isearch/next, isearch/forward, isearch/backward,
    isearch/exit, isearch/cancel, isearch/default,
    isearch/prev, isearch/accept
  * ble-edit: yank
  * ble-bind -d で今迄に bind した物を表示できる様に。
  * ble-edit: complete, 取り敢えずファイル名補完だけ
  * ble-edit: command-help

## 2013-06-04
  * ble-edit: discard-line, accept-line
  * ble-edit: history-prev, history-next
  * ble-edit: set-mark, kill-line, kill-backward-line, exchange-point-and-mark
  * ble-edit: clear-screen
  * ble-edit: transpose-chars
  * ble-edit: insert-string

## 2013-06-03
  * ble-edit: bell, self-insert, redraw-line,
  * ble-edit: delete-char, delete-backward-char, delete-char-or-exit,
    delete-forward-backward-char
  * ble-edit: forward-char, backward-char, end-of-line, beginning-of-line
  * ble-edit: quoted-insert
  * ble.sh: 取り敢えず簡単に文字列を入力できる程度までは完成

## 2013-06-02
  * ble-getopt.sh: bugfixes
  * ble-getopt.sh: 無事に完了した場合に OPTARGS を unset する様に変更
  * ble-decode-kbd, ble-decode-unkbd

## 2013-05-31
  * ble-getopt.sh: created
  * ble-decode: 大枠が完成

## 2013-05-30
  * highlight.sh: 取り敢えず簡単な色付け
  * ble.sh:

    -- 経緯 --
    highlight.sh の方針だと bash が表示する編集中の内容を消す事が出来ないし、
    カーソルの位置も bash が表示する物の場所を指している。
    色を付けて表示した物は、補助的に bash が表示する物の下に並べて表示する
    ぐらいしか方法がない。

    また readline 関数をスクリプトから呼び出す事が出来ないので、
    結局、色付けを更新したいタイミングで READLINE_LINE や READLINE_POINT の動作を
    スクリプトの側で全て模倣して再現しなければならない。
    READLINE_LINE, READLINE_POINT の bash の仕様が変な所為で、日本語など
    のマルチバイトで正しく処理する為に、色々と汚い事をしなければならない。

    以上の事から、文字列の編集などの操作からスクリプトの実行まで
    全部自分で好きな様に実装して bash readline の機能を全て上書きする事にした。
    その為に、スクリプトを新しく書き直す。zle を真似て ble (bash line editor)
    と名付ける。

    -- 方針としては --
    a. read -n 1 を用いて 1 文字ずつ標準入力から文字を取り出してそれを処理していく
    b. bash の bind で全ての文字に ble のバイト受信関数を繋げて、
       バイト列を受信しながら処理する。

    highlight.sh の延長線上で b. の方針にしたが、
    もしかすると a. の方針も可能かも知れない。

## 2013-05-29
  * highlight.sh: 作成
