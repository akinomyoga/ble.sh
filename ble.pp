#!/bin/bash
#%[release = 0]
#%[measure_load_time = 0]
#%[debug_keylogger = 1]
#%[leakvar = ""]
#%[target = getenv("blesh_target")]
#%if target == "osh"
#%%$> out/ble.osh
#%else
#%%$> out/ble.sh
#%end
#%#----------------------------------------------------------------------------
#%if measure_load_time
_ble_init_measure_prev=
_ble_init_measure_section=
function ble/init/measure/section {
  local now=${EPOCHREALTIME:-$(date +'%s.%N')}

  local s=${now%%[!0-9]*} u=000000
  if [[ $s != "$now" ]]; then
    u=${now##*[!0-9]}000000
    u=${u::6}
  fi
  local stime=$s.$u time=$((s*1000000+10#0$u))

  if [[ $_ble_init_measure_section ]]; then
    local elapsed=$((time-_ble_init_measure_prev))
    s=$((elapsed/1000))
    u=00$((elapsed%1000))
    u=${u:${#u}-3}
    elapsed=$s.${u}ms
    builtin printf '[ble.sh init %s] %s done (%s)\n' "$stime" "$_ble_init_measure_section" "$elapsed" >&2
  else
    builtin printf '[ble.sh init %s] start\n' "$stime" >&2
  fi

  _ble_init_measure_section=$1
  _ble_init_measure_prev=$time
}
_ble_debug_measure_fork_count=$(echo $BASHPID)
TIMEFORMAT='  [Elapsed %Rs; CPU U:%Us S:%Ss (%P%%)]'
function ble/debug/measure-set-timeformat {
  local title=$1 opts=$2
  local new=$(echo $BASHPID)
  local fork=$(((new-_ble_debug_measure_fork_count-1)&0xFFFF))
  _ble_debug_measure_fork_count=$new
  TIMEFORMAT="  [Elapsed %Rs; CPU U:%Us S:%Ss (%P%%)] $title"
  [[ :$opts: != *:nofork:* ]] &&
    TIMEFORMAT=$TIMEFORMAT" ($fork forks)"
}
#%end
#%if leakvar
#%%expand
$"leakvar"=__t1wJltaP9nmow__
#%%end.i
function ble/bin/grep { command grep "$@"; }
function ble/util/print { printf '%s\n' "$1"; }
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
ble/init/measure/section 'parse'
time {
ble/init/measure/section 'source'
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
  #%[commit_hash = getenv("BLE_GIT_COMMIT_ID")]
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
             '  --install PREFIX' \
             '    Install ble.sh and exit' \
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
             '  --bash-debug-version=TYPE' \
             '    This controls the warning mesage for the debug version of Bash.  When' \
             '    "full" is specified to TYPE, ble.sh prints the full message to the terminal' \
             '    when it is loaded in a debug version of Bash.  This is the default.  When' \
             '    "short" is specified, a short version of the message is printed.  When' \
             '    "once" is specified, the full message is printed only once for a specific' \
             '    version of debug Bash.  When "ignore" is specified, the message is not' \
             '    printed even when ble.sh is loaded in a debug version of Bash.' \
             '' \
             '  -o BLEOPT=VALUE' \
             '    Set a value for the specified bleopt option.' \
             '  --debug-bash-output' \
             '    Internal settings for debugging' \
             '' ;;
    --test | --update | --clear-cache | --lib | --install) _ble_init_command=1 ;;
    esac
  done
  unset _ble_init_arg
  if [ -n "$_ble_init_exit" ]; then
    unset _ble_init_exit
    unset _ble_init_command
    unset _ble_init_version
    return 0 2>/dev/null || exit 0
  fi
} 2>/dev/null # set -x 対策 #D0930

#------------------------------------------------------------------------------
# check shell

#%if target == "osh"
if [ -z "$OIL_VERSION" ]; then
  if [ "$0" == osh ]; then
    echo "ble.sh: Oil with a version under 0.8.pre3 is not supported." >&3
  else
    echo "ble.sh: This shell is not Oil. Please use this script with Oil." >&3
  fi
  return 1 2>/dev/null || exit 1
fi 3>&2 >/dev/null 2>&1 # set -x 対策 #D0930

function let { local __expr; for __expr; do eval "(($__expr))"; done; }

function ble/base/check-oil-version {
  local rex='^([0-9]+)\.([0-9]+)\.(pre)?([0-9]+)'
  [[ $OIL_VERSION =~ $rex ]]
  _ble_bash_oil=$((BASH_REMATCH[1]*10000+BASH_REMATCH[2]*100+BASH_REMATCH[4]))
}
{
  _ble_bash_oil=803
  ble/base/check-oil-version
} &>/dev/null # set -x 対策 #D0930

#%else
if [ -z "${BASH_VERSION-}" ]; then
  echo "ble.sh: This shell is not Bash. Please use this script with Bash." >&3
  unset _ble_init_exit
  unset _ble_init_command
  unset _ble_init_version
  return 1 2>/dev/null || exit 1
fi 3>&2 >/dev/null 2>&1 # set -x 対策 #D0930

if [ -z "${BASH_VERSINFO-}" ] || [ "${BASH_VERSINFO-0}" -lt 3 ]; then
  echo "ble.sh: Bash with a version under 3.0 is not supported." >&3
  unset -v _ble_init_exit _ble_init_command _ble_init_version
  return 1 2>/dev/null || exit 1
fi 3>&2 >/dev/null 2>&1 # set -x 対策 #D0930
#%end

if [[ ! $_ble_init_command ]]; then
  # We here check the cases where we do not want a line editor.  We first check
  # the cases that Bash provides.  We also check the cases where other
  # frameworks try to do a hack using an interactive Bash.  We honestly do not
  # want to add exceptions for every random framework that tries to do a naive
  # hack using interactive sessions, but it is easier than instructing users to
  # add a proper workaround/check by themselves.
  if [[ ${BASH_EXECUTION_STRING+set} ]]; then
    # builtin echo "ble.sh: ble.sh will not be activated for Bash started with '-c' option." >&3
    _ble_init_exit=1
  elif ((BASH_SUBSHELL)); then
    builtin echo "ble.sh: ble.sh cannot be loaded into a subshell." >&3
    _ble_init_exit=1
  elif [[ $- != *i* ]]; then
    case " ${BASH_SOURCE[*]##*/} " in
    (*' .bashrc '* | *' .bash_profile '* | *' .profile '* | *' bashrc '* | *' profile '*) ((0)) ;;
    esac &&
      builtin echo "ble.sh: This is not an interactive session." >&3 || ((1))
    _ble_init_exit=1
  elif ! [[ -t 4 && -t 5 ]] && ! { [[ ${bleopt_connect_tty-} ]] && >/dev/tty; }; then
    if [[ ${bleopt_connect_tty-} ]]; then
      builtin echo "ble.sh: cannot find a controlling TTY/PTY in this session." >&3
    else
      builtin echo "ble.sh: stdout/stdin are not connected to TTY/PTY." >&3
    fi
    _ble_init_exit=1
  elif [[ ${NRF_CONNECT_VSCODE-} && ! -t 3 ]]; then
    # Note #D2129: VS Code Extension "nRF Connect" tries to extract an
    # interactive setting by sending multiline commands to an interactive
    # session.  We may turn off accept_line_threshold for an nRF Connect
    # session as we do for Midnight Commander, but we do not need to enable the
    # line editor for nRF Connect in the first place.
    _ble_init_exit=1
  fi

  if [[ $_ble_init_exit ]]; then
    builtin unset -v _ble_init_exit _ble_init_command _ble_init_version
    return 1 2>/dev/null || builtin exit 1
  fi
fi 3>&2 4<&0 5>&1 &>/dev/null # set -x 対策 #D0930

{
#%if target == "osh"
  # Pretend to be bash-5.0
  _ble_bash=50000
  BASH_VERSINFO=(0 22 0 0 release python)
#%else
  _ble_bash=$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))
#%end

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
      \builtin unset -v FUNCNEST
    fi 2>/dev/null'
  _ble_bash_FUNCNEST_restore='
    if [[ $_ble_bash_FUNCNEST_adjusted ]]; then
      _ble_bash_FUNCNEST_adjusted=
      if [[ $_ble_bash_FUNCNEST_set ]]; then
        FUNCNEST=$_ble_bash_FUNCNEST
      else
        \builtin unset -v FUNCNEST
      fi
    fi 2>/dev/null'
  _ble_bash_FUNCNEST_local_adjust='
    \local _ble_local_FUNCNEST _ble_local_FUNCNEST_set
    _ble_local_FUNCNEST_set=${FUNCNEST+set}
    _ble_local_FUNCNEST=${FUNCNEST-}
    if [[ $_ble_local_FUNCNEST_set ]]; then
      \local FUNCNEST
      \builtin unset -v FUNCNEST
    fi'
  _ble_bash_FUNCNEST_local_leave='
    if [[ $_ble_local_FUNCNEST_set ]]; then
      FUNCNEST=$_ble_local_FUNCNEST
    fi'
  \builtin eval -- "$_ble_bash_FUNCNEST_adjust"

  \builtin unset -v POSIXLY_CORRECT

  _ble_bash_POSIXLY_CORRECT_adjust='
    if [[ ! ${_ble_bash_POSIXLY_CORRECT_adjusted-} ]]; then
      _ble_bash_POSIXLY_CORRECT_adjusted=1
      _ble_bash_POSIXLY_CORRECT_set=${POSIXLY_CORRECT+set}
      _ble_bash_POSIXLY_CORRECT=${POSIXLY_CORRECT-}
      if [[ $_ble_bash_POSIXLY_CORRECT_set ]]; then
        \builtin unset -v POSIXLY_CORRECT
      fi

      # ユーザが触ったかもしれないので何れにしても workaround を呼び出す。
      ble/base/workaround-POSIXLY_CORRECT
    fi'
  _ble_bash_POSIXLY_CORRECT_unset='
    if [[ ${POSIXLY_CORRECT+set} ]]; then
      \builtin unset -v POSIXLY_CORRECT
      ble/base/workaround-POSIXLY_CORRECT
    fi'
  _ble_bash_POSIXLY_CORRECT_local_adjust='
    \builtin local _ble_local_POSIXLY_CORRECT _ble_local_POSIXLY_CORRECT_set
    _ble_local_POSIXLY_CORRECT_set=${POSIXLY_CORRECT+set}
    _ble_local_POSIXLY_CORRECT=${POSIXLY_CORRECT-}
    '$_ble_bash_POSIXLY_CORRECT_unset
  _ble_bash_POSIXLY_CORRECT_local_leave='
    if [[ $_ble_local_POSIXLY_CORRECT_set ]]; then
      POSIXLY_CORRECT=$_ble_local_POSIXLY_CORRECT
    fi'
  _ble_bash_POSIXLY_CORRECT_local_enter='
    _ble_local_POSIXLY_CORRECT_set=${POSIXLY_CORRECT+set}
    _ble_local_POSIXLY_CORRECT=${POSIXLY_CORRECT-}
    '$_ble_bash_POSIXLY_CORRECT_unset
  _ble_bash_POSIXLY_CORRECT_local_return='
    \builtin local _ble_local_POSIXLY_CORRECT_ext=$?
    if [[ $_ble_local_POSIXLY_CORRECT_set ]]; then
      POSIXLY_CORRECT=$_ble_local_POSIXLY_CORRECT
    fi
    \return "$_ble_local_POSIXLY_CORRECT_ext"'
#%if target == "osh"
  _ble_bash_POSIXLY_CORRECT_local_return=${_ble_bash_POSIXLY_CORRECT_local_return/'\return'/'return'}
#%end
} 2>/dev/null

function ble/base/workaround-POSIXLY_CORRECT {
  # This function will be overwritten by ble-decode
  true
}
function ble/base/restore-POSIXLY_CORRECT {
  if [[ ! $_ble_bash_POSIXLY_CORRECT_adjusted ]]; then return 0; fi # Note: set -e の為 || は駄目
  _ble_bash_POSIXLY_CORRECT_adjusted=
  if [[ $_ble_bash_POSIXLY_CORRECT_set ]]; then
    POSIXLY_CORRECT=$_ble_bash_POSIXLY_CORRECT
  else
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_unset"
  fi
}
## @fn ble/base/is-POSIXLY_CORRECT
##   Check if the POSIX mode is enabled in the user context.  This function is
##   assumed to be called in the adjusted state.
function ble/base/is-POSIXLY_CORRECT {
  [[ $_ble_bash_POSIXLY_CORRECT_adjusted && $_ble_bash_POSIXLY_CORRECT_set ]]
}

function ble/variable#load-user-state/variable:FUNCNEST {
  if [[ $_ble_bash_FUNCNEST_adjusted ]]; then
    __ble_var_set=$_ble_bash_FUNCNEST_set
    __ble_var_val=$_ble_bash_FUNCNEST
    return 0
  elif [[ ${_ble_local_FUNCNEST_set-} ]]; then
    __ble_var_set=$_ble_local_FUNCNEST_set
    __ble_var_set=$_ble_local_FUNCNEST
    return 0
  else
    return 1
  fi
}

function ble/variable#load-user-state/variable:POSIXLY_CORRECT {
  if [[ $_ble_bash_POSIXLY_CORRECT_adjusted ]]; then
    __ble_var_set=$_ble_bash_POSIXLY_CORRECT_set
    __ble_var_val=$_ble_bash_POSIXLY_CORRECT
    return 0
  elif [[ ${_ble_local_POSIXLY_CORRECT_set-} ]]; then
    __ble_var_set=$_ble_local_POSIXLY_CORRECT_set
    __ble_var_set=$_ble_local_POSIXLY_CORRECT
    return 0
  else
    return 1
  fi
}

