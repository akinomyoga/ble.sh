#!/bin/bash
#%$> out/ble.sh
#%[release = 0]
#%[measure_load_time = 0]
#%[debug_keylogger = 1]
#%#----------------------------------------------------------------------------
#%define inc
#%%[guard_name = "@_included".replace("[^_a-zA-Z0-9]", "_")]
#%%expand
#%%%if $"guard_name" != 1
#%%%%[$"guard_name" = 1]
###############################################################################
# Included from @.sh

#%%%%if measure_load_time
time {
echo @.sh >&2
#%%%%%include @.sh
}
#%%%%else
#%%%%%include @.sh
#%%%%end
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
# load_time (2015-12-03)
#   core           12ms
#   decode         10ms
#   color           2ms
#   edit            9ms
#   syntax          5ms
#   ble-initialize 14ms
time {
echo prologue >&2
#%end
#------------------------------------------------------------------------------
# check --help or --version

{
  #%$ echo "_ble_init_version=$FULLVER+$(git show -s --format=%h)"
  _ble_init_exit=
  _ble_init_test=
  for _ble_init_arg; do
    case $_ble_init_arg in
    --version)
      _ble_init_exit=1
      echo "ble.sh -- Bash Line Editor (ble-$_ble_init_version)" ;;
    --help)
      _ble_init_exit=1
      printf '%s\n' \
             "# ble.sh -- Bash Line Editor (ble-$_ble_init_version)" \
             'usage: source ble.sh [OPTION...]' \
             '' \
             'OPTION' \
             '' \
             '  --help' \
             '    Show this help' \
             '  --version' \
             '    Show version' \
             '' \
             '  --rcfile=BLERC' \
             '  --init-file=BLERC' \
             '    Specify the ble init file. The default is ~/.blerc.' \
             '' \
             '  --attach=ATTACH' \
             '  --noattach' \
             '    The option "--attach" selects the strategy of "ble-attach" from the' \
             '    list: ATTACH = "attach" | "prompt" | "none". The default strategy is' \
             '    "prompt". The option "--noattach" is a synonym for "--attach=none".' \
             '' \
             '  --noinputrc' \
             '    Do not read inputrc settings for ble.sh' \
             '' \
             '  --keep-rlvars' \
             '    Do not change readline settings for ble.sh' \
             '' \
             '  --debug-bash-output' \
             '    Internal settings for debugging' \
             '' ;;
    --test)
      _ble_init_test=1 ;;
    esac
  done
  if [ -n "$_ble_init_exit" ]; then
    unset _ble_init_version
    unset _ble_init_arg
    unset _ble_init_exit
    unset _ble_init_test
    return 1 2>/dev/null || exit 1
  fi
} 2>/dev/null # set -x 対策 #D0930

#------------------------------------------------------------------------------
# check shell

if [ -z "$BASH_VERSION" ]; then
  echo "ble.sh: This shell is not Bash. Please use this script with Bash." >&3
  return 1 2>/dev/null || exit 1
fi 3>&2 >/dev/null 2>&1 # set -x 対策 #D0930

if [ -z "$BASH_VERSINFO" ] || [ "$BASH_VERSINFO" -lt 3 ]; then
  echo "ble.sh: Bash with a version under 3.0 is not supported." >&3
  return 1 2>/dev/null || exit 1
fi 3>&2 >/dev/null 2>&1 # set -x 対策 #D0930

