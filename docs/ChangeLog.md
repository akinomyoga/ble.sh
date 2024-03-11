<!---------------------------------------------------------------------------->
# ble-0.4.0-devel4

2023-04-03... (`#D2030`...) 1a5c451c...

## New features

- bgproc: support opts `kill9-timeout=TIMEOUT` `#D2034` 3ab41652
- progcomp(cd): change display name and support mandb desc (requested by EmilySeville7cfg) `#D2039` 74402098
- cmdspec: add completion options for builtins (motivated by EmilySeville7cfg) `#D2040` 9bd24691
- syntax: support bash-5.3 function subst `${ list; }` `#2045` 0906fd95 71272a4b
- complete: support `bleopt complete_requote_threshold` (requested by rauldipeas) `#2048` bb7e118e
- menu (`ble/widget/menu/append-arg`): add option `bell` (motivated by bkerin) `#D2066` 3f31be18 bbf3fed3
- make: support `make uninstall` `#D2068` a39a4a89
- edit: support `bleopt {edit_marker{,_error},exec_exit_mark}` `#D2079` e4e1c874
- edit: add widget `zap-to-char` `#D2082` ce7ce403
- keymap/vi: split widget `text-object` into `text-object-{inner,outer}` (requested by Darukutsu) `#D2093` 11cf118a
- keymap/vi: implement text-object in xmap for brackets (requested by Darukutsu) `#D2095` 7d80167c
- util: support `ble-import -C callback` (motivated by Dominiquini) `#D2102` 0fdbe3b0
- mandb: look for git subcommands (motivated by bkerin) `#D2112` 9641c3b8
- edit (`display-shell-version`): show the `atuin` version `#D2124` 9045fb87
- complete: add widgets `auto_complete/insert-?word` (requested by Tommimon) `#D2127` 0c4b6772
- edit: add widgets `execute-named-command` and `history-goto` `#D2144` aa92b42a
- keymap/vi_nmap: support `shell-expand-line` `#D2145` aa92b42a
- main: support `bash ble.sh --install` `#D2169` 986d26a3 3801a87e
- util(stty): support `bleopt term_stty_restore` (requested by TheFantasticWarrior) `#D2170` e64b02b7
  - util: update workaround of Bash 5.2 `checkwinsize` for `term_stty_restore` (reported by TheFantasticWarrior) `#D2184` ef8272a4
- magic expansions
  - edit: support `bleopt edit_magic_accept` (requested by pl643, bkerin) `#D2175` 3e9d8907
  - edit: support `bleopt edit_magic_accept=verify-syntax` `#D2178` ac84c153
  - edit: support `bleopt edit_magic_{expand,accept}=autocd` (motivated by Jai-JAP) `#D2187` xxxxxxxx
- main: support shell variable `BLE_VER` `#D2177` a12dedab
- util(bleopt, blehook, ble-face): support wildcards `*` and `?` and change `@` to match an empty string `#D2182` bf595293

## Changes

- edit: clear character highlighting for overwriting mode (requested by mozirilla213) `#D2052` 1afc616b
- history (`ble/builtin/history -w`): write file even without any new entries (requested by Jai-JAP) `#D2053` c78e5c9f
- auto-complete: overwrite subsequent characters with self-insert in overwrite mode `#D2059` 7044b2db
- complete: move face definitions `menu_filter_*` to `core-complete-def.sh` `#D2060` af022266
- make: add `INSDIR_LICENSE` for install location of licenses (reported by willemw) `#D2064` d39998f0 acf3b091
- prompt: show prompt ruler after markers (motivated by U-Labs) `#D2067` e4a90378
- complete: suffix a space to non-filenames with `compopt -o filenames` (reported by Dominiquini) `#D2096` aef8927f
- edit: distinguish space and delimiters in `cword` and `eword` `#D2121` 4f453710
- prompt: update status line on face change (motivated by Vosjedev) `#D2134` f3e7e386
- decode: specify the default keymap for the keymap load hooks `#D2141` 4a34ccf2
- progcomp(compopt): refactor the completion option `ble/{no- => }default` `#D2155` 51f9f4f6

## Fixes

- util (`conditional-sync`): fix bugs when `pid=PID` is specified (contributed by bkerin) `#D2031` 09f5cec2 `#D2034` 09f5cec2
  - util (`conditional-sync`): fix wrong command grouping overwriting `pid=PID` (reported by dragonde, georglauterbach) `#D2122`
- bgproc: return status of bgproc process `#D2036` 887d92dd
- mandb: replace TAB with 4 spaces before removing control characters (reported by EmilySeville7cfg) `#D2038` 313cfb25
- menu(desc): fix a bug that prefix is not shown with menu-filter `#D2039` e92b78d6
- progcomp: make option unique after applying mandb description `#D2042` 308ceeed
- util (`ble/util/idle`): fix an infinite loop `#D2043` 5f4c0afd
- main: fix `--inputrc=TYPE` not applied on startup `#D2044` 1b15b851 0adce7c9
- stty: suggest `stty sane` after exiting from bash >= 5.2 to non-ble session `#D2046` b57ab2d6
- util (`ble/builtin/readonly`): adjust bash options (reported by dongxi8) `#D2050` 1f3cbc01
- history (`ble/builtin/history`): fix error message on the empty `HISTFILE` `#D2061` a2e2c4b6
- complete: exit auto-complete mode on complete self-insert `#D2075` 2783d3d0
- complete: fix error messages on empty command names `#D2085` dab8dd04
- complete: fix parsing the output of `complete -p` in bash-5.2 (reported by maheis) `#D2088` a7eb5d04
- make: specify bash to search the awk path using `type -p` (reported by rashil2000) `#D2089` 26826354
- keymap/vi: fix the behavior of text-object for quotes in xmap (reported by Darukutsu) `#D2094` 5f9a44ec
- edit(redo): fix broken common prefix/suffix determination (reported by Darukutsu) `#D2098` c920ea65
- keymap/vi: improve text-object in omap for brackets (reported by Darukutsu) `#D2100` d1a1d538
- decode(bind): fix command-line argument parsing `#D2107` 57a13c3c
- edit(gexec): fix a bug that `LINENO` is vanishing `#D2108` b5776596
- mandb: fix extraction of option description in format 5 (reported by bkerin) `#D2110` 90a992cc
- decode: fix handling of @ESC in quoted-insert `#D2119` 0bbc3639
- syntax: save stat after command name for consistent completion-context `#D2126` 50d6f1bb
- term: fix control sequences for hiding cursor (reported by n87) `#D2130` f9b9aea8
- highlight: fix inconsistent tab width in plain layer (reported by dgudim) `#D2132` f9072c40
- decode: consume incomplete keyseq in macros `#D2137` 27e6309e
- keymap/vi: fix conflicting binding to <kbd>C-RET</kbd> in `vi_imap` `#D2146` 0b18f3c2
- decode: force updating cache for <kbd>@ESC</kbd> `#D2148` 6154d71c
- progcomp(compopt): support printing the current options (reported by bkerin) `#D2154` 51f9f4f6
- progcomp(compopt): properly handle dynamically specified `plusdirs` `#D2156` 51f9f4f6
- edit: fix `BLE_COMMAND_ID` starting from `2` `#D2160` 8f4bf62a
- util(vbell): fix previous vbell not fully cleared `#D2181` 6c740a94
- decode(rlfunc): fix widget name `vi-command/edit-and-execute-{line => command}` (fixed by alexandregv) 6aa8ba67

## Compatibility

- main: check `nawk` version explicitly `#D2037` 0ff7bca1
- mandb: inject in bash-completion-2.12 interfaces `#D2041` dabc8553
- complete: determine comp prefix from `COMPS` when `ble/syntax-raw` is specified (reported by teutat3s) `#D2049` f16c0d80
- syntax: allow double-quotes in `$(())` in bash-4.4 (requested by mozirilla213) `#D2051` 611c1d93
- syntax: support version-dependent arithmetic backslash `#D2051` 611c1d93
- util: work around mawk 1.3.3-20090705 regex (reported by dongxi8, Frezrik) `#D2055` 4089c4e1
- complete: update a workaround for cobra-1.5.0 (reported by 3ximus) `#D2057` a24435d3
- make: work around ecryptfs bug (reported by juanejot) `#D2058` 969a763e dc0cdb30
- edit: update mc-4.8.29 integration (reported by mooreye) `#D2062` 2c4194a2 68c5c5c4
- make: work around `make-3.81` bug of pattern rules `#D2065` f7ec170b
- decode: work around `convert-meta on` in bash >= 5.2 with broken locale (reported by 3ximus) `#D2069` 226f9718
- canvas: adjust GraphemeClusterBreak of hankaku-kana voiced marks `#D2077` 31d168cc
- canvas: update tables and grapheme clusters for Unicode 15.1.0 `#D2078` 503bb38b 9d84b424 9d84b424
- complete: use conditional-sync for cobraV2 completions (reported by sebhoss) `#D2084` 595f905b
- term: add workarounds for `eterm` `#D2087` a643f0ea
- global: adjust bash options for utilities outside the ble context (motivated by jkemp814) `#D2092` 6b144de7
- decode,syntax: quote `$#` in arguments properly `#D2097` 40a625d3
- global: work around case-interleaving collation (reported by dongxi8) `#D2103` a3b94bb3
- nsearch: set `immediate-accept` for `empty=emulate-readline` (reported by blackteahamburger) `#D2104` 870ecef7
- decode(bind): support the colonless form of `bind -x` of bash-5.3 `#D2106` 78d7d2e3
- decode, vi_digraph: trim CR of text resources in MSYS `#D2105` 6f4badf4
- progcomp: conditionally suffix space for git completion (reported by bkerin) `#D2111` 2c7cca2f
- main: fix initialization errors with `set -u` `#D2116` b503887a
- progcomp: work around slow `make` completion in large repository (reported by blackteahamburger) `#D2117` 5f3a0010
- util(TRAPEXIT): fix condition for `stty sane` in Cygwin `#D2118` a7f604e1
- progcomp: fix the detection of the zoxide completion (reported by 6801318d8d) `#D2120` 29cd8f10
- progcomp: pass original command path to completion functions (reported by REmerald) `#D2125` 0cf0383a
- main: work around nRF Connect initialization (requested by liyafe1997) `#D2129` 2df3b109
- main(unload): redirect streams to work around trap `EXIT` in bash-5.2 (reported by ragnarov) `#D2142` 38a8d571
- complete: call the `docker` command through `ble/util/conditional-sync` `#D2150` 6c3f824a
- util(joblist): fix job detection in Bash 5.3 `#D2157` 6d835818
  - util(joblist): exclude more foreground dead jobs in Bash 5.3 `#D2174` 8a321424
- util,complete: work around regex `/=.../` failing in Solaris nawk `#D2162` 46fdf44a
- main: fix issues in MSYS1 `#D2163` 5f0b88fb
- util: work around bash-3.1 bug that `10>&-` fails to close the fd `#D2164` b5938192
- decode: fix the problem that key always timed out in bash-3 `#D2173` 0b176e76
- term: adjust the result of `tput clear` for `ncurses >= 6.1` (reported by cmndrsp0ck) `#D2185` 18dd51ab

## Contrib

