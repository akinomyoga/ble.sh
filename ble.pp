#!/bin/bash
#%$> out/ble.sh
#%[release = 1]
#%[measure_load_time = 0]
#%[debug_keylogger = 1]
#%#----------------------------------------------------------------------------
#%m inc
#%%[guard = "@_included".replace("[^_a-zA-Z0-9]", "_")]
#%%if @_included != 1
#%%%[@_included = 1]
###############################################################################
# Included from ble-@.sh

#%%%if measure_load_time
time {
echo ble-@.sh >&2
#%%%%include ble-@.sh
}
#%%%else
#%%%%include ble-@.sh
#%%%end
#%%end
#%end
#%#----------------------------------------------------------------------------
# bash script to souce from interactive shell sessions
#
# ble - bash line editor
#
# Author: 2013, 2015-2017, K. Murase <myoga.murase@gmail.com>
#

#%if measure_load_time
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
# check shell

if [ -z "$BASH_VERSION" ]; then
  echo "ble.sh: This is not a bash. Please use this script with bash." >&2
  return 1 2>/dev/null || exit 1
fi

_ble_bash=$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))

if [ "$_ble_bash" -lt 30000 ]; then
  unset _ble_bash
  echo "ble.sh: bash with a version under 3.0 is not supported." >&2
  return 1 2>/dev/null || exit 1
fi

# DEBUG version の Bash では遅いという通知
case ${BASH_VERSINFO[4]} in
(alp*|bet*|dev*|rc*|releng*|maint*)
  printf '%s\n' \
    "ble.sh may become very slow because this is a debug version of Bash" \
    "  (version '$BASH_VERSION', release status: '${BASH_VERSINFO[4]}')." \
    "  We recommend using ble.sh with a release version of Bash." >&2 ;;
esac

if ((BASH_SUBSHELL)); then
  builtin echo "ble.sh: ble.sh cannot be loaded into a subshell." >&2
  return 1 2>/dev/null || builtin exit 1
elif [[ $- != *i* ]]; then
  case " ${BASH_SOURCE[*]##*/} " in
  (*' .bashrc '* | *' .bash_profile '* | *' .profile '* | *' bashrc '* | *' profile '*) false ;;
  esac  &&
    builtin echo "ble.sh: This is not an interactive session." >&2 || ((1))
  return 1 2>/dev/null || builtin exit 1
elif ! [[ -t 0 && -t 1 ]]; then
  builtin echo "ble.sh: cannot find the correct TTY/PTY in this session." >&2
  return 1 2>/dev/null || builtin exit 1
fi

if [[ -o posix ]]; then
  unset _ble_bash
  echo "ble.sh: ble.sh is not intended to be used in bash POSIX modes (--posix)." >&2
  return 1 2>/dev/null || exit 1
fi

_ble_bash_sete=
_ble_bash_setx=
_ble_bash_setv=
_ble_bash_setu=
_ble_bash_setk=
_ble_bash_setB=
_ble_bash_options_adjusted=
function ble/adjust-bash-options {
  [[ $_ble_bash_options_adjusted ]] && return 1
  _ble_bash_options_adjusted=1
  _ble_bash_sete=; [[ -o errexit ]] && _ble_bash_sete=1 && set +e
  _ble_bash_setx=; [[ -o xtrace  ]] && _ble_bash_setx=1 && set +x
  _ble_bash_setv=; [[ -o verbose ]] && _ble_bash_setv=1 && set +v
  _ble_bash_setu=; [[ -o nounset ]] && _ble_bash_setu=1 && set +u
  _ble_bash_setk=; [[ -o keyword ]] && _ble_bash_setk=1 && set +k
  _ble_bash_setB=; [[ -o braceexpand ]] && _ble_bash_setB=1 || set -B
}
function ble/restore-bash-options {
  [[ $_ble_bash_options_adjusted ]] || return 1
  _ble_bash_options_adjusted=
  [[ ! $_ble_bash_setB && -o braceexpand ]] && set +B
  [[ $_ble_bash_setk && ! -o keyword ]] && set -k
  [[ $_ble_bash_setu && ! -o nounset ]] && set -u
  [[ $_ble_bash_setv && ! -o verbose ]] && set -v
  [[ $_ble_bash_setx && ! -o xtrace  ]] && set -x
  [[ $_ble_bash_sete && ! -o errexit ]] && set -e
}
ble/adjust-bash-options