if [[ $- != *i* && ! $_ble_init_test ]]; then
  { ((${#BASH_SOURCE[@]})) && [[ ${BASH_SOURCE[${#BASH_SOURCE[@]}-1]} == *bashrc ]]; } ||
    builtin echo "ble.sh: This is not an interactive session." >&3
  return 1 2>/dev/null || builtin exit 1
fi 3>&2 &>/dev/null # set -x 対策 #D0930

function ble/base/adjust-bash-options {
  [[ $_ble_bash_options_adjusted ]] && return 1 || :
  _ble_bash_options_adjusted=1

  _ble_bash_sete=; [[ -o errexit ]] && _ble_bash_sete=1 && set +e
  _ble_bash_setx=; [[ -o xtrace  ]] && _ble_bash_setx=1 && set +x
  _ble_bash_setv=; [[ -o verbose ]] && _ble_bash_setv=1 && set +v
  _ble_bash_setu=; [[ -o nounset ]] && _ble_bash_setu=1 && set +u

  # Note: nocasematch は bash-3.0 以上
  _ble_bash_nocasematch=
  shopt -q nocasematch 2>/dev/null &&
    _ble_bash_nocasematch=1 && shopt -u nocasematch
} 2>/dev/null # set -x 対策 #D0930
function ble/base/restore-bash-options {
  [[ $_ble_bash_options_adjusted ]] || return 1
  _ble_bash_options_adjusted=
  [[ $_ble_bash_setv && ! -o verbose ]] && set -v
  [[ $_ble_bash_setu && ! -o nounset ]] && set -u
  [[ $_ble_bash_setx && ! -o xtrace  ]] && set -x
  [[ $_ble_bash_sete && ! -o errexit ]] && set -e
  if [[ $_ble_bash_nocasematch ]]; then shopt -s nocasematch; fi # Note: set -e により && は駄目
} 2>/dev/null # set -x 対策 #D0930

{
  _ble_base_adjust_FUNCNEST='
    if [[ ! $_ble_bash_funcnest_adjusted ]]; then
      _ble_bash_funcnest_adjusted=1
      _ble_bash_funcnest=$FUNCNEST FUNCNEST=
    fi 2>/dev/null'
  _ble_base_restore_FUNCNEST='
    if [[ $_ble_bash_funcnest_adjusted ]]; then
      _ble_bash_funcnest_adjusted=
      FUNCNEST=$_ble_bash_funcnest
    fi 2>/dev/null'

  _ble_bash_funcnest_adjusted=
  builtin eval -- "$_ble_base_adjust_FUNCNEST"
  _ble_bash_options_adjusted=
  ble/base/adjust-bash-options
} &>/dev/null # set -x 対策 #D0930

## @var _ble_edit_POSIXLY_CORRECT_adjusted
##   現在 POSIXLY_CORRECT 状態を待避した状態かどうかを保持します。
## @var _ble_edit_POSIXLY_CORRECT_set
##   待避した POSIXLY_CORRECT の設定・非設定状態を保持します。
## @var _ble_edit_POSIXLY_CORRECT_set
##   待避した POSIXLY_CORRECT の値を保持します。
_ble_edit_POSIXLY_CORRECT_adjusted=
_ble_edit_POSIXLY_CORRECT_set=
_ble_edit_POSIXLY_CORRECT=
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
  [[ $_ble_edit_POSIXLY_CORRECT_adjusted ]] && return 0
  _ble_edit_POSIXLY_CORRECT_adjusted=1
  _ble_edit_POSIXLY_CORRECT_set=${POSIXLY_CORRECT+set}
  _ble_edit_POSIXLY_CORRECT=$POSIXLY_CORRECT
  builtin unset -v POSIXLY_CORRECT

  # ユーザが触ったかもしれないので何れにしても workaround を呼び出す。
  ble/base/workaround-POSIXLY_CORRECT
}
function ble/base/restore-POSIXLY_CORRECT {
  if [[ ! $_ble_edit_POSIXLY_CORRECT_adjusted ]]; then return 0; fi # Note: set -e の為 || は駄目
  _ble_edit_POSIXLY_CORRECT_adjusted=
  if [[ $_ble_edit_POSIXLY_CORRECT_set ]]; then
    POSIXLY_CORRECT=$_ble_edit_POSIXLY_CORRECT
  else
    ble/base/unset-POSIXLY_CORRECT
  fi
}
ble/base/adjust-POSIXLY_CORRECT

builtin bind &>/dev/null # force to load .inputrc
if [[ ! -o emacs && ! -o vi && ! $_ble_init_test ]]; then
  builtin echo "ble.sh: ble.sh is not intended to be used with the line-editing mode disabled (--noediting)." >&2
  return 1
fi

if shopt -q restricted_shell; then
  builtin echo "ble.sh: ble.sh is not intended to be used in restricted shells (--restricted)." >&2
  return 1
fi

if [[ ${BASH_EXECUTION_STRING+set} ]]; then
  # builtin echo "ble.sh: ble.sh will not be activated for Bash started with '-c' option." >&2
  return 1 2>/dev/null || builtin exit 1
fi

_ble_init_original_IFS=$IFS
IFS=$' \t\n'

if [[ $_ble_base ]]; then
  if ! ble/base/unload-for-reload; then
    builtin echo "ble.sh: an old version of ble.sh seems to be already loaded." >&2
    return 1
  fi
fi

#------------------------------------------------------------------------------
# Initialize version information

_ble_bash=$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))
_ble_bash_loaded_in_function=0
[[ ${FUNCNAME+set} ]] && _ble_bash_loaded_in_function=1

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
# check environment

# ble/bin

function ble/util/put { builtin printf '%s' "$*"; }
function ble/util/print { builtin printf '%s\n' "$*"; }

## @fn ble/bin/.default-utility-path commands...
##   取り敢えず ble/bin/* からコマンドを呼び出せる様にします。
function ble/bin/.default-utility-path {
  local cmd
  for cmd; do
    builtin eval "function ble/bin/$cmd { command $cmd \"\$@\"; }"
  done
}
## @fn ble/bin/.freeze-utility-path commands...
##   PATH が破壊された後でも ble が動作を続けられる様に、
##   現在の PATH で基本コマンドのパスを固定して ble/bin/* から使える様にする。
##
##   実装に ble/util/assign を使用しているので ble-core 初期化後に実行する必要がある。
##
function ble/bin/.freeze-utility-path {
  local cmd path q=\' Q="'\''" fail=
  for cmd; do
    if ble/util/assign path "builtin type -P -- $cmd 2>/dev/null" && [[ $path ]]; then
      builtin eval "function ble/bin/$cmd { '${path//$q/$Q}' \"\$@\"; }"
    else
      fail=1
    fi
  done
  ((!fail))
}

if ((_ble_bash>=40000)); then
  function ble/bin#has { type "$@" &>/dev/null; }
else
  function ble/bin#has {
    local cmd
    for cmd; do type "$cmd" || return 1; done &>/dev/null
    return 0
  }