- histdb
  - fix(histdb): show error message only when bgproc crashed `#D2036` 887d92dd
  - util: add `ble/util/{time,timeval,mktime}` `#D2133` 34a886fe
  - histdb: suppress outputs from `PRAGMA quick_check;` `#D2147` 6154d71c
  - histdb: fix variable leak of `ret` `#D2152` 98a2ae15
  - util: fix `ble/util/time` in `bash < 4.2` `#D2161` 623dba91
  - histdb: support subcommands `#D2167` 4d7dd1ee
  - histdb: support `top`, `stats`, `calendar`, and `week` `#D2167` 4d7dd1ee
  - histdb: unify the color palette selection `#D2167` 4d7dd1ee
- contrib/fzf-git: update to be consistent with the upstream (motivated by arnoldmashava) `#D2054` c78e5c9f
- contrib/layer/pattern: add `{pattern}` layer `#D2074` 449d92ca
- contrib/fzf-git: fix unsupported command modes (reported by dgudim) `#D2083` ba2b8865
- contrib/bash-preexec: support the latest version of `bash-preexec` (reported by mcarans) `#D2128` 50af4d9c
- contrib/config/execmark: output error status through `ble/canvas/trace` `#D2136` 64cdcd01

## Documentation

- docs(CONTRIBUTING): add styleguide (motivated by bkerin) `#D2056` 44cf6756
- docs(README): fix dead links to blerc.template (fixed by weskeiser) e0f3ac28
- github: add FUNDING `#D2080` 3f133936
- blerc: describe keybinding to accept autosuggestion by TAB (motivated by TehFunkWagnalls) `#D2090` cd069860
- docs: apply Grammarly and fix typos `#D2099` 8b3f6f8c
- docs(README): add sabbrev example for named directories `#D2115` a9a21a0e

## Test

- test(bash): fix condition for bash bug of history expansion `#D2071` aacf1462
- test(main): fix delimiter of `MSYS` in adding `winsymlinks` `#D2071` aacf1462
- test(util,vi): adjust `ble/util/is-stdin-ready` while testing `#D2105` 23a05827 6f4badf4
- test(vi): suppress warnings for non-interactive sessions `#D2113` b8b7ba0c
- test(bash,util): fix tests in interactive session `#D2123` 06ad3a6c
- test(vi): fix broken states after test `#D2123` 06ad3a6c
- test(bash): fix test cases for history expansion `#D2131` 838b4652
- test(bash): add tests for bash array bugs `#D2149` 6154d71c
- github/workflows: update versions of GitHub Actions `#D2186` xxxxxxxx

## Internal changes

- refactor: move files `{keymap/ => lib/keymap.}*` f4c973b8
- global: fix coding style `#D2072` bdcecbbf
- memo: add recent configs and create directories `#D2073` 99cb5e81
- highlight: generalize `region` layer `#D2074` 449d92ca
- keymap/vi: integrate vi tests into the test framework `#D2101` d16b8438
- global(leakvar): fix variable leak `#D2114` d3e1232d
- make(scan): apply builtin checks to `contrib` `#D2135` 2f16d985
  - contrib/fzf-git: do not use `ble/util/print` in a script mode (reported by dgudim) `#D2166` 8f0dfe9b
- decode: change Isolated ESC to U+07FC `#D2138` 82bfa665
- edit: introduce `selection` keymap for more flexible shift selection `#D2139` 2cac11ad
  - edit: fix a regression that delete-selection does not work (reported by cmndrsp0ck) `#D2151` 98a2ae15
- util: support `bleopt connect_tty` `#D2140` f940696f
  - util: support `ble/fd#add-cloexec` and add `O_CLOEXEC` by default `#D2158` 785267e1
  - util: fix error of bad file descriptors (reported by ragnarov) `#D2159` 785267e1
  - util: work around macOS/FreeBSD failure on `exec 32>&2` (reported by tessus, jon-hotaisle) `#D2165` 8f0dfe9b
  - main: record external file descriptors on `ble-attach` `#D2183` a508a827
- main: fix unprocessed `-PGID` in `*.pid` for cleanup `#D2143` a5da23c0
- history: prevent `SIGPIPE` from reverting the TTY state in trap `EXIT` `#D2153` 4b8a0799
  - history: fix initially shifted history index `#D2180` e425dc56
- edit: support `bleopt internal_exec_int_trace` (motivated by tessus) `#D2171` cebea478 3801a87e

<!---------------------------------------------------------------------------->
# ble-0.4.0-devel3

2020-12-02...2023-04-03 (`#D1427`...`#D2030`) 276baf2...1a5c451c

## New features

- decode (`ble-decode-kbd`): support various specifications of key sequences `#D1439` 0f01cab
- edit: support new options `bleopt edit_line_type={logical,graphical}` (motivated by 3ximus) `#D1442` 40ae242
- complete: support new options `bleopt complete_limit{,_auto}` (contributed by timjrd) `#D1445` b13f114 5504bbc
  - complete: update the default value of `bleopt complete_limit{,auto}` `#D1500` aae553c
  - complete: inject user interruption and complete limits into `bash-completion` through `read` (motivated by timjrd) `#D1504` 856cec2 `#D1507` 4fc51ae
- edit (kill/copy): combine multiple kills and copies (suggested by 3ximus) `#D1443` 66564e1
  - edit (`{kill,copy}-region-or`): fix unconditionally combined kills/copies (reported by 3ximus) `#D1447` 1631751
- canvas: update emoji database and support `bleopt emoji_version` (motivated by endorfina) `#D1454` d1f8c27
  - emoji: unify emoji tables of different versions `#D1671` af82662
- canvas, edit: support `bleopt info_display` (suggested by 0neGuyDev) `#D1458` 69228fa
  - canvas (panel): always call `panel::render` to update height `#D1472` 51d2c05
  - util (visible-bell): work around coordinate mismatches in subshells `#D1495` 01cfb10
  - canvas: work around kitty's quirk not recognizing <kbd>DECSTBM</kbd> (<kbd>CSI ; r</kbd>) `#D1503` eca2976
- prompt: support `bleopt prompt_status_{line,align}` and `face prompt_status_line` `#D1462` cca1cbc
  - prompt: fix missing height allocation for status line `#D1487` b424fa5
  - prompt: support `bleopt prompt_status_align=justify` `#D1494` c30a0db
- syntax: properly support case patterns `#D1474` `#D1475` `#D1476` 64b55b7
- keymap/vi: add `ble/keymap:vi/script/get-mode` for user-defined mode strings `#D1488` f25a6e8 462918d
- prompt: support multiline `prompt_rps1` `#D1502` 4fa139a
  - canvas: fix wrong coordinate calculation on linefolding (reported by telometto) `#D1602` 9badb5f
  - prompt: fix coordinates after `prompt_rps1` `#D1972` e128801
  - prompt: clear remaining SGR after `prompt_rps1` (reported by linwaytin) `#D2003` ea99d944
- syntax: support tilde expansions in parameter expansions `#D1513` 0506df2
- decode: support `ble-bind -m KEYMAP --cursor DECSCUSR` (motivated by jmederosalvarado) `#D1514` `#D1515` `#D1516` 79d671d
  - decode: reflect changes after `ble-bind --cursor` `#D1873` 39efcf9
- edit: support `nsearch` options (motivated by Alyetama, rashil2000, carv-silva) `#D1517` 9125795
  - edit: support `nsearch` opts `empty=emulate-readline` (motivated by jainpratik163) `#D1661` d68ba61
  - edit: support bash-5.2 binding of `prior/next` to `history-search-{for,back}ward` `#D1661` d26a6e1
- syntax: support the deprecated redirection `>& file` `#D1539` b9b0de4
- complete: complete file descriptors and heredoc words after redirections `#D1539` b9b0de4
- main: support `blehook ATTACH DETACH`, `BLE_ONLOAD`, `BLE_ATTACHED` `#D1543` 750ca38
- main: support `ble` `#D1544` 750ca38
- main (`ble-update`): support package updates and `sudo` updates (motivated by huresche, oc1024) `#D1548` 0bc2660
  - main (`ble-update`): fix help message (contributed by NoahGorny) 50288bf
- syntax: support undocumented `${a~}` and `${a~~}` `#D1561` 4df29a6
- lib: support `lib/vim-airline` (motivated by huresche) `#D1565` da1d0ff
  - util (`ble/gdict`): refactor `#D1569` 7732eed
  - vim-airline: support `bleopt vim_airline_theme` `#D1589` 73b037f
  - prompt: track dependencies and detect changes `#D1590` `#D1591` cf8d949
  - prompt: preserve `LINES` and `COLUMNS` for custom sequences `#D1592` 040016d
  - color: fix the face initialiation order for uses in prompts (motivated by jmederosalvarado) `#D1593` 321371f
  - prompt (`contrib/prompt-git`): support dirty checking `#D1601` b2713d9
  - prompt (`contrib/prompt-git`): do not use `ble/util/idle` in Bash 3 `#D1606` 959cf27
  - util (`bleopt`): add new option `-I` to reinitialize user settings on reload `#D1607` 959cf27
  - vi (vi_cmap): fix wrong prompt calculations by the outdated initial values `#D1653` 2710b23
  - vim-airline: measure separator widths and fix layout of status line `#D1999` 1ce0d1ad 478c9a10
- util, color: refactor configuration interfaces (`bleopt`, `blehook`, `ble-face`) `#D1568` c94d292
  - color: support new face setting function `ble-face`
  - util (`bleopt`): support option `-r` and `-u` and wildcards in option names
  - util (`blehook`): hide internal hooks by default and support option `-a`
  - util, color: fix argument analysis of `bleopt`, `blehook`, and `ble-face` (fixup c94d292) `#D1571` bb53271
  - util (`blehook`): show explicitly specified internal hooks `#D1594` f4312df
  - util (`bleopt`): do no select obsoleted options by wildcards `#D1595` f4312df
  - util (`bleopt`): fix error messages for unknown options `#D1610` 66df3e2
  - util (`bleopt`, `bind`): fix error message and exit status, respectively `#D1640` b663cee
  - util (`blehook`): support wildcards `#D1861` 480b7b3
- progcomp: support quoted commands and better `progcomp_alias` `#D1581` `#D1583` dbe87c3
  - progcomp: fix a bug that command names may stray into completer function names `#D1611` 1f2d45f
- syntax: highlight quotes of the `\?` form `#D1584` 5076a03
  - syntax: recognize escape \" in double-quoted strings `#D1641` 4b71449
- prompt: support a new backslash sequence `\g{...}` `#D1609` be31391
  - prompt: accept more general `[TYPE:]SPEC` in `\g{...}` like `ble-face` `#D1963` 81b3b0e
  - prompt: fix non-working 24-bit color in `\g{...}` `#D1977` 881ec25
- complete: add a new option `bleopt complete_limit_auto_menu` `#D1618` 1829d80
- canvas: support grapheme clusters (motivated by huresche) `#D1619` c0d997b
  - canvas (`ble/util/c2w`): use `EastAsianWidth` and `GeneralCategory` to mimic `wcwidth` `#D1645` 9a132b7
  - canvas (c2w:auto): work around combining chars applied to the previous line `#D1649` 1cbbecb
  - canvas (c2w:auto): avoid duplicate requests `#D1649` 1cbbecb a3047f56
  - canvas (c2w:auto): send <kbd>DSR(6)</kbd> in the internal state `#D1664` a3047f5
  - canvas (c2w): support `bleopt char_width_mode=musl` `#D1668` 05b258f `#D1672` af82662
  - canvas (c2w:auto): detect `emacs` and `musl` `#D1668` 05b258f