bind &>/dev/null # force to load .inputrc
if [[ ! -o emacs && ! -o vi ]]; then
  unset _ble_bash
  echo "ble.sh: ble.sh is not intended to be used with the line-editing mode disabled (--noediting)." >&2
  return 1
fi

if shopt -q restricted_shell; then
  unset _ble_bash
  echo "ble.sh: ble.sh is not intended to be used in restricted shells (--restricted)." >&2
  return 1
fi

_ble_init_original_IFS_set=${IFS+set}
_ble_init_original_IFS=$IFS
IFS=$' \t\n'

_ble_bash_loaded_in_function=0
[[ ${FUNCNAME+set} ]] && _ble_bash_loaded_in_function=1

#------------------------------------------------------------------------------
# check environment

function ble/util/put { builtin printf '%s' "$1"; }
function ble/util/print { builtin printf '%s\n' "$1"; }

# will be overwritten by src/util.sh
function ble/util/assign { builtin eval "$1=\$(builtin eval -- \"\${@:2}\")"; }

# ble/bin

## 関数 ble/bin/.default-utility-path commands...
##   取り敢えず ble/bin/* からコマンドを呼び出せる様にします。
function ble/bin/.default-utility-path {
  local cmd
  for cmd; do
    eval "function ble/bin/$cmd { command $cmd \"\$@\"; }"
  done
}
## 関数 ble/bin/.freeze-utility-path commands...
##   PATH が破壊された後でも ble が動作を続けられる様に、
##   現在の PATH で基本コマンドのパスを固定して ble/bin/* から使える様にする。
##
##   実装に ble/util/assign を使用しているので ble-core 初期化後に実行する必要がある。
##
function ble/bin/.freeze-utility-path {
  local cmd path q=\' Q="'\''" fail=
  for cmd; do
    if ble/util/assign path "builtin type -P -- $cmd 2>/dev/null" && [[ $path ]]; then
      eval "function ble/bin/$cmd { '${path//$q/$Q}' \"\$@\"; }"
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

_ble_init_posix_command_list=(sed date rm mkdir mkfifo sleep stty sort awk chmod grep cat wc mv sh)
function ble/.check-environment {
  if ! ble/bin#has "${_ble_init_posix_command_list[@]}" &>/dev/null; then
    local cmd commandMissing=
    for cmd in "${_ble_init_posix_command_list[@]}"; do
      if ! type "$cmd" &>/dev/null; then
        commandMissing="$commandMissing\`$cmd', "
      fi
    done
    echo "ble.sh: Insane environment: The command(s), ${commandMissing}not found. Check your environment variable PATH." >&2

    # try to fix PATH
    local default_path=$(command -p getconf PATH 2>/dev/null)
    [[ $default_path ]] || return 1

    local original_path=$PATH
    export PATH=${default_path}${PATH:+:}${PATH}
    [[ :$PATH: == *:/bin:* ]] || PATH=/bin${PATH:+:}$PATH
    [[ :$PATH: == *:/usr/bin:* ]] || PATH=/usr/bin${PATH:+:}$PATH
    if ! ble/bin#has "${_ble_init_posix_command_list[@]}" &>/dev/null; then
      PATH=$original_path
      return 1
    fi
    echo "ble.sh: modified PATH=${PATH::${#PATH}-${#original_path}}:\$PATH" >&2
  fi

  if [[ ! $USER ]]; then
    echo "ble.sh: Insane environment: \$USER is empty." >&2
    if type id &>/dev/null; then
      export USER=$(id -un)
      echo "ble.sh: modified USER=$USER" >&2
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

if [[ $_ble_base ]]; then
  echo "ble.sh: ble.sh seems to be already loaded." >&2
  return 1
fi

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
  builtin cd -L . &&
    local pwd=$PWD &&
    builtin cd -P "${path%/*}/" &&
    path=${PWD%/}/${path##*/}
  builtin cd -L "$pwd"
  return 0
}
function ble/util/readlink/.resolve-loop {
  local path=$ret
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
      path=${path%/}/$link
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
    ble/bin/.freeze-utility-path readlink ls
    function ble/util/readlink/.resolve { ble/util/readlink/.resolve-loop; }
  fi

  ble/util/readlink/.resolve
}
function ble/util/readlink {
  ret=$1
  if [[ -h $ret ]]; then ble/util/readlink/.resolve; fi
}

#---------------------------------------

function ble/base/.create-user-directory {
  local var=$1 dir=$2
  if [[ ! -d $dir ]]; then
    # dangling symlinks are silently removed
    [[ ! -e $dir && -h $dir ]] && ble/bin/rm -f "$dir"
    if [[ -e $dir || -h $dir ]]; then
      echo "ble.sh: cannot create a directory '$dir' since there is already a file." >&2
      return 1
    fi
    if ! (umask 077; ble/bin/mkdir -p "$dir"); then
      echo "ble.sh: failed to create a directory '$dir'." >&2
      return 1
    fi
  elif ! [[ -r $dir && -w $dir && -x $dir ]]; then
    ble/util/print "ble.sh: permission of '$dir' is not correct." >&2
    return 1
  elif [[ ! -O $dir ]]; then
    ble/util/print "ble.sh: owner of '$dir' is not correct." >&2
    return 1
  fi
  eval "$var=\$dir"
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
  echo "ble.sh: ble base directory not found!" 1>&2
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
  [[ $_ble_base != */out ]] || return

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
  [[ -r /tmp && -w /tmp && -x /tmp ]] || return

  local tmp_dir=/tmp/blesh
  if [[ ! -d $tmp_dir ]]; then
    [[ ! -e $tmp_dir && -h $tmp_dir ]] && ble/bin/rm -f "$tmp_dir"
    if [[ -e $tmp_dir || -h $tmp_dir ]]; then
      echo "ble.sh: cannot create a directory '$tmp_dir' since there is already a file." >&2
      return 1
    fi
    ble/bin/mkdir -p "$tmp_dir" || return
    ble/bin/chmod a+rwxt "$tmp_dir" || return
  elif ! [[ -r $tmp_dir && -w $tmp_dir && -x $tmp_dir ]]; then
    echo "ble.sh: permision of '$tmp_dir' is not correct." >&2
    return 1
  fi

  ble/base/.create-user-directory _ble_base_run "$tmp_dir/$UID"
}
function ble/base/initialize-runtime-directory {
  ble/base/initialize-runtime-directory/.xdg && return
  ble/base/initialize-runtime-directory/.tmp && return

  # fallback
  local tmp_dir=$_ble_base/run
  if [[ ! -d $tmp_dir ]]; then
    ble/bin/mkdir -p "$tmp_dir" || return
    ble/bin/chmod a+rwxt "$tmp_dir" || return
  fi
  ble/base/.create-user-directory _ble_base_run "$tmp_dir/${USER:-$UID}@$HOSTNAME"
}
if ! ble/base/initialize-runtime-directory; then
  echo "ble.sh: failed to initialize \$_ble_base_run." 1>&2
  return 1
fi

function ble/base/clean-up-runtime-directory {
  local file pid mark removed
  mark=() removed=()
  for file in "$_ble_base_run"/[1-9]*.*; do
    [[ -e $file ]] || continue
    pid=${file##*/}; pid=${pid%%.*}
    [[ ${mark[pid]} ]] && continue
    mark[pid]=1
    if ! kill -0 "$pid" &>/dev/null; then
      removed=("${removed[@]}" "$_ble_base_run/$pid."*)
    fi
  done
  ((${#removed[@]})) && ble/bin/rm -f "${removed[@]}"
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
  [[ $_ble_base != */out ]] || return

  local cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}
  if [[ ! -d $cache_dir ]]; then
    [[ $XDG_CACHE_HOME ]] &&
      echo "ble.sh: XDG_CACHE_HOME='$XDG_CACHE_HOME' is not a directory." >&2
    return 1
  fi
  if ! [[ -r $cache_dir && -w $cache_dir && -x $cache_dir ]]; then
    [[ $XDG_CACHE_HOME ]] &&
      echo "ble.sh: XDG_CACHE_HOME='$XDG_CACHE_HOME' doesn't have a proper permission." >&2
    return 1
  fi

  ble/base/.create-user-directory _ble_base_cache "$cache_dir/blesh/0.2"
}
function ble/base/initialize-cache-directory {
  ble/base/initialize-cache-directory/.xdg && return

  # fallback
  local cache_dir=$_ble_base/cache.d
  if [[ ! -d $cache_dir ]]; then
    ble/bin/mkdir -p "$cache_dir" || return
    ble/bin/chmod a+rwxt "$cache_dir" || return

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
  echo "ble.sh: failed to initialize \$_ble_base_cache." 1>&2
  return 1
fi

#%if measure_load_time
}
#%end

# Solaris: src/util の中でちゃんとした awk が必要
ble/bin/awk.use-solaris-xpg4

##%x inc.r/@/getopt/
#%x inc.r/@/core/

ble/bin/.freeze-utility-path "${_ble_init_posix_command_list[@]}" # <- this uses ble/util/assign.
ble/bin/.freeze-utility-path man
# Solaris: .freeze-utility-path で上書きされた awk を戻す
ble/bin/awk.use-solaris-xpg4

#%x inc.r/@/decode/
#%x inc.r/@/color/
#%x inc.r/@/edit/
#%x inc.r/@/form/
#%x inc.r/@/syntax-lazy/
#------------------------------------------------------------------------------

function ble-initialize {
  ble-decode-initialize # 7ms
  ble-edit-initialize # 3ms
}

_ble_attached=
function ble-attach {
  [[ $_ble_attached ]] && return

  # 取り敢えずプロンプトを表示する
  ble/term/enter      # 3ms (起動時のずれ防止の為 stty)
  ble-edit-attach     # 0ms (_ble_edit_PS1 他の初期化)
  ble/textarea#redraw # 37ms
  ble/util/buffer.flush >&2

  # keymap 初期化
  local IFS=$' \t\n'
  ble-decode/reset-default-keymap # 264ms (keymap/vi.sh)
  if ! ble-decode-attach; then # 53ms
    ble-edit/detach
    ble/term/finalize
    return 1
  fi
  _ble_attached=1
  _ble_edit_detach_flag= # do not detach or exit

  ble-edit/reset-history # 27s for bash-3.0

  # Note: ble-decode/reset-default-keymap 内で
  #   info を設定する事があるので表示する。
  ble-edit/info/default
  ble-edit/bind/.tail
}

function ble-detach {
  [[ $_ble_attached ]] || return
  _ble_attached=
  _ble_edit_detach_flag=${1:-detach} # schedule detach
}

#%if measure_load_time
echo ble-initialize >&2
time ble-initialize
#%else
ble-initialize
#%end

# 状態復元
if [[ $_ble_init_original_IFS_set ]]; then
  IFS=$_ble_init_original_IFS
else
  builtin unset -v IFS
fi
builtin unset -v _ble_init_original_IFS_set
builtin unset -v _ble_init_original_IFS

function ble/base/process-blesh-arguments {
  local opt_attach=1
  local opt_rcfile=
  local opt_error=
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (--noattach|noattach)
      opt_attach= ;;
    (--rcfile=*|--init-file=*)
      opt_rcfile=${arg#*=} ;;
    (--rcfile|--init-file)
      opt_rcfile=$1; shift ;;
    (*)
      echo "ble.sh: unrecognized argument '$arg'" >&2
      opt_error=1
    esac
  done

  [[ $opt_rcfile ]] && source "$opt_rcfile"
  [[ $opt_attach ]] && ble-attach
  [[ ! $opt_error ]]
}

ble/base/process-blesh-arguments "$@"
#%if measure_load_time
}
#%end

return 0
###############################################################################
