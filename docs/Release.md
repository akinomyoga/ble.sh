# ble-0.4.0-devel2

## Usage

**Prerequisites**

Bash 3.0+ and basic POSIX utilities are required.

**Download ble-0.4.0-devel2.tar.xz**

https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel2/ble-0.4.0-devel2.tar.xz

```bash
# DOWNLOAD with wget
wget https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel2/ble-0.4.0-devel2.tar.xz

# DOWNLOAD with curl
curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel2/ble-0.4.0-devel2.tar.xz
```

**Trial & Install**

```bash
# TRIAL
tar xJf ble-0.4.0-devel2.tar.xz
source ble-0.4.0-devel2/ble.sh

# INSTALL (quick)
tar xJf ble-0.4.0-devel2.tar.xz -C ~/.local/share/blesh
echo 'source ~/.local/share/blesh' >> ~/.bashrc

# INSTALL (more robust)
tar xJf ble-0.4.0-devel2.tar.xz -C ~/.local/share/blesh
# Add the following line near the top of ~/.bashrc
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --attach=none
# Add the following line at the end of ~/.bashrc
[[ ${BLE_VERSION-} ]] && ble-attach
```

--------------------------------------------------------------------------------

# ble-0.3.3

## Usage

**Prerequisites**

Bash 3.0+ and basic POSIX utilities are required.

**Download ble-0.3.3.tar.xz**

https://github.com/akinomyoga/ble.sh/releases/download/v0.3.3/ble-0.3.3.tar.xz

```bash
# DOWNLOAD with wget
wget https://github.com/akinomyoga/ble.sh/releases/download/v0.3.3/ble-0.3.3.tar.xz

# DOWNLOAD with curl
curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.3.3/ble-0.3.3.tar.xz
```

**Trial & Install**

```bash
# TRIAL
tar xJf ble-0.3.3.tar.xz
source ble-0.3.3/ble.sh

# INSTALL
tar xJf ble-0.3.3.tar.xz -C ~/.local/share/blesh
# Add the following line near the top of ~/.bashrc
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --attach=none
# Add the following line at the end of ~/.bashrc
[[ ${BLE_VERSION-} ]] && ble-attach
```

## New features

- syntax: allow unquoted `[!` and `[^` in `simple-word` (reported by cmplstofB) `#D1303` 4bf8b86 (master: 1efe833)

## Changes

- auto-complete: bind `insert-on-end` to `C-e` `#D1250` 1070aba (master: 90b45eb)
- util (`bleopt`): fail when a specified bleopt variable does not exist (test-util) 0a51044 (master: 5966f22)
- edit: preserve `PS1` when `internal_suppress_bash_output` is set `#D1344` 537acf2 (master: 6ede0c7)
- complete: change to generate filenames starting from `.` by default `#D1425` e26867d (master: 987436d)

## Fix

