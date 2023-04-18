#!/bin/bash
#%$> out/ble.sh
#%[release = 0]
#%[measure_load_time = 0]
#%[debug_keylogger = 1]
#%[leakvar = ""]
#%#----------------------------------------------------------------------------
#%if measure_load_time
_ble_debug_measure_fork_count=$(echo $BASHPID)
TIMEFORMAT='[Elapsed %Rs; CPU U:%Us S:%Ss (%P%%)]'
function ble/debug/measure-set-timeformat {
  local title=$1 opts=$2
  local new=$(echo $BASHPID)
  local fork=$(((new-_ble_debug_measure_fork_count-1)&0xFFFF))
  _ble_debug_measure_fork_count=$new
  TIMEFORMAT="[Elapsed %Rs; CPU U:%Us S:%Ss (%P%%)] $title"
  [[ :$opts: != *:nofork:* ]] &&
    TIMEFORMAT=$TIMEFORMAT" ($fork forks)"
}
#%end
#%if leakvar
#%%expand
$"leakvar"=__t1wJltaP9nmow__
#%%end.i
function ble/bin/grep { command grep "$@"; }
function ble/util/print { printf '%s\n' "$*"; }
source "${BASH_SOURCE%/*}/lib/core-debug.sh"
#%end
#%define inc
#%%[guard_name = "@_included".replace("[^_a-zA-Z0-9]", "_")]
#%%expand
#%%%if $"guard_name" != 1
#%%%%[$"guard_name" = 1]
###############################################################################
# Included from @.sh

#%%%%if leakvar
ble/debug/leakvar#check $"leakvar" "[before include @.sh]"
#%%%%end.i
#%%%%if measure_load_time
time {
#%%%%%include @.sh
ble/debug/measure-set-timeformat '@.sh'
}
#%%%%else
#%%%%%include @.sh
#%%%%end
#%%%%if leakvar
ble/debug/leakvar#check $"leakvar" "[after include @.sh]"
#%%%%end.i
#%%%end
#%%end.i
#%end
#%#----------------------------------------------------------------------------
# ble.sh -- Bash Line Editor (https://github.com/akinomyoga/ble.sh)
#
#   Bash configuration designed to be sourced in interactive bash sessions.
#
#   Copyright: 2013, 2015-2019, Koichi Murase <myoga.murase@gmail.com>
#

#%if measure_load_time
echo "ble.sh: $EPOCHREALTIME load start" >&2
time {
echo "ble.sh: $EPOCHREALTIME parsed" >&2
# load_time (2015-12-03)
#   core           12ms
#   decode         10ms
#   color           2ms
#   edit            9ms
#   syntax          5ms
#   ble-initialize 14ms
time {
#%end
#------------------------------------------------------------------------------
# check --help or --version

{
  #%[commit_hash = system("git show -s --format=%h")]
  #%[ble_version = getenv("FULLVER") + "+" + commit_hash]
  #%expand
  ##%if commit_hash != ""
  _ble_init_version=$"ble_version"
  ##%else
  ###%error Failed to get the commit id (version = $"ble_version").
  ##%end
  #%end.i
  _ble_init_exit=
  _ble_init_command=
  for _ble_init_arg; do
    case $_ble_init_arg in
    --version)
      _ble_init_exit=0
      echo "ble.sh (Bash Line Editor), version $_ble_init_version" ;;
    --help)
      _ble_init_exit=0
      printf '%s\n' \
             "# ble.sh (Bash Line Editor), version $_ble_init_version" \
             'usage: source ble.sh [OPTION...]' \
             '' \
             'OPTION' \
             '' \
             '  --help' \
             '    Show this help and exit' \
             '  --version' \
             '    Show version and exit' \
             '  --test' \
             '    Run test and exit' \
             '  --update' \
             '    Update ble.sh and exit' \
             '  --clear-cache' \
             '    Clear ble.sh cache and exit' \
             '' \
             '  --rcfile=BLERC' \
             '  --init-file=BLERC' \
             '    Specify the ble init file. The default is ~/.blerc if any, or' \
             '    ~/.config/blesh/init.sh.' \
             '' \
             '  --norc' \
             '    Do not load the ble init file.' \
             '' \
             '  --attach=ATTACH' \
             '  --noattach' \
             '    The option "--attach" selects the strategy of "ble-attach" from the list:' \
             '    ATTACH = "attach" | "prompt" | "none". The default strategy is "prompt".' \
             '    When "attach" is specified, ble.sh immediately attaches to the session in' \
             '    "source ble.sh".  When "prompt" is specified, ble.sh attaches to the' \
             '    session before the first prompt using PROMPT_COMMAND.  When "none" is' \
             '    specified, ble.sh does not attach to the session automatically, so' \
             '    ble-attach needs to be called explicitly.  The option "--noattach" is a' \
             '    synonym for "--attach=none".' \
             '' \
             '  --inputrc=TYPE' \
             '  --noinputrc' \
             '    The option "--inputrc" selects the strategy of reconstructing user' \
             '    keybindings from the list: "auto" (default), "diff", "all", "user", "none".' \
             '    When "diff" is specified, user keybindings are extracted by the diff of the' \
             '    outputs of the "bind" builtin between the current session and the plain' \
             '    Bash.  When "all" is specified, the user keybindings are extracted from' \
             '    /etc/inputrc and ${INPUTRC:-~/.inputrc*}.  When "user" is specified, the' \
             '    user keybindings are extracted from ${INPUTRC:-~/.inputrc*}.  When "none"' \
             '    is specified, the user keybindings are not reconstructed from the state of' \
             '    Readline, and only the bindings by "ble-bind" are applied.  The option' \
             '    "--noinputrc" is a synonym for "--inputrc=none".' \
             '' \
             '  --keep-rlvars' \
             '    Do not change readline settings for ble.sh' \
             '' \
             '  -o BLEOPT=VALUE' \
             '    Set a value for the specified bleopt option.' \
             '  --debug-bash-output' \
             '    Internal settings for debugging' \
             '' ;;
    --test | --update | --clear-cache | --lib) _ble_init_command=1 ;;
    esac
  done
  if [ -n "$_ble_init_exit" ]; then
    unset _ble_init_version
    unset _ble_init_arg
    unset _ble_init_exit
    unset _ble_init_command
    return 0 2>/dev/null || exit 0
  fi
} 2>/dev/null # set -x 対策 #D0930

#------------------------------------------------------------------------------
# check shell

if [ -z "${BASH_VERSION-}" ]; then
  echo "ble.sh: This shell is not Bash. Please use this script with Bash." >&3
  return 1 2>/dev/null || exit 1
fi 3>&2 >/dev/null 2>&1 # set -x 対策 #D0930

if [ -z "${BASH_VERSINFO-}" ] || [ "${BASH_VERSINFO-0}" -lt 3 ]; then
  echo "ble.sh: Bash with a version under 3.0 is not supported." >&3
  return 1 2>/dev/null || exit 1
fi 3>&2 >/dev/null 2>&1 # set -x 対策 #D0930

if [[ ! $_ble_init_command ]]; then
  if [[ ${BASH_EXECUTION_STRING+set} ]]; then
    # builtin echo "ble.sh: ble.sh will not be activated for Bash started with '-c' option." >&3
    return 1 2>/dev/null || builtin exit 1
  fi

  if ((BASH_SUBSHELL)); then
    builtin echo "ble.sh: ble.sh cannot be loaded into a subshell." >&3
    return 1 2>/dev/null || builtin exit 1
  elif [[ $- != *i* ]]; then
    case " ${BASH_SOURCE[*]##*/} " in
    (*' .bashrc '* | *' .bash_profile '* | *' .profile '* | *' bashrc '* | *' profile '*) ((0)) ;;
    esac &&
      builtin echo "ble.sh: This is not an interactive session." >&3 || ((1))
    return 1 2>/dev/null || builtin exit 1
  elif ! [[ -t 4 && -t 5 ]] && ! ((1)) >/dev/tty; then
    builtin echo "ble.sh: cannot find a controlling TTY/PTY in this session." >&3
    return 1 2>/dev/null || builtin exit 1
  fi
fi 3>&2 4<&0 5>&1 &>/dev/null # set -x 対策 #D0930

{
  ## @var _ble_bash_POSIXLY_CORRECT_adjusted
  ##   現在 POSIXLY_CORRECT 状態を待避した状態かどうかを保持します。
  ## @var _ble_bash_POSIXLY_CORRECT_set
  ##   待避した POSIXLY_CORRECT の設定・非設定状態を保持します。
  ## @var _ble_bash_POSIXLY_CORRECT_set
  ##   待避した POSIXLY_CORRECT の値を保持します。
  _ble_bash_POSIXLY_CORRECT_adjusted=1
  _ble_bash_POSIXLY_CORRECT_set=${POSIXLY_CORRECT+set}
  _ble_bash_POSIXLY_CORRECT=${POSIXLY_CORRECT-}

  POSIXLY_CORRECT=y

  # 暫定対策 expand_aliases (ble/base/adjust-bash-options を呼び出す迄の暫定)
  _ble_bash_expand_aliases=
  \shopt -q expand_aliases &&
    _ble_bash_expand_aliases=1 &&
    \shopt -u expand_aliases || ((1))

  # 対策 FUNCNEST
  _ble_bash_FUNCNEST_adjusted=
  _ble_bash_FUNCNEST=
  _ble_bash_FUNCNEST_set=
  _ble_bash_FUNCNEST_adjust='
    if [[ ! $_ble_bash_FUNCNEST_adjusted ]]; then
      _ble_bash_FUNCNEST_adjusted=1
      _ble_bash_FUNCNEST_set=${FUNCNEST+set}
      _ble_bash_FUNCNEST=${FUNCNEST-}
      builtin unset -v FUNCNEST
    fi 2>/dev/null'
  _ble_bash_FUNCNEST_restore='
    if [[ $_ble_bash_FUNCNEST_adjusted ]]; then
      _ble_bash_FUNCNEST_adjusted=
      if [[ $_ble_bash_FUNCNEST_set ]]; then
        FUNCNEST=$_ble_bash_FUNCNEST
      else
        builtin unset -v FUNCNEST
      fi
    fi 2>/dev/null'
  \builtin eval -- "$_ble_bash_FUNCNEST_adjust"

  \builtin unset -v POSIXLY_CORRECT
} 2>/dev/null

function ble/base/workaround-POSIXLY_CORRECT {
  # This function will be overwritten by ble-decode
  true
}
function ble/base/unset-POSIXLY_CORRECT {
  if [[ ${POSIXLY_CORRECT+set} ]]; then
    builtin unset -v POSIXLY_CORRECT
    ble/base/workaround-POSIXLY_CORRECT
  fi
}
function ble/base/adjust-POSIXLY_CORRECT {
  if [[ $_ble_bash_POSIXLY_CORRECT_adjusted ]]; then return 0; fi # Note: set -e 対策
  _ble_bash_POSIXLY_CORRECT_adjusted=1
  _ble_bash_POSIXLY_CORRECT_set=${POSIXLY_CORRECT+set}
  _ble_bash_POSIXLY_CORRECT=${POSIXLY_CORRECT-}
  if [[ $_ble_bash_POSIXLY_CORRECT_set ]]; then
    builtin unset -v POSIXLY_CORRECT
  fi

  # ユーザが触ったかもしれないので何れにしても workaround を呼び出す。
  ble/base/workaround-POSIXLY_CORRECT
}
function ble/base/restore-POSIXLY_CORRECT {
  if [[ ! $_ble_bash_POSIXLY_CORRECT_adjusted ]]; then return 0; fi # Note: set -e の為 || は駄目
  _ble_bash_POSIXLY_CORRECT_adjusted=
  if [[ $_ble_bash_POSIXLY_CORRECT_set ]]; then
    POSIXLY_CORRECT=$_ble_bash_POSIXLY_CORRECT
  else
    ble/base/unset-POSIXLY_CORRECT
  fi
}
function ble/base/is-POSIXLY_CORRECT {
  if [[ $_ble_bash_POSIXLY_CORRECT_adjusted ]]; then
    [[ $_ble_bash_POSIXLY_CORRECT_set ]]
  else
    [[ ${POSIXLY_CORRECT+set} ]]
  fi
}

