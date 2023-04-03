# ble-0.4.0-devel3

## Usage

**Prerequisites**

Bash 3.0+ and basic POSIX utilities are required.

**Download ble-0.4.0-devel3.tar.xz**

https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel3/ble-0.4.0-devel3.tar.xz

```bash
# DOWNLOAD with wget
wget https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel3/ble-0.4.0-devel3.tar.xz

# DOWNLOAD with curl
curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.4.0-devel3/ble-0.4.0-devel3.tar.xz
```

**Trial & Install**

```bash
# TRIAL
tar xJf ble-0.4.0-devel3.tar.xz
source ble-0.4.0-devel3/ble.sh

# INSTALL (quick)
tar xJf ble-0.4.0-devel3.tar.xz -C ~/.local/share/blesh
echo 'source ~/.local/share/blesh' >> ~/.bashrc

# INSTALL (more robust)
tar xJf ble-0.4.0-devel3.tar.xz -C ~/.local/share/blesh
# Add the following line near the top of ~/.bashrc
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --attach=none
# Add the following line at the end of ~/.bashrc
[[ ${BLE_VERSION-} ]] && ble-attach
```

--------------------------------------------------------------------------------
# ble-0.3.4

## Usage

**Prerequisites**

Bash 3.0+ and basic POSIX utilities are required.

**Download ble-0.3.4.tar.xz**

https://github.com/akinomyoga/ble.sh/releases/download/v0.3.4/ble-0.3.4.tar.xz

```bash
# DOWNLOAD with wget
wget https://github.com/akinomyoga/ble.sh/releases/download/v0.3.4/ble-0.3.4.tar.xz

# DOWNLOAD with curl
curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.3.4/ble-0.3.4.tar.xz
```

**Trial & Install**

```bash
# TRIAL
tar xJf ble-0.3.4.tar.xz
source ble-0.3.4/ble.sh

# INSTALL
tar xJf ble-0.3.4.tar.xz -C ~/.local/share/blesh
# Add the following line near the top of ~/.bashrc
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --attach=none
# Add the following line at the end of ~/.bashrc
[[ ${BLE_VERSION-} ]] && ble-attach
```

## blesh-0.3 Fixes
- decode: fix `bind` emulation in .bashrc (v0.3) 742777e
- global: pick fixes and changes from ble-0.1..0.2 backports 78bbc5e
- bump 0.3.4 9da6774