fi

# POSIX utilities

_ble_init_posix_command_list=(sed date rm mkdir mkfifo sleep stty tty sort awk chmod grep cat wc mv sh od cp)
function ble/.check-environment {
  if ! ble/bin#has "${_ble_init_posix_command_list[@]}"; then
    local cmd commandMissing=
    for cmd in "${_ble_init_posix_command_list[@]}"; do
      if ! type "$cmd" &>/dev/null; then
        commandMissing="$commandMissing\`$cmd', "
      fi
    done
    ble/util/print "ble.sh: Insane environment: The command(s), ${commandMissing}not found. Check your environment variable PATH." >&2

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

  if [[ ! $USER ]]; then
    ble/util/print "ble.sh: Insane environment: \$USER is empty." >&2
    if type id &>/dev/null; then
      export USER=$(id -un)
      ble/util/print "ble.sh: modified USER=$USER" >&2
    fi
  fi

  # 暫定的な ble/bin/$cmd 設定
  ble/bin/.default-utility-path "${_ble_init_posix_command_list[@]}"

  return 0
}
if ! ble/.check-environment; then
  _ble_bash=
  return 1
fi

_ble_bin_awk_supports_null_RS=
function ble/bin/awk-supports-null-record-separator {
  if [[ ! $_ble_bin_awk_supports_null_RS ]]; then
    local count=0 awk_script='BEGIN { RS = "\0"; } { count++; } END { print count; }'
    ble/util/assign count 'printf "a\0b\0" | ble/bin/awk "$awk_script" '
    if ((count==2)); then
      _ble_bin_awk_supports_null_RS=yes
    else
      _ble_bin_awk_supports_null_RS=no
    fi
  fi
  [[ $_ble_bin_awk_supports_null_RS == yes ]]
}
_ble_bin_awk_solaris_xpg4=
function ble/bin/awk.use-solaris-xpg4 {
  if [[ ! $_ble_bin_awk_solaris_xpg4 ]]; then
    if [[ $OSTYPE == solaris* ]] && type /usr/xpg4/bin/awk >/dev/null; then
      _ble_bin_awk_solaris_xpg4=yes
    else
      _ble_bin_awk_solaris_xpg4=no
    fi
  fi

  # Solaris の既定の awk は絶望的なので /usr/xpg4/bin/awk (nawk) を使う
  [[ $_ble_bin_awk_solaris_xpg4 == yes ]] &&
    function ble/bin/awk { /usr/xpg4/bin/awk "$@"; }
}