- rlfunc: support vi word operations in `emacs` keymap (requested by SolarAquarion) `#D1624` 21d636a
- edit: support `TMOUT` for the session timeout `#D1631` 0e16dbd
- edit: support bash-5.2 `READLINE_ARGUMENT` `#D1638` d347fb3
- complete: support `complete [-DI]` in old versions of Bash through `_DefaultCmD_` and `_InitialWorD_` `#D1639` 925b2cd
- rlfunc: support nsearch widgets in `vi_nmap` keymap (requested by cornfeedhobo) `#D1651` 9a7c8b1
- prompt: support `bleopt prompt_ruler` (motivated by Barbarossa93) `#D1666` 05cf638
  - prompt: fix hanging by a zero-width `prompt_ruler` `#D1673` 9033f29
- edit: support `bleopt canvas_winch_action` (requested by Johann-Goncalves-Pereira, guptapriyanshu7) `#D1679` 2243e91
  - blerc: fix the name of the option `bleopt canvas_winch_action` (reported by Knusper) b1be640
  - edit: go back to the previous lines with `redraw-here` more aggressively `#D1966` a125187
- menu (menu-style:desc): improve descriptions (motivated by Shahabaz-Bagwan) `#D1685` 4de1b45
- menu (menu-style:desc): support multicolumns (motivated by Shahabaz-Bagwan) `#D1686` 231dc39
  - menu (menu-style:desc): fix not working `bleopt menu_desc_multicolumn_width=` `#D1727` 2140d1e
- term: let <kbd>DECSCUSR</kbd> pass through terminal multiplexers (motivated by cmplstofB) `#D1697` a3349e4
  - util: refactor `_ble_term_TERM` `#D1746` 63fba6b
- complete: requote for more compact representations on full completions `#D1700` a1859b6
  - complete (requote): requote from optarg/rhs starting point `#D1786` 93c2786
- complete: improve support for `declare` and `[[ ... ]]` `#D1701` da38404
  - syntax: fix completion and highlighting of `declare` with assignment arguments `#D1704` `#D1705` e12bae4
  - cmdspec: refactor `{mandb => cmdspec}_opts` `#D1706` `#D1707` 0786e92
- complete (menu-style:align): refactor `complete_menu_align => menu_align_{min,max}` (motivated by banoris) `#D1717` 22a2449
- prompt: support `bleopt prompt_command_changes_layout` `#D1750` e199bee
- exec: measure execution times `#D1756` 2b28bec
  - edit: work around a bash-4.4..5.1 bug of `exit` outputting time to stderr of exit context `#D1765` 3de751e e61dbaa
  - edit (`exec_elapsed_mark`): show hours and days `#D1793` 699dabb
- util: preserve original traps and restore them on unload `#D1775` `#D1776` `#D1777` 398e404
  - util (trap): fix a bug of restoring original traps `#D1850` 8d918b6
- progcomp: support `compopt -o ble/no-default` to suppress default completions `#D1789` 7b70a0e
- sabbrev: support options `-r` and `--reset` to remove entries `#D1790` 29b8be3
- util (blehook): support `hook!=handler` and `hook+-=handler` `#D1791` 0b8c097
- prompt: escape control characters in `\w` and `\W` `#D1798` 8940434 a9551e5
  - prompt: fix wrongly escaped UTF-8 chars in `\w` and `\W` `#D1806` d340233
  - prompt: fix a bug that `\u` is expanded to the shell name `#D1975` fe339c3
- emacs: support `bleopt keymap_emacs_mode_string_multiline` (motivated by ArianaAsl) `#D1818` 8e9d273
- util: synchronize rlvars with `bleopt complete_{menu_color{,_match},skip_matched} term_bracketed_paste_mode` (motivated by ArianaAsl) `#D1819` 6d20f51
  - util: suppress false warnings of `bind` inside non-interactive shells (reported by wukuan405) `#D1823` 1e19a67
- history: support `bleopt history_erasedups_limit` (motivated by SuperSandro2000) `#D1822` e4afb5a 3110967
- prompt: support `bleopt prompt_{emacs,vi}_mode_indicator` (motivated by ferdinandyb) `#D1843` 2b905f8
- util (`ble-import`): support option `-q` `#D1859` 1ca87a9
- history: support extension `HISTCONTROL=strip` (motivated by aiotter) `#D1874` 021e033
- benchmark (ble-measure): support an option `-V` `#D1881` 571ecec
- color: allow setting color filter by `_ble_color_color2sgr_filter` `#D1902` 88e74cc
- auto-complete: add `bleopt complete_auto_complete_opts` (motivated by DUOLabs333) `#D1901` `#D1911` 1478a04 6a21ebb
- menu-complete: add `bleopt complete_menu_complete_opts` (requested by DUOLabs333) `#D1911` 6a21ebb
- edit (`magic-space`): support `bleopt edit_magic_expand=...:alias` (requested by telometto) `#D1912` 63da2ac
  - auto-complete: cancel auto-complete for `magic-space` `#D1913` 01b4f67
- complete: support ambiguous completion for command paths `#D1922` 8a716ad
- complete: preserve original path segments as long as possible `#D1923` `#D1924` e3cdb9d
- main: support `BLE_SESSION_ID` and `BLE_COMMAND_ID` `#D1925` 44d9e10 `#D1947` 46ac426 `#D1954` 651c70c
- main: support an option `--inputrc={diff,all,user,none}` `#D1926` 92f2006
- util (`ble/builtin/trap`): support Bash 5.2 `trap -P` `#D1937` 826a275
- syntax: highlight `\?` in here documents `#D1959` e619e73
- syntax: recognize history expansion in here documents, `"...!"` (bash <= 4.2), and `$!` (bash <= 4.1) `#D1959` e619e73
- syntax: support context after `((...))` and `[[ ... ]]` in bash-5.2 `#D1962` 67cb967
- edit: support the readline variable `search-ignore-case` of bash-5.3 `#D1976` e3ad110
- menu-complete: add `insert_unique` option to the `complete` widget `#D1995` 36efbb7
- syntax: check alias expansions of `coproc` variable names `#D1996` 92ce433
- syntax: support new parameter transformation `"${arr@k}"` `#D1998` 1dd7e385
- edit: support a user command `ble append-line` (requested by mozirilla213) `#D2001` 2a524f34
- decode: accept isolated <kbd>ESC \<char\></kbd> (requested by mozirilla213) `#D2004` d7210494
- sabbrev: add widget `magic-slash` to approximate Zsh named directories (motivated by mozirilla213) `#D2008` e6b9581c
- sabbrev: support inline and linewise sabbre with `ble-sabbrev -il` `#D2012` 56208534
- complete: add `bleopt complete_source_sabbrev_{opts,ignore}` (motivated by mozirilla213) `#D2013` f95eb0cc `#D2016` 45c76746
- util.bgproc: separate `ble/util/bgproc` from `histdb` (motivated by bkerin) `#D2017` 7803305f
  - util.bgproc: fix use of `ble/util/idle` in bash-3 `#D2026` 79a6bd41
  - util.bgproc: increase frequency of bgproc termination check (motivated by bkerin) `#D2027` 8d623c19
  - util.bgproc: fix an `fd#alloc` failure in bash-4.2 `#D2029` 7c4ff7bc
- menu-complete: support selection by index (requested by bkerin) `#D2023` b91b8bc8

## Changes

- syntax: exclude <code>\\ + LF</code> at the word beginning from words (motivated by cmplstofB) `#D1431` 67e62d6
- complete: do not quote `:` and `=` in non-filename completions generated by progcomp (reported by 3ximus) `#D1434` d82535e
- edit: preserve the state of `READLINE_{LINE,POINT,MARK}` `#D1437` 8379d4a
- edit: change default behavior of <kbd>C-w</kbd> and <kbd>M-w</kbd> to operate on backward words `#D1448` 47a3301
- prompt: rename `bleopt prompt_{status_line => term_status}` `#D1462` cca1cbc
- edit (`ble/builtin/read`): cancel by <kbd>C-d</kbd> on an empty line `#D1473` ecb8888
- syntax: change syntax context after `time ;` and `! ;` for Bash 4.4 `#D1477` 4628370
- decode (rlfunc): update mapping `vi-replace` in `imap` and `vi-editing-mode` in `nmap` (reported by onelittlehope) `#D1484` f2ca811
- prompt: invalidate prompt and textarea on prompt setting changes `#D1492` 1f55913
- README: update informations on stable versions `#D1509` c8e658e
- README: update the description of how to uninstall `#D1510` c8e658e
- util (`bleopt`): validate initial user settings `#D1511` 82c5ece
  - util (`bleopt`): fix a bug that old values are double-expanded on init (fixup 82c5ece) `#D1521` f795c07
  - util (`bleopt`): do not validate obsoleted initial settings `#D1527` 032f6b2
- main: preserve user-space overridden builtins `#D1519` 0860be0
  - util (`ble/util/type`): fix a bug that aliases are not properly highlighted (reported by 3ximus) `#D1526` 45b30a7
  - main: preserve user's `expand_aliases` and allow aliases in internal space (fixup 0860be0) `#D1574` afc4112
  - main: main: fix expand_aliases unset on ble-reload (fixup afc4112) `#D1577` 3417388
- main: accept non-regular files as `blerc` and add option `--norc` `#D1530` 7244e2f
- prompt: let `stderr` pass through to tty in evaluating `PS0` (reported by tycho-kirchner) `#D1541` 24a88ce
- prompt: adjust behavior of `LINENO` and prompt sequence `\#` (reported by tycho-kirchner) `#D1542` 8b0257e
  - prompt: update `PS0` between multiple commands (motivated by tycho-kirchner) `#D1560` 8f29203
- edit (`widget:display-shell-version`): include `ble.sh` version `#D1545` 750ca38
  - edit (`display-shell-version`): detect configurations and print details `#D1781` 5015cb56
  - edit (`display-shell-version`): show information of the OS distribution and properly handle saved locales `#D1854` 066ec63 bdb7dd6
  - edit (`display-shell-version`): show `gawk`, `make`, and `git` versions of the build time `#D1892` e618133
  - edit (`display-shell-version`): support running as a user command (reported by DhruvaG2000) `#D1893` e618133
  - edit (`display-shell-version`): show warnings for fzf-integration `#D1907` 3bc3bea
  - edit (`display-shell-version`): show the `zoxide` version `#D1907` 3bc3bea
- complete (`ble-sabbrev`): support colored output `#D1546` 750ca38
- decode (`ble-bind`): support colored output `#D1547` 750ca38
  - decode (`ble-bind`): output bindings of the specified keymaps with `ble-bind -m KEYMAP` (fixup 750ca38) `#D1559` 6e0245a
- keymap/vi: update mode names on change of `bleopt keymap_vi_mode_name_*` (motivated by huresche) `#D1565` 11ac106
- main: show notifications against debug versions of Bash `#D1612` 8f974aa
- term: terminal identification
  - term (`_ble_term_TERM`): update `vte` identification `#D1620` 00e74d8
  - term (`_ble_term_TERM`): detect wezterm-20220408 `#D1909` 486564a
  - term (`_ble_term_TERM`): detect konsole `#D1988` 600e845 ed53858