## @fn ble/base/list-shopt names...
##   @var[out] shopt
if ((_ble_bash>=40100)); then
  function ble/base/list-shopt { shopt=$BASHOPTS; }
else
  function ble/base/list-shopt {
    shopt=
    local name
    for name; do
      shopt -q "$name" 2>/dev/null && shopt=$shopt:$name
    done
  }
fi 2>/dev/null # set -x 対策
function ble/base/evaldef {
  local shopt
  ble/base/list-shopt extglob expand_aliases
  shopt -s extglob
  shopt -u expand_aliases
  builtin eval -- "$1"; local ext=$?
  [[ :$shopt: == *:extglob:* ]] || shopt -u extglob
  [[ :$shopt: != *:expand_aliases:* ]] || shopt -s expand_aliases
  return "$ext"
}

# will be overwritten by src/util.sh
if ((_ble_bash>=50300)); then
  function ble/util/assign { builtin eval -- "$1=\${ builtin eval -- \"\$2\"; }"; }
else
  function ble/util/assign { builtin eval -- "$1=\$(builtin eval -- \"\$2\")"; }
fi

{
  _ble_bash_builtins_adjusted=
  _ble_bash_builtins_save=
} 2>/dev/null # set -x 対策
function ble/base/adjust-builtin-wrappers/.impl1 {
  # Note: 何故か local POSIXLY_CORRECT の効果が
  #   builtin unset -v POSIXLY_CORRECT しても残存するので関数に入れる。
  # Note: set -o posix にしても read, type, builtin, local 等は上書き
  #   された儘なので難しい。unset -f builtin さえすれば色々動く様になる
  #   ので builtin は unset -f builtin してしまう。
  unset -f builtin
  builtin local builtins1 keywords1
  builtins1=(builtin unset enable unalias return break continue declare local typeset eval exec set)
  keywords1=(if then elif else case esac while until for select do done '{' '}' '[[' function)
  if [[ ! $_ble_bash_builtins_adjusted ]]; then
    _ble_bash_builtins_adjusted=1

    builtin local defs
    ble/util/assign defs '
      \builtin declare -f "${builtins1[@]}" || ((1))
      \builtin alias "${builtins1[@]}" "${keywords1[@]}" || ((1))' # set -e 対策
    _ble_bash_builtins_save=$defs
  fi
  builtin local POSIXLY_CORRECT=y
  builtin unset -f "${builtins1[@]}"
  builtin unalias "${builtins1[@]}" "${keywords1[@]}" || ((1)) # set -e 対策
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_unset"
}
function ble/base/adjust-builtin-wrappers/.impl2 {
  # Workaround (bash-3.0..4.3) #D0722
  #
  #   builtin unset -v POSIXLY_CORRECT でないと unset -f : できないが、bash-3.0
  #   -- 4.3 のバグで、local POSIXLY_CORRECT の時、builtin unset -v
  #   POSIXLY_CORRECT しても POSIXLY_CORRECT が有効であると判断されるので、
  #   "unset -f :" (非POSIX関数名) は別関数で実行する事にする。呼び出し元で既に
  #   builtin unset -v POSIXLY_CORRECT されている事を前提とする。

  # function :, alias : の保存
  local defs
  ble/util/assign defs 'LC_ALL= LC_MESSAGES=C builtin type :; alias :' || ((1)) # set -e 対策
  defs=${defs#$': is a shell builtin\n'}
  _ble_bash_builtins_save=$_ble_bash_builtins_save$'\n'$defs

  builtin unset -f :
  builtin unalias : || ((1)) # set -e 対策
}
## @fn ble/base/adjust-builtin-wrappers
##
##   Note: This function needs to be called after adjusting POSIXLY_CORRECT by
##   calling « builtin eval -- "$_ble_bash_POSIXLY_CORRECT_adjust" »
##
##   Note (#D2221) We have been delayed the execution of "unset -f :"
##   (adjust-builtin-wrappers-2) until POSIXLY_CORRECT is unset.  However, .
##   we can now call "ble/base/adjust-builtin-wrappers/.impl2" immediately
##   after "ble/base/adjust-builtin-wrappers/.impl1" because we now unset
##   POSIXLY_CORRECT earlier.  We combine those two functions again.
##
function ble/base/adjust-builtin-wrappers {
  ble/base/adjust-builtin-wrappers/.impl1

  # Note (#D2221): In Bash 3.0 and 3.1, when "local POSIXLY_CORRECT" is used in
  # a function, the POSIX mode remains effective even after the function
  # returns.  This can be fixed by calling "unset -v POSIXLY_CORRECT".
  builtin unset -v POSIXLY_CORRECT

  ble/base/adjust-builtin-wrappers/.impl2
} 2>/dev/null
function ble/base/restore-builtin-wrappers {
  if [[ $_ble_bash_builtins_adjusted ]]; then
    _ble_bash_builtins_adjusted=
    ble/base/evaldef "$_ble_bash_builtins_save"
    return 0
  fi
}
{
  ble/base/adjust-builtin-wrappers

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
function ble/base/xtrace/.fdcheck { >&"$1"; } 2>/dev/null
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
  local open=---- close=----
  if ((_ble_bash>=40200)); then
    builtin printf '%s [%(%F %T %Z)T] %s %s\n' "$open" -1 "$1" "$close"
  else
    local date
    ble/util/assign date 'date 2>/dev/null'
    builtin printf '%s [%s] %s %s\n' "$open" "$date" "$1" "$close"
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

  ((_ble_bash>=40000&&level==0)) || return 0
  _ble_bash_xtrace_debug_enabled=
  if [[ ${bleopt_debug_xtrace:-/dev/null} == /dev/null ]]; then
    if [[ $_ble_bash_xtrace_debug_fd ]]; then
      builtin eval "exec $_ble_bash_xtrace_debug_fd>&-" || return 0 # disable=#D2164 (here bash4+)
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

  ((_ble_bash>=40000&&level==0)) || return 0
  if [[ $_ble_bash_xtrace_debug_enabled ]]; then
    ble/base/xtrace/.log "$FUNCNAME"
    _ble_bash_xtrace_debug_enabled=

    # Note: ユーザーの BASH_XTRACEFD にごみが混入しない様にする為、
    # BASH_XTRACEFD を書き換える前に先に PS4 を戻す。
    ble/variable#copy-state _ble_base_PS4 PS4

    if [[ $_ble_bash_XTRACEFD_dup ]]; then
      # BASH_XTRACEFD の fd を元の出力先に繋ぎ直す
      builtin eval "exec $BASH_XTRACEFD>&$_ble_bash_XTRACEFD_dup" &&
        builtin eval "exec $_ble_bash_XTRACEFD_dup>&-" || ((1)) # disable=#D2164 (here bash4+)
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

## @fn ble/base/.adjust-bash-options vset vshopt
##   @var[out] $vset
##   @var[out] $vshopt
function ble/base/.adjust-bash-options {
  builtin eval -- "$1=\$-"
  set +evukT -B
  ble/base/xtrace/adjust

  [[ $2 == shopt ]] || local shopt
  # Note: nocasematch は bash-3.1 以上
  ble/base/list-shopt extdebug nocasematch
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

function ble/variable#load-user-state/variable:LC_ALL/.impl {
  local __ble_save=_ble_bash_$1
  __ble_var_set=${!__ble_save+set}
  __ble_var_val=${!__ble_save-}
  [[ $__ble_var_set ]] && ble/variable#get-attr -v __ble_var_att "$1"
  return 0
}
function ble/variable#load-user-state/variable:LC_COLLATE {
  ble/variable#load-user-state/variable:LC_ALL/.impl LC_COLLATE
}
function ble/variable#load-user-state/variable:LC_ALL {
  ble/variable#load-user-state/variable:LC_ALL/.impl LC_ALL
}
function ble/variable#load-user-state/variable:LC_CTYPE {
  [[ $_ble_bash_LC_ALL ]] && ble/variable#load-user-state/variable:LC_ALL/.impl LC_CTYPE
}
function ble/variable#load-user-state/variable:LC_MESSAGES {
  [[ $_ble_bash_LC_ALL ]] && ble/variable#load-user-state/variable:LC_ALL/.impl LC_MESSAGES
}
function ble/variable#load-user-state/variable:LC_NUMERIC {
  [[ $_ble_bash_LC_ALL ]] && ble/variable#load-user-state/variable:LC_ALL/.impl LC_NUMERIC
}
function ble/variable#load-user-state/variable:LC_TIME {
  [[ $_ble_bash_LC_ALL ]] && ble/variable#load-user-state/variable:LC_ALL/.impl LC_TIME
}
function ble/variable#load-user-state/variable:LANG {
  [[ $_ble_bash_LC_ALL ]] && ble/variable#load-user-state/variable:LC_ALL/.impl LANG
}