## Fixes
- complete: fix a problem that candidates are not updated after menu-filter (reported by 3ximus) `#D1428` 1c7786e (master: 98fbc1c)
- edit: work around the wrong job information of Bash in trap handlers (reported by 3ximus) `#D1435` `#D1436` d40847f (master: bc4735e)
- edit (command-help): work around the Bash bug that tempenv vanishes with `builtin eval` `#D1438` cc8ca96 (master: 8379d4a)
- global: suppress missing locale errors (reported by 3ximus) `#D1440` b52a798 (master: 4d3c595)
- edit (sword): fix definition of `sword` (shell words) `#D1441` 2370bce (master: f923388)
- edit (`kill-forward-logical-line`): fix a bug not deleting newline at the end of the line `#D1443` 2a8a7f6 (master: 09cf7f1)
- global: work around bash-4.2 bug of `declare -gA` (reported by 0xC0ncord) `#D1470` 2f85ed3 (master: 8856a04)
- global: fix declaration of associative arrays for `ble-reload` (reported by 0xC0ncord) `#D1471` 422de69 (master: 3cae6e4)
- util (`ble/util/msleep`): fix hang in Cygwin by swithing from `/dev/udp/0.0.0.0/80` to `/dev/zero` `#D1452` 5ace564 (master: d4d718a)
- syntax: fix broken AST with `[[` keyword `#D1454` 1d48e79 (master: 69658ef)
- benchmark (`ble-measure`): work around a locale-dependent decimal point of `EPOCHREALTIME` (reported by 3ximus) `#D1460` f3833ad (master: 1aa471b)
- util (`ble/util/msleep`): work around the bash-4.3 bug of `read -t` (reported by 3ximus) `#D1468` `#D1469` 70797cf (master: 4ca9b2e)
- bind: work around broken `cmd_xmap` after switching the editing mode `#D1478` 909f461 (master: 8d354c1)
- edit: clear graphic rendition on newlines and external commands `#D1479` 59ede5c (master: 18bb2d5)
- decode (rlfunc): work around incomplete bytes in keyseq (reported by onelittlehope) `#D1483` 948a38d (master: 3559658) beb0383 37363be
- canvas: fix a glitch that SGR at the end of command line is applied to new lines `#D1498` 6871634 (master: 4bdfdbf)
- syntax: fix a bug that `eval() { :; }`, `declare() { :; }` are not treated as function definition `#D1529` 6c1d295 (master: b429095)
- decode: fix a hang on attach failure by cache corruption `#D1531` d4b0700 (master: 24ea379)
- progcomp: fix non-working `complete -C prog` (reported by Archehandoro) `#D1535` 47b3ade (master: 026432d)
- bind: fix a problem that `bind '"seq":"key"'` causes a loop macro `bind -s key key` (reported by thanosz) `#D1536` e2a502d (master: ea05fc5)
- main: work around `. ble.sh --{test,update,clear-cache}` in intereactive sessions `#D1555` 500915f (master: bbc2a90)
- main: fix reloading after ble-update (fixup 500915f (master: bbc2a90)) (fixed by oc1024) `#D1558` 9372670
- main: fix exit status for `bash ble.sh --test` (fixup 500915f (master: bbc2a90)) `#D1558` 641238a
- main: work around sourcing `ble.sh` inside subshells `#D1554` 500915f (master: bbc2a90)
- global: use a better workaround of bash-4.2 `declare -gA` by separating assignment `#D1567` 40827ef (master: 2408a20)
- util: work around bash-3.0 bug `"${scal[@]/xxx}"` `#D1570` 7e10cf4 (master: 24f79da)
- syntax: fix a bug that argument completion is attempted in nested commands (reported by huresche) `#D1579` 6987ae8 (master: 301d40f)
- edit (brackated-paste): fix incomplete `CR => LF` conversion (reported by alborotogarcia) `#D1587` 2651c8e (master: 8d6da16)
- main (adjust-bash-options): adjust `LC_COLLATE=C` `#D1588` 94cc9d2 (master: e87ac21)
- highlight (`layer:region`): fix blocked lower-layer changes without selection changes `#D1596` d40d42a (master: 5ede3c6)
- complete (`auto-menu`): fix sleep loops by clock/sclock difference `#D1597` 0abc15b (master: 53dd018)
- util: work around the Bash 3 bug of array assignments with `^A` and `^?` in Bash 3.2 `#D1614` 0eac4df (master: b9f7611)
- benchmark (`ble-measure`): fix a bug that the result is always 0 in Bash 3 and 4 (fixup bbc2a904) `#D1615` bc3cdab (master: a034c91)
- decode, canvas, etc.: explicitly treat CSI arguments as decimal numbers (reported by GorrillaRibs) `#D1625` 97bce68 (master: c6473b7) 2ea48d7
- edit: fix a bug that `command-help` doesn't work `#D1635` c375fbb (master: 0f6a083)
- complete: fix a task scheduling bug of referencing two different clocks (reported by rashil2000) `#D1636` df9f932 (master: fea5f5b)
- canvas: update prompt trace on `char_width_mode` change (reported by Barbarossa93) `#D1642` 00f9ce8 (master: 68ee111)
- decode: fix a bug that the characters input while initialization are delayed `#D1670` 734bd50 (master: 430f449)
- util (`ble/util/readfile`): fix a bug of always exiting with 1 in `bash <= 3.2` (reported by laoshaw) `#D1678` 51d244a (master: 61705bf)
- trace: fix wrong positioning of the ellipses on overflow `#D1684` dea87c7 (master: b90ac78)
- mandb: generate completions of options also for the empty word `#D1689` dea87c7 (master: b90ac78)
- complete: do not generate keywords for quoted command names `#D1691` 5b1e5be (master: 60d244f)
- menu (menu-style:align): fix the failure of delaying `ble/canvas/trace` on items (motivated by banoris) `#D1710` 3d56593 (master: acc9661)
- complete: fix empty completions with `FIGNORE` (reported by seanfarley) `#D1711` 49e75ee (master: 144ea5d)
- main: fix the message of owner errors of cache directories (reported by zim0369) `#D1712` 02aeb4a (master: b547a41)
- util (`ble/string#escape-for-bash-specialchars`): fix escaping of TAB `#D1713` accf8f3 (master: 7db3d2b)
- util (visible-bell): erase visible-bell before running external commands `#D1723` 72a11ae (master: 0da0c1c)
- util (`ble/function`): work around `shopt -u extglob` `#D1725` 3819e83 (master: 952c388)
- syntax: fix uninitialized syntax-highlighting in bash-3.2 `#D1731` 7bd03a5 (master: e3f5bf7)
- main: fix the workaround for `set -eu` and refactor `#D1743` a949af0 (master: 6a946f0)
- progcomp: retry completions on `$? == 124` also for non-default completions (reported by SuperSandro2000) `#D1759` e217932 (master: 82b9c01)
- util (`ble/util/import`): work around filenames with bash special characters `#D1763` 4179e3d (master: b27f758)
- edit: fix the restore failure of `PS1` and `PROMPT_COMMAND` on `ble-detach` `#D1784` 4f4c924 (master: b9fdaab)
- complete: do not attempt an independent rhs completion for arguments (reported by rsteube) `#D1787` 7bf32ca (master: f8bbe2c)
- history: work around possible dirty prefix `*` in the history output `#D1808` 84184ce (master: 64a740d)
- util(`ble/util/eval-pathname-expansion`): fix restoring shopt options in bash-4.0 `#D1825` d3b3f7b (master: 736f4da)
- decode: fix the workaround for `set -e` with `--prompt=attach` `#D1832` 51cb735 (master: 5111323)
- decode (`encoding:C`): fix initialization for isolated ESC `#D1839` aaa74b5 (master: c3bba5b)
- main. util: fix problems of readlink etc. found by test in macOS (reported by aiotter) `#D1849` a1adc7f (master: fa955c1) `#D1855` a22e145
- progcomp: fix a bug that `COMP_WORDBREAKS` is ignored `#D1872` b338066 (master: 4d2dd35)
- global: quote `return $?` `#D1884` 4f14f7a (master: 801d14a)
- main: fix adjustments of bash options (reported by rashil2000) `#D1895` 7bd25c9 (master: 138c476)
- decode: fix a bug that the tab completion do not work with bash-4.4 and lower `#D1928` 6351e7f (master: 7da9bce)
- bind: fix <kbd>M-C-@</kbd>, <kbd>C-x C-@</kbd>, and <kbd>M-C-x</kbd> (`bash-4.2 -o emacs`) `#D1920` 02f45f3 (master: a410b03)
- complete: fix non-working ambiguous path completion with `..` and `.` in the path `#D1930` fdb76e9 (master: 632e90a)
- main (ble-reload): fix failure by non-existent rcfile `#D1931` 58de996 (master: b7ae2fa)
- util: fix ble/util/clock in bash-4.2 [main: fix the timestamp in the session ID in bash-4.2] `#D1954` 9a24b1e (master: 651c70c1)
- edit (`ble/textarea#render`): fix interleaving outputs to `_ble_util_buffer` and `DRAW_BUFF` `#D1987` 62519a7 (master: 6d61388)
- keymap/vi (`operator:filter`): do not append newline at the end of line `#D1994` 8207d4f (master: bce2033)
- keymap/vi (`expand-range-for-linewise-operator`): fix the end point being not extended `#D1994` 8207d4f (master: bce2033)
- syntax: fix unrecognized asignment `echo arr[i]+=rhs` [sabbrev: apply sabbrev to right-hand sides of variable assignments] `#D2007` 948f50f (master: 41faa494)