- edit: suppress only `stderr` with `internal_suppress_bash_output` (motivated by rashil2000) `#D1646` a30887f
- prompt: do not evaluate `PROMPT_COMMAND` for subprompts `#D1654` 08e903e
- Makefile: work around the case the repository is cloned without `--recursive` `#D1655` 22ace5f
- repo: add subdirectories `make` and `docs` `#D1657` 75bd04c
- util: time out <kbd>CPR</kbd> requests `#D1669` 1481d48
  - util (CPR): fix the problem of always timing out (fixup 1481d48) `#D1792` 9b331c4
- main: suppress non-interactive warnings from manually sourced startup files (reported by andreclerigo) `#D1676` 0525528 88e2df5
- mandb: integrate `mandb` with `bash-completion` (motivated by Shahabaz-Bagwan, bbyfacekiller and EmilySeville7cfg) `#D1688` c1cd666
- syntax: do not start argument completions immediately after previous word (reported by EmilySeville7cfg) `#D1690` 371a5a4
  - syntax: revert 371a5a4 and generate empty completion source on syntax error `#D1609` e09fcab
- syntax: strictly check variable names of `for`-statements `#D1692` d056547
- widget `self-insert`: untranslate control chars and insert the last character `#D1696` 5ff3021
- complete (`source:command`): exclude inactive aliases `#D1715` d6242a7
- complete (`source:command`): not quote aliases and keywords `#D1715` d6242a7
- highlight (`wtype=CTX_CMDI`): check alias names before shell expansions `#D1715` d6242a7
  - util (`ble/is-alias`): fix a bug of unredirected error messages for bash-3.2 (fixup d6242a7) `#D1730` 31372cb
- edit (`history_share`): update history on `discard-line` (reported by SuperSandro2000) `#D1742` 8dbefe0
- canvas: do not insert explicit newlines on line folding if possible (reported by banoris) `#D1745` 02b9da6 dc3827b
  - edit: fix layout with `prompt_rps1` caused by missing `opts=relative` for `ble/textmap#update` `#D1769` f6af802
- edit (`ble-bind -x`): preserve multiline prompts on execution of `bind -x` commands (requested by SuperSandro2000) `#D1755` 7d05a28
- util (`ble/util/buffer`): hide cursor in rendering `#D1758` e332dc5
- complete (`action:file`): always suffix `/` to complete symlinked directory names (reported by SuperSandro2000) `#D1759` 397ac1f
- edit (command-help): show source files for functions `#D1779` 7683ab9
- edit (`ble/builtin/exit`): defer exit in trap handlers (motivated by SuperSandro2000) `#D1782` f62fc04 6fdabf3
  - util (`blehook`): fix a bug that the the hook arguments are lost (reported by SuperSandro2000) `#D1804` 479795d
  - edit: fix a bug of `ble/builtin/exit` inside subshells in the `EXIT` trap `#D1973` 0451521
- complete (`source:command/get-desc`): show function location and body `#D1788` 496e798
- edit (`ble-detach`): prepend a space to `stty sane` for `HISTIGNORE=' *'` `#D1796` 26b532e
- decode (`bind`): do not treat non-beginning `#` as comments `#D1820` 65c4138
- history: disable the history file when `HISTFILE` is empty `#D1836` 9549e83
- complete: generate options by empty-word copmletion after filenames (reported by geekscrapy) `#D1846` 6954b13
  - complete: do not show option descriptions for the empty-word completion (requested by geekscrapy) `#D1846` 1c7f7a1
- syntax (`extract-command`): extract unexpected command names as commands `#D1848` 5b63459
- main (`ble-reload`): preserve the original initialization options `#D1852` d8c92cc
 - main (`ble-reload`): fix a bug that the default rcfile is not loaded `#D1914` 85b5828
- blehook: print reusable code to restore the user hooks `#D1857` b763677
  - blehook: separate internal and user hooks `#D1856` b763677
  - blehook: prefer the uniq  `!=` to the addition `+=` `#D1871` fe7abd4
  - blehook: print hooks with `--color=auto` by default `#D1875` 3953afe
- util (`ble/builtin/trap`): refactor
  - trap,blehook: rename `ERR{ => EXEC}` and separate from the `ERR` trap `#D1858` 94d1371
  - trap: remove the support for the shell function `TRAPERR` `#D1858` 94d1371
  - trap: preserve `BASH_COMMAND` in trap handlers `#D1858` 94d1371
  - util (`ble/builtin/trap`): run EXIT trap in subshells `#D1862` 5b351e8
  - util (`ble/builtin/trap`): fix the RETURN trap `#D1863` 793dfad
  - trap,blehook: move to a new file `util.hook.sh` `#D1864` 55a182b
  - trap (`trap -p`): fix unprinted existing user traps `#D1864` 55a182b
  - trap (`ble/builtin/trap/finalize`): fix a failure of restoring the original trap `#D1864` 55a182b
  - trap (`trap -p`): print also custom traps `#D1864` 55a182b
  - trap: preserve positional parameters for user trap handlers `#D1865` 9e2963c
  - trap: suppress `INT` processing with user traps `#D1866` 5c28387
  - trap: unify handling of `DEBUG` and the other traps `#D1867` a22c25b
  - trap: work around possible interferences by recursive traps `#D1867` a22c25b
  - trap: ignore `RETURN` for `ble/builtin/trap/.handler` `#D1867` a22c25b
  - trap: fix a bug that `DEBUG` for internal commands clears `$?` `#D1867` a22c25b
  - trap: use `ble/util/assign/.mktmp` to read the `DEBUG` trap `#D1910` 1de9a1e
- progcomp: reproduce arguments of completion functions passed by Bash `#D1872` 4d2dd35
- prompt: preserve transient prompt with `same-dir` after `clear-screen` `#D1876` 69013d9
- color: let `bleopt term_index_colors` override the default if specified `#D1878` 7d238c0
- canvas: update Unicode version 15.0.0 `#D1880` 49e55f4
- decode (`vi_imap-rlfunc.txt`): update the widget for `backward-kill-word` as `kill-backward-{u => c}word` `#D1896` e19b796
- color: rearrange color table by `ble palette` (suggested by stackoverflow/caoanan) `#D1961` bb8541d
- util (`ble/util/idle`): process events before idle sleep `#D1980` 559d64b
- keymap/vi (`decompose-meta`): translate <kbd>S-a</kbd> to <kbd>A</kbd> `#D1988` 600e845
- sabbrev: apply sabbrev to right-hand sides of variable assignments `#D2006` 41faa494
- complete (`source:argument`): fallback to rhs completion also for `name+=rhs` `#D2006` 41faa494
- auto-complete: limit the line length for auto-complete `#D2009` 5bfbd6f2
- complete (`source:argument`): generate sabbrev completions after normal completions (motivated by mozirilla213) `#D2011` a6f168d0
- complete (`source:option`): carve out `ble/complete/source:option/generate-for-command` (requested by mozirilla213) `#D2014` 54ace59c

## Fixes

- term: fix a bug that VTE based terminals are not recognized `#D1427` 7e16d9d
- complete: fix a problem that candidates are not updated after menu-filter (reported by 3ximus) `#D1428` 98fbc1c
- complete/mandb-related fixes
  - mandb: support mandb in FreeBSD `#D1432` 6c54f79
  - mandb: fix BS contamination used by nroff to represent bold (reported by rlnore) `#D1429` b5c875a
  - mandb: fix an encoding prpblem of utf8 manuals `#D1446` 7a4a480
  - mandb: improve extraction and cache for each locale `#D1480` 3588158
  - mandb: fix an infinite loop by a leak variable (reported by rlanore, riblo) `#D1550` 0efcb65
  - mandb: work around old groff in macOS (reported by killermoehre) `#D1551` d4f816b
  - mandb: use `manpath` and `man -w`, and read `/etc/man_db.conf` and `~/.manpath` `#D1637` 2365e09
  - mandb: support the formats of the man pages of `awk` and `sed` (reported by bbyfacekiller) `#D1687` 6932018
  - mandb: generate completions of options also for the empty word `#D1689` b90ac78
  - mandb: support the man-page formats of `wget`, `fish`, and `ping` (reported by bbyfacekiller) `#D1687` a79280e
  - mandb: carry optarg for e.g. `-a, --accept=LIST` `#D1687` 23d5657
  - mandb: parse `--help` for specified commands `#D1693` e1ad2f1
  - mandb: fix small issues of man-page analysis `#D1708` caa77bc
  - mandb: insert a comma in brace expansions instead of a space `#D1719` 0ac7f03
  - mandb: support man-page format of `rsync` `#D1733` 7900144
  - mandb: fix a bug that the description is inserted for `--no-OPTION` `#D1761` 88614b8
  - mandb: fix a bug that the man page is not correctly searched (fixup 2365e09) `#D1794` 65ffe70
  - mandb: support the man-page formats of `man ls` in coreutils/Japanese and in macOS `#D1847` fa32829
  - mandb: include short name in the longname description `#D1879` 60b6989
- edit: work around the wrong job information of Bash in trap handlers (reported by 3ximus) `#D1435` `#D1436` bc4735e
- edit (command-help): work around the Bash bug that tempenv vanishes with `builtin eval` `#D1438` 8379d4a
- global: suppress missing locale errors (reported by 3ximus) `#D1440` 4d3c595
- edit (sword): fix definition of `sword` (shell words) `#D1441` f923388
- edit (`kill-forward-logical-line`): fix a bug not deleting newline at the end of the line `#D1443` 09cf7f1
- util (`ble/util/msleep`): fix hang in Cygwin by swithing from `/dev/udp/0.0.0.0/80` to `/dev/zero` `#D1452` d4d718a
  - util (`ble/util/msleep`): work around the bash-4.3 bug of `read -t` (reported by 3ximus) `#D1468` `#D1469` 4ca9b2e
- syntax: fix broken AST with `[[` keyword `#D1454` 69658ef
- benchmark (`ble-measure`): work around a locale-dependent decimal point of `EPOCHREALTIME` (reported by 3ximus) `#D1460` 1aa471b
- global: work around bash-4.2 bug of `declare -gA` (reported by 0xC0ncord) `#D1470` 8856a04
  - global: fix declaration of associative arrays for `ble-reload` (reported by 0xC0ncord) `#D1471` 3cae6e4
  - global: use a better workaround of bash-4.2 `declare -gA` by separating assignment `#D1567` 2408a20
- bind: work around broken `cmd_xmap` after switching the editing mode `#D1478` 8d354c1
  - decode (`encoding:C`): fix initialization for isolated ESC `#D1839` c3bba5b
- edit: clear graphic rendition on newlines and external commands `#D1479` 18bb2d5
- decode (rlfunc): work around incomplete bytes in keyseq (reported by onelittlehope) `#D1483` 3559658 beb0383 37363be
- main: fix a bug that unset `IFS` is not correctly restored `#D1489` 808f6f7
  - edit: fix error messages on accessing undo records in emacs mode (reported by rux616) `#D1497`  61a57c0 e9be69e
- canvas: fix a glitch that SGR at the end of command line is applied to new lines `#D1498` 4bdfdbf
- syntax: fix a bug that `eval() { :; }`, `declare() { :; }` are not treated as function definition `#D1529` b429095
- decode: fix a hang on attach failure by cache corruption `#D1531` 24ea379
- edit, etc: add workarounds for `localvar_inherit` `#D1532` 7b63c60
  - edit: fix a bug that `command-help` doesn't work `#D1635` 0f6a083