- [ble-0.3] reload: fix a bug that the state is broken by `ble-reload` `#D1266` f2f30d1 (master: N/A)
- decode (`ble/builtin/bind`): remove comment from bind argument `#D1267` 82f4aaa (master: 880bb2c)
- complete: clear menu on history move `#D1248` 04fddd6 (master: 06cc7de)
- syntax: fix a bug that arguments of `eval` are not highlighted `#D1254` 38a7fc7 (master: 5046d14)
- decode: use `BRE` instead of `ERE` for `POSIX sed` (reported by dylankb) `#D1283` a577ec4 (master: 2184739)
- vi (vi-command/nth-column): fix a bug in arithmetic expansion (reported by andychu) `#D1292` ea2fa8e (master: da6cc47)
- complete: fix a bug that menu-filter is only partially turned off by `complete_menu_filter` `#D1298` 7278e27 (master: b3654e2)
- syntax: fix failglob errors of heredocs of the form `<<$(echo A)` `#D1308` 5ba9400 (master: 3212fd2)
- util (`bleopt`): fix a bug that a new setting is not defined with `name:=` (test-util) `#D1312` f2dbad0 (master: c757b92)
- util (`ble/util/{save,restore}-vars`): fix a bug that `name` and `prefix` cannot be saved/restored (test-util) f91f7ed (master: 5f2480c)
- util (`ble/path#remove{,-glob}`): fix corner cases (test-util) 2ba1d42 (master: ccbc9f8)
- util (`ble/variable#get-attr`): fix an error message with special variable names such as `?` and `*` `#D1321` b58f006 (master: 557b774)
- edit: fix a bug that `set +H` is cancelled on command execution `#D1332` bc454a2 (master: 02bdf4e)
- syntax (`ble/syntax/parse/shift`): fix a bug of shift skip in nested words `#D1333` 78e2170 (master: 65fbba0)
- util (`ble-stackdump`): fix a shift of line numbers `#D1337` 1505a5b (master: a14b72f)
- edit (`ble-bind -x`): check range of `READLINE_{POINT,MARK}` `#D1339` 1bc1ff6 (master: efe1e81)
- main: fix a bug that `~/.config/blesh/init.sh` is not detected (GitHub #53 by rux616) 9f74da6 (master: 61f9e10)
- util (`ble/string#to{upper,lower}`): work around `LC_COLLATE=en_US.utf8` (test-util) `#D1341` 5d9aa64 (master: 1f6b44e) `#D1355` 4e67719 (master: 4da6103)
  - fixup 5d9aa64 fef40eb (master: N/A)
- util (encoding, keyseq): fix miscelleneous encoding bugs (test-util) 6d72d2a (master: 435bd16)
- edit: work around `WINCH` not updating `COLUMNS`/`LINES` after `ble-reload` `#D1345` e2d54a2 (master: a190455)
- complete: initialize `bleopt complete_menu_style` options before `complete_load` hook (reported by rux616) `#D1352` 15ba24f (master: 8a9a386)
- main: fix problems caused by multiple `source ble.sh` in bashrc `#D1354` 983e8a9 (master: 5476933)
- syntax: allow single-character variable name in named redirections `{a}<>` `#D1360` 52de342 (master: 4760409)
- decode (`bind`): work around `shopt -s nocasematch` (reported by tigger04) `#D1372` b34ad58 (master: 855cacf)
- prompt: fix a bug that rprompt is not cleared when `bleopt prompt_rps1` is reset `#D1377` c736bd5 (master: 1904b1d)
- complete: fix a bug of duplicated completions of filenames with spaces `#D1390` 048f17e (master: 98576c7)
- complete: fix bugs that quotation disappears on ambiguous completion `#D1387` 048f17e (master: 98576c7)
- complete: fix a bug that progcomp retry by 124 caused the default completion again `#D1386` 048f17e (master: 98576c7)
- syntax (tree-enumerate): fix unmodified `wtype` of reconstructed words at the end `#D1385` 048f17e (master: 98576c7)
- complete: fix superlinear performace of ambiguous matching globpat `#D1389` bd4657a (master: 71afaba)
- prompt: fix a bug that lonig rps1 is not correctly turned off `#D1401` 9266961 (master: d84bcd8)
- prompt: fix extra spaces on line folding before double width character `#D1400` 9266961 (master: d84bcd8)
- syntax (glob bracket expression): fix a bug of unsupported POSIX brackets `#D1402` e1eca65 (master: 6fd9e22)
- syntax (`ble/syntax:bash/simple-word/evaluate-path-spec`): fix a bug of unrecognized `[!...]` and `[^...]` `#D1403` 50fcd03 (master: 0b842f5)
- highlight: fix remaininig highlighting of vanishing words `#D1421` `#D1422` 0f85719 (master: 1066653)
- highlight: fix unhighlighted tilde expansions `~+` (reported by cmplstofB) `#D1424` 1f9abf6 (master: a32962e)
- complete: fix a problem that the user setting `dotglob` is changed `#D1425` e26867d (master: 987436d)
- complete: fix a problem of redundant unmatched ambiguous part with tilde expansions in the common prefix `#D1417` 20cb6af (master: 5777d7f)
- complete (`source:file`): fix a bug that tilde expansion candidates are always filtered out `#D1416` 20cb6af (master: 5777d7f)
- complete (`cd`): fix duplicate candidates by `CDPATH` (reported by Lennart00 at `oh-my-bash`) `#D1415` 20cb6af (master: 5777d7f)

## Compatibility

- msys2: support2 MSYS (motivated by SUCHMOKUO) `#D1264` 500e051 (master: 47e2863)
  - edit: support `\$` in `PS1` for MSYS2 `#D1265` b8c2ca6 (master: f6f8956)
  - edit: fixup b8c2ca6 fe78bd6 (master: N/A)
  - msys2: work around MSYS2 Bash bug of missing <kbd>CR</kbd> `#D1270` 8c09190 (master: 71f3498)
- edit (`ble/widget/bracketed-paste`): fix error messages on `paste_end` in older version of Bash (test-util) 1631069 (master: b2c7d1c)
- decode: work around Bash-3.1 bug of `declare -f` rejecting special characters in function names (test-util) 1631069 (master: b2c7d1c)
- util (`ble/variable#get-attr`): fix a bug that attributes are not obtained in Bash <= 4.3 (test-util) 1631069 (master: b2c7d1c)
- decode: work around Bash-4.1 bug that locale not applied with `LC_CTYPE=C eval command` (test-util) 1631069 (master: b2c7d1c)
- complete: follow Bash-5.1 change of arithmetic literal `10#` `#D1322` b58f006 (master: 557b774)
- decode: work around Bash-4.1 arithmetic bug of array subscripts evaluated in discarded branches `#D1320` b58f006 (master: 557b774)
- decode: fix a bug of broken cmap cache found in ble-0.3 `#D1327` 4b15993 (master: 16b56bf)
- util (strftime): fix a bug not working with `-v var` option in Bash <= 4.1 (test-util) 360211c (master: f1a2818)
- complete: work around slow `compgen -c` in Cygwin `#D1329` 185a443 (master: 5327f5d)
- edit: work around problems with `mc` (reported by onelittlehope) `#D1392` 4d534b4 (master: e97aa07)
  - highlight: fix a problem that the attribute of the last character is applied till EOL `#D1393` f47a5b8 (master: 2ddb1ba) `#D1395` 8c1e17c (master: ef09932)

## Internal

- global: check isolated identifiers and leak variables `#D1246` f92ba5c (master: 19cc99d) 9461953 (master: 2e74b6d)
- main: unset `BLE_VERSION`, `_ble_bash`, etc. on `ble-unload` `#D1382` 2bbd0fb (master: 6b615b6)
  - complete: fix unfiltered tilde expansions `#D1414` 20cb6af (master: 5777d7f)

-------------------------------------------------------------------------------
# ble-0.2.6

## New features

- syntax: allow unquoted `[!` and `[^` in `simple-word` (reported by cmplstofB) `#D1303` 5cff40f (master: 1efe833)

## Changes

- edit: preserve `PS1` when `internal_suppress_bash_output` is set `#D1344` 72ae9c6 (master: 6ede0c7)

## Fix

- decode: use `BRE` instead of `ERE` for `POSIX sed` (reported by dylankb) `#D1283` bca4598 (master: 2184739)
- vi (vi-command/nth-column): fix a bug in arithmetic expansion (reported by andychu) `#D1292` 4260bc2 (master: da6cc47)
- syntax: fix failglob errors of heredocs of the form `<<$(echo A)` `#D1308` 1f874ba (master: 3212fd2)
- util (`bleopt`): fix a bug that a new setting is not defined with `name:=` (test-util) `#D1312` a9eb0e9 (master: c757b92)
- util (`ble/util/{save,restore}-vars`): fix a bug that `name` and `prefix` cannot be saved/restored (test-util) 49841db (master: 5f2480c)
- edit: fix a bug that `set +H` is cancelled on command execution `#D1332` 2ff6d06 (master: 02bdf4e)
- syntax (`ble/syntax/parse/shift`): fix a bug of shift skip in nested words `#D1333` bc935bd (master: 65fbba0)
- util (`ble-stackdump`): fix a shift of line numbers `#D1337` b597e90 (master: a14b72f)
- edit (`ble-bind -x`): check range of `READLINE_{POINT,MARK}` `#D1339` 47a93e8 (master: efe1e81)
- util (`ble/string#to{upper,lower}`): work around `LC_COLLATE=en_US.utf8` (test-util) `#D1341` 5b32621 (master: 1f6b44e) `#D1355` b38ef10 (master: 4da6103)
- util (encoding, keyseq): fix miscelleneous encoding bugs (test-util) 03c0b44 (master: 435bd16)
- edit: work around `WINCH` not updating `COLUMNS`/`LINES` after `ble-reload` `#D1345` 50af6a5 (master: a190455)
- syntax: allow single-character variable name in named redirections `{a}<>` `#D1360` f81734f (master: 4760409)
- syntax (glob bracket expression): fix a bug of unsupported POSIX brackets `#D1402` b7ea892 (master: 6fd9e22)
- highlight: fix remaininig highlighting of vanishing words `#D1421` `#D1422` cc5e4d1 (master: 1066653)
- highlight: fix unhighlighted tilde expansions `~+` (reported by cmplstofB) `#D1424` 3f7f044 (master: a32962e)

## Compatibility

- msys2: support2 MSYS (motivated by SUCHMOKUO) `#D1264` 7cf81c0 (master: 47e2863)
  - edit: support `\$` in `PS1` for MSYS2 `#D1265` 8f44624 (master: f6f8956)
  - msys2: work around MSYS2 Bash bug of missing <kbd>CR</kbd> `#D1270` bbe1b61 (master: 71f3498)
- edit (`ble/widget/bracketed-paste`): fix error messages on `paste_end` in older version of Bash (test-util) a80f1d1 (master: b2c7d1c)
- decode: work around Bash-3.1 bug of `declare -f` rejecting special characters in function names (test-util) a80f1d1 (master: b2c7d1c)
- util (`ble/variable#get-attr`): fix a bug that attributes are not obtained in Bash <= 4.3 (test-util) a80f1d1 (master: b2c7d1c)
- decode: work around Bash-4.1 bug that locale not applied with `LC_CTYPE=C eval command` (test-util) a80f1d1 (master: b2c7d1c)
- decode: fix a bug of broken cmap cache found in ble-0.3 `#D1327` 366e8c1 (master: 16b56bf)
- util (strftime): fix a bug not working with `-v var` option in Bash <= 4.1 (test-util) 4f11463 (master: f1a2818)
- complete: work around slow `compgen -c` in Cygwin `#D1329` 887be6e (master: 5327f5d)
- edit: work around problems with `mc` (reported by onelittlehope) `#D1392` a2d6099 (master: e97aa07)

## Internal

- global: check isolated identifiers and leak variables `#D1246` 146c98b (master: 19cc99d)

-------------------------------------------------------------------------------
# ble-0.1.14

## Change

- edit: preserve `PS1` when `internal_suppress_bash_output` is set `#D1344` 549f8f5 (master: 6ede0c7)

## Fix

- fixup ab01ceb 8129816 (v0.2: 51bde60)
- decode: use `BRE` instead of `ERE` for `POSIX sed` (reported by dylankb) `#D1283` 1244d86 (master: 2184739)
- edit: fix a bug that `set +H` is cancelled on command execution `#D1332` ba3687a (master: 02bdf4e)
- syntax (`ble/syntax/parse/shift`): fix a bug of shift skip in nested words `#D1333` 16fb351 (master: 65fbba0)
- util (`ble-stackdump`): fix a shift of line numbers `#D1337` 5d5b86b (master: a14b72f)
- edit (`ble-bind -x`): check range of `READLINE_{POINT,MARK}` `#D1339` 6909cc0 (master: efe1e81)
- util (`ble/string#to{upper,lower}`): work around `LC_COLLATE=en_US.utf8` (test-util) `#D1341` 31476cc (master: 1f6b44e) `#D1355` 65cab5c (master: 4da6103)
- util (encoding, keyseq): fix miscelleneous encoding bugs (test-util) 11d8db7 (master: 435bd16)
- edit: work around `WINCH` not updating `COLUMNS`/`LINES` after `ble-reload` `#D1345` e15c5a6 (master: a190455)
- syntax: allow single-character variable name in named redirections `{a}<>` `#D1360` 6bbed24 (master: 4760409)
- highlight: fix remaininig highlighting of vanishing words `#D1421` `#D1422` bf8fdc8 (master: 1066653)

## Compatibility

- global: work around Bash 3.2 bug of array initialization with <kbd>SOH</kbd>/<kbd>DEL</kbd> `#D1238` 566f53e (master: defdbd4) `#D1241`
- msys2: support2 MSYS (motivated by SUCHMOKUO) `#D1264` 19a36ea (master: 47e2863)
  - edit: support `\$` in `PS1` for MSYS2 `#D1265` 8658738 (master: f6f8956)
  - msys2: work around MSYS2 Bash bug of missing <kbd>CR</kbd> `#D1270` b72c063 (master: 71f3498)
- decode: fix a bug of broken cmap cache found in ble-0.3 `#D1327` fc6ded3 (master: 16b56bf)
- util (strftime): fix a bug not working with `-v var` option in Bash <= 4.1 (test-util) cb2389c (master: f1a2818)
- complete: work around slow `compgen -c` in Cygwin `#D1329` d6d49cc (master: 5327f5d)
- edit: work around problems with `mc` (reported by onelittlehope) `#D1392` 15111cf (master: e97aa07)

## Internal

- global: check isolated identifiers and leak variables `#D1246` 03b3204 (master: 19cc99d) 2e74b6d