#------------------------------------------------------------------------------

# will be overwritten by src/util.sh
function ble/util/assign {
  builtin eval "$1=\$(builtin eval -- \"\${@:2}\")"
}

# readlink -f (taken from akinomyoga/mshex.git)
## @fn ble/util/readlink path
##   @var[out] ret
function ble/util/readlink {
  ret=
  local path=$1
  case "$OSTYPE" in
  (cygwin|msys|linux-gnu)
    # 少なくとも cygwin, GNU/Linux では readlink -f が使える
    ble/util/assign ret 'PATH=/bin:/usr/bin readlink -f "$path"' ;;
  (darwin*|*)
    # Mac OSX には readlink -f がない。
    local PWD=$PWD OLDPWD=$OLDPWD
    while [[ -h $path ]]; do
      local link; ble/util/assign link 'PATH=/bin:/usr/bin readlink "$path" 2>/dev/null || true'
      [[ $link ]] || break

      if [[ $link = /* || $path != */* ]]; then
        # * $link ~ 絶対パス の時
        # * $link ~ 相対パス かつ ( $path が現在のディレクトリにある ) の時
        path=$link
      else
        local dir=${path%/*}
        path=${dir%/}/$link
      fi
    done
    ret=$path ;;
  esac
}

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
    ble/util/print "ble.sh: permission of '$tmpdir' is not correct." >&2
    return 1
  elif [[ ! -O $dir ]]; then
    ble/util/print "ble.sh: owner of '$tmpdir' is not correct." >&2
    return 1
  fi
  builtin eval "$var=\$dir"
}

##
## @var _ble_base
##
##   ble.sh のインストール先ディレクトリ。
##   読み込んだ ble.sh の実体があるディレクトリとして解決される。
##
function ble/base/initialize-base-directory {
  local src=$1
  local defaultDir=$2

  # resolve symlink
  if [[ -h $src ]] && type -t readlink &>/dev/null; then
    local ret; ble/util/readlink "$src"; src=$ret
  fi

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
  local runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$UID}
  if [[ ! -d $runtime_dir ]]; then
    [[ $XDG_RUNTIME_DIR ]] &&
      ble/util/print "ble.sh: XDG_RUNTIME_DIR='$XDG_RUNTIME_DIR' is not a directory." >&2
    return 1
  fi
  if ! [[ -r $runtime_dir && -w $runtime_dir && -x $runtime_dir ]]; then
    [[ $XDG_RUNTIME_DIR ]] &&
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
  return 1
fi

# ロード時刻の記録 (ble-update で使う為)
: >| "$_ble_base_run/$$.load"

function ble/base/clean-up-runtime-directory {
  local file pid mark removed
  mark=() removed=()
  for file in "$_ble_base_run"/[1-9]*.*; do
    [[ -e $file ]] || continue
    pid=${file##*/}; pid=${pid%%.*}
    [[ ${mark[pid]} ]] && continue
    mark[pid]=1
    if ! builtin kill -0 "$pid" &>/dev/null; then
      removed=("${removed[@]}" "$_ble_base_run/$pid."*)
    fi
  done
  ((${#removed[@]})) && ble/bin/rm -rf "${removed[@]}"
}

# initialization time = 9ms (for 70 files)
if shopt -q failglob &>/dev/null; then
  shopt -u failglob
  ble/base/clean-up-runtime-directory
  shopt -s failglob
else
  ble/base/clean-up-runtime-directory
fi

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
if ! ble/base/initialize-cache-directory; then
  ble/util/print "ble.sh: failed to initialize \$_ble_base_cache." 1>&2
  builtin unset -v _ble_bash BLE_VERSION BLE_VERSINFO
  return 1
fi
function ble/base/print-usage-for-no-argument-command {
  local name=${FUNCNAME[1]} desc=$1; shift
  printf '%s\n' \
         "usage: $name" \
         "$desc" >&2
  [[ $1 != --help ]] && return 2
  return 0
}
function ble-reload { source "$_ble_base/ble.sh"; }
#%$ pwd=$(pwd) q=\' Q="'\''" bash -c 'echo "_ble_base_repository=$q${pwd//$q/$Q}$q"'
#%$ echo "_ble_base_branch=$(git rev-parse --abbrev-ref HEAD)"
function ble-update {
  if (($#)); then
    ble/base/print-usage-for-no-argument-command 'Update and reload ble.sh.' "$@"
    return "$?"
  fi

  # check make
  local MAKE=
  if type gmake &>/dev/null; then
    MAKE=gmake
  elif type make &>/dev/null && make --version 2>&1 | ble/bin/grep -qiF 'GNU Make'; then
    MAKE=make
  else
    ble/util/print "ble-update: GNU Make is not available." >&2
    return 1
  fi

  # check git, gawk
  if ! ble/bin#has git gawk; then
    local command
    for command in git gawk; do
      type "$command" &>/dev/null ||
        ble/util/print "ble-update: '$command' command is not available." >&2
    done
    return 1
  fi

  if [[ $_ble_base_repository && $_ble_base_repository != release:* ]]; then
    if [[ -e $_ble_base_repository/.git ]]; then
      ( ble/util/print "cd into $_ble_base_repository..." >&2 &&
          builtin cd "$_ble_base_repository" &&
          git pull && git submodule update --recursive --remote &&
          { ! "$MAKE" -q || builtin exit 6; } && "$MAKE" all &&
          if [[ $_ble_base != "$_ble_base_repository"/out ]]; then
            "$MAKE" INSDIR="$_ble_base" install
          fi ); local ext=$?
      if ((ext==6)); then
        [[ $_ble_base/ble.sh -nt $_ble_base_run/$$.load ]] && ble-reload
        return 0
      fi
      ((ext==0)) && ble-reload
      return "$ext"
    fi

    ble/util/print 'ble-update: git repository not found' >&2
  fi

  if [[ $_ble_base_branch ]]; then
    # release version
    local branch=$_ble_base_branch
    ( ble/bin/mkdir -p "$_ble_base/src" && builtin cd "$_ble_base/src" &&
        git clone --recursive --depth 1 https://github.com/akinomyoga/ble.sh "$_ble_base/src/ble.sh" -b "$branch" &&
        builtin cd ble.sh && "$MAKE" all && "$MAKE" INSDIR="$_ble_base" install ) &&
      ble-reload
    return "$?"
  fi
  return 1
}
#%if measure_load_time
}
#%end

# Solaris: src/util の中でちゃんとした awk が必要
ble/bin/awk.use-solaris-xpg4

#%x inc.r|@|src/def|
#%x inc.r|@|src/util|

ble/bin/.freeze-utility-path "${_ble_init_posix_command_list[@]}" # <- this uses ble/util/assign.
ble/bin/.freeze-utility-path man
ble/bin/.freeze-utility-path groff nroff mandoc gzip bzcat lzcat xzcat # used by core-complete.sh
# Solaris: .freeze-utility-path で上書きされた awk を戻す
ble/bin/awk.use-solaris-xpg4

ble/builtin/trap/install-hook EXIT
ble/builtin/trap/install-hook INT

blehook ERR+='ble/builtin/trap/invoke ERR'
blehook ERR+='ble/function#try TRAPERR'

#%x inc.r|@|src/decode|
#%x inc.r|@|src/color|
#%x inc.r|@|src/canvas|
#%x inc.r|@|src/history|
#%x inc.r|@|src/edit|
#%x inc.r|@|lib/core-complete-def|
#%x inc.r|@|lib/core-syntax-def|
#------------------------------------------------------------------------------
# function .ble-time { echo "$*"; time "$@"; }

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

_ble_attached=
function ble-attach {
  if (($#)); then
    ble/base/print-usage-for-no-argument-command 'Attach to ble.sh.' "$@"
    return "$?"
  fi

  # when detach flag is present
  if [[ $_ble_edit_detach_flag ]]; then
    case $_ble_edit_detach_flag in
    (exit) return 0 ;;
    (*) _ble_edit_detach_flag= ;; # cancel "detach"
    esac
  fi

  [[ $_ble_attached ]] && return 0
  _ble_attached=1

  # 特殊シェル設定を待避
  builtin eval -- "$_ble_base_adjust_FUNCNEST"
  ble/base/adjust-bash-options
  ble/base/adjust-POSIXLY_CORRECT

  # char_width_mode=auto
  ble/canvas/attach

  # 取り敢えずプロンプトを表示する
  ble/term/enter      # 3ms (起動時のずれ防止の為 stty)
  ble-edit/initialize # 3ms
  ble-edit/attach     # 0ms (_ble_edit_PS1 他の初期化)
  ble/textarea#redraw # 37ms
  ble/util/buffer.flush >&2

  # keymap 初期化
  local IFS=$' \t\n'
  ble/decode/initialize # 7ms
  ble/decode/reset-default-keymap # 264ms (keymap/vi.sh)
  if ! ble/decode/attach; then # 53ms
    _ble_attached=
    ble-edit/detach
    return 1
  fi

  ble/history:bash/reset # 27s for bash-3.0

  # Note: 再描画 (初期化中のエラーメッセージ・プロンプト変更等の為)
  ble/textarea#redraw

  # Note: ble-decode/{initialize,reset-default-keymap} 内で
  #   info を設定する事があるので表示する。
  ble-edit/info/default
  ble-edit/bind/.tail
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

  ble-edit/detach
  ble/decode/detach
  READLINE_LINE='' READLINE_POINT=0
}
function ble-detach/message {
  ble/util/buffer.flush >&2
  printf '%s\n' "$@" 1>&2
  ble-edit/info/hide
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
  ble/base/unload
  return 0
}
function ble/base/unload {
  ble/util/is-running-in-subshell && return 1
  local IFS=$' \t\n'
  builtin unset -v _ble_bash BLE_VERSION BLE_VERSINFO
  ble/term/stty/TRAPEXIT
  ble/term/leave
  ble/util/buffer.flush >&2
  ble/fd#finalize
  ble/util/import/finalize
  ble-decode/keymap/unload
  ble-edit/bind/clear-keymap-definition-loader
  ble/bin/rm -rf "$_ble_base_run/$$".* 2>/dev/null
  blehook/invoke unload
  return 0
}
blehook EXIT+=ble/base/unload

_ble_base_attach_from_prompt=
## @fn ble/base/attach-from-PROMPT_COMMAND prompt_command lambda
function ble/base/attach-from-PROMPT_COMMAND {
#%if measure_load_time
  echo "ble.sh: $EPOCHREALTIME start prompt-attach" >&2
#%end
  # 後続の設定によって PROMPT_COMMAND が置換された場合にはそれを保持する
  {
    if (($#==0)); then
      ble/array#replace PROMPT_COMMAND ble/base/attach-from-PROMPT_COMMAND
      blehook PRECMD-=ble/base/attach-from-PROMPT_COMMAND
    else
      local prompt_command=$1 lambda=$2

      # 待避していた内容を復元・実行
      [[ $PROMPT_COMMAND != "$lambda" ]] && local PROMPT_COMMAND
      PROMPT_COMMAND=$prompt_command
      local ble_base_attach_from_prompt_command=processing
      ble/prompt/update/.eval-prompt_command 2>&3
      ble/util/unlocal ble_base_attach_from_prompt_command
      blehook PRECMD-="$lambda"

      # #D1354: 入れ子の ble/base/attach-from-PROMPT_COMMAND の時は一番
      #   外側で ble-attach を実行する様にする。3>&2 2>/dev/null のリダ
      #   イレクトにより stdout.off の効果が巻き戻されるのを防ぐ為。
      [[ $ble_base_attach_from_prompt_command == processing ]] && return
    fi

    # 既に attach 状態の時は処理はスキップ
    [[ $_ble_base_attach_from_prompt ]] || return 0
    _ble_base_attach_from_prompt=
  } 3>&2 2>/dev/null # set -x 対策 #D0930

  ble-attach

  # Note: 何故か分からないが PROMPT_COMMAND から ble-attach すると
  # ble/bin/stty や ble/bin/mkfifo や tty 2>/dev/null などが
  # ジョブとして表示されてしまう。joblist.flush しておくと平気。
  # これで取り逃がすジョブもあるかもしれないが仕方ない。
  ble/util/joblist.flush &>/dev/null
  ble/util/joblist.check
#%if measure_load_time
  echo "ble.sh: $EPOCHREALTIME end prompt-attach" >/dev/tty
#%end
}

function ble/base/process-blesh-arguments {
  local opt_attach=prompt
  local flags=
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
        flags=E$flags
        ble/util/print "ble.sh ($arg): an option argument is missing." >&2
      fi ;;
    (--noinputrc)
      _ble_builtin_bind_inputrc_done=noinputrc ;;
    (--rcfile=*|--init-file=*|--rcfile|--init-file)
      if [[ $arg != *=* ]]; then
        local rcfile=$1; shift
      else
        local rcfile=${arg#*=}
      fi
      if [[ $rcfile && -f $rcfile ]]; then
        _ble_base_rcfile=$rcfile
      else
        ble/util/print "ble.sh ($arg): '$rcfile' is not a regular file." >&2
        flags=E$flags
      fi ;;
    (--keep-rlvars)
      flags=V$flags ;;
    (--debug-bash-output)
      bleopt_internal_suppress_bash_output= ;;
    (*)
      ble/util/print "ble.sh: unrecognized argument '$arg'" >&2
      flags=E$flags ;;
    esac
  done

  ble/base/load-rcfile # blerc

  # rlvar (#D1148)
  #   勝手だが ble.sh の参照する readline 変数を
  #   便利だと思われる設定の方向に書き換えてしまう。
  #   多くのユーザは自分で設定しないので ble.sh の便利な機能が off になっている。
  #   一方で設定するユーザは自分で off に設定するぐらいはできるだろう。
  if [[ $flags != *V* ]]; then
    ((_ble_bash>=40100)) && builtin bind 'set skip-completed-text on'
    ((_ble_bash>=40300)) && builtin bind 'set colored-stats on'
    ((_ble_bash>=40400)) && builtin bind 'set colored-completion-prefix on'
  fi

  # attach
  case $opt_attach in
  (attach) ble-attach ;;
  (prompt)
    _ble_base_attach_from_prompt=1
    if ((_ble_bash>=50100)); then
      ((${#PROMPT_COMMAND[@]})) || PROMPT_COMMAND[0]=
      ble/array#push PROMPT_COMMAND ble/base/attach-from-PROMPT_COMMAND
      if [[ $_ble_edit_detach_flag == reload ]]; then
        _ble_edit_detach_flag=prompt-attach
        blehook PRECMD+=ble/base/attach-from-PROMPT_COMMAND
      fi
    else
      local q=\' Q="'\''"
      ble/function#lambda PROMPT_COMMAND \
                          "ble/base/attach-from-PROMPT_COMMAND '${PROMPT_COMMAND//$q/$Q}' \"\$FUNCNAME\""
      if [[ $_ble_edit_detach_flag == reload ]]; then
        _ble_edit_detach_flag=prompt-attach
        blehook PRECMD+="$PROMPT_COMMAND"
      fi
    fi ;;
  esac
  [[ $flags != *E* ]]
}

function ble/base/initialize/.clean-up {
  # 一時グローバル変数消去
  builtin unset -v _ble_init_version
  builtin unset -v _ble_init_arg
  builtin unset -v _ble_init_exit
  builtin unset -v _ble_init_test

  # 状態復元
  IFS=$_ble_init_original_IFS
  builtin unset -v _ble_init_original_IFS
  if [[ ! $_ble_attached ]]; then
    ble/base/restore-bash-options
    ble/base/restore-POSIXLY_CORRECT
    builtin eval -- "$_ble_base_restore_FUNCNEST"
  fi
}

function ble/base/test {
  local error=
  if ((!_ble_make_command_check_count)); then
    echo "MACHTYPE: $MACHTYPE"
    echo "BLE_VERSION: $BLE_VERSION"
  fi
  echo "BASH_VERSION: $BASH_VERSION"
  source "$_ble_base"/lib/test-main.sh || error=1
  source "$_ble_base"/lib/test-util.sh || error=1
  [[ ! $error ]]
}

if [[ $_ble_init_test ]]; then
  if ! ble/base/test; then
    ble/base/initialize/.clean-up 2>/dev/null # set -x 対策 #D0930
    { return 1 || exit 1; } 2>/dev/null # set -x 対策 #D0930
  fi
else
  ble/base/process-blesh-arguments "$@"
fi

ble/base/initialize/.clean-up 2>/dev/null # set -x 対策 #D0930

#%if measure_load_time
}
echo "ble.sh: $EPOCHREALTIME load end" >&2
#%end

{ return 0 || exit 0; } &>/dev/null # set -x 対策 #D0930
###############################################################################