- progcomp: fix non-working `complete -C prog` (reported by Archehandoro) `#D1535` 026432d
- bind: fix a problem that `bind '"seq":"key"'` causes a loop macro `bind -s key key` (reported by thanosz) `#D1536` ea05fc5
  - bind: fix errors on readline macros (reported by RakibFiha) `#D1537` c257299
- main: work around sourcing `ble.sh` inside subshells `#D1554` bbc2a90
  - main: fix exit status for `bash ble.sh --test` (fixup bbc2a90) `#D1558` 641238a
  - main: fix reloading after ble-update (fixup bbc2a90) (fixed by oc1024) `#D1558` 9372670
- main: work around `. ble.sh --{test,update,clear-cache}` in intereactive sessions `#D1555` bbc2a90
- Makefile: create `run` directory instead of `tmp` `#D1557` 9bdb37d
- main: fix the workaround for `set -e` `#D1564` ab2f70b
  - main: fix the workaround for `set -u` `#D1575` 76073a9
  - main: fix the workaround for `set -eu` and refactor `#D1743` 6a946f0
  - decode: fix the workaround for `set -e` with `--prompt=attach` `#D1832` 5111323
- util: work around bash-3.0 bug `"${scal[@]/xxx}"` `#D1570` 24f79da
- sabbrev (`ble-sabbrev`): fix delayed output before the initialization `#D1573` 5d85238
- history: fix the workaround for bash-3.0 bug of reducing histories `#D1576` 15c9133
- syntax: fix a bug that argument completion is attempted in nested commands (reported by huresche) `#D1579` 301d40f
- edit (brackated-paste): fix incomplete `CR => LF` conversion (reported by alborotogarcia) `#D1587` 8d6da16
- main (adjust-bash-options): adjust `LC_COLLATE=C` `#D1588` e87ac21
- highlight (`layer:region`): fix blocked lower-layer changes without selection changes `#D1596` 5ede3c6
- complete (`auto-menu`): fix sleep loops by clock/sclock difference `#D1597` 53dd018
- history: fix a bug that history data is cleared on `history -r` `#D1605` 72c274e
- util (`ble/string#quote-command`): remove redundant trailing spaces for single word command `#D1613` 94556b4
- util: work around the Bash 3 bug of array assignments with `^A` and `^?` in Bash 3.2 `#D1614` b9f7611
- benchmark (`ble-measure`): fix a bug that the result is always 0 in Bash 3 and 4 (fixup bbc2a904) `#D1615` a034c91
- complete: fix a bug that the shopt settings are not restored correctly (reported by Lun4m) `#D1623` 899c114
- decode, canvas, etc.: explicitly treat CSI arguments as decimal numbers (reported by GorrillaRibs) `#D1625` c6473b7 2ea48d7
- history: fix the vanishing history entry used for `ble-attach` `#D1629` eb34061
- global: work around readonly `TMOUT` (reported by farmerbobathan) `#D1630` 44e6ec1
- complete: fix a task scheduling bug of referencing two different clocks (reported by rashil2000) `#D1636` fea5f5b
- canvas: update prompt trace on `char_width_mode` change (reported by Barbarossa93) `#D1642` 68ee111
- decode (`cmap/initialize`): fix unquoted special chars in the cmap cache `#D1647` 7434d2d
- decode: fix a bug that the characters input while initialization are delayed `#D1670` 430f449
- util (`ble/util/readfile`): fix a bug of always exiting with 1 in `bash <= 3.2` (reported by laoshaw) `#D1678` 61705bf
- trace: fix wrong positioning of the ellipses on overflow `#D1684` b90ac78
- complete: do not generate keywords for quoted command names `#D1691` 60d244f
- menu (menu-style:align): fix the failure of delaying `ble/canvas/trace` on items (motivated by banoris) `#D1710` acc9661
- complete: fix empty completions with `FIGNORE` (reported by seanfarley) `#D1711` 144ea5d
- main: fix the message of owner errors of cache directories (reported by zim0369) `#D1712` b547a41
- util (`ble/string#escape-for-bash-specialchars`): fix escaping of TAB `#D1713` 7db3d2b
- complete: fix failglob messages while progcomp for commands containing globchars `#D1716` e26a3a8
  - complete: fix a bug that the default progcomp does not work properly `#D1722` 01643fa
- highlight: fix a bug that arrays without the element `0` is not highlighted `#D1721` b0a0b6f
- util (visible-bell): erase visible-bell before running external commands `#D1723` 0da0c1c
  - util(`ble/util/eval-pathname-expansion`): fix restoring shopt options in bash-4.0 `#D1825` 736f4da
- util (`ble/function`): work around `shopt -u extglob` `#D1725` 952c388
- syntax: fix uninitialized syntax-highlighting in bash-3.2 `#D1731` e3f5bf7
- make: fix a bug that config update messages are removed on install `#D1736` 72d968f
- util: fix bugs in conversions from `'` to `\''` `#D1739` 6d15782
- canvas: fix unupdated prompt on async wcwidth resolution `#D1740` e14fa5d
- progcomp: retry completions on `$? == 124` also for non-default completions (reported by SuperSandro2000) `#D1759` 82b9c01
- app: work around data corruption by WINCH on intermediate state `#D1762` 5065fda
- util (`ble/util/import`): work around filenames with bash special characters `#D1763` b27f758
- edit: fix the restore failure of `PS1` and `PROMPT_COMMAND` on `ble-detach` `#D1784` b9fdaab
- complete: do not attempt an independent rhs completion for arguments (reported by rsteube) `#D1787` f8bbe2c
- history: fix the unsaved history in the detached state `#D1795` 344168e
- edit: fix an unexpected leave from the command layout on `read` `#D1800` 4dbf16f
  - edit: fix the command layout remaining after job information (reported by mozirilla213) `#D1991` dcfb067
- history: work around possible dirty prefix `*` in the history output `#D1808` 64a740d
- decode (`ble-bind`): fix the printed definition of `-c`/`-x` bindings `#D1821` 94de078
- command-help (`.read-man`): add missing `ble/util/assign/.rmtmp` `#D1840` 937a164
- complete: fix wrong `COMP_POINT` with `progcomp_alias` `#D1841` 369f7c0
- main (`ble-update`): fix error message with system-wide installation of `ble.sh` (fixed by tars0x9752) 1d2a9c1 a450775
- main. util: fix problems of readlink etc. found by test in macOS (reported by aiotter) `#D1849` fa955c1 `#D1855` a22e145
- progcomp: fix a bug that `COMP_WORDBREAKS` is ignored `#D1872` 4d2dd35
- global: quote `return $?` `#D1884` 801d14a
- canvas (`ble/canvas/trace`): fix text justification for empty lines (reported by rashil2000) `#D1894` cdf74c2
- main: fix adjustments of bash options (reported by rashil2000) `#D1895` 138c476
- complete: suppress error messages for non-bash_completion `_parse_help` (reported by nik312123) `#D1900` 267de7f
- prompt: fix the marker position for the readline variable `show-mode-in-prompt` (reported by Strykar) `#D1903` 09bb4d3
- highlight: fix a bug that `bleopt filename_ls_colors` is not working (reported by qoreQyaS) `#D1919` b568ade
- bind: fix <kbd>M-C-@</kbd>, <kbd>C-x C-@</kbd>, and <kbd>M-C-x</kbd> (`bash-4.2 -o emacs`) `#D1920` a410b03
- complete (action:file): support `ble/syntax-raw` in the filename extraction (reported by qoreQyaS) `#D1921` 32277da
- decode: fix a bug that the tab completion do not work with bash-4.4 and lower `#D1928` 7da9bce
- complete: fix non-working ambiguous path completion with `..` and `.` in the path `#D1930` 632e90a
- main (`ble-reload`): fix failure by non-existent rcfile `#D1931` b7ae2fa
- syntax (`ble/syntax/highlight/vartype`): check variable in global scope `#D1932` b7026de
- menu (linewise): fix layout calculation with variable width of line prefix (reported by bkerin) `#D1979` cc852dc
- edit (`ble/textarea#render`): fix interleaving outputs to `_ble_util_buffer` and `DRAW_BUFF` `#D1987` 6d61388
- keymap/vi (`expand-range-for-linewise-operator`): fix the end point being not extended `#D1994` bce2033
- keymap/vi (`operator:filter`): do not append newline at the end of line `#D1994` bce2033
- highlight: fix shifted error marks after delayed `core-syntax` `#D2000` f4145f16
- syntax: fix unrecognized variable assignment of the form `echo arr[i]+=rhs` `#D2007` 41faa494
- menu (linewise): fix clipping of long line (reported by bkerin) `#D2025` 4c6a4775

## Documentation

- blerc: add all the missing options `#D1667` 0228d76
- blerc: add missing faces `argument_option` and `cmdinfo_cd_cdpath` (reported by Prikalel) `#D1675` 26aaf87
- README: describe how to invoke multiple widgets with a keybinding (motivated by michaelmob) `#D1699` 6123551
- README: add links to `bash-it` and `oh-my-bash` `#D1724` 4a2575f
- README: mention the Guix package (motivated by kiasoc5) `#D1888` 0f7c04b
- blerc: add frequently used keybindings (motivated by KiaraGrouwstra, micimize) `#D1896` `#D1897` e19b796
- wiki/Q&A: add item for defining a widget calling multiple widgets (motivated by micimize) `#D1898` e19b796
- blerc: rename from `blerc` to `blerc.template` `#D1899` e19b796
- README: add a link to the explanation on the "more reliable setup" of bashrc (motivated by telometto) `#D1905` 09bb4d3
- README: describe `contrib/fzf` integration (reported by SuperSandro2000, tbagrel1) `#D1907` 3bc3bea b568ade
- README: add links to Manual pages for *kspec* and `modifyOtherKeys` `#D1917` fb7bd0b1 b568ade
- README: explain the build process `#D1964` `#D1965` 14ca1e5

## Optimization

- syntax (`layer:syntax/word`): perform pathname expansions in background subshells (motivated by 3ximus) `#D1449` 13e7bdd
  - syntax (`simple-word/is-simple-noglob`): suppress error messages on expansions `#D1461` a56873f
  - syntax (`simple-word/eval`): fix unperformed tilde expansions in the background (reported by 3ximus) `#D1463` 6ebec48
  - syntax (`simple-word/eval`): propagate timeouts in sync highlighting (reported by 3ximus) `#D1465` c2555e2
  - edit: change the priority of `render-defer` and `menu-filter` `#D1501` aae553c
- complete: perform pathname expansions in subshells (motivated by 3ximus) `#D1450` d511896
- complete: support `bleopt complete_timeout_compvar` to time out pathname expansions for `COMP_WORDS` / `COMP_LINE` `#D1457` cc2881a
- complete (`ble/complete/source:file`): remove slow old codes (reported by timjrd) `#D1512` e5be0c1
- syntax (`ble/syntax:bash/simple-word/eval`): optimize large array passing (motivated by timjrd) `#D1522` c89aa23
  - syntax (`ble/syntax:bash/simple-word/eval`): use `mapfile -d ''` for Bash 5.2 `#D1604` 72c274e