{
  _ble_bash_builtins_adjusted=
  _ble_bash_builtins_save=
} 2>/dev/null # set -x 対策
## @fn ble/base/adjust-builtin-wrappers/.assign
##   @remarks This function may be called with POSIXLY_CORRECT=y
function ble/base/adjust-builtin-wrappers/.assign {
  if [[ ${_ble_util_assign_base-} ]]; then
    local _ble_local_tmpfile; ble/util/assign/mktmp
    builtin eval -- "$1" >| "$_ble_local_tmpfile"
    local IFS=
    ble/bash/read -d '' defs < "$_ble_local_tmpfile"
    IFS=$_ble_term_IFS
    ble/util/assign/rmtmp
  else
    defs=$(builtin eval -- "$1")
  fi || ((1))
}
function ble/base/adjust-builtin-wrappers-1 {
  # Note: 何故か local POSIXLY_CORRECT の効果が
  #   builtin unset -v POSIXLY_CORRECT しても残存するので関数に入れる。
  # Note: set -o posix にしても read, type, builtin, local 等は上書き
  #   された儘なので難しい。unset -f builtin さえすれば色々動く様になる
  #   ので builtin は unset -f builtin してしまう。
  unset -f builtin
  builtin local POSIXLY_CORRECT=y builtins1 keywords1
  builtins1=(builtin unset enable unalias return break continue declare local typeset eval exec set)
  keywords1=(if then elif else case esac while until for select do done '{' '}' '[[' function)
  if [[ ! $_ble_bash_builtins_adjusted ]]; then
    _ble_bash_builtins_adjusted=1

    builtin local defs
    ble/base/adjust-builtin-wrappers/.assign '
      \builtin declare -f "${builtins1[@]}" || ((1))
      \builtin alias "${builtins1[@]}" "${keywords1[@]}" || ((1))' # set -e 対策
    _ble_bash_builtins_save=$defs
  fi
  builtin unset -f "${builtins1[@]}"
  builtin unalias "${builtins1[@]}" "${keywords1[@]}" || ((1)) # set -e 対策
  ble/base/unset-POSIXLY_CORRECT
} 2>/dev/null
function ble/base/adjust-builtin-wrappers-2 {
  # Workaround (bash-3.0..4.3) #D0722
  #
  #   builtin unset -v POSIXLY_CORRECT でないと unset -f : できないが、
  #   bash-3.0 -- 4.3 のバグで、local POSIXLY_CORRECT の時、
  #   builtin unset -v POSIXLY_CORRECT しても POSIXLY_CORRECT が有効であると判断されるので、
  #   "unset -f :" (非POSIX関数名) は別関数で adjust-POSIXLY_CORRECT の後で実行することにする。

  # function :, alias : の保存
  local defs
  ble/base/adjust-builtin-wrappers/.assign 'LC_ALL= LC_MESSAGES=C builtin type :; alias :' || ((1)) # set -e 対策
  defs=${defs#$': is a function\n'}
  _ble_bash_builtins_save=$_ble_bash_builtins_save$'\n'$defs

  builtin unset -f :
  builtin unalias : || ((1)) # set -e 対策
} 2>/dev/null
function ble/base/restore-builtin-wrappers {
  if [[ $_ble_bash_builtins_adjusted ]]; then
    _ble_bash_builtins_adjusted=
    builtin eval -- "$_ble_bash_builtins_save"
  fi
}
{
  ble/base/adjust-builtin-wrappers-1
  ble/base/adjust-builtin-wrappers-2

  # 対策 expand_aliases (暫定) 終了
  if [[ $_ble_bash_expand_aliases ]]; then
    shopt -s expand_aliases
  fi
} 2>/dev/null # set -x 対策

# From src/util.sh
function ble/variable#copy-state {
  local src=$1 dst=$2
  if [[ ${!src+set} ]]; then
    builtin eval -- "$dst=\${$src}"
  else
    builtin unset -v "$dst[0]" 2>/dev/null || builtin unset -v "$dst"
  fi
}