{ ble/base/adjust-bash-options; } &>/dev/null # set -x 対策 #D0930

function ble/init/force-load-inputrc {
  builtin unset -f "$FUNCNAME"

  builtin bind &>/dev/null # force to load .inputrc

  # WA #D1534 workaround for msys2 .inputrc
  if [[ $OSTYPE == msys* ]]; then
    local bind_emacs
    ble/util/assign bind_emacs 'builtin bind -m emacs -p 2>/dev/null'
    [[ $'\n'$bind_emacs$'\n' == *$'\n"\\C-?": backward-kill-line\n' ]] &&
      builtin bind -m emacs '"\C-?": backward-delete-char' 2>/dev/null
  fi
}
ble/init/force-load-inputrc

if [[ ! -o emacs && ! -o vi && ! $_ble_init_command ]]; then
  builtin echo "ble.sh: ble.sh is not intended to be used with the line-editing mode disabled (--noediting)." >&2
  ble/base/restore-bash-options
  ble/base/restore-builtin-wrappers
  ble/base/restore-POSIXLY_CORRECT
  builtin eval -- "$_ble_bash_FUNCNEST_restore"
  builtin unset -v _ble_bash
  return 1 2>/dev/null || builtin exit 1
fi

if shopt -q restricted_shell; then
  builtin echo "ble.sh: ble.sh is not intended to be used in restricted shells (--restricted)." >&2
  ble/base/restore-bash-options
  ble/base/restore-builtin-wrappers
  ble/base/restore-POSIXLY_CORRECT
  builtin eval -- "$_ble_bash_FUNCNEST_restore"
  builtin unset -v _ble_bash
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

function ble/variable#load-user-state/variable:IFS {
  __ble_var_set=${_ble_init_original_IFS_set-}
  __ble_var_val=${_ble_init_original_IFS-}
  ble/variable#get-attr -v __ble_var_att IFS
  return 0
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
    [[ ${_ble_bash_BASH_REMATCH-} =~ $_ble_bash_BASH_REMATCH_rex ]]
  }
fi

function ble/variable#load-user-state/variable:BASH_REMATCH {
  if ((_ble_bash_BASH_REMATCH_level)); then
    __ble_var_set=${BASH_REMATCH+set}
    __ble_var_val=("${_ble_bash_BASH_REMATCH[@]}")
    ble/variable#get-attr -v __ble_var_att BASH_REMATCH
    return 0
  else
    return 1
  fi
}