- main: prefer `nawk` over `mawk` and `gawk` `#D1523` `#D1524` c89aa23
  - main (`ble/bin/.freeze-utility-path`): fix unupdated temporary implementations `#D1528` c70a3b4
  - util (`ble/util/assign`): work around subshell conflicts `#D1578` 6e4bb12
- history: use `mapfile -d ''` to load history in Bash 5.2 `#D1603` 72c274e
- prompt: use `${PS1@P}` when the prompt contains only safe prompt sequences `#D1617` 8b5da08
  - prompt: fix not properly set `$?` in `${PS1@P}` evaluation (reported by nihilismus) `#D1644` 521aff9
  - prompt: fix a bug that the special treatment of `\$` in Cygwin/MSYS is disabled `#D1741` 4782a33
- decode: cache `inputrc` translations `#D1652` 994e2a5
- complete: use `awk` for batch `quote-insert` (motivated by banoris) `#D1714` a0b2ad2 92d9734
  - complete (quote-insert.batch): fix regex escaping in bracket expr of awk (reported by telometto) `#D1729` 8039b77
- prompt: reduce redundant evaluation of `PROMPT_COMMAND` on the startup `#D1778` 042376b
- main: run `ble/base/unload` directly at the end of `EXIT` handler `#D1797` 115baec
- util: optimize `ble/util/writearray` `#D1816` 96e9bf8
- history: optimize processing of `erasedups` (motivated by SuperSandro2000) `#D1817` 944d48e
- debug: add `ble/debug/profiler` (motivated by SuperSandro2000) `#D1824` f629698 11aa4ab 7bb10a7
  - util (`ble/string#split`): optimize `#D1826` 7bb10a7
  - global: avoid passing arbitrary strings through `awk -v var=value` `#D1827` 82232de
  - edit: properly set `LINENO` for `PS1`, `PROMPT_COMMAND`, and `DEBUG` `#D1830` 4d24f84

## Compatibility

- term: work around quirks of Solaris xpg4 awk `#D1481` 6ca0b8c
- term: support key sequences and control sequences of Solaris console `#D1481` 6ca0b8c
- term: work around Cygwin-console bug of bottom `IL`/`DL` `#D1482` 5dce0b8
- term: work around leaked <kbd>DA2R</kbd> in screen from outside terminal `#D1485` e130619
- complete: work around `fzf` completion settings loaded automatically `#D1508` 4fc51ae
- complete: work around `bash-completion` bugs (reported by oc1024) `#D1533` 9d4ad56
- main: work around MSYS2 .inputrc (reported by n1kk) `#D1534` 9e786ae
- util (`modifyOtherKeys`): work around a quirk of kitty (reported by NoahGorny) `#D1549` f599525
  - util (`modifyOtherKeys`): update the workaround for a new quiark of kitty `#D1627` 3e4ecf5
  - util (`modifyOtherKeys`): use the kitty protocol for kitty 0.23+ which removes the support of `modifyOtherKeys` (reported by kovidgoyal) `#D1681` ec91574
  - util (`modifyOtherKeys`): set up `modifyOtherKeys` only after `DA2` (reported by dongxi8) `#D1885` 149eee9
- global: work around empty `vi_imap` cache by `tmux-resurrect` `#D1562` 560160b
- decode: identify `kitty` and treat `\e[27u` as isolated ESC (reported by lyiriyah) `#D1585` c2a84a2
- complete: suppress known error messages of `bash-completion` (reported by oc1024, Lun4m) `#D1622` d117973
- decode: work around kitty keypad keys in modifyOtherKeys (reported by Nudin) `#D1626` 27c80f9
- main: work around `set -B` and `set -k` `#D1628` a860769
- term: disable `modifyOtherKeys` and do not send `DA2` for `st` (requested by Shahabaz-Bagwan) `#D1632` 92c7b26
- cmap: add `st`-specific escape sequences for cursor keys `#D1633` acfb879
- cmap: distinguish <kbd>find</kbd>/<kbd>select</kbd> from <kbd>home</kbd>/<kbd>end</kbd> for openSUSE `inputrc.keys` (reported by cornfeedhobo) `#D1648` c4d28f4
  - cmap: freeze the internal codes of <kbd>find</kbd>/<kbd>select</kbd> and kitty special keys `#D1674` fdfe62a
- main: work around self-modifying `PROMPT_COMMAND` by `bash-preexec` (reported by cornfeedhobo) `#D1650` 39ebf53
  - main: fix an infinite loop on `ble-reload` with externally saved `PROMPT_COMMAND` (reported by tars0x9752) `#D1851` 53af663
- decode: work around openSUSE broken `/etc/inputrc` `#D1662` e5b0c86
- decode: work around the overwritten builtin `set` (reported by eadmaster) `#D1680` a6b4e2c
- complete: work around the variable leaks by `virsh` completion from `libvirt` (reported by telometto) `#D1682` f985b9a
- stty: do not remove keydefs for <kbd>C-u</kbd>, <kbd>C-v</kbd>, <kbd>C-w</kbd>, and <kbd>C-?</kbd> (reported by laoshaw) `#D1683` 82f74f0
- builtin: print usages of emulated builtins on option errors `#D1694` 6f74021
- decode (`ble/builtin/bind`): improve compatibility of the deprecated form `bind key:rlfunc` (motivated by cmplstofB) `#D1698` b6fc4f0
  - decode (`ble/builtin/bind`): fix a bug that only lowercase is accepted for deprecated form `bind key:rlfunc` (reported by returntrip) `#D1726` a67458e e363f1b
- complete: work around a false warning messages of gawk-4.0.2 `#D1709` 9771693
- main: work around `XDG_RUNTIME_DIR` of a different user by `su` (reported by zim0369) `#D1712` 8d37048
- main (`ble/util/readlink`): work around non-standard or missing `readlink` (motivated by peterzky) `#D1720` a41279e
  - util (`ble/function#pop`): allow popping unset function `#D1834` c0abc95
- menu (`menu-style:desc`): work around xenl quirks for relative cursor movements (reported by telometto) `#D1728` 3e136a6
- global: work around the arithmetic syntax error of `10#` in Bash-5.1 `#D1734` 7545ea3
- global: adjust implementations for Bash 5.2 `patsub_replacement` `#D1738` 4590997
  - global: work around `compat42` quoting of `"${v/pat/"$rep"}"` `#D1751` a75bb25
  - prompt: fix a bug of `ble/prompt/print` redundantly quoting `$` `#D1752` a75bb25
  - global: identify bash-4.2 bug that internal quoting of `${v/%$empty/"$rep"}` remains `#D1753` a75bb25
  - global: work around `shopt -s compat42` `#D1754` a75bb25
- global (`ble/builtin/*`): work around `set -eu` in NixOS initialization (reported by SuperSandro2000) `#D1743` 001c595
- util, edit, contrib: add support for `bash-preexec` (motivated by SuperSandro2000) `#D1744` e85f52c
  - util (`ble/builtin/trap`): fix resetting `$?` and `$_` (reported by SuperSandro2000) `#D1757` dfc6221
  - util (`ble/builtin/trap`): fix a failure of setting the trap-handler exit status (reported by SuperSandro2000) `#D1771` c513ed4
  - edit (`TRAPDEBUG`): partially restore `$_` after `DEBUG` trap (reported by aiotter) `#D1853` 0b95d5d
- main: check `IN_NIX_SHELL` to inactivate ble.sh in nix-shell (suggested by SuperSandro2000) `#D1747` b4bd955
  - main: force prompt-attach inside the nix-shell `rc` `#D1766` ceb2e7c
- canvas: test the terminal for the sequence of clearing `DECSTBM` `#D1748` 4b1601d
- main: check `/dev/tty` on startup (reported by andychu) `#D1749` 711c69f
  - main: fix the check of tty on stdin/stdout `#D1833` 80f09c9
- util: add identification of Windows Terminal `wt` `#D1758` e332dc5
- complete: evaluate words for `noquote` (motivated by SuperSandro2000) `#D1767` 0a42299
- edit (TRAPDEBUG): preserve original `DEBUG` trap and enabled it in `PROMPT_COMMAND` (motivated by ammarooo) `#D1772` `#D1773` ec2a67a
  - main, trap: fix initialization order of `{save,restore}-BASH_REMATCH` (reported by SuperSandro2000) `#D1780` 689534d
- global: work around bash-3.0 bug that single quotes remains for `"${v-$''}"` `#D1774` 9b96578
- util: work around old `vte` not supporting `DECSCUSR` yet setting `TERM=xterm` (reported by dongxi8) `#D1785` 70277d0
- progcomp: work around the cobra V2 description hack (reported by SuperSandro2000) `#D1803` 71d0736
- complete: work around blocking `_scp_remote_files` and `_dnf` (reported by iantra) `#D1807` a4a779e 46f5c13
- history: work around broken timestamps in `HISTFILE` (reported by johnyaku) `#D1831` 5ef28eb
- progcomp: disable `command_not_found_handle` (reported by telometto, wisnoskij) `#D1834` 64d471a d5fe1d1 973ae8c
- util (`modifyOtherKeys`): work around delayed terminal identification `#D1842` 14f3c81
  - util (`modifyOtherKeys`): fix a bug that kitty protocol is never activated `#D1842` 14f3c81
- util (`modifyOtherKeys`): pass-through kitty protocol sequences (motivated by ferdinandyb) `#D1845` f66e0c1
- main: show warning for empty locale (movivated by Ultra980) `#D1927` 92f2006
- main: never load `/etc/inputrc` in openSUSE (motivated by Ultra980) `#D1926` 92f2006 0ceb0cb
- canvas: refine detection of `bleopt char_width_mode=musl` `#D1929` b0c16dd
- term (`terminology`): work around terminal glitches `#D1946` 9a1b4f9
- main (`ble/bin/awk`): add workaround for macOS `awk-32` `#D1974` e2ec89c
- util.hook: workaround bash-5.2 bug of nested read by `WINCH` `#D1981` a5b10e8
  - main (`ble/base/adjust-builtin-wrappers`): fix persistent tempenv `IFS=` in bash-5.0 (reported by pt12lol) `#D2030` 5baf6f63
- edit: always adjust the terminal states with `bind -x` (reported by linwaytin) `#D1983` 5d14cf1
  - edit: restore `PS1` while processing `bind -x` (reported by adoyle-h) `#D2024` 2eadcd5b
- syntax: suppress brace expansions in designated array initialization in Bash 5.3 `#D1989` 1e7b884
- progcomp: work around slow `nix` completion `#D1997` 2c1aacf
- complete: suppress error messages from `_adb` (reported by mozirilla213) `#D2005` f2aa32b0

## Test