## Changes
- syntax: exclude <code>\\ + LF</code> at the word beginning from words (motivated by cmplstofB) `#D1431` 1b00fd2 (master: 67e62d6)
- edit: preserve the state of `READLINE_{LINE,POINT,MARK}` `#D1437` cc8ca96 (master: 8379d4a)
- edit: change default behavior of <kbd>C-w</kbd> and <kbd>M-w</kbd> to operate on backward words `#D1448` b1fd84a (master: 47a3301)
- edit (`ble/builtin/read`): cancel by <kbd>C-d</kbd> on an empty line `#D1473` 4fae77a (master: ecb8888)
- syntax: change syntax context after `time ;` and `! ;` for Bash 4.4 `#D1477` e55e3df (master: 4628370)
- decode (rlfunc): update mapping `vi-replace` in `imap` and `vi-editing-mode` in `nmap` (reported by onelittlehope) `#D1484` 3a2d0fe (master: f2ca811)
- prompt: invalidate prompt and textarea on prompt setting changes `#D1492` e28f330 (master: 1f55913)
- main: accept non-regular files as `blerc` and add option `--norc` `#D1530` 4b0eb87 (master: 7244e2f)
- prompt: adjust behavior of `LINENO` and prompt sequence `\#` (reported by tycho-kirchner) `#D1542` f3668ba (master: 8b0257e)
- main: show notifications against debug versions of Bash `#D1612` 0ee8415 (master: 8f974aa)
- edit: suppress only `stderr` with `internal_suppress_bash_output` (motivated by rashil2000) `#D1646` b0a9021 (master: a30887f)
- prompt: do not evaluate `PROMPT_COMMAND` for subprompts `#D1654` 9c0e515 (master: 08e903e)
- main: suppress non-interactive warnings from manually sourced startup files (reported by andreclerigo) `#D1676` a602876 (master: 0525528) 88e2df5
- main: suppress non-interactive warnings from manually sourced startup files (reported by andreclerigo) `#D1676` 0525528 79efd42 (master: 88e2df5)
- syntax: revert 99f2234 (master: 371a5a4) and generate empty completion source on syntax error `#D1609` e09fcab
- syntax: do not start argument completions immediately after previous word (reported by EmilySeville7cfg) `#D1690` 99f2234 (master: 371a5a4)
- syntax: revert 371a5a4 and generate empty completion source on syntax error `#D1609` a1d1286 (master: e09fcab)
- canvas: do not insert explicit newlines on line folding if possible (reported by banoris) `#D1745` d878fce (master: 02b9da6) dc3827b
- edit (`ble-bind -x`): preserve multiline prompts on execution of `bind -x` commands (requested by SuperSandro2000) `#D1755` 240bfaa (master: 7d05a28)
- util (`ble/util/buffer`): hide cursor in rendering `#D1758` 5907567 (master: e332dc5)
- complete (`action:file`): always suffix `/` to complete symlinked directory names (reported by SuperSandro2000) `#D1759` ebdc58b (master: 397ac1f)
- edit: fix layout with `prompt_rps1` caused by missing `opts=relative` for `ble/textmap#update` `#D1769` e799191 (master: f6af802)
- edit (`ble-detach`): prepend a space to `stty sane` for `HISTIGNORE=' *'` `#D1796` 31bc2b7 (master: 26b532e)
- edit: the widgets `{kill,copy,delete}-region-or` now receives widgets as arguments `#D1021` e222c48 (master: bbbd155)
- decode (`bind`): do not treat non-beginning `#` as comments `#D1820` f9db7d8 (master: 65c4138)
- history: disable the history file when `HISTFILE` is empty `#D1836` 7153250 (master: 9549e83)
- main (`ble-reload`): preserve the original initialization options `#D1852` 8912d81 (master: d8c92cc)
- progcomp: reproduce arguments of completion functions passed by Bash `#D1872` b338066 (master: 4d2dd35)
- color: let `bleopt term_index_colors` override the default if specified `#D1878` e7c657c (master: 7d238c0)
- decode (`vi_imap-rlfunc.txt`): update the widget for `backward-kill-word` as `kill-backward-{u => c}word` `#D1896` 3c4e3a4 (master: e19b796)
- term (`_ble_term_TERM`): detect wezterm-20220408 `#D1909` f3a8382 (master: 486564a)
- keymap/vi (`decompose-meta`): translate <kbd>S-a</kbd> to <kbd>A</kbd> `#D1988` 9e0c187 (master: 600e845)
- term (`_ble_term_TERM`): detect konsole `#D1988` 9e0c187 (master: 600e845) ed53858