ble/init/adjust-IFS
ble/base/adjust-BASH_REMATCH

## @fn ble/init/clean-up [opts]
function ble/init/clean-up {
  local ext=$? opts=$1 # preserve exit status

  # 一時グローバル変数消去
  builtin unset -v _ble_init_version
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
#%if target == "osh"
  local opt_attach=none
#%else
  local opt_attach=prompt
#%end
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
    (--bash-debug-version=*|--bash-debug-version)
      local value=
      if [[ $arg == *=* ]]; then
        value=${arg#*=}
      elif (($#)); then
        value=$1; shift
      else
        opts=$opts:E
        ble/util/print "ble.sh ($arg): an option argument is missing." >&2
        continue
      fi
      case $value in
      (full|short|once|ignore)
        opts=$opts:bash-debug-version=$value ;;
      (*)
        opts=$opts:E
        ble/util/print "ble.sh ($arg): unrecognized value '$value'." >&2
      esac ;;
    (--debug-bash-output)
      bleopt_internal_suppress_bash_output= ;;
    (--test | --update | --clear-cache | --lib | --install)
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
  builtin unset -v _ble_bash
  return 2 2>/dev/null || builtin exit 2
fi

if [[ ${_ble_base-} ]]; then
  [[ $_ble_init_command ]] && _ble_init_attached=$_ble_attached
  if ! _ble_bash=$_ble_bash ble/base/unload-for-reload; then
    builtin echo "ble.sh: an old version of ble.sh seems to be already loaded." >&2
    ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
    return 1 2>/dev/null || builtin exit 1
  fi
fi

#------------------------------------------------------------------------------
# Initialize version information

_ble_bash_loaded_in_function=0
#%if target == "osh"
# OSH_TODO: How to test this?
false && _ble_bash_loaded_in_function=1
#%else
local _ble_local_test 2>/dev/null && _ble_bash_loaded_in_function=1
#%end

_ble_version=0
BLE_VERSION=$_ble_init_version
function ble/base/initialize-version-variables {
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
  ((_ble_version=major*10000+minor*100+patch))
  BLE_VERSINFO=("$major" "$minor" "$patch" "$hash" "$status" noarch)
  BLE_VER=$_ble_version
}
function ble/base/clear-version-variables {
  builtin unset -v _ble_bash _ble_version BLE_VERSION BLE_VERSINFO BLE_VER
}
ble/base/initialize-version-variables

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

# ble/bin

if ((_ble_bash>=40000)); then
  function ble/bin#has { builtin type -t -- "$@" &>/dev/null; }
else
  function ble/bin#has {
    local cmd
    for cmd; do builtin type -t -- "$cmd" || return 1; done &>/dev/null
    return 0
  }
fi

## @fn ble/bin#get-path command
##   @var[out] path
function ble/bin#get-path {
  local cmd=$1
  ble/util/assign path 'builtin type -P -- "$cmd" 2>/dev/null' && [[ $path ]]
}

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
    [[ $flags == *n* ]] && ble/bin#has ble/bin/"$cmd" && continue
    ble/bin#has ble/bin/.frozen:"$cmd" && continue
    if ble/bin#get-path "$cmd"; then
      [[ $path == ./* || $path == ../* ]] && path=$PWD/$path
      builtin eval "function ble/bin/$cmd { '${path//$q/$Q}' \"\$@\"; }"
    else
      fail=1
    fi
  done
  ((!fail))
}

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
    local default_path
    ble/util/assign default_path 'command -p getconf PATH 2>/dev/null'
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
    if ble/util/assign USER 'id -un 2>/dev/null' && [[ $USER ]]; then
      export USER
      ble/util/print "ble.sh: modified USER=$USER" >&2
    fi
  fi
  _ble_base_env_USER=$USER

  if [[ ! ${HOSTNAME-} ]]; then
    ble/util/print "ble.sh: suspicious environment: \$HOSTNAME is empty."
    if ble/util/assign HOSTNAME 'uname -n 2>/dev/null' && [[ $HOSTNAME ]]; then
      export HOSTNAME
      ble/util/print "ble.sh: fixed HOSTNAME=$HOSTNAME" >&2
    fi
  fi
  _ble_base_env_HOSTNAME=$HOSTNAME

  if [[ ! ${HOME-} ]]; then
    ble/util/print "ble.sh: insane environment: \$HOME is empty." >&2
    local home
    if ble/util/assign home 'getent passwd 2>/dev/null | awk -F : -v UID="$UID" '\''$3 == UID {print $6}'\''' && [[ $home && -d $home ]] ||
        { [[ $USER && -d /home/$USER && -O /home/$USER ]] && home=/home/$USER; } ||
        { [[ $USER && -d /Users/$USER && -O /Users/$USER ]] && home=/Users/$USER; } ||
        { [[ $home && ! ( -e $home && -h $home ) ]] && ble/bin/mkdir -p "$home" 2>/dev/null; }
    then
      export HOME=$home
      ble/util/print "ble.sh: modified HOME=$HOME" >&2
    fi
  fi

  if [[ ! ${LANG-} ]]; then
    ble/util/print "ble.sh: suspicious environment: \$LANG is empty." >&2
  fi

  # Check locale and work around `convert-meta on' in bash >= 5.2
  if ((_ble_bash>=50200)); then
    # Note #D2069: In bash >= 5.2, when the specified locale does not exist,
    # the readline setting `convert-meta' is automatically turned on when
    # Readline is first initialized.  This interferes with ble.sh's trick to
    # distinguish isolated ESCs from meta ESCs, i.e., the combination "ESC ["
    # is converted to "<C0> <9B> [" by ble.sh's macro, <C0> is converted to
    # "ESC @" by `convert-meta', and "ESC @" is again converted to "<C0> <9B>
    # @".  This forms an infinite loop.  ble.sh tries to adjust `convert-meta',
    # but Readline's adjustment takes place at a random timing which is not
    # controllable.  To work around this, we need to forcibly initialize
    # Readline before ble.sh adjusts `convert-meta'.

    local error
    # Note: We check if the current locale setting produces an error message.
    # We try the workaround only when the locale appears to be broken because
    # the workaround may have a side effect of consuming user's input.
    ble/util/assign error '{ LC_ALL= LC_CTYPE=C ble/util/put; } 2>&1'
    if [[ $error ]]; then
      ble/util/print "$error" >&2
      ble/util/print "ble.sh: please check the locale settings (LANG and LC_*)." >&2

      # Note: Somehow, the workaround of using "read -et" only works after
      # running `LC_ALL= LC_CTYPE=C cmd'.  In bash < 5.3, ble/util/assign at
      # this point is executed under a subshell, so we need to run `LC_ALL=
      # LC_CTYPE=C ble/util/put' again in the main shell
      ((_ble_bash>=50300)) || { LC_ALL= LC_CTYPE=C ble/util/put; } 2>/dev/null

      # We here forcibly initialize locales of Readline to make Readline's
      # adjustment of convert-meta take place here.
      local dummy
      builtin read -et 0.000001 dummy </dev/tty
    fi
  fi

  # 暫定的な ble/bin/$cmd 設定
  ble/bin/.default-utility-path "${_ble_init_posix_command_list[@]}"

  return 0
}
if ! ble/init/check-environment; then
  ble/util/print "ble.sh: failed to adjust the environment. canceling the load of ble.sh." >&2
  ble/base/clear-version-variables
  ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
  return 1
fi

# Note: src/util.sh で ble/util/assign を定義した後に呼び出される。
_ble_bin_awk_type=
function ble/bin/awk/.instantiate {
  local path q=\' Q="'\''" ext=1

  if ble/bin#get-path nawk; then
    [[ $path == ./* || $path == ../* ]] && path=$PWD/$path
    # Note: Some distribution (like Ubuntu) provides gawk as "nawk" by
    # default. To avoid wrongly picking up gawk as nawk, we need to check the
    # version output from the command.  2024-12-10 In KaKi87's server [1],
    # Debian 12 provided mawk as "nawk".
    # [1] https://github.com/akinomyoga/ble.sh/issues/535#issuecomment-2528258996
    local version
    ble/util/assign version '"$path" -W version' 2>/dev/null </dev/null
    if [[ $version != *'GNU Awk'* && $version != *mawk* ]]; then
      builtin eval "function ble/bin/nawk { '${path//$q/$Q}' -v AWKTYPE=nawk \"\$@\"; }"
      if [[ ! $_ble_bin_awk_type ]]; then
        _ble_bin_awk_type=nawk
        builtin eval "function ble/bin/awk { '${path//$q/$Q}' -v AWKTYPE=nawk \"\$@\"; }" && ext=0
      fi
    fi
  fi

  if ble/bin#get-path mawk; then
    [[ $path == ./* || $path == ../* ]] && path=$PWD/$path
    builtin eval "function ble/bin/mawk { '${path//$q/$Q}' -v AWKTYPE=mawk \"\$@\"; }"
    if [[ ! $_ble_bin_awk_type ]]; then
      _ble_bin_awk_type=mawk
      builtin eval "function ble/bin/awk { '${path//$q/$Q}' -v AWKTYPE=mawk \"\$@\"; }" && ext=0
    fi
  fi

  if ble/bin#get-path gawk; then
    [[ $path == ./* || $path == ../* ]] && path=$PWD/$path
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
    elif ble/bin#get-path awk; then
      [[ $path == ./* || $path == ../* ]] && path=$PWD/$path
      local version
      ble/util/assign version '"$path" -W version' 2>/dev/null </dev/null && [[ $version ]] ||
        ble/util/assign version '"$path" --version' 2>/dev/null </dev/null
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
          local -x LC_ALL= LC_CTYPE=C LC_COLLATE=C 2>/dev/null
          /usr/bin/awk -v AWKTYPE=nawk "$@"; local ext=$?
          ble/util/unlocal LC_ALL LC_CTYPE LC_COLLATE 2>/dev/null
          return "$ext"
        }
      elif [[ $_ble_bin_awk_type == [gmn]awk ]] && ! ble/is-function ble/bin/"$_ble_bin_awk_type" ; then
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

# Do not overwrite by ble/bin#freeze-utility-path
function ble/bin/.frozen:awk { return 0; }
function ble/bin/.frozen:nawk { return 0; }
function ble/bin/.frozen:mawk { return 0; }
function ble/bin/.frozen:gawk { return 0; }

if [[ $OSTYPE == darwin* ]]; then
  function ble/bin/sed/.instantiate {
    local path=
    ble/bin#get-path sed || return 1

    if [[ $path == /usr/bin/sed ]]; then
      # macOS sed seems to have the same issue as macOS awk.  In macOS, we
      # always run "sed" in the C locale.
      function ble/bin/sed {
        local -x LC_ALL= LC_CTYPE=C LC_COLLATE=C 2>/dev/null
        /usr/bin/sed "$@"; local ext=$?
        ble/util/unlocal LC_ALL LC_CTYPE LC_COLLATE 2>/dev/null
        return "$ext"
      }
    else
      [[ $path == ./* || $path == ../* ]] && path=$PWD/$path
      local q=\' Q="'\''"
      builtin eval "function ble/bin/sed { '${path//$q/$Q}' \"\$@\"; }"
    fi
    return 0
  }
  function ble/bin/sed {
    if ble/bin/sed/.instantiate; then
      ble/bin/sed "$@"
    else
      command sed "$@"
    fi
  }
  function ble/bin/.frozen:sed { return 0; }
else
  function ble/bin/sed/.instantiate { return 0; }
fi

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
      function ble/bin/awk0.available { return 0; }
      return 0
    fi
  done

  if ble/bin/awk0.available/test ble/bin/awk &&
      function ble/bin/awk0 { ble/bin/awk "$@"; }; then
    function ble/bin/awk0.available { return 0; }
    return 0
  fi

  function ble/bin/awk0.available { return 1; }
  return 1
}

function ble/base/is-msys1 {
  local cr; cr=$'\r'
  [[ $OSTYPE == msys && ! $cr ]]
}

function ble/base/is-wsl {
  local kernel_version
  if [[ -d /usr/lib/wsl/lib && -r /proc/version ]] &&
       ble/bash/read kernel_version < /proc/version &&
       [[ $kernel_version == *-microsoft-* ]]
  then
    function ble/base/is-wsl { return 0; }
    return 0
  else
    function ble/base/is-wsl { return 1; }
    return 1
  fi
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

function ble/init/adjust-environment {
  builtin unset -f "$FUNCNAME"

  if [[ ${IN_NIX_SHELL-} ]]; then
    # Since "nix-shell" overwrites BASH to the path to a binary image different
    # from the current one, the Bash process crashes on attempting loading
    # loadable builtins.  We rewrite it to the correct one.
    local ret=
    ble/util/readlink "/proc/$$/exe" 2>/dev/null
    [[ -x $ret ]] && BASH=$ret
  fi
}
ble/init/adjust-environment

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
  ble/util/print "ble.sh: ble base directory not found!" >&2
  ble/base/clear-version-variables
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

  # Note: Some versions of WSL around 2023-09 seem to have an issue with the
  # permission of /run/user/*, so we avoid to use them in WSL.
  [[ $runtime_dir == /run/user/* ]] && ble/base/is-wsl && return 1

  if ! [[ -r $runtime_dir && -w $runtime_dir && -x $runtime_dir ]]; then
    [[ $runtime_dir == "$XDG_RUNTIME_DIR" ]] &&
      ble/util/print "ble.sh: XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' doesn't have a proper permission." >&2
    return 1
  fi

  ble/base/.create-user-directory _ble_base_run "$runtime_dir/blesh"
}
function ble/base/initialize-runtime-directory/.tmp {
  [[ -r /tmp && -w /tmp && -x /tmp ]] || return 1

  # Note: WSL seems to clear /tmp after the first instance of Bash starts,
  # which causes a problem of missing /tmp after blesh's initialization.
  # https://github.com/microsoft/WSL/issues/8441#issuecomment-1139434972
  # https://github.com/akinomyoga/ble.sh/discussions/462
  ble/base/is-wsl && return 1

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
function ble/base/initialize-runtime-directory/.base {
  local tmp_dir=$_ble_base/run
  if [[ ! -d $tmp_dir ]]; then
    ble/bin/mkdir -p "$tmp_dir" || return 1
    ble/bin/chmod a+rwxt "$tmp_dir" || return 1
  fi
  ble/base/.create-user-directory _ble_base_run "$tmp_dir/${USER:-$UID}@$HOSTNAME"
}
function ble/base/initialize-runtime-directory/.home {
  local cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
  if [[ ! -d $cache_dir ]]; then
    if [[ $XDG_CACHE_HOME ]]; then
      ble/util/print "ble.sh: XDG_CACHE_HOME='$XDG_CACHE_HOME' is not a directory." >&2
      return 1
    else
      ble/bin/mkdir -p "$cache_dir" || return 1
    fi
  fi
  if ! [[ -r $cache_dir && -w $cache_dir && -x $cache_dir ]]; then
    if [[ $XDG_CACHE_HOME ]]; then
      ble/util/print "ble.sh: XDG_CACHE_HOME='$XDG_CACHE_HOME' doesn't have a proper permission." >&2
    else
      ble/util/print "ble.sh: '$cache_dir' doesn't have a proper permission." >&2
    fi
    return 1
  fi
  ble/base/.create-user-directory _ble_base_run "$cache_dir/blesh/run"
}
function ble/base/initialize-runtime-directory {
  ble/base/initialize-runtime-directory/.xdg && return 0
  ble/base/initialize-runtime-directory/.tmp && return 0
  ble/base/initialize-runtime-directory/.base && return 0
  ble/base/initialize-runtime-directory/.home
}
if ! ble/base/initialize-runtime-directory; then
  ble/util/print "ble.sh: failed to initialize \$_ble_base_run." >&2
  ble/base/clear-version-variables
  ble/init/clean-up 2>/dev/null # set -x 対策 #D0930
  return 1
fi

# ロード時刻の記録 (ble-update で使う為)
>| "$_ble_base_run/$$.load"

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
      if ble/string#match "$run_pid" '^-?[0-9]+$' && kill -0 "$run_pid" &>/dev/null; then
        if ((pid==$$)); then
          # 現セッションの背景プロセスの場合は遅延させる
          bgpids[ibgpid++]=$run_pid
        else
          builtin kill -- "$run_pid" &>/dev/null
          ble/util/msleep 50
          builtin kill -0 "$run_pid" &>/dev/null &&
            (ble/util/nohup "ble/util/conditional-sync '' '((1))' 100 progressive-weight:pid=$run_pid:no-wait-pid:timeout=3000:SIGKILL")
        fi
      fi
    fi

    removed[iremoved++]=$file
  done
  ((iremoved)) && ble/bin/rm -rf "${removed[@]}" 2>/dev/null
  ((ibgpid)) && (ble/util/nohup 'ble/bin/sleep 3; builtin kill -- "${bgpids[@]}" &>/dev/null')

  [[ $failglob ]] && shopt -s failglob
  [[ $noglob ]] && set -f
  return 0
}

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

#%if target == "osh"
  local ver=${BLE_VERSINFO[0]}.${BLE_VERSINFO[1]}+osh
#%else
  local ver=${BLE_VERSINFO[0]}.${BLE_VERSINFO[1]}
#%end
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
#%if target == "osh"
  local ver=${BLE_VERSINFO[0]}.${BLE_VERSINFO[1]}+osh
#%else
  local ver=${BLE_VERSINFO[0]}.${BLE_VERSINFO[1]}
#%end
  ble/base/.create-user-directory _ble_base_cache "$cache_dir/$UID/$ver"
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
  ble/util/print "ble.sh: failed to initialize \$_ble_base_cache." >&2
  ble/base/clear-version-variables
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
  ble/util/print "ble.sh: failed to initialize \$_ble_base_state." >&2
  ble/base/clear-version-variables
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
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  local -a _ble_local_options=()

  [[ ! -e $_ble_base_rcfile ]] ||
    ble/array#push _ble_local_options --rcfile="${_ble_base_rcfile:-/dev/null}"
  [[ $_ble_base_arguments_inputrc == auto ]] ||
    ble/array#push _ble_local_options --inputrc="$_ble_base_arguments_inputrc"

  local name
  for name in keep-rlvars; do
    if [[ :$_ble_base_arguments_opts: == *:"$name":* ]]; then
      ble/array#push _ble_local_options "--$name"
    fi
  done
  ble/util/unlocal name

  ble/array#push _ble_local_options '--bash-debug-version=ignore'

  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
  source "$_ble_base/ble.sh" "${_ble_local_options[@]}"
}

#%[quoted_repository   = "'" + getenv("PWD"               ).replace("'", "'\\''") + "'"]
#%[quoted_branch       = "'" + getenv("BLE_GIT_BRANCH"    ).replace("'", "'\\''") + "'"]
#%[quoted_git_version  = "'" + getenv("BUILD_GIT_VERSION" ).replace("'", "'\\''") + "'"]
#%[quoted_make_version = "'" + getenv("BUILD_MAKE_VERSION").replace("'", "'\\''") + "'"]
#%[quoted_gawk_version = "'" + getenv("BUILD_GAWK_VERSION").replace("'", "'\\''") + "'"]
#%expand
_ble_base_repository=$"quoted_repository"
_ble_base_branch=$"quoted_branch"
_ble_base_repository_url=https://github.com/akinomyoga/ble.sh
_ble_base_build_git_version=$"quoted_git_version"
_ble_base_build_make_version=$"quoted_make_version"
_ble_base_build_gawk_version=$"quoted_gawk_version"
#%end.i
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
      builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
      ble-reload
      ext=$?
      builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_enter"
      return "$ext"
    fi
    return 0
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
    ble/util/joblist/__suppress__
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
## @fn ble-update/.check-build-dependencies
##   @var[out] make
function ble-update/.check-build-dependencies {
  # check make
  make=
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
  return 0
}
## @fn ble-update/.check-repository
function ble-update/.check-repository {
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
      return 0
    fi
  fi
  return 1
}
function ble-update/.impl {
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

  local make
  ble-update/.check-build-dependencies || return 1

  local insdir_doc=$_ble_base/doc
  [[ ! -d $insdir_doc && -d ${_ble_base%/*}/doc/blesh ]] &&
    insdir_doc=${_ble_base%/*}/doc/blesh

  if ble-update/.check-repository; then
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
function ble-update {
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
  ble-update/.impl "$@"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return"
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
ble/bin/sed/.instantiate

ble/function#trace trap ble/builtin/trap ble/builtin/trap/finalize
ble/function#trace ble/builtin/trap/.handler ble/builtin/trap/invoke ble/builtin/trap/invoke.sandbox
ble/builtin/trap/install-hook EXIT
ble/builtin/trap/install-hook INT
ble/builtin/trap/install-hook ERR inactive
ble/builtin/trap/install-hook RETURN inactive

# @var _ble_base_session
# @var BLE_SESSION_ID
function ble/base/initialize-session {
  local ret
  ble/string#split ret / "${_ble_base_session-}"
  [[ ${ret[1]} == "$$" ]] && return 0

  ble/util/timeval; local start_time=$ret
  ((start_time-=SECONDS*1000000))

  _ble_base_session=${start_time::${#start_time}-6}.${start_time:${#start_time}-6}/$$
  export BLE_SESSION_ID=$_ble_base_session
}
ble/base/initialize-session

# DEBUG version の Bash では遅いという通知
function ble/base/check-bash-debug-version {
  case ${BASH_VERSINFO[4]} in
  (alp*|bet*|dev*|rc*|releng*|maint*) ;;
  (*) return 0 ;;
  esac

  local type=check ret
  ble/opts#extract-last-optarg "$_ble_base_arguments_opts" bash-debug-version check && type=$ret
  [[ $type == ignore ]] && return 0

  local file=$_ble_base_cache/base.bash-debug-version-checked.txt
  local -a checked=()
  [[ ! -d $file && -r $file && -s $file ]] && ble/util/mapfile checked < "$file"
  if ble/array#index checked "$BASH_VERSION"; then
    [[ $type == once ]] && return 0
  else
    ble/util/print "$BASH_VERSION" >> "$file"
  fi

  local sgr0=$_ble_term_sgr0
  local sgr1=${_ble_term_setaf[4]}
  local sgr2=${_ble_term_setaf[6]}
  local sgr3=${_ble_term_setaf[2]}
  local sgrC=${_ble_term_setaf[8]}
  local bold=$_ble_term_bold
  if [[ $type == short || $_ble_init_command ]]; then
    ble/util/print-lines \
      "Note: ble.sh can be very slow in a debug version of Bash: $sgr3$BASH_VERSION$sgr0"
  else
    ble/util/print-lines \
      "$bold# ble.sh with debug version of Bash$sgr0" \
      '' \
      'ble.sh may become very slow because this is a debug version of Bash (version' \
      "\`$sgr3$BASH_VERSION$sgr0', release status: \`$sgr3${BASH_VERSINFO[4]}$sgr0').  We recommend using" \
      'ble.sh with a release version of Bash.  If you want to use ble.sh with a' \
      'non-release version of Bash, it is highly recommended to build Bash with the' \
      "configure option \`$sgr2--with-bash-malloc=no$sgr0' for practical performance:" \
      '' \
      "  $sgr1./configure $bold--with-bash-malloc=no$sgr0" \
      '' \
      'To suppress this startup warning message, please specify the option' \
      "\`$sgr2--bash-debug-version=short$sgr0' or \`${sgr2}once$sgr0' or \`${sgr2}ignore$sgr0' to \`ble.sh':" \
      '' \
      "  ${sgrC}# Show a short version of the message$sgr0" \
      "  ${sgr1}source /path/to/ble.sh $bold--bash-debug-version=short$sgr0" \
      '' \
      "  ${sgrC}# Do not print the warning message more than once$sgr0" \
      "  ${sgr1}source /path/to/ble.sh $bold--bash-debug-version=once$sgr0" \
      '' \
      "  ${sgrC}# Show the warning message only once for each debug version of Bash$sgr0" \
      "  ${sgr1}source /path/to/ble.sh $bold--bash-debug-version=ignore$sgr0" \
      ''
  fi
}
ble/base/check-bash-debug-version

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

# initialization time = 9ms (for 70 files)
ble/function#try ble/util/idle.push ble/base/clean-up-runtime-directory

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
    '' \
    '  # Diagnostics' \
    '  summary ... Summarize the current shell setup' \
    ''
}
function ble/dispatch:summary {
  ble/widget/display-shell-version
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
    if ble/string#match "$cmd" '^[-a-zA-Z0-9]+$'; then
      if ble/is-function ble/dispatch:"$cmd"; then
        ble/dispatch:"$cmd" "$@"
        return "$?"
      elif ble/is-function "ble-$cmd"; then
        "ble-$cmd" "$@"
        return "$?"
      fi
    fi

    if ble/is-function ble/bin/ble; then
      # There seems to be an existing command "ble" for BLE (Bluetooth Low
      # Energy) which has the following subcommands [1]: abort, begin,
      # callback, characteristics, close, connect, descriptors, disable,
      # disconnect, dread, dwrite, enable, equal, execute, expand, getrssi,
      # info, mtu, pair, read, reconnect, scanner, services, shorten, start,
      # stop, unpair, userdata, write.  If we receive an unknown subcommand and
      # an external command "ble" exists, we redirect the call to the external
      # command "ble".
      #
      # [1] https://www.androwish.org/home/wiki?name=ble+command
      ble/bin/ble "$cmd" "$@"
      return "$?"
    fi

    ble/util/print "ble (ble.sh): unrecognized subcommand '$cmd'." >&2
    return 2
  esac
}
function ble {
  case ${1-} in
  (attach|detach|update|reload)
    # These subcommands can affect the POSIX mode, so we need to call them
    # without the adjustment of the POSIX mode.
    "ble-$@" ;;
  (*)
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
    ble/dispatch "$@"
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_return" ;;
  esac
}


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

# ble-attach needs to be performed at the very end of the Bash startup file.
# However, in some environment, the terminal or the session manager would start
# Bash with a custom startup file, and ~/.bashrc is sourced from the custom
# startup file.  In this case, when the user puts "ble-attach" at the end of
# ~/.bashrc, other settings would continue to be executed even after the
# execution of "ble-attach".
function ble/base/attach/.needs-prompt-attach {
  local ext=1

  [[ $1 == *:force:* ]] && return 1

  # nix-shell loads the Bash startup file from inside its custom file "rc".
  if [[ ${IN_NIX_SHELL-} && "${BASH_SOURCE[*]}" == */rc ]]; then
    # We force prompt-attach when ble-attach is run inside "nix-shell rc".
    ext=0
  fi

  if [[ ${VSCODE_INJECTION-} ]]; then
    # VS Code also tries to source ~/.bashrc from its
    # "shellIntegration-bash.sh". VS Code shell integration seems to set the
    # variable "VSCODE_INJECTION" while it sources the user's startup file, and
    # it unsets the variable after the initialization.
    ext=0
  elif [[ ${kitty_bash_inject-} ]]; then
    # When the startup file is sourced from kitty's shell ingteration
    # "kitty.bash", the variable "kitty_bash_inject" is set.  The variable is
    # unset after the initialization.  If we find it, we cancel the manual
    # attaching and switch to the prompt attach.
    ext=0
  elif [[ ${ghostty_bash_inject-} || ${__ghostty_bash_flags-} ]]; then
    # Ghostty seems to use a shell-integration code derived from kitty's.  By
    # the way, kitty is licensed under GPL-3.0, while Ghostty is licensed under
    # the MIT license.  Is it allowed to include a derivative of a part of
    # kitty in the MIT-licensed Ghostty?  It may be non-trivial whether the
    # shell integration is an essential part of Ghostty.
    # Note: Ghostty has updated the variable name on 2025-01-17 from
    # "ghostty_bash_inject" to "__ghostty_bash_flags".
    ext=0
  fi

  return "$ext"
}

## @fn ble-attach [opts]
function ble-attach {
#%if leakvar
ble/debug/leakvar#check $"leakvar" A1-begin
#%end.i
  if (($# >= 2)); then
    # Note: We may not use "ble/util/print-lines" because it can be in the
    # POSIX mode.
    builtin printf '%s\n' \
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
#%if measure_load_time
  ble/init/measure/section 'prompt'
#%end
  _ble_attached=1
  BLE_ATTACHED=1

#%if leakvar
ble/debug/leakvar#check $"leakvar" A3-guard
#%end.i
  # 特殊シェル設定を待避
  builtin eval -- "$_ble_bash_FUNCNEST_adjust"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_adjust"
  ble/base/adjust-builtin-wrappers
  ble/base/adjust-bash-options
  ble/base/adjust-BASH_REMATCH

#%if leakvar
ble/debug/leakvar#check $"leakvar" A4-adjust
#%end.i

  if ble/base/attach/.needs-prompt-attach; then
    ble/base/install-prompt-attach
    _ble_attached=
    BLE_ATTACHED=
    ble/base/restore-BASH_REMATCH
    ble/base/restore-bash-options
    ble/base/restore-builtin-wrappers
    ble/base/restore-POSIXLY_CORRECT
#%if leakvar
ble/debug/leakvar#check $"leakvar" A4b1
#%end.i
    builtin eval -- "$_ble_bash_FUNCNEST_restore"
    return 0
  fi
#%if leakvar
ble/debug/leakvar#check $"leakvar" A4b2
#%end.i

  # reconnect standard streams
  ble/fd/save-external-standard-streams
  exec 0<&"$_ble_util_fd_tui_stdin"
  exec 1>&"$_ble_util_fd_tui_stdout"
  exec 2>&"$_ble_util_fd_tui_stderr"

  # Terminal initialization and Terminal requests (5.0ms)
  #   The round-trip communication will take time, so we first adjust the
  #   terminal state and send requests.  We then calculate the first prompt,
  #   which takes about 50ms, while waiting for the responses from the
  #   terminal.
  ble/util/notify-broken-locale
  ble/term/initialize     # 0.4ms
  ble/term/attach noflush # 2.5ms (起動時のずれ防止の為 stty -echo は早期に)
  ble/canvas/attach       # 1.8ms (requests for char_width_mode=auto)
  ble/util/buffer.flush   # 0.3ms

#%if leakvar
ble/debug/leakvar#check $"leakvar" A5-term/init
#%end.i

  # Show the first prompt (44.7ms)
  ble-edit/initialize       # 0.3ms
  ble-edit/attach           # 2.1ms (_ble_edit_PS1 他の初期化)
  ble_attach_first_prompt=1 \
    ble/canvas/panel/render # 42ms
  ble/util/buffer.flush     # 0.2ms
#%if measure_load_time
  ble/util/print >&2
  ble/init/measure/section 'bind'
#%end

#%if leakvar
ble/debug/leakvar#check $"leakvar" A6-edit
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
    ble/base/restore-builtin-wrappers
    ble/base/restore-POSIXLY_CORRECT
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

  # We here temporarily restore PS1 and PROMPT_COMMAND for the user hooks
  # registered to ATTACH.  Note that in this context, ble-edit/adjust-PS1 is
  # already performed by the above ble-edit/attach.
  ble-edit/restore-PS1
  blehook/invoke ATTACH
  ble-edit/adjust-PS1
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
#%if measure_load_time
  ble/init/measure/section 'idle'
#%end
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
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"
    ble/base/print-usage-for-no-argument-command 'Detach from ble.sh.' "$@"
    builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
    return 2
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
  ble/util/buffer.print-lines "$@"
  ble/util/buffer.flush
  ble/edit/info/clear
  ble/textarea#render
  ble/util/buffer.flush
}

function ble/base/unload-for-reload {
  if [[ $_ble_attached ]]; then
    ble-detach/impl
    local ret
    ble/edit/marker#instantiate 'reload' &&
      ble/util/print "$ret" >&"$_ble_util_fd_tui_stderr"
    [[ $_ble_edit_detach_flag ]] ||
      _ble_edit_detach_flag=reload
  fi

  # We here localize "_ble_bash" to avoid overwriting _ble_bash, which is
  # already initialized by the new instance of ble.sh.
  local _ble_bash=$_ble_bash
  ble/base/unload reload
  return 0
}
## @fn ble/base/unload [opts]
function ble/base/unload {
  ble/util/is-running-in-subshell && return 1

  # Adjust environment
  local IFS=$_ble_term_IFS
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_adjust"
  ble/base/adjust-builtin-wrappers
  ble/base/adjust-bash-options
  ble/base/adjust-BASH_REMATCH

  # src/edit.sh
  ble-edit/bind/clear-keymap-definition-loader
  ble/widget/.bell/.clear-DECSCNM

  # decode.sh
  ble/decode/keymap#unload

  # src/util.sh
  ble/term/stty/TRAPEXIT "$1"
  ble/term/leave
  ble/util/buffer.flush
  blehook/invoke unload
  ble/builtin/trap/finalize "$1"
  ble/util/import/finalize

  # main
  ble/base/clean-up-runtime-directory finalize
  ble/fd#finalize # this is used by the above function
  ble/base/clear-version-variables
  return 0
} 0<&"$_ble_util_fd_tui_stdin" 1>&"$_ble_util_fd_tui_stdout" 2>&"$_ble_util_fd_tui_stderr"

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

    local prompt_command=ble/base/attach-from-PROMPT_COMMAND
    if ((_ble_bash>=50300)); then
      local prompt_command_new=ble::base::attach-from-PROMPT_COMMAND
      ble/function#copy "$prompt_command" "$prompt_command_new" &&
        prompt_command=$prompt_command_new
    fi
    ble/array#push PROMPT_COMMAND "$prompt_command"

    if [[ $_ble_edit_detach_flag == reload ]]; then
      _ble_edit_detach_flag=prompt-attach
      blehook internal_PRECMD!=ble/base/attach-from-PROMPT_COMMAND
    fi
  else
    local save_index=${#_ble_base_attach_PROMPT_COMMAND[@]}
    _ble_base_attach_PROMPT_COMMAND[save_index]=${PROMPT_COMMAND-}
    # Note: We adjust FUNCNEST and POSIXLY_CORRECT but do not need to be
    # restore them here because "ble/base/attach-from-PROMPT_COMMAND" fails
    # only when "ble-attach" fails, in such a case "ble-attach" already restore
    # them.
    ble/function#lambda PROMPT_COMMAND '
      local _ble_local_lastexit=$? _ble_local_lastarg=$_
      builtin eval -- "$_ble_bash_FUNCNEST_adjust"
      builtin eval -- "$_ble_bash_POSIXLY_CORRECT_adjust"
      ble/util/setexit "$_ble_local_lastexit" "$_ble_local_lastarg"
      ble/base/attach-from-PROMPT_COMMAND '"$save_index"' "'"$FUNCNAME"'"'
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

    builtin eval -- "$_ble_bash_FUNCNEST_adjust"

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
      if local ret; ble/array#index PROMPT_COMMAND "$FUNCNAME"; then
        local keys; keys=("${!PROMPT_COMMAND[@]}")
        ((ret==keys[${#keys[@]}-1])) || is_last_PROMPT_COMMAND=
        ble/idict#replace PROMPT_COMMAND "$FUNCNAME"
      fi
      blehook internal_PRECMD-="$FUNCNAME" || ((1)) # set -e 対策
    else
      local save_index=$1 lambda=$2

      # 待避していた内容を復元・実行
      local PROMPT_COMMAND=${_ble_base_attach_PROMPT_COMMAND[save_index]}
      local ble_base_attach_from_prompt_command=processing
      ble/prompt/update/.eval-prompt_command 2>&"$_ble_util_fd_tui_stderr"
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

      # #D1354: 入れ子の ble/base/attach-from-PROMPT_COMMAND の時は一番外側で
      #   ble-attach を実行する様にする。2>/dev/null のリダイレクトにより
      #   stdout.off の効果が巻き戻されるのを防ぐ為。
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
  } 2>/dev/null # set -x 対策 #D0930

  ble-attach force; local ext=$?

  # Note: When POSIXLY_CORRECT is adjusted outside this function, and when
  # "ble-attach force" fails, the adjusted POSIXLY_CORRECT may be restored.
  # For such a case, we need to locally adjust POSIXLY_CORRECT to work around
  # 5.3 function names with a slash.
  builtin eval -- "$_ble_bash_FUNCNEST_local_adjust"
  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_adjust"

  # Note: 何故か分からないが PROMPT_COMMAND から ble-attach すると
  # ble/bin/stty や ble/bin/mkfifo や tty 2>/dev/null などが
  # ジョブとして表示されてしまう。joblist.flush しておくと平気。
  # これで取り逃がすジョブもあるかもしれないが仕方ない。
  ble/util/joblist.flush &>/dev/null
  ble/util/joblist.check
#%if measure_load_time
  ble/util/print "ble.sh: $EPOCHREALTIME end prompt-attach" >&2
#%end

  builtin eval -- "$_ble_bash_POSIXLY_CORRECT_local_leave"
  builtin eval -- "$_ble_bash_FUNCNEST_local_leave"
  return "$?"
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
    set -- bash main util canvas decode edit syntax complete keymap.vi
    local timestamp
    ble/util/strftime -v timestamp '%Y%m%d.%H%M%S'
    logfile=$_ble_base_cache/test.$timestamp.log
    >| "$logfile"
    ble/test/log#open "$logfile"
  fi

  if ((!_ble_make_command_check_count)); then
    ble/test/log "MACHTYPE: $MACHTYPE"
    ble/test/log "BLE_VERSION: $BLE_VERSION"
  fi
#%if target == "osh"
  ble/test/log "OIL_VERSION: $OIL_VERSION"
#%else
  ble/test/log "BASH_VERSION: $BASH_VERSION"
#%end
  local line='locale:' var ret
  for var in LANG "${!LC_@}"; do
    ble/string#quote-word "${!var}"
    line="$line $var=$ret"
  done
  ble/test/log "$line"

  local _ble_test_section_failure_count=0
  local section
  for section; do
    local file=$_ble_base/lib/test-$section.sh
    if [[ -f $file ]]; then
      source "$file"
    else
      ble/test/log "ERROR: Test '$section' is not defined."
      error=1
    fi
  done
  ((_ble_test_section_failure_count)) && error=1

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
function ble/base/sub:install {
  local insdir=${1:-${XDG_DATA_HOME:-$HOME/.local/share}}/blesh

  local dir=$insdir sudo=
  [[ $dir == /* ]] || dir=./$dir
  while [[ $dir && ! -d $dir ]]; do
    dir=${dir%/*}
  done
  [[ $dir ]] || dir=/
  if ! [[ -r $dir && -w $dir && -x $dir ]]; then
    if ((EUID!=0)) && [[ ! -O $dir ]] && ble/bin#has sudo; then
      sudo=1
    else
      ble/util/print "ble.sh --install: $dir: permission denied" >&2
      return 1
    fi
  fi

  if [[ ${_ble_base_repository-} == release:nightly-* ]]; then
    if [[ $insdir == "$_ble_base" ]]; then
      ble/util/print "ble.sh --install: already installed" >&2
      return 1
    fi
    local ret
    ble/string#quote-word "$insdir"; local qinsdir=$ret
    ble/string#quote-word "$_ble_base"; local qbase=$ret
    if [[ $sudo ]]; then
      ble/util/print "\$ sudo mkdir -p $qinsdir"
      sudo mkdir -p "$insdir"
      ble/util/print "\$ sudo cp -Rf $qbase/* $qinsdir/"
      sudo cp -Rf "$_ble_base"/* "$insdir/"
      ble/util/print "\$ sudo rm -rf $qinsdir/{cache.d,run}"
      sudo rm -rf "$insdir"/{cache.d,run}
    else
      ble/util/print "\$ mkdir -p $qinsdir"
      ble/bin/mkdir -p "$insdir"
      ble/util/print "\$ cp -Rf $qbase/* $qinsdir/"
      ble/bin/cp -Rf "$_ble_base"/* "$insdir/"
      ble/util/print "\$ rm -rf $qinsdir/cache.d/*"
      ble/bin/rm -rf "$insdir/cache.d"/*
    fi
  elif local make; ble-update/.check-build-dependencies && ble-update/.check-repository; then
    ( ble/util/print "cd into $_ble_base_repository..." >&2 &&
        builtin cd "$_ble_base_repository" &&
        ble-update/.make ${sudo:+--sudo} install INSDIR="$insdir" )
  else
    ble/util/print "ble.sh --install: not supported." >&2
    return 1
  fi
}
function ble/base/sub:lib { return 0; } # do nothing

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
ble/debug/measure-set-timeformat 'Total' nofork; }
_ble_init_exit=$?
[[ ${BLE_ATTACHED-} ]] || ble/init/measure/section 'wait'
ble/util/setexit "$_ble_init_exit"
#%end

ble/init/clean-up check-attach 2>/dev/null # set -x 対策 #D0930
{ builtin eval "return $? || exit $?"; } 2>/dev/null # set -x 対策 #D0930
###############################################################################