- github/workflows: add CI checks in macOS and msys2 (requested by aiotter) `##D1881` c5ddacc
  - github/workflows (nightly): add check for macOS (contributed by aiotter) `#D1881` 4cb0baa
  - github/workflows (nightly, test): interchange setup `#D1881` 4cb0baa
  - github/workflows: add `test.yml` `#D1881` 824dc53
  - fix for macOS tests
    - test (ble/util/c2s): fix locale settings in tests `#D1881` 26ed622
    - test (ble/util/msleep): loosen the condition `#D1881` 26ed622
    - test (ble/util/msleep): skip test in CI `#D1881` 26ed622
  - fix for msys2 tests
    - test: ensure a non-empty locale `#D1881` c5d1b82
    - test (ble/util/readlink): work around msys symlinks `#D1881` c5d1b82
    - test (ble/util/declare-print-definitions): skip array assignments involing CR in msys `#D1881` c5d1b82
    - test (ble/util/is-stdin-ready): skip test in the CI msys `#D1881` c5d1b82
    - main (bind): suppress non-interactive warning in msys `#D1881` c5d1b82
    - canvas (GraphemeClusterBreak): handle surrogate pairs for UCS-2 `wchar_t` `#D1881` 18bf121
    - util (ble/encoding:UTF-8/b2c): fix interpretation of leading byte `#D1881` 2e1a7c1
    - util (ble/util/s2c): work around intermediate mbstate of bash <= 5.2 `#D1881` 2e1a7c1
    - util (ble/util/s2bytes): clear locale cache `#D1881` 2e1a7c1
  - complete: fix syntax error for bash-3.0 `#D1881` 0b3e611
  - github/workflows: work around grep-3.0 which crashes in windows-latest `#D1915` fb7bd0b
- test (ble/util/writearray): use `ble/file#hash` instead of `sha256sum` `#D1882` b76e21e
- test (ble/util/readlink): work around external aliases `#D1890` 0c6291f

## Internal changes and fixes

- main: include hostname in local runtime directory `#D1444` 6494836
- global: update the style of document comments ff4c4e7
- util: add function `ble/string#quote-words` `#D1451` f03b87b
- syntax (`ble/syntax:bash/simple-word/eval`): cache `#D1453` 6d8311e
  - syntax (`simple-word/eval`): support `opts=single` for a better cache performance (motivated by 3ximus) `#D1464` 10caaa4
- global: refactor `setup => set up / set-up` `#D1456` c37a9dd
- global: clean up helps of user functions `#D1459` 33c283e
- benchmark (`ble-measure`): support `-T TIME` and `-B TIME` option `#D1460` 1aa471b
- util, color (`bleopt`, `blehook`, `ble-color-setface`): support `--color` and fix `sgr0` contamination in non-color output `#D1466` 69248ff
- global: fix status check for read timeout `#D1467` e886883
- decode: move `{keymap/*. => lib/core-decode.*-}rlfunc.txt` and clean up files `#D1486` f7323b4
  - Makefile: fix up f7323b4: restore rule for `keymap/*.txt` `#D1496` 054e5c1
- util, etc: ensure each function to work with arbitrary `IFS` `#D1490` `#D1491` 5f9adfe
- tui, canvas (`ble/canvas/trace`): support `opts=clip` `#D1493` 61ce90c
- tui, edit: add a new render mode for full-screen applications 817889d
- test (`test-canvas`): fix dependency on `ext/contra` `#D1525` c89aa23
- util: inherit special file descriptors `#D1552` 98835b5
  - util: fix a bug that old tty is used in new sessions `#D1586` 0e55b8e
- global: use `_ble_term_IFS` `#D1557` d23ad3c
- global: work around `localvar_inherit` for varname-list init `#D1566` 5c2edfc
- util: fix `ble/util/dense-array#fill-range` a46fdaf
- util: fix leak variables `buff`, `trap`, `{x,y}{1,2}` `#D1572` 5967d6c
- util: fix leak variables `#D1643` fcf634b
- edit (`command-help`): use `ble/util/assign/.mktmp` to determine the temporary filename `#D1663` 1af0800
- make: update lint check `#D1709` 7e26dcd
- test: save the test log to a file `#D1735` d8e6ea7
- benchmark: improve determination of the base time `#D1737` ad866c1
- make: add fallback Makefile for BSD make `#D1805` e5d8d00c
- main: support `bleopt debug_xtrace` (requested by SuperSandro2000) `#D1810` 022d38b
- test: clean up check failures by `make check` and `make scan` `#D1812` bb3e0a3
- util (`fd#alloc`): limit the search range of free fds `#D1813` 43be0e4 4c90072
- github/workflows: define an action for the nightly builds (contributed by uyha) `#D1814` a3082a0
- global: quote numbers for unexpected `IFS` `#D1835` 0179afc
- history: refactor hooks `history_{{delete,clear,insert} => change}` `#D1860` c393c93
- history: rename the hook `history_{on => }leave` `#D1860` c393c93
- make: check necessary `.git` `#D1887` 0f7c04b
- benchmark (zsh): fix for `KSH_ARRAYS` `#D1886` a144ffa 8cb9b84
- benchmark: support for ksh as `benchmark.ksh` `#D1886` 5dae4da
- github/workflows (build): rename directory in `ble-nightly.tar.xz` to `ble-nightly` (reported by Harduex) `#D1891` f20854f 4ea2e23 43c6d4b
- edit: update prompts on g2sgr change `#D1906` 40625ac
- util, decode, vi: fix leak variables `#D1933` 8d5cab8
- util: support `bleopt debug_idle` `#D1945` fa10184
- global: work around bash-4.4 no-argument return in trap `#D1970` eb4ffce
- util: replace builtin `readonly` with a shell function (requested by mozirilla213) `#D1985` 8683c84 e4758db
  - util (`ble/builtin/readonly`): show file and line in warnings `#D2015` 467fa448 2c9b56d7
- global: avoid directly using `/dev/tty` `#D1986` a835b83
- util: add `ble/util/message` `#D2001` 2a524f34
- global: normalize bracket expressions to `_a-zA-Z` / `_a-zA-Z0-9` `#D2006` 41faa494
- global: fix leak variables `#D2018` 6f5604de
- edit: handle nested WINCH properly `#D2020` a6b2c078
- make: include the source filenames in the installed files (suggested by bkerin) `#D2027` 610fab39

## Contrib

- prompt-git: detect staged changes `#D1718` 2b48e31
- prompt-git: fix a bug that information is not updated on reload `#D1732` 361e9c5
- config/execmark: show exit status in a separate line `#D1828` 4d24f84
  - config/execmark: add names of exit statuses `#D2019` a6b2c078
- prompt-git: ignore untracked files in submodules `#D1829` 4d24f84
- integration/fzf
  - fzf-completion: fix integration (reported by ferdinandyb) `#D1837` 12c022b
  - fzf-completion: remove `noquote` (reported by MK-Alias) `#D1889` 0c6291f
  - fzf-initialize: check directory existence before adding it to `PATH` (reported by Strykar) `#D1904` 09bb4d3
  - fzf-key-bindings: fix a problem that `modifyOtherKeys` is not reflected (reported by SuperSandro2000) `#D1908` 486564a
  - fzf-completion: quote only with `filenames` when `ble/syntax-raw` is specified (reported by christianknauer) `#D1978` 8965b61
- integration/zoxide
  - complete, contrib: add completion integration with `zoxide` (reported by ferdinandyb) `#D1838` a96bafe
  - zoxide: update `contrib/integration/zoxide` for zoxide v0.8.1 `#D1907` 3bc3bea
  - zoxide: adjust `zoxide icanon` (reported by linwaytin) `#D1993` dc7de6b
- README: update description on `_ble_contrib_fzf_base` (reported by Strykar) `#D1904` 09bb4d3
- colorglass: add color filter `#D1902` 88e74cc
  - colorglass: add `bleopt colorglass_{saturation,brightness}` (motivated by auwsom) `#D1906` 40625ac
- add `histdb` `#D1925` 44d9e10
  - histdb: support auto-complete source `histdb-word` `#D1938` 00cae74
  - histdb: automatically upgrade histdb version `#D1940` 4fac1e3
  - histdb: support auto-complete source `histdb-history` `#D1941` 4fac1e3
  - histdb: handle multiple exec lines for `histdb_ignore` `#D1942` 36e1c89
  - histdb: kill orphan `sqlite3` processes `#D1943` 36e1c89
  - histdb: back up the database `#D1944` 36e1c89
  - histdb: fix miscellaneous SQL query errors `#D1947` 46ac426
  - histdb: output error messages to tty `#D1952` 651c70c
  - histdb: fix remaining debug function name "assign{2 => }" in bash <= 3.2 `#D1953` 651c70c
  - histdb: fix a problem that the background process fails to start in bash-3.0 `#D1956` 651c70c
  - histdb: fix a bug that history search fails with a single quote in the commandline `#D1957` 651c70c
  - histdb: fix `histdb-word` completions in the middle of the commandline `#D1968` adaec05
  - histdb: support `bleopt histdb_remarks` `#D1968` adaec05
  - histdb: support timeout of background processes `#D1971` e0566bd
  - histdb: enable database timeout for transactions `#D1982` a5b10e8
  - histdb: fix `.timeout` not set for background `sqlite3` `#D1982` 20b42fa
  - histdb: suppress color codes in the default `histdb_remarks` `#D1968` 20b42fa
  - histdb: disable timeout of background processes in Bash 3.2 `#D1992` 20b42fa
  - histdb: rewrite to use `ble/util/bgproc` `#D2017` 7803305f
- integration: move `fzf` and `bash-preexec` integrations to subdir `#D1939` 86d9467

<!---------------------------------------------------------------------------->
# ble-0.4.0-devel2

2020-01-12 -- 2020-12-02 (`#D1215`...`#D1426`) c74abc5...276baf2

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
- syntax: allow unquoted `[!` and `[^` in `simple-word` (reported by cmplstofB) `#D1303` 1efe833
- util (`ble/util/print-global-definitions`): support arrays and unset variables (test-util) 6e85f1c
- util (`ble/util/cat`): support NUL and multiple files (test-util) d19a9af
- edit: support Bash 5.1 `READLINE_MARK` and `PROMPT_COMMANDS` `#D1328` e97a858 `#D1338` 657bea5
  - edit, main: support array PROMPT_COMMAND in bash-5.1 `#D1380` b852a4f
- syntax: support confusing parameter expansions like `${#@}`, etc. `#D1330` b7b42eb
- contrib: add contrib for user settings `#D1335` f290115
- syntax: support `${var@UuLK}` in Bash 5.1 `#D1336` 04da4dd
- main: add an option `--test` `#D1340` 1410c72
- util (`ble/builtin/trap`): support `return` in `INT`/`EXIT`/`WINCH` `#D1347` `#D1348` 3865488
- history: support timestamp (reported by rux616) `#D1351` 4bcbd71 `#D1356` 350bb15 `#D1364` 1d8adf9
- edit: support Bash 4.4 `PS0` `#D1357` 23a1ac5
- vi: support `bleopt keymap_vi_mode_{update_prompt,show,name_*}` (suggested by Dave-Elec) `#D1365` 76be6f1
- prompt: support prompt sequence `\q{...}` `#D1365` 76be6f1
- edit: support `bind 'set show-mode-in-prompt'` `#D1365` 76be6f1
  - prompt: fix a bug that mode string is not shown in `auto_complete` and other sub-modes (reported by tigger04) `#D1371` f6fc7ff
  - prompt: redraw prompts on the prompt content change (reported by tigger04) `#D1371` 1954a1e
- prompt: support `bleopt prompt_{{ps1,rps1}{_final,_transient}}` (suggested by Dave-Elec) `#D1366` 06381c9
  - prompt: fix a bug that prompt are always re-insntiated for every rendering `#D1374` 0770cda
  - prompt: fix a bug that rprompt is not cleared when `bleopt prompt_rps1` is reset `#D1377` 1904b1d
  - prompt: fix a bug that prompts updated by `PROMPT_COMMAND` are not reflected immediately (reported by 3ximus) `#D1426` bbda197