# BASH_XTRACEFD は書き換えると勝手に元々設定されていた fd を閉じてしまうので、
# 元々の fd を dup しておくなど特別な配慮が必要。
{
  _ble_bash_xtrace=()
  _ble_bash_xtrace_debug_enabled=
  _ble_bash_xtrace_debug_filename=
  _ble_bash_xtrace_debug_fd=
  _ble_bash_XTRACEFD=
  _ble_bash_XTRACEFD_set=
  _ble_bash_XTRACEFD_dup=
  _ble_bash_PS4=
} 2>/dev/null # set -x 対策
# From src/util.sh (ble/fd#is-open and ble/fd#alloc/.nextfd)
function ble/base/xtrace/.fdcheck { builtin : >&"$1"; } 2>/dev/null
function ble/base/xtrace/.fdnext {
  local _ble_local_init=${_ble_util_openat_nextfd:=${bleopt_openat_base:-30}}
  for (($1=_ble_local_init;$1<_ble_local_init+1024;$1++)); do
    ble/base/xtrace/.fdcheck "${!1}" || break
  done
  (($1<_ble_local_init+1024)) ||
    { (($1=_ble_local_init,_ble_util_openat_nextfd++)); builtin eval "exec ${!1}>&-"; } ||
    ((1))
} 
function ble/base/xtrace/.log {
  local bash=${_ble_bash:-$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))}
  local open=---- close=----
  if ((bash>=40200)); then
    builtin printf '%s [%(%F %T %Z)T] %s %s\n' "$open" -1 "$1" "$close"
  else
    builtin printf '%s [%s] %s %s\n' "$open" "$(date 2>/dev/null)" "$1" "$close"
  fi >&"${BASH_XTRACEFD:-2}"
}
function ble/base/xtrace/adjust {
  local level=${#_ble_bash_xtrace[@]} IFS=$' \t\n'
  if [[ $- == *x* ]]; then
    _ble_bash_xtrace[level]=1
  else
    _ble_bash_xtrace[level]=
  fi
  set +x

  ((level==0)) || return 0
  _ble_bash_xtrace_debug_enabled=
  if [[ ${bleopt_debug_xtrace:-/dev/null} == /dev/null ]]; then
    if [[ $_ble_bash_xtrace_debug_fd ]]; then
      builtin eval "exec $_ble_bash_xtrace_debug_fd>&-" || return 0
      _ble_bash_xtrace_debug_filename=
      _ble_bash_xtrace_debug_fd=
    fi
  else
    if [[ $_ble_bash_xtrace_debug_filename != "$bleopt_debug_xtrace" ]]; then
      _ble_bash_xtrace_debug_filename=$bleopt_debug_xtrace
      [[ $_ble_bash_xtrace_debug_fd ]] || ble/base/xtrace/.fdnext _ble_bash_xtrace_debug_fd
      builtin eval "exec $_ble_bash_xtrace_debug_fd>>\"$bleopt_debug_xtrace\"" || return 0
    fi

    _ble_bash_XTRACEFD=${BASH_XTRACEFD-}
    _ble_bash_XTRACEFD_set=${BASH_XTRACEFD+set}
    if [[ ${BASH_XTRACEFD-} =~ ^[0-9]+$ ]] && ble/base/xtrace/.fdcheck "$BASH_XTRACEFD"; then
      ble/base/xtrace/.fdnext _ble_bash_XTRACEFD_dup
      builtin eval "exec $_ble_bash_XTRACEFD_dup>&$BASH_XTRACEFD" || return 0
      builtin eval "exec $BASH_XTRACEFD>&$_ble_bash_xtrace_debug_fd" || return 0
    else
      _ble_bash_XTRACEFD_dup=
      local newfd; ble/base/xtrace/.fdnext newfd
      builtin eval "exec $newfd>&$_ble_bash_xtrace_debug_fd" || return 0
      BASH_XTRACEFD=$newfd
    fi

    ble/variable#copy-state PS4 _ble_base_PS4
    PS4=${bleopt_debug_xtrace_ps4:-'+ '}

    _ble_bash_xtrace_debug_enabled=1
    ble/base/xtrace/.log "$FUNCNAME"
    set -x
  fi
}
function ble/base/xtrace/restore {
  local level=$((${#_ble_bash_xtrace[@]}-1)) IFS=$' \t\n'
  ((level>=0)) || return 0
  if [[ ${_ble_bash_xtrace[level]-} ]]; then
    set -x
  else
    set +x
  fi
  builtin unset -v '_ble_bash_xtrace[level]'

  ((level==0)) || return 0
  if [[ $_ble_bash_xtrace_debug_enabled ]]; then
    ble/base/xtrace/.log "$FUNCNAME"
    _ble_bash_xtrace_debug_enabled=

    # Note: ユーザーの BASH_XTRACEFD にごみが混入しない様にする為、
    # BASH_XTRACEFD を書き換える前に先に PS4 を戻す。
    ble/variable#copy-state _ble_base_PS4 PS4

    if [[ $_ble_bash_XTRACEFD_dup ]]; then
      # BASH_XTRACEFD の fd を元の出力先に繋ぎ直す
      builtin eval "exec $BASH_XTRACEFD>&$_ble_bash_XTRACEFD_dup" &&
        builtin eval "exec $_ble_bash_XTRACEFD_dup>&-" || ((1))
    else
      # BASH_XTRACEFD の fd は新しく割り当てた fd なので値上書きで閉じて良い
      if [[ $_ble_bash_XTRACEFD_set ]]; then
        BASH_XTRACEFD=$_ble_bash_XTRACEFD
      else
        builtin unset -v BASH_XTRACEFD
      fi
    fi
  fi
}

function ble/base/.adjust-bash-options {
  builtin eval -- "$1=\$-"
  set +evukT -B
  ble/base/xtrace/adjust

  [[ $2 == shopt ]] || local shopt
  if ((_ble_bash>=40100)); then
    shopt=$BASHOPTS
  else
    # Note: nocasematch は bash-3.1 以上
    shopt=
    shopt -q extdebug 2>/dev/null && shopt=$shopt:extdebug
    shopt -q nocasematch 2>/dev/null && shopt=$shopt:nocasematch
  fi
  [[ $2 == shopt ]] || builtin eval -- "$2=\$shopt"
  shopt -u extdebug
  shopt -u nocasematch 2>/dev/null
  return 0
} 2>/dev/null # set -x 対策
## @fn ble/base/.restore-bash-options var_set var_shopt
##   @param[out] var_set var_shopt
function ble/base/.restore-bash-options {
  local set=${!1} shopt=${!2}
  [[ :$shopt: == *:nocasematch:* ]] && shopt -s nocasematch
  [[ :$shopt: == *:extdebug:* ]] && shopt -s extdebug
  ble/base/xtrace/restore
  [[ $set == *B* ]] || set +B
  [[ $set == *T* ]] && set -T
  [[ $set == *k* ]] && set -k
  [[ $set == *u* ]] && set -u
  [[ $set == *v* ]] && set -v
  [[ $set == *e* ]] && set -e # set -e は最後
  return 0
} 2>/dev/null # set -x 対策

{
  : "${_ble_bash_options_adjusted=}"
  _ble_bash_set=$-
  _ble_bash_shopt=${BASHOPTS-}
} 2>/dev/null # set -x 対策
function ble/base/adjust-bash-options {
  [[ $_ble_bash_options_adjusted ]] && return 1 || ((1)) # set -e 対策
  _ble_bash_options_adjusted=1

  ble/base/.adjust-bash-options _ble_bash_set _ble_bash_shopt

  # Note: expand_aliases はユーザー設定を復元する為に記録する
  _ble_bash_expand_aliases=
  shopt -q expand_aliases 2>/dev/null &&
    _ble_bash_expand_aliases=1

  # locale 待避
  # Note #D1854: ble/widget/display-shell-version で此処で待避した変数を参照す
  #   る事に注意する。此処に新しい変数を追加する時は display-shell-version の方
  #   にも処理スキップを追加する必要がある。
  ble/variable#copy-state LC_ALL _ble_bash_LC_ALL
  if [[ ${LC_ALL-} ]]; then
    ble/variable#copy-state LC_CTYPE    _ble_bash_LC_CTYPE
    ble/variable#copy-state LC_MESSAGES _ble_bash_LC_MESSAGES
    ble/variable#copy-state LC_NUMERIC  _ble_bash_LC_NUMERIC
    ble/variable#copy-state LC_TIME     _ble_bash_LC_TIME
    ble/variable#copy-state LANG        _ble_bash_LANG
    [[ ${LC_CTYPE-}    ]] && LC_CTYPE=$LC_ALL
    [[ ${LC_MESSAGES-} ]] && LC_MESSAGES=$LC_ALL
    [[ ${LC_NUMERIC-}  ]] && LC_NUMERIC=$LC_ALL
    [[ ${LC_TIME-}     ]] && LC_TIME=$LC_ALL
    LANG=$LC_ALL
    LC_ALL=
  fi
  ble/variable#copy-state LC_COLLATE _ble_bash_LC_COLLATE
  LC_COLLATE=C

  # TMOUT 確認 #D1630 WA readonly TMOUT
  if local TMOUT= 2>/dev/null; then # #D1630 WA
    _ble_bash_tmout_wa=()
  else
    _ble_bash_tmout_wa=(-t 2147483647)
  fi
} 2>/dev/null # set -x 対策 #D0930 / locale 変更
function ble/base/restore-bash-options {
  [[ $_ble_bash_options_adjusted ]] || return 1
  _ble_bash_options_adjusted=

  # locale 復元
  ble/variable#copy-state _ble_bash_LC_COLLATE LC_COLLATE
  if [[ $_ble_bash_LC_ALL ]]; then
    ble/variable#copy-state _ble_bash_LC_CTYPE    LC_CTYPE
    ble/variable#copy-state _ble_bash_LC_MESSAGES LC_MESSAGES
    ble/variable#copy-state _ble_bash_LC_NUMERIC  LC_NUMERIC
    ble/variable#copy-state _ble_bash_LC_TIME     LC_TIME
    ble/variable#copy-state _ble_bash_LANG        LANG
  fi
  ble/variable#copy-state _ble_bash_LC_ALL LC_ALL

  [[ $_ble_bash_nocasematch ]] && shopt -s nocasematch

  ble/base/.restore-bash-options _ble_bash_set _ble_bash_shopt
} 2>/dev/null # set -x 対策 #D0930 / locale 変更
function ble/base/recover-bash-options {
  # bind -x が終わる度に設定が復元されてしまうので毎回設定し直す #D1526 #D1574
  if [[ $_ble_bash_expand_aliases ]]; then
    shopt -s expand_aliases
  else
    shopt -u expand_aliases
  fi
}

{ ble/base/adjust-bash-options; } &>/dev/null # set -x 対策 #D0930

builtin bind &>/dev/null # force to load .inputrc

# WA #D1534 workaround for msys2 .inputrc
if [[ $OSTYPE == msys* ]]; then
  [[ $(builtin bind -m emacs -p 2>/dev/null | grep '"\\C-?"') == '"\C-?": backward-kill-line' ]] &&
    builtin bind -m emacs '"\C-?": backward-delete-char' 2>/dev/null
fi

if [[ ! -o emacs && ! -o vi && ! $_ble_init_command ]]; then
  builtin echo "ble.sh: ble.sh is not intended to be used with the line-editing mode disabled (--noediting)." >&2
  ble/base/restore-bash-options
  ble/base/restore-builtin-wrappers
  ble/base/restore-POSIXLY_CORRECT
  builtin eval -- "$_ble_bash_FUNCNEST_restore"
  return 1 2>/dev/null || builtin exit 1
fi

if shopt -q restricted_shell; then
  builtin echo "ble.sh: ble.sh is not intended to be used in restricted shells (--restricted)." >&2
  ble/base/restore-bash-options
  ble/base/restore-builtin-wrappers
  ble/base/restore-POSIXLY_CORRECT
  builtin eval -- "$_ble_bash_FUNCNEST_restore"
  return 1 2>/dev/null || builtin exit 1
fi

#--------------------------------------
# save IFS / BASH_REMATCH

function ble/init/adjust-IFS {
  _ble_init_original_IFS_set=${IFS+set}
  _ble_init_original_IFS=$IFS
  IFS=$' \t\n'
}
function ble/init/restore-IFS {
  if [[ $_ble_init_original_IFS_set ]]; then
    IFS=$_ble_init_original_IFS
  else
    builtin unset -v IFS
  fi
  builtin unset -v _ble_init_original_IFS_set
  builtin unset -v _ble_init_original_IFS
}

if ((_ble_bash>=50100)); then
  _ble_bash_BASH_REMATCH_level=0
  _ble_bash_BASH_REMATCH=()
  function ble/base/adjust-BASH_REMATCH {
    ((_ble_bash_BASH_REMATCH_level++==0)) || return 0
    _ble_bash_BASH_REMATCH=("${BASH_REMATCH[@]}")
  }
  function ble/base/restore-BASH_REMATCH {
    ((_ble_bash_BASH_REMATCH_level>0&&
        --_ble_bash_BASH_REMATCH_level==0)) || return 0
    BASH_REMATCH=("${_ble_bash_BASH_REMATCH[@]}")
  }

else
  _ble_bash_BASH_REMATCH_level=0
  _ble_bash_BASH_REMATCH=()
  _ble_bash_BASH_REMATCH_rex=none

  ## @fn ble/base/adjust-BASH_REMATCH/increase delta
  ##   @param[in] delta
  ##   @var[in,out] i rex
  function ble/base/adjust-BASH_REMATCH/increase {
    local delta=$1
    ((delta)) || return 1
    ((i+=delta))
    if ((delta==1)); then
      rex=$rex.
    else
      rex=$rex.{$delta}
    fi
  }
  function ble/base/adjust-BASH_REMATCH/is-updated {
    local i n=${#_ble_bash_BASH_REMATCH[@]}
    ((n!=${#BASH_REMATCH[@]})) && return 0
    for ((i=0;i<n;i++)); do
      [[ ${_ble_bash_BASH_REMATCH[i]} != "${BASH_REMATCH[i]}" ]] && return 0
    done
    return 1
  }
  # This is a simplified version of ble/string#index-of text sub
  function ble/base/adjust-BASH_REMATCH/.find-substr {
    local t=${1#*"$2"}
    ((ret=${#1}-${#t}-${#2},ret<0&&(ret=-1),ret>=0))
  }
  function ble/base/adjust-BASH_REMATCH {
    ((_ble_bash_BASH_REMATCH_level++==0)) || return 0
    ble/base/adjust-BASH_REMATCH/is-updated || return 1

    local size=${#BASH_REMATCH[@]}
    if ((size==0)); then
      _ble_bash_BASH_REMATCH=()
      _ble_bash_BASH_REMATCH_rex=none
      return 0
    fi

    local rex= i=0
    local text=$BASH_REMATCH sub ret isub

    local -a rparens=()
    local isub rex i=0 count=0
    for ((isub=1;isub<size;isub++)); do
      local sub=${BASH_REMATCH[isub]}

      # 既存の子一致の孫一致になるか確認
      while ((count>=1)); do
        local end=${rparens[count-1]}
        if ble/base/adjust-BASH_REMATCH/.find-substr "${text:i:end-i}" "$sub"; then
          ble/base/adjust-BASH_REMATCH/increase "$ret"
          ((rparens[count++]=i+${#sub}))
          rex=$rex'('
          break
        else
          ble/base/adjust-BASH_REMATCH/increase "$((end-i))"
          rex=$rex')'
          builtin unset -v 'rparens[--count]'
        fi
      done

      ((count>0)) && continue

      # 新しい子一致
      if ble/base/adjust-BASH_REMATCH/.find-substr "${text:i}" "$sub"; then
        ble/base/adjust-BASH_REMATCH/increase "$ret"
        ((rparens[count++]=i+${#sub}))
        rex=$rex'('
      else
        break # 復元失敗
      fi
    done

    while ((count>=1)); do
      local end=${rparens[count-1]}
      ble/base/adjust-BASH_REMATCH/increase "$((end-i))"
      rex=$rex')'
      builtin unset -v 'rparens[--count]'
    done

    ble/base/adjust-BASH_REMATCH/increase "$((${#text}-i))"

    _ble_bash_BASH_REMATCH=("${BASH_REMATCH[@]}")
    _ble_bash_BASH_REMATCH_rex=$rex
  }
  function ble/base/restore-BASH_REMATCH {
    ((_ble_bash_BASH_REMATCH_level>0&&
        --_ble_bash_BASH_REMATCH_level==0)) || return 0
    [[ $_ble_bash_BASH_REMATCH =~ $_ble_bash_BASH_REMATCH_rex ]]
  }
fi

ble/init/adjust-IFS
ble/base/adjust-BASH_REMATCH

## @fn ble/init/clean-up [opts]
function ble/init/clean-up {
  local ext=$? opts=$1 # preserve exit status

  # 一時グローバル変数消去
  builtin unset -v _ble_init_version
  builtin unset -v _ble_init_arg
  builtin unset -v _ble_init_exit
  builtin unset -v _ble_init_command
  builtin unset -v _ble_init_attached

  # 状態復元
  ble/base/restore-BASH_REMATCH
  ble/init/restore-IFS
  if [[ :$opts: != *:check-attach:* || ! $_ble_attached ]]; then
    ble/base/restore-bash-options
    ble/base/restore-POSIXLY_CORRECT
    ble/base/restore-builtin-wrappers
    builtin eval -- "$_ble_bash_FUNCNEST_restore"
  fi
  return "$ext"
}

#------------------------------------------------------------------------------
# read arguments

function ble/util/put { builtin printf '%s' "$1"; }
function ble/util/print { builtin printf '%s\n' "$1"; }
function ble/util/print-lines { builtin printf '%s\n' "$@"; }

_ble_base_arguments_opts=
_ble_base_arguments_attach=
_ble_base_arguments_rcfile=
## @fn ble/base/read-blesh-arguments args
##   @var[out] _ble_base_arguments_opts
##   @var[out] _ble_base_arguments_attach
##   @var[out] _ble_base_arguments_rcfile
function ble/base/read-blesh-arguments {
  local opts=
  local opt_attach=prompt
  local opt_inputrc=auto

  builtin unset -v _ble_init_command # 再解析
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (--noattach|noattach)
      opt_attach=none ;;
    (--attach=*) opt_attach=${arg#*=} ;;
    (--attach)
      if (($#)); then
        opt_attach=$1; shift
      else
        opt_attach=attach
        opts=$opts:E
        ble/util/print "ble.sh ($arg): an option argument is missing." >&2
      fi ;;

    (--noinputrc)
      opt_inputrc=none ;;
    (--inputrc=*) opt_inputrc=${arg#*=} ;;
    (--inputrc)
      if (($#)); then
        opt_inputrc=$1; shift
      else
        opt_inputrc=inputrc
        opts=$opts:E
        ble/util/print "ble.sh ($arg): an option argument is missing." >&2
      fi ;;

    (--rcfile=*|--init-file=*|--rcfile|--init-file)
      if [[ $arg != *=* ]]; then
        local rcfile=$1; shift
      else
        local rcfile=${arg#*=}
      fi

      _ble_base_arguments_rcfile=${rcfile:-/dev/null}
      if [[ ! $rcfile || ! -e $rcfile ]]; then
        ble/util/print "ble.sh ($arg): '$rcfile' does not exist." >&2
        opts=$opts:E
      elif [[ ! -r $rcfile ]]; then
        ble/util/print "ble.sh ($arg): '$rcfile' is not readable." >&2
        opts=$opts:E
      fi ;;
    (--norc)
      _ble_base_arguments_rcfile=/dev/null ;;
    (--keep-rlvars)
      opts=$opts:keep-rlvars ;;
    (--debug-bash-output)
      bleopt_internal_suppress_bash_output= ;;
    (--test | --update | --clear-cache | --lib)
      if [[ $_ble_init_command ]]; then
        ble/util/print "ble.sh ($arg): the option '--$_ble_init_command' has already been specified." >&2
        opts=$opts:E
      else
        _ble_init_command=${arg#--}
      fi ;;
    (--*)
      ble/util/print "ble.sh: unrecognized long option '$arg'" >&2
      opts=$opts:E ;;
    (-?*)
      local i c
      for ((i=1;i<${#arg};i++)); do
        c=${arg:i:1}
        case -$c in
        (-o)
          if ((i+1<${#arg})); then
            local oarg=${arg:i+1}
            i=${#arg}
          elif (($#)); then
            local oarg=$1; shift
          else
            opts=$opts:E
            i=${#arg}
            continue
          fi
          local rex='^[_a-zA-Z][_a-zA-Z0-9]*='
          if [[ $oarg =~ $rex ]]; then
            builtin eval -- "bleopt_${oarg%%=*}=\${oarg#*=}"
          else
            ble/util/print "ble.sh: unrecognized option '-o $oarg'" >&2
            opts=$opts:E
          fi ;;
        (-*)
          ble/util/print "ble.sh: unrecognized option '-$c'" >&2
          opts=$opts:E ;;
        esac
      done
      ;;
    (*)
      if [[ ${_ble_init_command-} ]]; then
        _ble_init_command[${#_ble_init_command[@]}]=$arg
      else
        ble/util/print "ble.sh: unrecognized argument '$arg'" >&2
        opts=$opts:E
      fi ;;
    esac
  done

  _ble_base_arguments_opts=$opts
  _ble_base_arguments_attach=$opt_attach
  _ble_base_arguments_inputrc=$opt_inputrc
  [[ :$opts: != *:E:* ]]
}
if ! ble/base/read-blesh-arguments "$@"; then
  builtin echo "ble.sh: cancel initialization." >&2
  ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
  return 2 2>/dev/null || builtin exit 2
fi

if [[ ${_ble_base-} ]]; then
  [[ $_ble_init_command ]] && _ble_init_attached=$_ble_attached
  if ! ble/base/unload-for-reload; then
    builtin echo "ble.sh: an old version of ble.sh seems to be already loaded." >&2
    ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
    return 1 2>/dev/null || builtin exit 1
  fi
fi

#------------------------------------------------------------------------------
# Initialize version information

# DEBUG version の Bash では遅いという通知
case ${BASH_VERSINFO[4]} in
(alp*|bet*|dev*|rc*|releng*|maint*)
  ble/util/print-lines \
    "ble.sh may become very slow because this is a debug version of Bash" \
    "  (version '$BASH_VERSION', release status: '${BASH_VERSINFO[4]}')." \
    "  We recommend using ble.sh with a release version of Bash." >&2 ;;
esac

_ble_bash=$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))
_ble_bash_loaded_in_function=0
local _ble_local_test 2>/dev/null && _ble_bash_loaded_in_function=1

_ble_version=0
BLE_VERSION=$_ble_init_version
function ble/base/initialize-version-information {
  local version=$BLE_VERSION

  local hash=
  if [[ $version == *+* ]]; then
    hash=${version#*+}
    version=${version%%+*}
  fi

  local status=release
  if [[ $version == *-* ]]; then
    status=${version#*-}
    version=${version%%-*}
  fi

  local major=${version%%.*}; version=${version#*.}
  local minor=${version%%.*}; version=${version#*.}
  local patch=${version%%.*}
  BLE_VERSINFO=("$major" "$minor" "$patch" "$hash" "$status" noarch)
  ((_ble_version=major*10000+minor*100+patch))
}
ble/base/initialize-version-information

#------------------------------------------------------------------------------
# workarounds for builtin read

function ble/bash/read {
  local TMOUT= 2>/dev/null # #D1630 WA readonly TMOUT
  builtin read "${_ble_bash_tmout_wa[@]}" -r "$@"
}
function ble/bash/read-timeout { builtin read -t "$@"; }

# WA for bash-5.2 nested read by WINCH causes corrupted "running_trap" (#D1982)
_ble_bash_read_winch=
if ((50200<=_ble_bash&&_ble_bash<50300)); then
  function ble/bash/read/.process-winch {
    if [[ $_ble_bash_read_winch != - ]]; then
      local _ble_local_handler=$_ble_bash_read_winch
      local _ble_bash_read_winch=
      builtin eval -- "$_ble_local_handler"
    fi
  }
  function ble/bash/read {
    local TMOUT= 2>/dev/null # #D1630 WA readonly TMOUT
    local _ble_bash_read_winch=-
    builtin read "${_ble_bash_tmout_wa[@]}" -r "$@"; local _ble_local_ext=$?
    ble/bash/read/.process-winch
    return "$_ble_local_ext"
  }
  function ble/bash/read-timeout {
    local _ble_bash_read_winch=-
    builtin read -t "$@"; local _ble_local_ext=$?
    ble/bash/read/.process-winch
    return "$_ble_local_ext"
  }
fi

#------------------------------------------------------------------------------
# check environment

# will be overwritten by src/util.sh
function ble/util/assign { builtin eval "$1=\$(builtin eval -- \"\$2\")"; }

# ble/bin

## @fn ble/bin/.default-utility-path commands...
##   取り敢えず ble/bin/* からコマンドを呼び出せる様にします。
function ble/bin/.default-utility-path {
  local cmd
  for cmd; do
    builtin eval "function ble/bin/$cmd { command $cmd \"\$@\"; }"
  done
}
## @fn ble/bin#freeze-utility-path [-n] commands...
##   PATH が破壊された後でも ble が動作を続けられる様に、
##   現在の PATH で基本コマンドのパスを固定して ble/bin/* から使える様にする。
##
##   実装に ble/util/assign を使用しているので ble-core 初期化後に実行する必要がある。
##
function ble/bin#freeze-utility-path {
  local cmd path q=\' Q="'\''" fail= flags=
  for cmd; do
    if [[ $cmd == -n ]]; then
      flags=n$flags
      continue
    fi
    [[ $flags == *n* ]] && ble/bin#has "ble/bin/$cmd" && continue
    ble/bin#has "ble/bin/.frozen:$cmd" && continue
    if ble/util/assign path "builtin type -P -- $cmd 2>/dev/null" && [[ $path ]]; then
      builtin eval "function ble/bin/$cmd { '${path//$q/$Q}' \"\$@\"; }"
    else
      fail=1
    fi
  done
  ((!fail))
}

if ((_ble_bash>=40000)); then
  function ble/bin#has { type -t "$@" &>/dev/null; }
else
  function ble/bin#has {
    local cmd
    for cmd; do type -t "$cmd" || return 1; done &>/dev/null
    return 0
  }
fi

# POSIX utilities

_ble_init_posix_command_list=(sed date rm mkdir mkfifo sleep stty tty sort awk chmod grep cat wc mv sh od cp ps)
function ble/init/check-environment {
  if ! ble/bin#has "${_ble_init_posix_command_list[@]}"; then
    local cmd commandMissing=
    for cmd in "${_ble_init_posix_command_list[@]}"; do
      if ! type "$cmd" &>/dev/null; then
        commandMissing="$commandMissing\`$cmd', "
      fi
    done
    ble/util/print "ble.sh: insane environment: The command(s), ${commandMissing}not found. Check your environment variable PATH." >&2

    # try to fix PATH
    local default_path=$(command -p getconf PATH 2>/dev/null)
    [[ $default_path ]] || return 1

    local original_path=$PATH
    export PATH=${default_path}${PATH:+:}${PATH}
    [[ :$PATH: == *:/bin:* ]] || PATH=/bin${PATH:+:}$PATH
    [[ :$PATH: == *:/usr/bin:* ]] || PATH=/usr/bin${PATH:+:}$PATH
    if ! ble/bin#has "${_ble_init_posix_command_list[@]}"; then
      PATH=$original_path
      return 1
    fi
    ble/util/print "ble.sh: modified PATH=${PATH::${#PATH}-${#original_path}}\$PATH" >&2
  fi

  if [[ ! ${USER-} ]]; then
    ble/util/print "ble.sh: insane environment: \$USER is empty." >&2
    if USER=$(id -un 2>/dev/null) && [[ $USER ]]; then
      export USER
      ble/util/print "ble.sh: modified USER=$USER" >&2
    fi
  fi
  _ble_base_env_USER=$USER

  if [[ ! ${HOSTNAME-} ]]; then
    ble/util/print "ble.sh: suspicious environment: \$HOSTNAME is empty."
    if HOSTNAME=$(uname -n 2>/dev/null) && [[ $HOSTNAME ]]; then
      export HOSTNAME
      ble/util/print "ble.sh: fixed HOSTNAME=$HOSTNAME" >&2
    fi
  fi
  _ble_base_env_HOSTNAME=$HOSTNAME

  if [[ ! ${LANG-} ]]; then
    ble/util/print "ble.sh: suspicious environment: \$LANG is empty." >&2
  fi

  # 暫定的な ble/bin/$cmd 設定
  ble/bin/.default-utility-path "${_ble_init_posix_command_list[@]}"

  return 0
}
if ! ble/init/check-environment; then
  ble/util/print "ble.sh: failed to adjust the environment. canceling the load of ble.sh." 1>&2
  builtin unset -v _ble_bash BLE_VERSION BLE_VERSINFO
  ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
  return 1
fi

# Note: src/util.sh で ble/util/assign を定義した後に呼び出される。
_ble_bin_awk_type=
function ble/bin/awk/.instantiate {
  local path q=\' Q="'\''" ext=1

  if ble/util/assign path "builtin type -P -- nawk 2>/dev/null" && [[ $path ]]; then
    # Note: Some distribution (like Ubuntu) provides gawk as "nawk" by
    # default. To avoid wrongly picking gawk as nawk, we need to check the
    # version output from the command.
    ble/util/assign version '"$path" -W version' 2>/dev/null </dev/null
    if [[ $version != *'GNU Awk'* && $version != *mawk* ]]; then
      builtin eval "function ble/bin/nawk { '${path//$q/$Q}' -v AWKTYPE=nawk \"\$@\"; }"
      if [[ ! $_ble_bin_awk_type ]]; then
        _ble_bin_awk_type=nawk
        builtin eval "function ble/bin/awk { '${path//$q/$Q}' -v AWKTYPE=nawk \"\$@\"; }" && ext=0
      fi
    fi
  fi

  if ble/util/assign path "builtin type -P -- mawk 2>/dev/null" && [[ $path ]]; then
    builtin eval "function ble/bin/mawk { '${path//$q/$Q}' -v AWKTYPE=mawk \"\$@\"; }"
    if [[ ! $_ble_bin_awk_type ]]; then
      _ble_bin_awk_type=mawk
      builtin eval "function ble/bin/awk { '${path//$q/$Q}' -v AWKTYPE=mawk \"\$@\"; }" && ext=0
    fi
  fi

  if ble/util/assign path "builtin type -P -- gawk 2>/dev/null" && [[ $path ]]; then
    builtin eval "function ble/bin/gawk { '${path//$q/$Q}' -v AWKTYPE=gawk \"\$@\"; }"
    if [[ ! $_ble_bin_awk_type ]]; then
      _ble_bin_awk_type=gawk
      builtin eval "function ble/bin/awk { '${path//$q/$Q}' -v AWKTYPE=gawk \"\$@\"; }" && ext=0
    fi
  fi

  if [[ ! $_ble_bin_awk_type ]]; then
    if [[ $OSTYPE == solaris* ]] && type /usr/xpg4/bin/awk >/dev/null; then
      # Solaris の既定の awk は全然駄目なので /usr/xpg4 以下の awk を使う。
      _ble_bin_awk_type=xpg4
      function ble/bin/awk { /usr/xpg4/bin/awk -v AWKTYPE=xpg4 "$@"; } && ext=0
    elif ble/util/assign path "builtin type -P -- awk 2>/dev/null" && [[ $path ]]; then
      local version
      ble/util/assign version '"$path" -W version || "$path" --version' 2>/dev/null </dev/null
      if [[ $version == *'GNU Awk'* ]]; then
        _ble_bin_awk_type=gawk
      elif [[ $version == *mawk* ]]; then
        _ble_bin_awk_type=mawk
      elif [[ $version == 'awk version '[12][0-9][0-9][0-9][01][0-9][0-3][0-9] ]]; then
        _ble_bin_awk_type=nawk
      else
        _ble_bin_awk_type=unknown
      fi
      builtin eval "function ble/bin/awk { '${path//$q/$Q}' -v AWKTYPE=$_ble_bin_awk_type \"\$@\"; }" && ext=0
      if [[ $OSTYPE == darwin* && $path == /usr/bin/awk && $_ble_bin_awk_type == nawk ]]; then
        # Note #D1974: macOS の awk-32 の multibyte character support が怪しい。
        #   問題は GitHub Actions の上では再現できていないが特別の入力で失敗す
        #   るのかもしれない。または、報告者の環境が壊れているだけの可能性もあ
        #   る。テスト不可能だが、そもそも nawk は UTF-8 に対応していない前提な
        #   ので、取り敢えず LC_CTYPE=C で実行する。
        function ble/bin/awk {
          local LC_ALL= LC_CTYPE=C 2>/dev/null
          /usr/bin/awk -v AWKTYPE=nawk "$@"; local ext=$?
          ble/util/unlocal LC_ALL LC_CTYPE 2>/dev/null
          return "$ext"
        }
      elif [[ $_ble_bin_awk_type == [gmn]awk ]] && ! ble/is-function "ble/bin/$_ble_bin_awk_type" ; then
        builtin eval "function ble/bin/$_ble_bin_awk_type { '${path//$q/$Q}' -v AWKTYPE=$_ble_bin_awk_type \"\$@\"; }"
      fi
    fi
  fi
  return "$ext"
}

# Note: ble//bin/awk/.instantiate が実行される前に使おうとした時の為の暫定実装
function ble/bin/awk {
  if ble/bin/awk/.instantiate; then
    ble/bin/awk "$@"
  else
    awk "$@"
  fi
}

# Do not overwrite by .freeze-utility-path
function ble/bin/.frozen:awk { :; }
function ble/bin/.frozen:nawk { :; }
function ble/bin/.frozen:mawk { :; }
function ble/bin/.frozen:gawk { :; }

## @fn ble/bin/awk0
##   awk implementation that supports NUL record separator
## @fn ble/bin/awk0.available
##   initialize ble/bin/awk0 and returns whether ble/bin/awk0 is available
function ble/bin/awk0.available/test {
  local count=0 cmd_awk=$1 awk_script='BEGIN { RS = "\0"; } { count++; } END { print count; }'
  ble/util/assign count 'printf "a\0b\0" | "$cmd_awk" "$awk_script"'
  ((count==2))
}
function ble/bin/awk0.available {
  local awk
  for awk in mawk gawk; do
    if ble/bin#freeze-utility-path -n "$awk" &&
        ble/bin/awk0.available/test ble/bin/"$awk" &&
        builtin eval -- "function ble/bin/awk0 { ble/bin/$awk -v AWKTYPE=$awk \"\$@\"; }"; then
      function ble/bin/awk0.available { ((1)); }
      return 0
    fi
  done

  if ble/bin/awk0.available/test ble/bin/awk &&
      function ble/bin/awk0 { ble/bin/awk "$@"; }; then
    function ble/bin/awk0.available { ((1)); }
    return 0
  fi

  function ble/bin/awk0.available { ((0)); }
  return 1
}

function ble/util/mkd {
  local dir
  for dir; do
    [[ -d $dir ]] && continue
    [[ -e $dir || -L $dir ]] && ble/bin/rm -f "$dir"
    ble/bin/mkdir -p "$dir"
  done
}

#------------------------------------------------------------------------------
# readlink -f (Originally taken from akinomyoga/mshex.git)

## @fn ble/util/readlink path
##   @var[out] ret

if ((_ble_bash>=40000)); then
  _ble_util_readlink_visited_init='local -A visited=()'
  function ble/util/readlink/.visited {
    [[ ${visited[$1]+set} ]] && return 0
    visited[$1]=1
    return 1
  }
else
  _ble_util_readlink_visited_init="local -a visited=()"
  function ble/util/readlink/.visited {
    local key
    for key in "${visited[@]}"; do
      [[ $1 == "$key" ]] && return 0
    done
    visited=("$1" "${visited[@]}")
    return 1
  }
fi

## @fn ble/util/readlink/.readlink path
##   @var[out] link
function ble/util/readlink/.readlink {
  local path=$1
  if ble/bin#has ble/bin/readlink; then
    ble/util/assign link 'ble/bin/readlink -- "$path"'
    [[ $link ]]
  elif ble/bin#has ble/bin/ls; then
    ble/util/assign link 'ble/bin/ls -ld -- "$path"' &&
      [[ $link == *" $path -> "?* ]] &&
      link=${link#*" $path -> "}
  else
    false
  fi
} 2>/dev/null
## @fn  ble/util/readlink/.resolve-physical-directory
##   @var[in,out] path
function ble/util/readlink/.resolve-physical-directory {
  [[ $path == */?* ]] || return 0
  local PWD=$PWD OLDPWD=$OLDPWD CDPATH=
  if builtin cd -L .; then
    local pwd=$PWD
    builtin cd -P "${path%/*}/" &&
      path=${PWD%/}/${path##*/}

    # Note #D1849: 現在ディレクトリが他者により改名されている場合や PWD がユー
    #   ザーに書き換えられている場合にも元のディレクトリに戻る為、cd -L . した
    #   後のパスに cd する。但し pwd の結果はこの関数の呼び出し前と変わってしま
    #   う (が実際にはこの方が良いだろう)。PWD は local にして元の値に戻すので
    #   変わらない。
    builtin cd "$pwd"
  fi
  return 0
}
function ble/util/readlink/.resolve-loop {
  local path=$ret
  while [[ $path == ?*/ ]]; do path=${path%/}; done
  builtin eval -- "$_ble_util_readlink_visited_init"
  while [[ -h $path ]]; do
    local link
    ble/util/readlink/.visited "$path" && break
    ble/util/readlink/.readlink "$path" || break
    if [[ $link == /* || $path != */* ]]; then
      path=$link
    else
      # 相対パス ../ は物理ディレクトリ構造に従って遡る。
      ble/util/readlink/.resolve-physical-directory
      path=${path%/*}/$link
    fi
    while [[ $path == ?*/ ]]; do path=${path%/}; done
  done
  ret=$path
}
function ble/util/readlink/.resolve {
  # 初回呼び出し時に実装を選択
  _ble_util_readlink_type=

  # より効率的な実装が可能な場合は ble/util/readlink/.resolve を独自定義。
  case $OSTYPE in
  (cygwin | msys | linux-gnu)
    # これらのシステムの標準 readlink では readlink -f が使える。
    #
    # Note: 例えば NixOS では標準の readlink を使おうとすると問題が起こるらしい
    #   ので、見えている readlink を使う。見えている readlink が非標準の時は -f
    #   が使えるか分からないので readlink -f による実装は有効化しない。
    #
    local readlink
    ble/util/assign readlink 'type -P readlink'
    case $readlink in
    (/bin/readlink | /usr/bin/readlink)
      _ble_util_readlink_type=readlink-f
      builtin eval "function ble/util/readlink/.resolve { ble/util/assign ret '$readlink -f -- \"\$ret\"'; }" ;;
    esac ;;
  esac

  if [[ ! $_ble_util_readlink_type ]]; then
    _ble_util_readlink_type=loop
    ble/bin#freeze-utility-path readlink ls
    function ble/util/readlink/.resolve { ble/util/readlink/.resolve-loop; }
  fi

  ble/util/readlink/.resolve
}
function ble/util/readlink {
  ret=$1
  if [[ -h $ret ]]; then ble/util/readlink/.resolve; fi
}

#---------------------------------------

_ble_bash_path=
function ble/bin/.load-builtin {
  local name=$1 path=$2
  if [[ ! $_ble_bash_path ]]; then
    local ret; ble/util/readlink "$BASH"
    _ble_bash_path=$ret
  fi

  if [[ ! $path ]]; then
    local bash_prefix=${ret%/*/*}
    path=$bash_prefix/lib/bash/$name
    [[ -s $path ]] || return 1
  fi

  if (enable -f "$path" "$name") &>/dev/null; then
    enable -f "$path" "$name"
    builtin eval -- "function ble/bin/$name { builtin $name \"\$@\"; }"
    return 0
  else
    return 1
  fi
}
# ble/bin/.load-builtin mkdir
# ble/bin/.load-builtin mkfifo
# ble/bin/.load-builtin rm

#------------------------------------------------------------------------------

function ble/base/.create-user-directory {
  local var=$1 dir=$2
  if [[ ! -d $dir ]]; then
    # dangling symlinks are silently removed
    [[ ! -e $dir && -h $dir ]] && ble/bin/rm -f "$dir"
    if [[ -e $dir || -h $dir ]]; then
      ble/util/print "ble.sh: cannot create a directory '$dir' since there is already a file." >&2
      return 1
    fi
    if ! (umask 077; ble/bin/mkdir -p "$dir" && [[ -O $dir ]]); then
      ble/util/print "ble.sh: failed to create a directory '$dir'." >&2
      return 1
    fi
  elif ! [[ -r $dir && -w $dir && -x $dir ]]; then
    ble/util/print "ble.sh: permission of '$dir' is not correct." >&2
    return 1
  elif [[ ! -O $dir ]]; then
    ble/util/print "ble.sh: owner of '$dir' is not correct." >&2
    return 1
  fi
  builtin eval "$var=\$dir"
}

##
## @var _ble_base
## @var _ble_base_blesh
## @var _ble_base_blesh_raw
##
##   ble.sh のインストール先ディレクトリ。
##   読み込んだ ble.sh の実体があるディレクトリとして解決される。
##
function ble/base/initialize-base-directory {
  local src=$1
  local defaultDir=${2-}

  # resolve symlink
  _ble_base_blesh_raw=$src
  if [[ -h $src ]]; then
    local ret; ble/util/readlink "$src"; src=$ret
  fi
  _ble_base_blesh=$src

  if [[ -s $src && $src != */* ]]; then
    _ble_base=$PWD
  elif [[ $src == */* ]]; then
    local dir=${src%/*}
    if [[ ! $dir ]]; then
      _ble_base=/
    elif [[ $dir != /* ]]; then
      _ble_base=$PWD/$dir
    else
      _ble_base=$dir
    fi
  else
    _ble_base=${defaultDir:-$HOME/.local/share/blesh}
  fi

  [[ -d $_ble_base ]]
}
if ! ble/base/initialize-base-directory "${BASH_SOURCE[0]}"; then
  ble/util/print "ble.sh: ble base directory not found!" 1>&2
  builtin unset -v _ble_bash BLE_VERSION BLE_VERSINFO
  ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
  return 1
fi

##
## @var _ble_base_run
##
##   実行時の一時ファイルを格納するディレクトリ。以下の手順で決定する。
##
##   1. ${XDG_RUNTIME_DIR:=/run/user/$UID} が存在すればその下に blesh を作成して使う。
##   2. /tmp/blesh/$UID を作成可能ならば、それを使う。
##   3. $_ble_base/tmp/$UID を使う。
##
function ble/base/initialize-runtime-directory/.xdg {
  local runtime_dir=
  if [[ $XDG_RUNTIME_DIR ]]; then
    if [[ ! -d $XDG_RUNTIME_DIR ]]; then
      ble/util/print "ble.sh: XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' is not a directory." >&2
      return 1
    elif [[ -O $XDG_RUNTIME_DIR ]]; then
      runtime_dir=$XDG_RUNTIME_DIR
    else
      # When XDG_RUNTIME_DIR is not owned by the current user, maybe "su" is
      # used to enter this session keeping the environment variables of the
      # original user.  We just ignore XDG_RUNTIME_DIR (without issueing
      # warnings) for such a case.
      false
    fi
  fi
  if [[ ! $runtime_dir ]]; then
    runtime_dir=/run/user/$UID
    [[ -d $runtime_dir && -O $runtime_dir ]] || return 1
  fi

  if ! [[ -r $runtime_dir && -w $runtime_dir && -x $runtime_dir ]]; then
    [[ $runtime_dir == "$XDG_RUNTIME_DIR" ]] &&
      ble/util/print "ble.sh: XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' doesn't have a proper permission." >&2
    return 1
  fi

  ble/base/.create-user-directory _ble_base_run "$runtime_dir/blesh"
}
function ble/base/initialize-runtime-directory/.tmp {
  [[ -r /tmp && -w /tmp && -x /tmp ]] || return 1

  local tmp_dir=/tmp/blesh
  if [[ ! -d $tmp_dir ]]; then
    [[ ! -e $tmp_dir && -h $tmp_dir ]] && ble/bin/rm -f "$tmp_dir"
    if [[ -e $tmp_dir || -h $tmp_dir ]]; then
      ble/util/print "ble.sh: cannot create a directory '$tmp_dir' since there is already a file." >&2
      return 1
    fi
    ble/bin/mkdir -p "$tmp_dir" || return 1
    ble/bin/chmod a+rwxt "$tmp_dir" || return 1
  elif ! [[ -r $tmp_dir && -w $tmp_dir && -x $tmp_dir ]]; then
    ble/util/print "ble.sh: permission of '$tmp_dir' is not correct." >&2
    return 1
  fi

  ble/base/.create-user-directory _ble_base_run "$tmp_dir/$UID"
}
function ble/base/initialize-runtime-directory {
  ble/base/initialize-runtime-directory/.xdg && return 0
  ble/base/initialize-runtime-directory/.tmp && return 0

  # fallback
  local tmp_dir=$_ble_base/run
  if [[ ! -d $tmp_dir ]]; then
    ble/bin/mkdir -p "$tmp_dir" || return 1
    ble/bin/chmod a+rwxt "$tmp_dir" || return 1
  fi
  ble/base/.create-user-directory _ble_base_run "$tmp_dir/${USER:-$UID}@$HOSTNAME"
}
if ! ble/base/initialize-runtime-directory; then
  ble/util/print "ble.sh: failed to initialize \$_ble_base_run." 1>&2
  builtin unset -v _ble_bash BLE_VERSION BLE_VERSINFO
  ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
  return 1
fi

# ロード時刻の記録 (ble-update で使う為)
: >| "$_ble_base_run/$$.load"

## @fn ble/base/clean-up-runtime-directory [opts]
##   既に存在しないプロセスに属する実行時ファイルを削除します。*.pid のファイル
##   名を持つ実行時ファイルはについては、子バックグラウンドプロセスのプロセスID
##   を含むと見做し、ファイルの内容を読み取ってそれが整数であればその整数に対し
##   て kill を実行します。
##
##   @param[in,opt] opts
##     finalize ... 自プロセス $$ に関連するファイルも削除します。現セッション
##       における ble.sh の終了処理時に呼び出される事を想定しています。
##
function ble/base/clean-up-runtime-directory {
  local opts=$1 failglob= noglob=
  if [[ $- == *f* ]]; then
    noglob=1
    set +f
  fi
  if shopt -q failglob &>/dev/null; then
    failglob=1
    shopt -u failglob
  fi

  local -a alive=() removed=() bgpids=()
  [[ :$opts: == *:finalize:* ]] && alive[$$]=0

  local file pid iremoved=0 ibgpid=0
  for file in "$_ble_base_run"/[1-9]*.*; do
    [[ -e $file || -h $file ]] || continue

    # extract pid (skip if it is not a number)
    pid=${file##*/}; pid=${pid%%.*}
    [[ $pid && ! ${pid//[0-9]} ]] || continue

    if [[ ! ${alive[pid]+set} ]]; then
      builtin kill -0 "$pid" &>/dev/null
      ((alive[pid]=$?==0))
    fi
    ((alive[pid])) && continue

    # kill process specified by the pid file
    if [[ $file == *.pid && -s $file ]]; then
      local run_pid IFS=
      ble/bash/read run_pid < "$file"
      if [[ $run_pid && ! ${run_pid//[0-9]} ]]; then
        if ((pid==$$)); then
          # 現セッションの背景プロセスの場合は遅延させる
          kill -0 "$run_pid" &>/dev/null && bgpids[ibgpid++]=$run_pid
        else
          kill "$run_pid"
        fi
      fi
    fi

    removed[iremoved++]=$file
  done
  ((iremoved)) && ble/bin/rm -rf "${removed[@]}" 2>/dev/null
  ((ibgpid)) && (ble/util/nohup 'ble/bin/sleep 3; kill "${bgpids[@]}"')

  [[ $failglob ]] && shopt -s failglob
  [[ $noglob ]] && set -f
  return 0
}

# initialization time = 9ms (for 70 files)
ble/base/clean-up-runtime-directory

##
## @var _ble_base_cache
##
##   環境毎の初期化ファイルを格納するディレクトリ。以下の手順で決定する。
##
##   1. ${XDG_CACHE_HOME:=$HOME/.cache} が存在すればその下に blesh を作成して使う。
##   2. $_ble_base/cache.d/$UID を使う。
##
function ble/base/initialize-cache-directory/.xdg {
  [[ $_ble_base != */out ]] || return 1

  local cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
  if [[ ! -d $cache_dir ]]; then
    [[ $XDG_CACHE_HOME ]] &&
      ble/util/print "ble.sh: XDG_CACHE_HOME='$XDG_CACHE_HOME' is not a directory." >&2
    return 1
  fi
  if ! [[ -r $cache_dir && -w $cache_dir && -x $cache_dir ]]; then
    [[ $XDG_CACHE_HOME ]] &&
      ble/util/print "ble.sh: XDG_CACHE_HOME='$XDG_CACHE_HOME' doesn't have a proper permission." >&2
    return 1
  fi

  local ver=${BLE_VERSINFO[0]}.${BLE_VERSINFO[1]}
  ble/base/.create-user-directory _ble_base_cache "$cache_dir/blesh/$ver"
}
function ble/base/initialize-cache-directory {
  ble/base/initialize-cache-directory/.xdg && return 0

  # fallback
  local cache_dir=$_ble_base/cache.d
  if [[ ! -d $cache_dir ]]; then
    ble/bin/mkdir -p "$cache_dir" || return 1
    ble/bin/chmod a+rwxt "$cache_dir" || return 1

    # relocate an old cache directory if any
    local old_cache_dir=$_ble_base/cache
    if [[ -d $old_cache_dir && ! -h $old_cache_dir ]]; then
      mv "$old_cache_dir" "$cache_dir/$UID"
      ln -s "$cache_dir/$UID" "$old_cache_dir"
    fi
  fi
  ble/base/.create-user-directory _ble_base_cache "$cache_dir/$UID"
}
function ble/base/migrate-cache-directory/.move {
  local old=$1 new=$2
  [[ -e $old ]] || return 0
  if [[ -e $new || -L $old ]]; then
    ble/bin/rm -rf "$old"
  else
    ble/bin/mv "$old" "$new"
  fi
}
function ble/base/migrate-cache-directory/.check-old-prefix {
  local old_prefix=$_ble_base_cache/$1
  local new_prefix=$_ble_base_cache/$2
  local file
  for file in "$old_prefix"*; do
    local old=$file
    local new=$new_prefix${file#"$old_prefix"}
    ble/base/migrate-cache-directory/.move "$old" "$new"
  done
}
function ble/base/migrate-cache-directory {
  local failglob=
  shopt -q failglob && { failglob=1; shopt -u failglob; }

  ble/base/migrate-cache-directory/.check-old-prefix cmap+default.binder-source decode.cmap.allseq
  ble/base/migrate-cache-directory/.check-old-prefix cmap+default decode.cmap
  ble/base/migrate-cache-directory/.check-old-prefix ble-decode-bind decode.bind

  local file
  for file in "$_ble_base_cache"/*.term; do
    local old=$file
    local new=$_ble_base_cache/term.${file#"$_ble_base_cache/"}; new=${new%.term}
    ble/base/migrate-cache-directory/.move "$old" "$new"
  done

  ble/base/migrate-cache-directory/.move "$_ble_base_cache/man" "$_ble_base_cache/complete.mandb"

  [[ $failglob ]] && shopt -s failglob
}
if ! ble/base/initialize-cache-directory; then
  ble/util/print "ble.sh: failed to initialize \$_ble_base_cache." 1>&2
  builtin unset -v _ble_bash BLE_VERSION BLE_VERSINFO
  ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
  return 1
fi
ble/base/migrate-cache-directory

##
## @var _ble_base_state
##
##   環境毎の初期化ファイルを格納するディレクトリ。以下の手順で決定する。
##
##   1. ${XDG_STATE_HOME:=$HOME/.state} (存在しなくても強制的に作成) の下に blesh を作成して使う。
##   2. (1. に失敗した時) $_ble_base/state.d/$UID を使う。
##
function ble/base/initialize-state-directory/.xdg {
  local state_dir=${XDG_STATE_HOME:-$HOME/.local/state}
  if [[ -e $state_dir || -L $state_dir ]]; then
    if [[ ! -d $state_dir ]]; then
      if [[ $XDG_STATE_HOME ]]; then
        ble/util/print "ble.sh: XDG_STATE_HOME='$XDG_STATE_HOME' is not a directory." >&2
      else
        ble/util/print "ble.sh: '$state_dir' is not a directory." >&2
      fi
      return 1
    fi
    if ! [[ -r $state_dir && -w $state_dir && -x $state_dir ]]; then
      if [[ $XDG_STATE_HOME ]]; then
        ble/util/print "ble.sh: XDG_STATE_HOME='$XDG_STATE_HOME' doesn't have a proper permission." >&2
      else
        ble/util/print "ble.sh: '$state_dir' doesn't have a proper permission." >&2
      fi
      return 1
    fi
  fi

  ble/base/.create-user-directory _ble_base_state "$state_dir/blesh"
}
function ble/base/initialize-state-directory {
  ble/base/initialize-state-directory/.xdg && return 0

  # fallback
  local state_dir=$_ble_base/state.d
  if [[ ! -d $state_dir ]]; then
    ble/bin/mkdir -p "$state_dir" || return 1
    ble/bin/chmod a+rwxt "$state_dir" || return 1

    # relocate an old state directory if any
    local old_state_dir=$_ble_base/state
    if [[ -d $old_state_dir && ! -h $old_state_dir ]]; then
      mv "$old_state_dir" "$state_dir/$UID"
      ln -s "$state_dir/$UID" "$old_state_dir"
    fi
  fi
  ble/util/print "ble.sh: using the non-standard position of the state directory: '$state_dir/$UID'" >&2
  ble/base/.create-user-directory _ble_base_state "$state_dir/$UID"
}
if ! ble/base/initialize-state-directory; then
  ble/util/print "ble.sh: failed to initialize \$_ble_base_state." 1>&2
  builtin unset -v _ble_bash BLE_VERSION BLE_VERSINFO
  ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
  return 1
fi


function ble/base/print-usage-for-no-argument-command {
  local name=${FUNCNAME[1]} desc=$1; shift
  ble/util/print-lines \
    "usage: $name" \
    "$desc" >&2
  [[ $1 != --help ]] && return 2
  return 0
}
function ble-reload {
  local -a options=()
  [[ ! -e $_ble_base_rcfile ]] ||
    ble/array#push options --rcfile="${_ble_base_rcfile:-/dev/null}"
  [[ $_ble_base_arguments_inputrc == auto ]] ||
    ble/array#push options --inputrc="$_ble_base_arguments_inputrc"
  local name
  for name in keep-rlvars; do
    if [[ :$_ble_base_arguments_opts: == *:"$name":* ]]; then
      ble/array#push options "--$name"
    fi
  done
  source "$_ble_base/ble.sh" "${options[@]}"
}

#%$ pwd=$(pwd) q=\' Q="'\''" bash -c 'echo "_ble_base_repository=$q${pwd//$q/$Q}$q"'
#%$ echo "_ble_base_branch=$(git rev-parse --abbrev-ref HEAD)"
_ble_base_repository_url=https://github.com/akinomyoga/ble.sh
#%$ echo "_ble_base_build_git_version=\"$BUILD_GIT_VERSION\""
#%$ echo "_ble_base_build_make_version=\"$BUILD_MAKE_VERSION\""
#%$ echo "_ble_base_build_gawk_version=\"$BUILD_GAWK_VERSION\""
function ble-update/.check-install-directory-ownership {
  if [[ ! -O $_ble_base ]]; then
    ble/util/print 'ble-update: install directory is owned by another user:' >&2
    ls -ld "$_ble_base"
    return 1
  elif [[ ! -r $_ble_base || ! -w $_ble_base || ! -x $_ble_base ]]; then
    ble/util/print 'ble-update: install directory permission denied:' >&2
    ls -ld "$_ble_base"
    return 1
  fi
}
function ble-update/.make {
  local sudo=
  if [[ $1 == --sudo ]]; then
    sudo=1
    shift
  fi

  if ! "$make" -q "$@"; then
    if [[ $sudo ]]; then
      sudo "$make" "$@"
    else
      "$make" "$@"
    fi
  else
    # インストール先に更新がなくても現在の session でロードされている ble.sh が
    # 古いかもしれないのでチェックしてリロードする。
    return 6
  fi
}
function ble-update/.reload {
  local ext=$1
  if [[ $ext -eq 0 || $ext -eq 6 && $_ble_base/ble.sh -nt $_ble_base_run/$$.load ]]; then
    if [[ ! -e $_ble_base/ble.sh ]]; then
      ble/util/print "ble-update: new ble.sh not found at '$_ble_base/ble.sh'." >&2
      return 1
    elif [[ ! -s $_ble_base/ble.sh ]]; then
      ble/util/print "ble-update: new ble.sh '$_ble_base/ble.sh' is empty." >&2
      return 1
    elif [[ $- == *i* && $_ble_attached ]] && ! ble/util/is-running-in-subshell; then
      ble-reload
    fi
    return "$?"
  fi
  ((ext==6)) && ext=0
  return "$ext"
}
function ble-update/.download-nightly-build {
  if ! ble/bin#has tar xz; then
    local command
    for command in tar xz; do
      ble/bin#has "$command" ||
        ble/util/print "ble-update (nightly): '$command' command is not available." >&2
    done
    return 1
  fi

  if ((EUID!=0)) && ! ble-update/.check-install-directory-ownership; then
    # _ble_base が自分の物でない時は sudo でやり直す
    sudo "$BASH" "$_ble_base/ble.sh" --update &&
      ble-update/.reload 6
    return "$?"
  fi

  local tarname=ble-nightly.tar.xz
  local url_tar=$_ble_base_repository_url/releases/download/nightly/$tarname
  (
    set +f
    shopt -u failglob nullglob

    # mkcd "$_ble_base/src"
    if ! ble/bin/mkdir -p "$_ble_base/src"; then
      ble/util/print "ble-update (nightly): failed to create the directory '$_ble_base/src'" >&2
      return 1
    fi
    if ! builtin cd "$_ble_base/src"; then
      ble/util/print "ble-update (nightly): failed to enter the directory '$_ble_base/src'" >&2
      return 1
    fi

    local ret
    ble/file#hash "$tarname"; local ohash=$ret

    # download "$url_tar" "$tarname"
    # Note: アップロードした直後は暫く 404 Not Found になるようなので何回か再試
    # 行する。
    local retry max_retry=5
    for ((retry=0;retry<=max_retry;retry++)); do
      if ((retry>0)); then
        local wait=$((retry<3?retry*10:30))
        ble/util/print "ble-update (nightly): retry downloading in $wait seconds... ($retry/$max_retry)" >&2
        ble/util/sleep "$wait"
      fi

      if ble/bin#has wget; then
        wget -N "$url_tar" && break
      elif ble/bin#has curl; then
        curl -LRo "$tarname" -z "$tarname" "$url_tar" && break
      else
        ble/util/print "ble-update (nightly): command 'wget' nor 'curl' is available." >&2
        return 1
      fi
    done
    if ((retry>max_retry)); then
      ble/util/print "ble-update (nightly): failed to download the archive from '$url_tar'." >&2
      return 7
    fi

    # 前回ダウンロードした物と同じ場合は省略
    ble/file#hash "$tarname"; local nhash=$ret
    [[ $ohash == "$nhash" ]] && return 6

    # tar xJf "$tarname"
    ble/bin/rm -rf ble-nightly*/
    if ! tar xJf "$tarname"; then
      ble/util/print 'ble-update (nightly): failed to extract the tarball. Removing possibly broken tarball.' >&2
      ble/bin/rm -rf "$tarname"
      return 1
    fi

    # cp -T ble-nightly* "$_ble_base"
    local extracted_dir=ble-nightly
    if [[ ! -d $extracted_dir ]]; then
      ble/util/print "ble-update (nightly): the directory 'ble-nightly' not found in the tarball '$PWD/$tarname'." >&2
      return 1
    fi
    ble/bin/cp -Rf "$extracted_dir"/* "$_ble_base/" || return 1
    ble/bin/rm -rf "$extracted_dir"
  ) &&
    ble-update/.reload
}
function ble-update {
  if (($#)); then
    ble/base/print-usage-for-no-argument-command 'Update and reload ble.sh.' "$@"
    return "$?"
  fi

  if [[ ${_ble_base_package_type-} ]] && ble/is-function ble/base/package:"$_ble_base_package_type"/update; then
    ble/util/print "ble-update: delegate to '$_ble_base_package_type' package manager..." >&2
    ble/base/package:"$_ble_base_package_type"/update; local ext=$?
    if ((ext==125)); then
      ble/util/print 'ble-update: fallback to the default update process.' >&2
    else
      ble-update/.reload "$ext"
      return "$?"
    fi
  fi

  if [[ ${_ble_base_repository-} == release:nightly-* ]]; then
    if ble-update/.download-nightly-build; local ext=$?; ((ext==0||ext==6||ext==7)); then
      if ((ext==6)); then
        ble/util/print 'ble-update (nightly): Already up to date.' >&2
      elif ((ext==7)); then
        ble/util/print 'ble-update (nightly): Remote temporarily unavailable. Try it again later.' >&2
      fi
      return 0
    fi
  fi

  # check make
  local make=
  if ble/bin#has gmake; then
    make=gmake
  elif ble/bin#has make && make --version 2>&1 | ble/bin/grep -qiF 'GNU Make'; then
    make=make
  else
    ble/util/print "ble-update: GNU Make is not available." >&2
    return 1
  fi

  # check git, gawk
  if ! ble/bin#has git gawk; then
    local command
    for command in git gawk; do
      ble/bin#has "$command" ||
        ble/util/print "ble-update: '$command' command is not available." >&2
    done
    return 1
  fi

  local insdir_doc=$_ble_base/doc
  [[ ! -d $insdir_doc && -d ${_ble_base%/*}/doc/blesh ]] &&
    insdir_doc=${_ble_base%/*}/doc/blesh

  if [[ ${_ble_base_repository-} && $_ble_base_repository != release:* ]]; then
    if [[ ! -e $_ble_base_repository/.git ]]; then
      ble/util/print "ble-update: git repository not found at '$_ble_base_repository'." >&2
    elif [[ ! -O $_ble_base_repository ]]; then
      ble/util/print "ble-update: git repository is owned by another user:" >&2
      ls -ld "$_ble_base_repository"
    elif [[ ! -r $_ble_base_repository || ! -w $_ble_base_repository || ! -x $_ble_base_repository ]]; then
      ble/util/print 'ble-update: git repository permission denied:' >&2
      ls -ld "$_ble_base_repository"
    else
      ( ble/util/print "cd into $_ble_base_repository..." >&2 &&
          builtin cd "$_ble_base_repository" &&
          git pull && git submodule update --recursive --remote &&
          if [[ $_ble_base == "$_ble_base_repository"/out ]]; then
            ble-update/.make all
          elif ((EUID!=0)) && ! ble-update/.check-install-directory-ownership; then
            ble-update/.make all
            ble-update/.make --sudo INSDIR="$_ble_base" INSDIR_DOC="$insdir_doc" install
          else
            ble-update/.make INSDIR="$_ble_base" INSDIR_DOC="$insdir_doc" install
          fi )
      ble-update/.reload "$?"
      return "$?"
    fi
  fi
  
  if ((EUID!=0)) && ! ble-update/.check-install-directory-ownership; then
    # _ble_base が自分の物でない時は sudo でやり直す
    sudo "$BASH" "$_ble_base/ble.sh" --update &&
      ble-update/.reload 6
    return "$?"
  else
    # _ble_base/src 内部に clone して make install
    local branch=${_ble_base_branch:-master}
    ( ble/bin/mkdir -p "$_ble_base/src" && builtin cd "$_ble_base/src" &&
        git clone --recursive --depth 1 "$_ble_base_repository_url" "$_ble_base/src/ble.sh" -b "$branch" &&
        builtin cd ble.sh && "$make" all &&
        "$make" INSDIR="$_ble_base" INSDIR_DOC="$insdir_doc" install ) &&
      ble-update/.reload
    return "$?"
  fi
  return 1
}
#%if measure_load_time
ble/debug/measure-set-timeformat ble.pp/prologue
}
#%end


#------------------------------------------------------------------------------
_ble_attached=
BLE_ATTACHED=

#%x inc.r|@|src/def|
#%x inc.r|@|src/util|

bleopt/declare -v debug_xtrace ''
bleopt/declare -v debug_xtrace_ps4 '+ '

ble/bin#freeze-utility-path "${_ble_init_posix_command_list[@]}" # <- this uses ble/util/assign.
ble/bin#freeze-utility-path man
ble/bin#freeze-utility-path groff nroff mandoc gzip bzcat lzcat xzcat # used by core-complete.sh

ble/function#trace trap ble/builtin/trap ble/builtin/trap/finalize
ble/function#trace ble/builtin/trap/.handler ble/builtin/trap/invoke ble/builtin/trap/invoke.sandbox
ble/builtin/trap/install-hook EXIT
ble/builtin/trap/install-hook INT
ble/builtin/trap/install-hook ERR inactive
ble/builtin/trap/install-hook RETURN inactive

# @var _ble_base_session
# @var BLE_SESSION_ID
function ble/base/initialize-session {
  [[ $_ble_base_session == */"$$" ]] && return 0

  local start_time=
  if ((_ble_bash>=50000)); then
    start_time=${EPOCHREALTIME//[!0-9]}
  elif ((_ble_bash>=40200)); then
    printf -v start_time '%(%s)T' -1
    ((start_time*=1000000))
  else
    ble/util/assign start_time 'ble/bin/date +%s'
    ((start_time*=1000000))
  fi
  ((start_time-=SECONDS*1000000))

  _ble_base_session=${start_time::${#start_time}-6}.${start_time:${#start_time}-6}/$$
  BLE_SESSION_ID=$_ble_base_session
}
ble/base/initialize-session

#%x inc.r|@|src/decode|
#%x inc.r|@|src/color|
#%x inc.r|@|src/canvas|
#%x inc.r|@|src/history|
#%x inc.r|@|src/edit|
#%x inc.r|@|lib/core-cmdspec-def|
#%x inc.r|@|lib/core-syntax-def|
#%x inc.r|@|lib/core-complete-def|
#%x inc.r|@|lib/core-debug-def|
#%x inc.r|@|contrib/integration/bash-preexec-def|

bleopt -I
#------------------------------------------------------------------------------
#%if measure_load_time
time {
#%end

## @fn ble [SUBCOMMAND]
##
##   無引数で呼び出した時、現在 ble.sh の内部空間に居るかどうかを判定します。
##
# Bluetooth Low Energy のツールが存在するかもしれない
ble/bin#freeze-utility-path ble
function ble/dispatch/.help {
  ble/util/print-lines \
    'usage: ble [SUBCOMMAND [ARGS...]]' \
    '' \
    'SUBCOMMAND' \
    '  # Manage ble.sh' \
    '  attach  ... alias of ble-attach' \
    '  detach  ... alias of ble-detach'  \
    '  update  ... alias of ble-update' \
    '  reload  ... alias of ble-reload' \
    '  help    ... Show this help' \
    '  version ... Show version' \
    '  check   ... Run unit tests' \
    '' \
    '  # Configuration' \
    '  opt     ... alias of bleopt' \
    '  bind    ... alias of ble-bind' \
    '  face    ... alias of ble-face' \
    '  hook    ... alias of blehook' \
    '  sabbrev ... alias of ble-sabbrev' \
    '  palette ... alias of ble-color-show' \
    ''
}
function ble/dispatch {
  if (($#==0)); then
    [[ $_ble_attached && ! $_ble_edit_exec_inside_userspace ]]
    return "$?"
  fi

  # import autoload measure assert stackdump color-show decode-{byte,char,key}
  local cmd=$1; shift
  case $cmd in
  (attach)  ble-attach "$@" ;;
  (detach)  ble-detach "$@" ;;
  (update)  ble-update "$@" ;;
  (reload)  ble-reload "$@" ;;
  (face)    ble-face "$@" ;;
  (bind)    ble-bind "$@" ;;
  (opt)     bleopt "$@" ;;
  (hook)    blehook "$@" ;;
  (sabbrev) ble-sabbrev "$@" ;;
  (palette) ble-palette "$@" ;;
  (help|--help) ble/dispatch/.help "$@" ;;
  (version|--version) ble/util/print "ble.sh, version $BLE_VERSION (noarch)" ;;
  (check|--test) ble/base/sub:test "$@" ;;
  (*)
    if ble/string#match "$cmd" '^[-a-z0-9]+$' && ble/is-function "ble-$cmd"; then
      "ble-$cmd" "$@"
    elif ble/is-function ble/bin/ble; then
      ble/bin/ble "$cmd" "$@"
    else
      ble/util/print "ble (ble.sh): unrecognized subcommand '$cmd'." >&2
      return 2
    fi
  esac
}
function ble { ble/dispatch "$@"; }


# blerc
_ble_base_rcfile=
_ble_base_rcfile_initialized=
function ble/base/load-rcfile {
  [[ $_ble_base_rcfile_initialized ]] && return 0
  _ble_base_rcfile_initialized=1

  # blerc
  if [[ ! $_ble_base_rcfile ]]; then
    { _ble_base_rcfile=$HOME/.blerc; [[ -f $_ble_base_rcfile ]]; } ||
      { _ble_base_rcfile=${XDG_CONFIG_HOME:-$HOME/.config}/blesh/init.sh; [[ -f $_ble_base_rcfile ]]; } ||
      _ble_base_rcfile=$HOME/.blerc
  fi
  if [[ -s $_ble_base_rcfile ]]; then
    source "$_ble_base_rcfile"
    blehook/.compatibility-ble-0.3/check
  fi
}

## @fn ble-attach [opts]
function ble-attach {
#%if leakvar
ble/debug/leakvar#check $"leakvar" A1-begin
#%end.i
  if (($# >= 2)); then
    ble/util/print-lines \
      'usage: ble-attach [opts]' \
      'Attach to ble.sh.' >&2
    [[ $1 != --help ]] && return 2
    return 0
  fi

#%if leakvar
ble/debug/leakvar#check $"leakvar" A2-arg
#%end.i
  # when detach flag is present
  if [[ $_ble_edit_detach_flag ]]; then
    case $_ble_edit_detach_flag in
    (exit) return 0 ;;
    (*) _ble_edit_detach_flag= ;; # cancel "detach"
    esac
  fi

  [[ ! $_ble_attached ]] || return 0
  _ble_attached=1
  BLE_ATTACHED=1

#%if leakvar
ble/debug/leakvar#check $"leakvar" A3-guard
#%end.i
  # 特殊シェル設定を待避
  builtin eval -- "$_ble_bash_FUNCNEST_adjust"
  ble/base/adjust-builtin-wrappers-1
  ble/base/adjust-bash-options
  ble/base/adjust-POSIXLY_CORRECT
  ble/base/adjust-builtin-wrappers-2
  ble/base/adjust-BASH_REMATCH

#%if leakvar
ble/debug/leakvar#check $"leakvar" A4-adjust
#%end.i
  if [[ ${IN_NIX_SHELL-} ]]; then
    # nix-shell rc の中から実行している時は強制的に prompt-attach にする
    if [[ "${BASH_SOURCE[*]}" == */rc && $1 != *:force:* ]]; then
      ble/base/install-prompt-attach
      _ble_attached=
      BLE_ATTACHED=
      ble/base/restore-BASH_REMATCH
      ble/base/restore-bash-options
      ble/base/restore-POSIXLY_CORRECT
      ble/base/restore-builtin-wrappers
#%if leakvar
ble/debug/leakvar#check $"leakvar" A4b1
#%end.i
      builtin eval -- "$_ble_bash_FUNCNEST_restore"
      return 0
    fi

    # nix-shell は BASH を誤った値に書き換えるので上書きする。
    local ret
    ble/util/readlink "/proc/$$/exe"
    [[ -x $ret ]] && BASH=$ret
#%if leakvar
ble/debug/leakvar#check $"leakvar" A4b2
#%end.i
  fi

  # char_width_mode=auto
  ble/canvas/attach
#%if leakvar
ble/debug/leakvar#check $"leakvar" A5-canvas
#%end.i

  # 取り敢えずプロンプトを表示する
  ble/term/enter      # 3ms (起動時のずれ防止の為 stty)
  ble-edit/initialize # 3ms
  ble-edit/attach     # 0ms (_ble_edit_PS1 他の初期化)
  ble/canvas/panel/render # 37ms
  ble/util/buffer.flush >&2
#%if leakvar
ble/debug/leakvar#check $"leakvar" A6-term/edit
#%end.i

  # keymap 初期化
  local IFS=$_ble_term_IFS
  ble/decode/initialize # 7ms
  ble/decode/reset-default-keymap # 264ms (keymap/vi.sh)
#%if leakvar
ble/debug/leakvar#check $"leakvar" A7-decode
#%end.i
  if ! ble/decode/attach; then # 53ms
    _ble_attached=
    BLE_ATTACHED=
    ble-edit/detach
    ble/term/leave
    ble/base/restore-BASH_REMATCH
    ble/base/restore-bash-options
    ble/base/restore-POSIXLY_CORRECT
    ble/base/restore-builtin-wrappers
    builtin eval -- "$_ble_bash_FUNCNEST_restore"
#%if leakvar
ble/debug/leakvar#check $"leakvar" A7b1
#%end.i
    return 1
  fi

  ble/history:bash/reset # 27s for bash-3.0
#%if leakvar
ble/debug/leakvar#check $"leakvar" A8-history
#%end.i

  blehook/invoke ATTACH
#%if leakvar
ble/debug/leakvar#check $"leakvar" A9-ATTACH
#%end.i

  # Note: 再描画 (初期化中のエラーメッセージ・プロンプト変更等の為)
  ble/textarea#redraw
#%if leakvar
ble/debug/leakvar#check $"leakvar" A10-redraw
#%end.i

  # Note: ble-decode/{initialize,reset-default-keymap} 内で
  #   info を設定する事があるので表示する。
  ble/edit/info/default
#%if leakvar
ble/debug/leakvar#check $"leakvar" A11-info
#%end.i
  ble-edit/bind/.tail
#%if leakvar
ble/debug/leakvar#check $"leakvar" A12-tail
#%end.i
}

function ble-detach {
  if (($#)); then
    ble/base/print-usage-for-no-argument-command 'Detach from ble.sh.' "$@"
    return "$?"
  fi

  [[ $_ble_attached && ! $_ble_edit_detach_flag ]] || return 1

  # Note: 実際の detach 処理は ble-edit/bind/.check-detach で実行される
  _ble_edit_detach_flag=${1:-detach} # schedule detach
}
function ble-detach/impl {
  [[ $_ble_attached ]] || return 1
  _ble_attached=
  BLE_ATTACHED=
  blehook/invoke DETACH

  ble-edit/detach
  ble/decode/detach
  READLINE_LINE='' READLINE_POINT=0
}
function ble-detach/message {
  ble/util/buffer.flush >&2
  printf '%s\n' "$@" 1>&2
  ble/edit/info/clear
  ble/textarea#render
  ble/util/buffer.flush >&2
}

function ble/base/unload-for-reload {
  if [[ $_ble_attached ]]; then
    ble-detach/impl
    ble/util/print "${_ble_term_setaf[12]}[ble: reload]$_ble_term_sgr0" 1>&2
    [[ $_ble_edit_detach_flag ]] ||
      _ble_edit_detach_flag=reload
  fi
  ble/base/unload reload
  return 0
}
## @fn ble/base/unload [opts]
function ble/base/unload {
  ble/util/is-running-in-subshell && return 1
  local IFS=$_ble_term_IFS
  ble/term/stty/TRAPEXIT "$1"
  ble/term/leave
  ble/util/buffer.flush >&2
  blehook/invoke unload
  ble/decode/keymap#unload
  ble-edit/bind/clear-keymap-definition-loader
  ble/builtin/trap/finalize "$1"
  ble/util/import/finalize
  ble/fd#finalize
  ble/base/clean-up-runtime-directory finalize
  builtin unset -v _ble_bash BLE_VERSION BLE_VERSINFO
  return 0
}

## @var _ble_base_attach_from_prompt
##   非空文字列の時、PROMPT_COMMAND 経由の ble-attach を現在試みている最中です。
##
## @arr _ble_base_attach_PROMPT_COMMAND
##   PROMPT_COMMAND 経由の ble-attach をする時、元々の PROMPT_COMMAND の値を保
##   持する配列です。複数回 ble.sh をロードした時に、各ロード時に待避した
##   PROMPT_COMMAND の値を配列の各要素に保持します。
##
##   Note #D1851: 以前の ble.sh ロード時に設定された値を保持したいので、既に要
##   素がある場合にはクリアしない。
_ble_base_attach_from_prompt=
((${#_ble_base_attach_PROMPT_COMMAND[@]})) ||
  _ble_base_attach_PROMPT_COMMAND=()
## @fn ble/base/install-prompt-attach
function ble/base/install-prompt-attach {
  [[ ! $_ble_base_attach_from_prompt ]] || return 0
  _ble_base_attach_from_prompt=1
  if ((_ble_bash>=50100)); then
    ((${#PROMPT_COMMAND[@]})) || PROMPT_COMMAND[0]=
    ble/array#push PROMPT_COMMAND ble/base/attach-from-PROMPT_COMMAND
    if [[ $_ble_edit_detach_flag == reload ]]; then
      _ble_edit_detach_flag=prompt-attach
      blehook internal_PRECMD!=ble/base/attach-from-PROMPT_COMMAND
    fi
  else
    local save_index=${#_ble_base_attach_PROMPT_COMMAND[@]}
    _ble_base_attach_PROMPT_COMMAND[save_index]=${PROMPT_COMMAND-}
    ble/function#lambda PROMPT_COMMAND \
                        "ble/base/attach-from-PROMPT_COMMAND $save_index \"\$FUNCNAME\""
    ble/function#trace "$PROMPT_COMMAND"
    if [[ $_ble_edit_detach_flag == reload ]]; then
      _ble_edit_detach_flag=prompt-attach
      blehook internal_PRECMD!="$PROMPT_COMMAND"
    fi
  fi
}
_ble_base_attach_from_prompt_lastexit=
_ble_base_attach_from_prompt_lastarg=
_ble_base_attach_from_prompt_PIPESTATUS=()
## @fn ble/base/attach-from-PROMPT_COMMAND prompt_command lambda
function ble/base/attach-from-PROMPT_COMMAND {
  # 後続の設定によって PROMPT_COMMAND が置換された場合にはそれを保持する
  {
    # save $?, $_ and ${PIPE_STATUS[@]}
    _ble_base_attach_from_prompt_lastexit=$? \
      _ble_base_attach_from_prompt_lastarg=$_ \
      _ble_base_attach_from_prompt_PIPESTATUS=("${PIPESTATUS[@]}")
#%if measure_load_time
    ble/util/print "ble.sh: $EPOCHREALTIME start prompt-attach" >&2
#%end
    if ((BASH_LINENO[${#BASH_LINENO[@]}-1]>=1)); then
      # 既にコマンドを実行している時にはそのコマンドの結果を記録する
      _ble_edit_exec_lastexit=$_ble_base_attach_from_prompt_lastexit
      _ble_edit_exec_lastarg=$_ble_base_attach_from_prompt_lastarg
      _ble_edit_exec_PIPESTATUS=("${_ble_base_attach_from_prompt_PIPESTATUS[@]}")
      # Note: 本当は一つ前のコマンドを知りたいが確実な方法がないのでこの関数の名前を入れておく。
      _ble_edit_exec_BASH_COMMAND=$FUNCNAME
    fi

    local is_last_PROMPT_COMMAND=1
    if (($#==0)); then
      if local ret; ble/array#index PROMPT_COMMAND ble/base/attach-from-PROMPT_COMMAND; then
        local keys; keys=("${!PROMPT_COMMAND[@]}")
        ((ret==keys[${#keys[@]}-1])) || is_last_PROMPT_COMMAND=
        ble/idict#replace PROMPT_COMMAND ble/base/attach-from-PROMPT_COMMAND
      fi
      blehook internal_PRECMD-=ble/base/attach-from-PROMPT_COMMAND || ((1)) # set -e 対策
    else
      local save_index=$1 lambda=$2

      # 待避していた内容を復元・実行
      local PROMPT_COMMAND=${_ble_base_attach_PROMPT_COMMAND[save_index]}
      local ble_base_attach_from_prompt_command=processing
      ble/prompt/update/.eval-prompt_command 2>&3
      ble/util/unlocal ble_base_attach_from_prompt_command
      _ble_base_attach_PROMPT_COMMAND[save_index]=$PROMPT_COMMAND
      ble/util/unlocal PROMPT_COMMAND

      # 可能なら自身を各 hook から除去
      blehook internal_PRECMD-="$lambda" || ((1)) # set -e 対策
      if [[ $PROMPT_COMMAND == "$lambda" ]]; then
        PROMPT_COMMAND=${_ble_base_attach_PROMPT_COMMAND[save_index]}
      else
        is_last_PROMPT_COMMAND=
      fi

      # #D1354: 入れ子の ble/base/attach-from-PROMPT_COMMAND の時は一番
      #   外側で ble-attach を実行する様にする。3>&2 2>/dev/null のリダ
      #   イレクトにより stdout.off の効果が巻き戻されるのを防ぐ為。
      [[ ${ble_base_attach_from_prompt_command-} != processing ]] || return 0
    fi

    # 既に attach 状態の時は処理はスキップ
    [[ $_ble_base_attach_from_prompt ]] || return 0
    _ble_base_attach_from_prompt=

    # Note #D1778: この attach-from-PROMPT_COMMAND が PROMPT_COMMAND
    #   処理の最後と見做せる場合、この時点で PROMPT_COMMAND は一通り終
    #   わったと見做せるので、ble-attach 内部で改めて PROMPT_COMMAND
    #   を実行する必要はなくなる。それを伝える為に中間状態の
    #   _ble_prompt_hash の値を設定する。
    # Note #D1778: bash-preexec 経由でプロンプトを設定しようとしている
    #   場合は、この時点で既に PRECMD に hook が移動している可能性があ
    #   るので PRECMD も発火しておく (PROMPT_COMMAND と PRECMD の順序
    #   が逆になるが仕方がない。問題になれば後で考える)。
    if [[ $is_last_PROMPT_COMMAND ]]; then
      ble-edit/exec:gexec/invoke-hook-with-setexit internal_PRECMD
      ble-edit/exec:gexec/invoke-hook-with-setexit PRECMD
      _ble_prompt_hash=$COLUMNS:$_ble_edit_lineno:prompt_attach
    fi
  } 3>&2 2>/dev/null # set -x 対策 #D0930

  ble-attach force

  # Note: 何故か分からないが PROMPT_COMMAND から ble-attach すると
  # ble/bin/stty や ble/bin/mkfifo や tty 2>/dev/null などが
  # ジョブとして表示されてしまう。joblist.flush しておくと平気。
  # これで取り逃がすジョブもあるかもしれないが仕方ない。
  ble/util/joblist.flush &>/dev/null
  ble/util/joblist.check
#%if measure_load_time
  ble/util/print "ble.sh: $EPOCHREALTIME end prompt-attach" >&2
#%end
}

function ble/base/process-blesh-arguments {
  local opts=$_ble_base_arguments_opts
  local attach=$_ble_base_arguments_attach
  local inputrc=$_ble_base_arguments_inputrc

  _ble_base_rcfile=$_ble_base_arguments_rcfile

  # reconstruction type of user-bindings
  _ble_decode_initialize_inputrc=$inputrc

#%if measure_load_time
time {
#%end
  ble/base/load-rcfile # blerc
#%if measure_load_time
ble/debug/measure-set-timeformat "blerc: '$_ble_base_rcfile'"; }
#%end
  ble/util/invoke-hook BLE_ONLOAD

  # attach
  case $attach in
  (attach) ble-attach ;;
  (prompt) ble/base/install-prompt-attach ;;
  (none) ;;
  (*) ble/util/print "ble.sh: unrecognized attach method --attach='$attach'." ;;
  esac
}

function ble/base/sub:test {
  local error= logfile=

  [[ ${LANG-} ]] || local LANG=en_US.UTF-8

  ble-import lib/core-test

  if (($#==0)); then
    set -- bash main util canvas decode edit syntax complete
    logfile=$_ble_base_cache/test.$(date +'%Y%m%d.%H%M%S').log
    : >| "$logfile"
    ble/test/log#open "$logfile"
  fi

  if ((!_ble_make_command_check_count)); then
    ble/test/log "MACHTYPE: $MACHTYPE"
    ble/test/log "BLE_VERSION: $BLE_VERSION"
  fi
  ble/test/log "BASH_VERSION: $BASH_VERSION"
  local line='locale:' var ret
  for var in LANG "${!LC_@}"; do
    ble/string#quote-word "${!var}"
    line="$line $var=$ret"
  done
  ble/test/log "$line"

  local section
  for section; do
    local file=$_ble_base/lib/test-$section.sh
    if [[ -f $file ]]; then
      source "$file" || error=1
    else
      ble/test/log "ERROR: Test '$section' is not defined."
      error=1
    fi
  done

  if [[ $logfile ]]; then
    ble/test/log#close
    ble/util/print "ble.sh: The test log was saved to '${_ble_term_setaf[4]}$logfile$_ble_term_sgr0'."
  fi
  [[ ! $error ]]
}
function ble/base/sub:update { ble-update; }
function ble/base/sub:clear-cache {
  (shopt -u failglob; ble/bin/rm -rf "$_ble_base_cache"/*)
}
function ble/base/sub:lib { :; } # do nothing

#%if measure_load_time
ble/debug/measure-set-timeformat ble.pp/epilogue; }
#%end

# Note: ble-attach 及びそれを呼び出す可能性がある物には DEBUG trap を
#   継承させる。これはユーザーの設定した user trap を正しく抽出する為
#   に必要。現在は ble-attach から呼び出される ble-edit/attach で処理
#   している。
ble/function#trace ble-attach
ble/function#trace ble
ble/function#trace ble/dispatch
ble/function#trace ble/base/attach-from-PROMPT_COMMAND

# Note #D1775: 以下は ble/base/unload 時に元の trap または ble.sh 有効時にユー
#   ザーが設定した trap を復元する為に用いる物。ble/base/unload は中で
#   ble/builtin/trap/finalize を呼び出す。ble/builtin/trap/finalize は別の箇所
#   で ble/function#trace されている。
ble/function#trace ble/base/unload

ble-import -f lib/_package
if [[ $_ble_init_command ]]; then
  ble/base/sub:"${_ble_init_command[@]}"; _ble_init_exit=$?
  [[ $_ble_init_attached ]] && ble-attach
  ble/util/setexit "$_ble_init_exit"
else
  ble/base/process-blesh-arguments "$@"
fi

#%if measure_load_time
ble/debug/measure-set-timeformat Total nofork; }
_ble_init_exit=$?
echo "ble.sh: $EPOCHREALTIME load end" >&2
ble/util/setexit "$_ble_init_exit"
#%end

ble/init/clean-up check-attach 2>/dev/null # set -x 対策 #D0930
{ builtin eval "return $? || exit $?"; } 2>/dev/null # set -x 対策 #D0930
###############################################################################