## Compatibility
- term: work around leaked <kbd>DA2R</kbd> in screen from outside terminal `#D1485` 4d77fab (master: e130619)
- util (`modifyOtherKeys`): work around a quirk of kitty (reported by NoahGorny) `#D1549` 823eb83 (master: f599525)
- global: work around empty `vi_imap` cache by `tmux-resurrect` `#D1562` d7d2a23 (master: 560160b)
- decode: identify `kitty` and treat `\e[27u` as isolated ESC (reported by lyiriyah) `#D1585` 2f7404e (master: c2a84a2)
- complete: suppress known error messages of `bash-completion` (reported by oc1024, Lun4m) `#D1622` 558322c (master: d117973)
- util (`modifyOtherKeys`): update the workaround for a new quiark of kitty `#D1627` 90d9284 (master: 3e4ecf5)
- main: work around `set -B` and `set -k` `#D1628` 55494eb (master: a860769)
- term: disable `modifyOtherKeys` and do not send `DA2` for `st` (requested by Shahabaz-Bagwan) `#D1632` 7e08766 (master: 92c7b26)
- cmap: add `st`-specific escape sequences for cursor keys `#D1633` 1391c90 (master: acfb879)
- cmap: distinguish <kbd>find</kbd>/<kbd>select</kbd> from <kbd>home</kbd>/<kbd>end</kbd> for openSUSE `inputrc.keys` (reported by cornfeedhobo) `#D1648` 886cc07 (master: c4d28f4)
- cmap: freeze the internal codes of <kbd>find</kbd>/<kbd>select</kbd> and kitty special keys `#D1674` 7d02058 (master: fdfe62a)
- decode: work around the overwritten builtin `set` (reported by eadmaster) `#D1680` 5acb117 (master: a6b4e2c)
- util (`modifyOtherKeys`): use the kitty protocol for kitty 0.23+ which removes the support of `modifyOtherKeys` (reported by kovidgoyal) `#D1681` 696264b (master: ec91574)
- complete: work around the variable leaks by `virsh` completion from `libvirt` (reported by telometto) `#D1682` 7a65fc3 (master: f985b9a)
- stty: do not remove keydefs for <kbd>C-u</kbd>, <kbd>C-v</kbd>, <kbd>C-w</kbd>, and <kbd>C-?</kbd> (reported by laoshaw) `#D1683` ff8fb83 (master: 82f74f0)
- decode (`ble/builtin/bind`): improve compatibility of the deprecated form `bind key:rlfunc` (motivated by cmplstofB) `#D1698` c3904ff (master: b6fc4f0)
- main: work around `XDG_RUNTIME_DIR` of a different user by `su` (reported by zim0369) `#D1712` dbf58e4 (master: 8d37048)
- main (`ble/util/readlink`): work around non-standard or missing `readlink` (motivated by peterzky) `#D1720` 60595bd (master: a41279e)
- decode (`ble/builtin/bind`): fix a bug that only lowercase is accepted for deprecated form `bind key:rlfunc` (reported by returntrip) `#D1726` 43cf9b9 (master: a67458e) e363f1b
- decode (`ble/builtin/bind`): fix a bug that only lowercase is accepted for deprecated form `bind key:rlfunc` (reported by returntrip) `#D1726` a67458e dd358d7 (master: e363f1b)
- global: work around the arithmetic syntax error of `10#` in Bash-5.1 `#D1734` b321b57 (master: 7545ea3)
- global: adjust implementations for Bash 5.2 `patsub_replacement` `#D1738` 66ae615 (master: 4590997)
- main: check `/dev/tty` on startup (reported by andychu) `#D1749` e6c2855 (master: 711c69f)
- global: work around `shopt -s compat42` `#D1754` 1f254b5 (master: a75bb25)
- global: identify bash-4.2 bug that internal quoting of `${v/%$empty/"$rep"}` remains `#D1753` 1f254b5 (master: a75bb25)
- prompt: fix a bug of `ble/prompt/print` redundantly quoting `$` `#D1752` 1f254b5 (master: a75bb25)
- global: work around `compat42` quoting of `"${v/pat/"$rep"}"` `#D1751` 1f254b5 (master: a75bb25)
- util: add identification of Windows Terminal `wt` `#D1758` 5907567 (master: e332dc5)
- global: work around bash-3.0 bug that single quotes remains for `"${v-$''}"` `#D1774` 30440b2 (master: 9b96578)
- util (`modifyOtherKeys`): fix a bug that kitty protocol is never activated `#D1842` f8aeb51 (master: 14f3c81)
- util (`modifyOtherKeys`): work around delayed terminal identification `#D1842` f8aeb51 (master: 14f3c81)
- main: resolve empty `HOSTNAME` [originally: contrib: add `histdb`] `#D1925` e82230e (master: 44d9e104)
- main: warn empty `LANG` [originally: main: support an option `--inputrc={diff,all,user,none}`] `#D1926` ede4ee7 (master: 92f2006)
- term (`terminology`): work around terminal glitches `#D1946` ccb93a5 (master: 9a1b4f9)
- edit: always adjust the terminal states with `bind -x` (reported by linwaytin) `#D1983` 992131c (master: 5d14cf1)
- syntax: suppress brace expansions in designated array initialization in Bash 5.3 `#D1989` 1f0d8e1 (master: 1e7b884)
- util (function#evaldef): work around `set -e` [progcomp: work around slow `nix` completion] `#D1997` 2ab4e4b (master: 2c1aacfc)
- util (`string#quote-word`): work around `set -ue` [util, edit: add `ble/util/message` and `ble append-line`] `#D2001` 2317562 (master: 2a524f34)
- complete: suppress error messages from `_adb` `#D2005` 2f77171 (master: f2aa32b)
- edit: restore `PS1` while processing `bind -x` `#D2024` 604c092 (master: 2eadcd5)

## Optimization
- complete (`ble/complete/source:file`): remove slow old codes (reported by timjrd) `#D1512` 60a33e2 (master: e5be0c1)
- util (`ble/util/assign`): work around subshell conflicts `#D1578` 4117d1b (master: 6e4bb12)
- prompt: fix not properly set `$?` in `${PS1@P}` evaluation (reported by nihilismus) `#D1644` a3cfd0d (master: 521aff9)
- util (`ble/string#split`): optimize `#D1826` 9dcbbd4 (master: 7bb10a7)
- debug: add `ble/debug/profiler` (motivated by SuperSandro2000) `#D1824` f629698 11aa4ab 9dcbbd4 (master: 7bb10a7)
- global: avoid passing arbitrary strings through `awk -v var=value` `#D1827` 9edb1aa (master: 82232de)

## Internal changes and fixes
- main: include hostname in local runtime directory `#D1444` 3e648a9 (master: 6494836)
- benchmark (`ble-measure`): support `-T TIME` and `-B TIME` option `#D1460` f3833ad (master: 1aa471b)
- global: fix status check for read timeout `#D1467` f190f9a (master: e886883)
- util, etc: ensure each function to work with arbitrary `IFS` `#D1490` `#D1491` c33fad0 (master: 5f9adfe)
- global: work around `localvar_inherit` for varname-list init `#D1566` 8c67b79 (master: 5c2edfc)
- util: fix `ble/util/dense-array#fill-range` e397120 (master: a46fdaf)
- util: fix leak variables `buff`, `trap`, `{x,y}{1,2}` `#D1572` 82113e9 (master: 5967d6c)
- util: fix leak variables `#D1643` 0817df6 (master: fcf634b)
- edit (`command-help`): use `ble/util/assign/.mktmp` to determine the temporary filename `#D1663` 2ff6078 (master: 1af0800)
- Makefile: add fallback Makefile for BSD make `#D1805` ea8b966 (master: e5d8d00)
- util, decode, vi: fix leak variables `#D1933` 9e2e823 (master: 8d5cab8)
- syntax: fix code formatting [originally: complete: support auto-complete sources] `#D1938` 450f70b (master: 00cae745)
- main: use builtin for ":" [histdb: support timeout of background processes] `#D1971` 482ddb5 (master: e0566bdc)
- global: normalize to `_a-zA-Z` [sabbrev: apply sabbrev to right-hand sides of variable assignments] `#D2006` a101fe6 (master: 41faa494)
- util (restore-vars): work around `set -u` [lib: add `util.bgproc` for `ble/util/bgproc`] `#D2017` 8787ca5 (master: 7803305f)
- util: update `ble/util/conditional-sync` [util.bgproc: increase frequency of bgproc termination check] `#D2027` 79fd13c (master: 8d623c1)

## Test
- util (ble/util/s2bytes): clear locale cache `#D1881` 45f3df3 (master: 2e1a7c1)
- util (ble/util/s2c): work around intermediate mbstate of bash <= 5.2 `#D1881` 45f3df3 (master: 2e1a7c1)
- util (ble/encoding:UTF-8/b2c): fix interpretation of leading byte `#D1881` 45f3df3 (master: 2e1a7c1)
- complete: fix syntax error for bash-3.0 `#D1881` b534799 (master: 0b3e611)

## Documentation
- blerc: rename from `blerc` to `blerc.template` `#D1899` 3c4e3a4 (master: e19b796)
- wiki/Q&A: add item for defining a widget calling multiple widgets (motivated by micimize) `#D1898` 3c4e3a4 (master: e19b796)
- blerc: add frequently used keybindings (motivated by KiaraGrouwstra, micimize) `#D1896` `#D1897` 3c4e3a4 (master: e19b796)

## Contrib
- fzf-key-bindings: fix a problem that `modifyOtherKeys` is not reflected (reported by SuperSandro2000) `#D1908` f3a8382 (master: 486564a)

## New features
- canvas: update emoji database and support `bleopt emoji_version` (motivated by endorfina) `#D1454` 3f6c9b9 (master: d1f8c27)
- syntax: support tilde expansions in parameter expansions `#D1513` e32914f (master: 0506df2)
- prompt (`contrib/prompt-git`): support dirty checking `#D1601` 50a0094 (master: b2713d9)
- util (`bleopt`, `bind`): fix error message and exit status, respectively `#D1640` 29728b1 (master: b663cee)
- edit: support bash-5.2 binding of `prior/next` to `history-search-{for,back}ward` `#D1661` a3a353e (master: d26a6e1)
- util: suppress false warnings of `bind` inside non-interactive shells (reported by wukuan405) `#D1823` 82c9934 (master: 1e19a67)
- auto-complete: cancel auto-complete for `magic-space` `#D1913` 05c0888 (master: 01b4f67)
- complete: support ambiguous completion for command paths `#D1922` 6d1e1ba (master: 8a716ad)
- syntax: support context after `((...))` and `[[ ... ]]` in bash-5.2 `#D1962` 57d7674 (master: 67cb967)

--------------------------------------------------------------------------------
# ble-0.2.7

## Usage

**Prerequisites**

Bash 3.0+ and basic POSIX utilities are required.

**Download ble-0.2.7.tar.xz**

https://github.com/akinomyoga/ble.sh/releases/download/v0.2.7/ble-0.2.7.tar.xz

```bash
# DOWNLOAD with wget
wget https://github.com/akinomyoga/ble.sh/releases/download/v0.2.7/ble-0.2.7.tar.xz

# DOWNLOAD with curl
curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.2.7/ble-0.2.7.tar.xz
```

**Trial & Install**

```bash
# TRIAL
tar xJf ble-0.2.7.tar.xz
source ble-0.2.7/ble.sh

# INSTALL
tar xJf ble-0.2.7.tar.xz -C ~/.local/share/blesh
# Add the following line near the top of ~/.bashrc
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --noattach
# Add the following line at the end of ~/.bashrc
((_ble_bash)) && ble-attach
```

## blesh-0.2 fixes
- global: fix `ble/{is- => util/is}function` 5e82ca7a
- global: pick fixes and changes from ble-0.1 backports 013eb1cd
- complete: fix up 4df15e1e f02bd2a5
- bump 0.2.7 1118c803

## Fixes
- edit: work around the wrong job information of Bash in trap handlers (reported by 3ximus) `#D1435` `#D1436` 795a647c (master: bc4735e0)
- edit (sword): fix definition of `sword` (shell words) `#D1441` 5e73cf6b (master: f9233889)
- edit (`kill-forward-logical-line`): fix a bug not deleting newline at the end of the line `#D1443` 03787a2d (master: 09cf7f14)
- global: work around bash-4.2 bug of `declare -gA` (reported by 0xC0ncord) `#D1470` a2ace444 (master: 8856a04f)
- global: fix declaration of associative arrays for `ble-reload` (reported by 0xC0ncord) `#D1471` 533eba77 (master: 3cae6e4d)
- util (`ble/util/msleep`): fix hang in Cygwin by swithing from `/dev/udp/0.0.0.0/80` to `/dev/zero` `#D1452` 46992e79 (master: d4d718ab)
- syntax: fix broken AST with `[[` keyword `#D1454` 0482bf64 (master: 69658efc)
- util (`ble/util/msleep`): work around the bash-4.3 bug of `read -t` (reported by 3ximus) `#D1468` `#D1469` fad78ea5 (master: 4ca9b2e2)
- bind: work around broken `cmd_xmap` after switching the editing mode `#D1478` 97ca1171 (master: 8d354c1b)
- edit: clear graphic rendition on newlines and external commands `#D1479` 759b96dd (master: 18bb2d5c)
- canvas: fix a glitch that SGR at the end of command line is applied to new lines `#D1498` a6ac1216 (master: 4bdfdbf8)
- syntax: fix a bug that `eval() { :; }`, `declare() { :; }` are not treated as function definition `#D1529` a4cda9c3 (master: b4290958)
- decode: fix a hang on attach failure by cache corruption `#D1531` a4c13ab8 (master: 24ea3792)
- benchmark (`ble-measure`): fix a bug that the result is always 0 in Bash 3 and 4 (fixup 8eb493a9 (master: bbc2a904)) `#D1615` a034c91
- main: work around `. ble.sh --{test,update,clear-cache}` in intereactive sessions `#D1555` 8eb493a9 (master: bbc2a904)
- main: fix reloading after ble-update (fixup 8eb493a9 (master: bbc2a904)) (fixed by oc1024) `#D1558` 9372670
- main: fix exit status for `bash ble.sh --test` (fixup 8eb493a9 (master: bbc2a904)) `#D1558` 641238a
- main: work around sourcing `ble.sh` inside subshells `#D1554` 8eb493a9 (master: bbc2a904)
- global: use a better workaround of bash-4.2 `declare -gA` by separating assignment `#D1567` 0b7de999 (master: 2408a207)
- edit (brackated-paste): fix incomplete `CR => LF` conversion (reported by alborotogarcia) `#D1587` ac738bb4 (master: 8d6da161)
- highlight (`layer:region`): fix blocked lower-layer changes without selection changes `#D1596` 650140ff (master: 5ede3c69)
- util: work around the Bash 3 bug of array assignments with `^A` and `^?` in Bash 3.2 `#D1614` 0ed7f6dc (master: b9f76118)
- benchmark (`ble-measure`): fix a bug that the result is always 0 in Bash 3 and 4 (fixup bbc2a904) `#D1615` 28e8dfed (master: a034c91a)
- decode, canvas, etc.: explicitly treat CSI arguments as decimal numbers (reported by GorrillaRibs) `#D1625` c9e4198b (master: c6473b78) 2ea48d7
- edit: fix a bug that `command-help` doesn't work `#D1635` b992bb5d (master: 0f6a0834)
- canvas: update prompt trace on `char_width_mode` change (reported by Barbarossa93) `#D1642` 56b77a83 (master: 68ee1112)
- util (`ble/util/readfile`): fix a bug of always exiting with 1 in `bash <= 3.2` (reported by laoshaw) `#D1678` 5b843bb6 (master: 61705bf6)
- complete: do not generate keywords for quoted command names `#D1691` 7211b1ec (master: 60d244fe)
- complete: fix empty completions with `FIGNORE` (reported by seanfarley) `#D1711` 90f388aa (master: 144ea5db)
- main: fix the message of owner errors of cache directories (reported by zim0369) `#D1712` d2bf86c1 (master: b547a41a)
- syntax: fix uninitialized syntax-highlighting in bash-3.2 `#D1731` 6aa12c82 (master: e3f5bf74)
- progcomp: retry completions on `$? == 124` also for non-default completions (reported by SuperSandro2000) `#D1759` c641fb1b (master: 82b9c011)
- util (`ble/util/import`): work around filenames with bash special characters `#D1763` 7da5f048 (master: b27f7585)
- edit: fix the restore failure of `PS1` and `PROMPT_COMMAND` on `ble-detach` `#D1784` 47dfdd94 (master: b9fdaabd)
- history: work around possible dirty prefix `*` in the history output `#D1808` cc14f59c (master: 64a740d7)
- decode: fix the workaround for `set -e` with `--prompt=attach` `#D1832` 958aae6b (master: 51113237)
- main. util: fix problems of readlink etc. found by test in macOS (reported by aiotter) `#D1849` 8f0acf3d (master: fa955c1a) `#D1855` a22e145
- global: quote `return $?` `#D1884` 9e10b54b (master: 801d14af)
- bind: fix <kbd>M-C-@</kbd>, <kbd>C-x C-@</kbd>, and <kbd>M-C-x</kbd> (`bash-4.2 -o emacs`) `#D1920` 342826f3 (master: a410b038)
- keymap/vi (`operator:filter`): do not append newline at the end of line `#D1994` 2a8e746f (master: bce20339)
- keymap/vi (`expand-range-for-linewise-operator`): fix the end point being not extended `#D1994` 2a8e746f (master: bce20339)
- syntax: fix unrecognized asignment `echo arr[i]+=rhs` [sabbrev: apply sabbrev to right-hand sides of variable assignments] `#D2006` 4ed4fd4f (master: 41faa494)
- syntax: fix unrecognized variable assignment of the form `echo arr[i]+=rhs` `#D2007` 4ed4fd4f (master: 41faa494)

## Changes
- syntax: exclude <code>\\ + LF</code> at the word beginning from words (motivated by cmplstofB) `#D1431` 6044a485 (master: 67e62d64)
- edit: change default behavior of <kbd>C-w</kbd> and <kbd>M-w</kbd> to operate on backward words `#D1448` 787ff57f (master: 47a3301a)
- edit: the widgets `{kill,copy,delete}-region-or` now receives widgets as arguments `#D1021` 8f48aff1 (master: bbbd155f)
- edit (`ble/builtin/read`): cancel by <kbd>C-d</kbd> on an empty line `#D1473` 551bde3a (master: ecb8888d)
- syntax: change syntax context after `time ;` and `! ;` for Bash 4.4 `#D1477` 0b66cf4a (master: 46283706)
- prompt: invalidate prompt and textarea on prompt setting changes `#D1492` 54d310df (master: 1f559135)
- prompt: adjust behavior of `LINENO` and prompt sequence `\#` (reported by tycho-kirchner) `#D1542` 4b63b164 (master: 8b0257e2)
- main: show notifications against debug versions of Bash `#D1612` 608ac2ad (master: 8f974aa1)
- prompt: do not evaluate `PROMPT_COMMAND` for subprompts `#D1654` 5c0cfdef (master: 08e903e0)
- main: suppress non-interactive warnings from manually sourced startup files (reported by andreclerigo) `#D1676` 2587bb01 (master: 05255282) 88e2df5
- main: suppress non-interactive warnings from manually sourced startup files (reported by andreclerigo) `#D1676` 0525528 5f638563 (master: 88e2df51)
- util (`ble/util/buffer`): hide cursor in rendering `#D1758` 4ecbbdc2 (master: e332dc5f)
- edit (`ble-detach`): prepend a space to `stty sane` for `HISTIGNORE=' *'` `#D1796` bd903716 (master: 26b532e7)
- history: disable the history file when `HISTFILE` is empty `#D1836` d97ca100 (master: 9549e831)
- keymap/vi (`decompose-meta`): translate <kbd>S-a</kbd> to <kbd>A</kbd> `#D1988` eaf66c7c (master: 600e845e)
- term (`_ble_term_TERM`): detect konsole `#D1988` eaf66c7c (master: 600e845e) ed53858
- complete (`source:argument`): fallback to rhs completion also for `name+=rhs` `#D2006` 4ed4fd4f (master: 41faa494)

## Compatibility
- highlight: fix a problem that the attribute of the last character is applied till EOL `#D1393` 36f9d809 (master: 2ddb1ba2) `#D1395` ef09932
- highlight: fix a problem that the attribute of the last character is applied till EOL `#D1393` 2ddb1ba `#D1395` 6bcb4053 (master: ef099326)
- global: work around empty `vi_imap` cache by `tmux-resurrect` `#D1562` d7130d55 (master: 560160b0)
- main: work around `set -B` and `set -k` `#D1628` 3c97ae84 (master: a8607692)
- cmap: add `st`-specific escape sequences for cursor keys `#D1633` bf46e344 (master: acfb8790)
- cmap: distinguish <kbd>find</kbd>/<kbd>select</kbd> from <kbd>home</kbd>/<kbd>end</kbd> for openSUSE `inputrc.keys` (reported by cornfeedhobo) `#D1648` ad675556 (master: c4d28f40)
- cmap: freeze the internal codes of <kbd>find</kbd>/<kbd>select</kbd> and kitty special keys `#D1674` f41b8004 (master: fdfe62a4)
- decode: work around the overwritten builtin `set` (reported by eadmaster) `#D1680` 93ae08d0 (master: a6b4e2ca)
- complete: work around the variable leaks by `virsh` completion from `libvirt` (reported by telometto) `#D1682` ee2ac075 (master: f985b9a4)
- stty: do not remove keydefs for <kbd>C-u</kbd>, <kbd>C-v</kbd>, <kbd>C-w</kbd>, and <kbd>C-?</kbd> (reported by laoshaw) `#D1683` c01487bf (master: 82f74f0a)
- main: work around `XDG_RUNTIME_DIR` of a different user by `su` (reported by zim0369) `#D1712` e5501a31 (master: 8d370486)
- main (`ble/util/readlink`): work around non-standard or missing `readlink` (motivated by peterzky) `#D1720` d785f5db (master: a41279ed)
- global: work around the arithmetic syntax error of `10#` in Bash-5.1 `#D1734` 2b55aa16 (master: 7545ea31)
- global: adjust implementations for Bash 5.2 `patsub_replacement` `#D1738` 359a3891 (master: 4590997a)
- main: check `/dev/tty` on startup (reported by andychu) `#D1749` 19fa0924 (master: 711c69f1)
- global: work around `shopt -s compat42` `#D1754` e7adfb34 (master: a75bb25a)
- global: identify bash-4.2 bug that internal quoting of `${v/%$empty/"$rep"}` remains `#D1753` e7adfb34 (master: a75bb25a)
- prompt: fix a bug of `ble/prompt/print` redundantly quoting `$` `#D1752` e7adfb34 (master: a75bb25a)
- global: work around `compat42` quoting of `"${v/pat/"$rep"}"` `#D1751` e7adfb34 (master: a75bb25a)
- util: add identification of Windows Terminal `wt` `#D1758` 4ecbbdc2 (master: e332dc5f)
- global: work around bash-3.0 bug that single quotes remains for `"${v-$''}"` `#D1774` fb607ad6 (master: 9b96578c)
- main: resolve empty `HOSTNAME` [add `histdb`] `#D1925` 5812f2ef (master: 44d9e104)
- main: warn empty `LANG` [main: support an option `--inputrc={diff,all,user,none}`] `#D1926` 3f29bee3 (master: 92f20063)
- main: never load `/etc/inputrc` in openSUSE (motivated by Ultra980) `#D1926` 3f29bee3 (master: 92f20063) 0ceb0cb
- main: show warning for empty locale (movivated by Ultra980) `#D1927` 3f29bee3 (master: 92f20063)
- term (`terminology`): work around terminal glitches `#D1946` 2d4caa67 (master: 9a1b4f9f)
- edit: always adjust the terminal states with `bind -x` (reported by linwaytin) `#D1983` cdda7c44 (master: 5d14cf17)
- syntax: suppress brace expansions in designated array initialization in Bash 5.3 `#D1989` 78dd47ee (master: 1e7b884d)
- edit: restore `PS1` while processing `bind -x` (reported by adoyle-h) `#D2024` c46f4230 (master: 2eadcd5b)

## Optimization
- util (`ble/util/assign`): work around subshell conflicts `#D1578` 59d6355c (master: 6e4bb126)
- prompt: fix not properly set `$?` in `${PS1@P}` evaluation (reported by nihilismus) `#D1644` 66fd10b7 (master: 521aff9b)
- util (`ble/string#split`): optimize `#D1826` 5b3fc89c (master: 7bb10a79)
- debug: add `ble/debug/profiler` (motivated by SuperSandro2000) `#D1824` f629698 11aa4ab 5b3fc89c (master: 7bb10a79)
- global: avoid passing arbitrary strings through `awk -v var=value` `#D1827` 4571695a (master: 82232de5)

## Internal changes and fixes
- main: include hostname in local runtime directory `#D1444` d19ab298 (master: 64948361)
- global: fix status check for read timeout `#D1467` 0bcc12c9 (master: e886883b)
- util, etc: ensure each function to work with arbitrary `IFS` `#D1490` `#D1491` 2fe60b64 (master: 5f9adfe8)
- util: fix `ble/util/dense-array#fill-range` b708ee29 (master: a46fdaf4)
- util: fix leak variables `buff`, `trap`, `{x,y}{1,2}` `#D1572` 36d151e2 (master: 5967d6ce)
- make: add fallback Makefile for BSD make `#D1805` 6498a5d3 (master: e5d8d00c)
- util, decode, vi: fix leak variables `#D1933` 002dda7f (master: 8d5cab85)
- syntax: fix code formatting [histdb: support auto-complete source `histdb-word`] `#D1938` edd48d1c (master: 00cae745)
- main: use builtin for `:` [histdb: support timeout of background processes] `#D1971` 8640dc41 (master: e0566bdc)
- global: normalize bracket expressions to `_a-zA-Z` / `_a-zA-Z0-9` `#D2006` 4ed4fd4f (master: 41faa494)
- util (restore-vars): work around `set -u` [util.bgproc: separate `ble/util/bgproc` from `histdb`] `#D2017` d60758ae (master: 7803305f)

## Test
- util (ble/util/s2bytes): clear locale cache `#D1881` 99e217d3 (master: 2e1a7c17)
- util (ble/util/s2c): work around intermediate mbstate of bash <= 5.2 `#D1881` 99e217d3 (master: 2e1a7c17)
- util (ble/encoding:UTF-8/b2c): fix interpretation of leading byte `#D1881` 99e217d3 (master: 2e1a7c17)

## New features
- syntax: support context after `((...))` and `[[ ... ]]` in bash-5.2 `#D1962` 74af9e60 (master: 67cb967a)

--------------------------------------------------------------------------------
# ble-0.1.15

## Usage

**Prerequisites**

Bash 3.0+ and basic POSIX utilities are required.

**Download ble-0.1.15.tar.xz**

https://github.com/akinomyoga/ble.sh/releases/download/v0.1.15/ble-0.1.15.tar.xz

```bash
# DOWNLOAD with wget
wget https://github.com/akinomyoga/ble.sh/releases/download/v0.1.15/ble-0.1.15.tar.xz

# DOWNLOAD with curl
curl -LO https://github.com/akinomyoga/ble.sh/releases/download/v0.1.15/ble-0.1.15.tar.xz
```

**Trial & Install**

```bash
# TRIAL
tar xJf ble-0.1.15.tar.xz
source ble-0.1.15/ble.sh

# INSTALL
tar xJf ble-0.1.15.tar.xz -C ~/.local/share/blesh
# Add the following line near the top of ~/.bashrc
[[ $- == *i* ]] && source ~/.local/share/blesh/ble.sh --noattach
# Add the following line at the end of ~/.bashrc
((_ble_bash)) && ble-attach
```

## blesh-0.1 fixes
- edit,highlight: backport changes in rebased commits dfac242
- bump 0.1.15 3f4d866

## Fixes
- edit (sword): fix definition of `sword` (shell words) `#D1441` 03980f1 (master: f923388)
- bind: work around broken `cmd_xmap` after switching the editing mode `#D1478` 847e602 (master: 8d354c1)
- benchmark (`ble-measure`): fix a bug that the result is always 0 in Bash 3 and 4 (fixup 4759768 (master: bbc2a90)) `#D1615` a034c91
- main: work around `. ble.sh --{test,update,clear-cache}` in intereactive sessions `#D1555` 4759768 (master: bbc2a90)
- main: fix reloading after ble-update (fixup 4759768 (master: bbc2a90)) (fixed by oc1024) `#D1558` 9372670
- main: fix exit status for `bash ble.sh --test` (fixup 4759768 (master: bbc2a90)) `#D1558` 641238a
- main: work around sourcing `ble.sh` inside subshells `#D1554` 4759768 (master: bbc2a90)
- util: work around the Bash 3 bug of array assignments with `^A` and `^?` in Bash 3.2 `#D1614` 9648bd4 (master: b9f7611)
- decode, canvas, etc.: explicitly treat CSI arguments as decimal numbers (reported by GorrillaRibs) `#D1625` 40a0ec9 (master: c6473b7) 2ea48d7
- edit: fix a bug that `command-help` doesn't work `#D1635` c99e2f1 (master: 0f6a083)
- canvas: update prompt trace on `char_width_mode` change (reported by Barbarossa93) `#D1642` 5b22cd6 (master: 68ee111)
- complete: do not generate keywords for quoted command names `#D1691` cd75f39 (master: 60d244f)
- progcomp: retry completions on `$? == 124` also for non-default completions (reported by SuperSandro2000) `#D1759` a66b547 (master: 82b9c01)
- edit: fix the restore failure of `PS1` and `PROMPT_COMMAND` on `ble-detach` `#D1784` a0f6594 (master: b9fdaab)
- history: work around possible dirty prefix `*` in the history output `#D1808` 0ed2ffb (master: 64a740d)
- main. util: fix problems of readlink etc. found by test in macOS (reported by aiotter) `#D1849` 1dc5938 (master: fa955c1) `#D1855` a22e145
- global: quote `return $?` `#D1884` c2ba90b (master: 801d14a)
- bind: fix <kbd>M-C-@</kbd>, <kbd>C-x C-@</kbd>, and <kbd>M-C-x</kbd> (`bash-4.2 -o emacs`) `#D1920` de577dc (master: a410b03)

## Changes
- syntax: exclude <code>\\ + LF</code> at the word beginning from words (motivated by cmplstofB) `#D1431` 69156f1 (master: 67e62d6)
- edit: change default behavior of <kbd>C-w</kbd> and <kbd>M-w</kbd> to operate on backward words `#D1448` 0a07c13 (master: 47a3301)
- edit: the widgets `{kill,copy,delete}-region-or` now receives widgets as arguments `#D1021` ec16708 (master: bbbd155)
- main: show notifications against debug versions of Bash `#D1612` 8f989e4 (master: 8f974aa)
- main: suppress non-interactive warnings from manually sourced startup files (reported by andreclerigo) `#D1676` 2a045d8 (master: 0525528) 88e2df5
- main: suppress non-interactive warnings from manually sourced startup files (reported by andreclerigo) `#D1676` 0525528 4ef844e (master: 88e2df5)
- util (`ble/util/buffer`): hide cursor in rendering `#D1758` 444abff (master: e332dc5)
- edit (`ble-detach`): prepend a space to `stty sane` for `HISTIGNORE=' *'` `#D1796` acb7c08 (master: 26b532e)
- history: disable the history file when `HISTFILE` is empty `#D1836` a79095a (master: 9549e83)

## Compatibility
- global: work around empty `vi_imap` cache by `tmux-resurrect` `#D1562` b0cc0a3 (master: 560160b)
- cmap: add `st`-specific escape sequences for cursor keys `#D1633` ae298f1 (master: acfb879)
- cmap: distinguish <kbd>find</kbd>/<kbd>select</kbd> from <kbd>home</kbd>/<kbd>end</kbd> for openSUSE `inputrc.keys` (reported by cornfeedhobo) `#D1648` 603cf41 (master: c4d28f4)
- cmap: freeze the internal codes of <kbd>find</kbd>/<kbd>select</kbd> and kitty special keys `#D1674` 66263c4 (master: fdfe62a)
- decode: work around the overwritten builtin `set` (reported by eadmaster) `#D1680` 43dcb66 (master: a6b4e2c)
- complete: work around the variable leaks by `virsh` completion from `libvirt` (reported by telometto) `#D1682` d13ce5b (master: f985b9a)
- stty: do not remove keydefs for <kbd>C-u</kbd>, <kbd>C-v</kbd>, <kbd>C-w</kbd>, and <kbd>C-?</kbd> (reported by laoshaw) `#D1683` 6335dc2 (master: 82f74f0)
- main (`ble/util/readlink`): work around non-standard or missing `readlink` (motivated by peterzky) `#D1720` 94137b7 (master: a41279e)
- global: work around the arithmetic syntax error of `10#` in Bash-5.1 `#D1734` 7c2463e (master: 7545ea3)
- global: adjust implementations for Bash 5.2 `patsub_replacement` `#D1738` f1599ee (master: 4590997)
- main: check `/dev/tty` on startup (reported by andychu) `#D1749` 28e9c44 (master: 711c69f)
- global: work around `shopt -s compat42` `#D1754` 59075cc (master: a75bb25)
- global: identify bash-4.2 bug that internal quoting of `${v/%$empty/"$rep"}` remains `#D1753` 59075cc (master: a75bb25)
- prompt: fix a bug of `ble/prompt/print` redundantly quoting `$` `#D1752` 59075cc (master: a75bb25)
- global: work around `compat42` quoting of `"${v/pat/"$rep"}"` `#D1751` 59075cc (master: a75bb25)
- util: add identification of Windows Terminal `wt` `#D1758` 444abff (master: e332dc5)
- global: work around bash-3.0 bug that single quotes remains for `"${v-$''}"` `#D1774` d0dc13e (master: 9b96578)
- highlight: fix a problem that the attribute of the last character is applied till EOL `#D1393` 2ddb1ba `#D1395` 8c33557 (master: ef09932)
- main: resolve empty `HOSTNAME` [add `histdb`] `#D1925` e6cc6c3 (master: 44d9e10)
- main: warn empty `LANG` [main: support an option `--inputrc={diff,all,user,none}`] `#D1926` 2bd1544 (master: 92f2006)
- term (`terminology`): work around terminal glitches `#D1946` c5c3bc9 (master: 9a1b4f9)
- edit: restore `PS1` while processing `bind -x` (reported by adoyle-h) `#D2024` 94db09b (master: 2eadcd5)

## Optimization
- prompt: fix not properly set `$?` in `${PS1@P}` evaluation (reported by nihilismus) `#D1644` a7b5c4b (master: 521aff9)

## Internal changes and fixes
- main: include hostname in local runtime directory `#D1444` 1a5e90a (master: 6494836)
- global: fix status check for read timeout `#D1467` b56d638 (master: e886883)
- util, etc: ensure each function to work with arbitrary `IFS` `#D1490` `#D1491` 7228fd0 (master: 5f9adfe)
- util: fix leak variables `buff`, `trap`, `{x,y}{1,2}` `#D1572` de71ada (master: 5967d6c)
- make: add fallback Makefile for BSD make `#D1805` 2cb758f (master: e5d8d00)
- util, decode, vi: fix leak variables `#D1933` a2197a6 (master: 8d5cab8)
- syntax: fix code formatting [histdb: support auto-complete source `histdb-word`] `#D1938` 492349f (master: 00cae74)

## Test
- util (ble/util/s2bytes): clear locale cache `#D1881` a8d7fd7 (master: 2e1a7c1)
- util (ble/util/s2c): work around intermediate mbstate of bash <= 5.2 `#D1881` a8d7fd7 (master: 2e1a7c1)
- util (ble/encoding:UTF-8/b2c): fix interpretation of leading byte `#D1881` a8d7fd7 (master: 2e1a7c1)

--------------------------------------------------------------------------------
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