- edit: support Bash 5.1 widgets `#D1368` e747ee3
- color: support `TERM=*-direct` `#D1369` 0d38897 `#D1370` f7dc477
- complete: support `bleopt complete_auto_menu` `#D1373` 77bfabd
  - complete: fix a problem of frequent bells with auto-menu activated `#D1381` 3b1d8ac
- complete: support `bleopt complete_menu_maxlines` `#D1375` 8e81cd7
- prompt: support `_ble_prompt_update` `#D1376` 0fa8739
- prompt: support `bleopt prompt_{xterm_title,screen_title,status_line}` `#D1378` 5c3f6fe
  - prompt: check `TERM` for prompt window titles when `_ble_term_TERM` is unavailable `#D1388` 3c88869
- syntax: support options `bleopt highlight_{syntax,filename,vartype}` to turn off highlighting (requested by pjmp) `#D1379` 0116f8b
- complete: support `shopt progcomp_alias` `#D1397` d68afa5
- complete: generate completions of options based on man pages `#D1405` 8183455
  - complete (mandb): fix a bug that `bleopt complete_menu_style` is globally changed `#D1412` b91fd10
- highlight: support colon separated lists of paths `#D1409` 2f40422
  - highlight: fix a bug that non-simple words are always highlighted as `syntax_error` (reported by cmplstofB) `#D1411` 46e2ac6
  - highlight: fix a bug that words are sometimes unhighlighted `#D1418` 4395484
  - highlight: fix a bug that non-existent directories are not highlighted in the command name context `#D1419` 4395484
- highlight: support options `#D1410` 2f40422
  - highlight: support highlighting of `declare` command options `#D1420` f0df481
  - highlight: fix unhighlighted tilde expansions `~+` (reported by cmplstofB) `#D1424` a32962e

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
- util (`bleopt`): fail when a specified bleopt variable does not exist (test-util) 5966f22
- builtin: let redefined builtins return 2 for `--help` `#D1323` 731896c
- edit: preserve `PS1` when `internal_suppress_bash_output` is set `#D1344` 6ede0c7
- complete: complete param expan in additional contexts `#D1358` 3683305
- main: reload on ble-update when ble.sh is already updated `#D1359` a441d4d
- main (`ble-update`): clone github repository if the original repository is not found `#D1363` 6e3b3b5
- util (bleopt): change output format d4b12cd
- syntax: allow `time -- command` for Bash 5.1 `#D1367` 00d0e93
- menu: preserve columns with `{forward,backward}-line` `#D1396` 3d5a341
- syntax: rename `ble_debug` to `bleopt syntax_debug` `#D1398` 3cda58b
- syntax: change a style of buffer contents in `bleopt syntax_debug` `#D1399` 3cda58b
- complete: change to generate filenames starting from `.` by default (motivated by cmplstofB) `#D1425` 987436d

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
- complete: clear menu on discard-line (reported by animecyc) `#D1290` fb794b3 `#D1315` 99880ef
- vi (vi-command/nth-column): fix a bug in arithmetic expansion (reported by andychu) `#D1292` da6cc47
- complete: fix a bug that insert-word does not for with ambiguous candidates `#D1295` 2f9a000
- complete: fix a bug that menu-filter is only partially turned off by `complete_menu_filter` `#D1298` b3654e2
- decode: fix error messages for unsupported readline functions `#D1301` 91bdb64
- global: work around `shopt -s assoc_expand_once` `#D1305` 31908e1
- global: work around `TMOUT` for `builtin read` `#D1306` 1c22a9d
- syntax: fix failglob errors of heredocs of the form `<<$(echo A)` `#D1308` 3212fd2
- decode (`ble-bind`): fix an error message `#D1311` c868b6d
- util (`bleopt`): fix a bug that a new setting is not defined with `name:=` (test-util) `#D1312` c757b92
- util (`ble/util/{save,restore}-vars`): fix a bug that `name` and `prefix` cannot be saved/restored (test-util) 5f2480c
- util: fix `ble/is-{inttype,readonly,transformed}` (test-util) 485e1ac
- util (`ble/path#remove{,-glob}`): fix corner cases (test-util) ccbc9f8
- history: fix a problem that the history is doubled by `history -a` in `bashrc` `#D1314` 34821fe
- util (`ble/variable#get-attr`): fix an error message with special variable names such as `?` and `*` `#D1321` 557b774
- util (has-glob-pattern): fix abort in subshells (test-util) `#D1326` dc292a2
- edit: fix a bug that `set +H` is cancelled on command execution `#D1332` 02bdf4e
- syntax (`ble/syntax/parse/shift`): fix a bug of shift skip in nested words `#D1333` 65fbba0
- global: work around Bash-4.4 `return` in trap handlers `#D1334` aa09d15
- util (`ble-stackdump`): fix a shift of line numbers `#D1337` a14b72f d785b64
- edit (`ble-bind -x`): check range of `READLINE_{POINT,MARK}` `#D1339` efe1e81
- main: fix a bug that `~/.config/blesh/init.sh` is not detected (GitHub #53 by rux616) 61f9e10
- util (`ble/string#to{upper,lower}`): work around `LC_COLLATE=en_US.utf8` (test-util) `#D1341` 1f6b44e `#D1355` 4da6103 5f0d49f
- util (encoding, keyseq): fix miscelleneous encoding bugs (test-util) 435bd16
  - `ble/util/c2keyseq`: work around bash ambiguous keyseq `\M-\C-\\`
  - `ble/util/c2keyseq`: fix a bug that `C1` characters are not properly encoded
  - `ble/util/keyseq2chars`: fix a bug that `\xHH` is not properly processed
  - `ble/encoding:UTF-8/b2c`: work around Bash-4.2 arithmetic crash
  - `ble/encoding:UTF-8/b2c`: fix a bug that `G0` characters lose its seventh bit
  - `ble/encoding:UTF-8/c2b`: fix a bug that the first byte gets redundant bits
- edit: work around `WINCH` not updating `COLUMNS`/`LINES` after `ble-reload` `#D1345` a190455
- complete: initialize `bleopt complete_menu_style` options before `complete_load` hook (reported by rux616) `#D1352` 8a9a386
- main: fix problems caused by multiple `source ble.sh` in bashrc `#D1354` 5476933
- syntax: allow single-character variable name in named redirections `{a}<>` `#D1360` 4760409
- complete: quote `#` and `~` at the beginning of word `#D1362` f62fe54
- decode (`bind`): work around `shopt -s nocasematch` (reported by tigger04) `#D1372` 855cacf
- syntax (tree-enumerate): fix unmodified `wtype` of reconstructed words at the end `#D1385` 98576c7
- complete: fix a bug that progcomp retry by 124 caused the default completion again `#D1386` 98576c7
- complete: fix bugs that quotation disappears on ambiguous completion `#D1387` 98576c7
- complete: fix a bug of duplicated completions of filenames with spaces `#D1390` 98576c7
- complete: fix superlinear performace of ambiguous matching globpat `#D1389` 71afaba
- prompt: fix extra spaces on line folding before double width character `#D1400` d84bcd8
- prompt: fix a bug that lonig rps1 is not correctly turned off `#D1401` d84bcd8
- syntax (glob bracket expression): fix a bug of unsupported POSIX brackets `#D1402` 6fd9e22
- syntax (`ble/syntax:bash/simple-word/evaluate-path-spec`): fix a bug of unrecognized `[!...]` and `[^...]` `#D1403` 0b842f5
- complete (`cd`): fix duplicate candidates by `CDPATH` (reported by Lennart00 at `oh-my-bash`) `#D1415` 5777d7f
- complete (`source:file`): fix a bug that tilde expansion candidates are always filtered out `#D1416` 5777d7f
- complete: fix a problem of redundant unmatched ambiguous part with tilde expansions in the common prefix `#D1417` 5777d7f
- highlight: fix remaininig highlighting of vanishing words `#D1421` `#D1422` 1066653
- complete: fix a problem that the user setting `dotglob` is changed `#D1425` 987436d

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
- decode: work around Bash-4.1 bug that locale not applied with `LC_CTYPE=C eval command` (test-util) b2c7d1c
- util (`ble/variable#get-attr`): fix a bug that attributes are not obtained in Bash <= 4.3 (test-util) b2c7d1c
- decode: work around Bash-3.1 bug of `declare -f` rejecting special characters in function names (test-util) b2c7d1c
- edit (`ble/widget/bracketed-paste`): fix error messages on `paste_end` in older version of Bash (test-util) b2c7d1c
- decode: work around Bash-4.1 arithmetic bug of array subscripts evaluated in discarded branches `#D1320` 557b774
- complete: follow Bash-5.1 change of arithmetic literal `10#` `#D1322` 557b774
- decode: fix a bug of broken cmap cache found in ble-0.3 `#D1327` 16b56bf
- util (strftime): fix a bug not working with `-v var` option in Bash <= 4.1 (test-util) f1a2818
- complete: work around slow `compgen -c` in Cygwin `#D1329` 5327f5d
- edit: work around problems with `mc` (reported by onelittlehope) `#D1392` e97aa07
  - highlight: fix a problem that the attribute of the last character is applied till EOL `#D1393` 2ddb1ba `#D1395` ef09932

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
- global: normalize calls of builtins `#D1313` b3b06f7
- test: refactor test `#D1316` `#D1317` 6c2f863
- util (`ble/util/openat`): change to open unused fds `#D1318` 6c2f863
- util: rename `ble/{util/openat => fd#alloc}` `#D1319` 6c2f863
- util (`ble/function#advice remove`): restore original command 149a640
- edit: rename `ble-edit/prompt/*` -> `ble/prompt/*` `#D1365` 76be6f1
- main: use `PROMPT_COMMAND` in bash-5.1 for prompt attach `#D1380` b852a4f
- main: unset `BLE_VERSION`, `_ble_bash`, etc. on `ble-unload` `#D1382` 6b615b6
- util: revisit `ble/variable#is-global` implementation `#D1383` 6b5468f
- cmap: recognize <kbd>SS3 O</kbd> as <kbd>blur</kbd> `#D1384` 445a5ad
- edit (`ble/widget/{accept-line,newline}`): automatically switch widgets by the keymap `#D1391` 5bed6e6
- complete: perform filter in `ble/complete/cand/yield` `#D1404` 7c6b67b 83fa830
  - complete: fix a bug that `ble/cmdinfo/complete:cd` candidates are unfiltered (reported by cmplstofB) `#D1413` 5c17a31
  - complete: fix unfiltered tilde expansions `#D1414` 5777d7f
  - complete: fix candidate filter failure in dynamic sabbrev expansion (reported by darrSonik) `#D1423` dabc515
- syntax, edit: use `type -a -t -- cmd` to get command types hidden by keywords `#D1406` ef2d912
- edit, complete: replace some external commands with Bash builtin `#D1407` 5386e93

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
  - ble-core.sh (ble-term/visible-bell): Add a function `ble/util/getmtime` to get modified time of files in a compatible way.
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
* ble-syntax.sh (_ble_syntax_stat): 解析状態に tchild, tprev (兄・子へのoffset情報) を追加。
* ble-syntax.sh (_ble_syntax_word): 形式変更。兄・子へのoffset情報はその場で計算する暫定方式。

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
