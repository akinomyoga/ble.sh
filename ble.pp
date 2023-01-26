#!/bin/bash
#%$> out/ble.sh
#%[release = 1]
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
  echo "ble.sh: This shell is not Bash. Please use this script with Bash." >&3
  return 1 2>/dev/null || exit 1
fi 3>&2 >/dev/null 2>&1 # set -x 対策 #D0930

if [ -z "${BASH_VERSINFO[0]}" ] || [ "${BASH_VERSINFO[0]}" -lt 3 ]; then
  echo "ble.sh: Bash with a version under 3.0 is not supported." >&3
  return 1 2>/dev/null || exit 1
fi 3>&2 >/dev/null 2>&1 # set -x 対策 #D0930

if ((BASH_SUBSHELL)); then
  builtin echo "ble.sh: ble.sh cannot be loaded into a subshell." >&3
  return 1 2>/dev/null || builtin exit 1
elif [[ $- != *i* ]]; then
  case " ${BASH_SOURCE[*]##*/} " in
  (*' .bashrc '* | *' .bash_profile '* | *' .profile '* | *' bashrc '* | *' profile '*) false ;;
  esac &&
    builtin echo "ble.sh: This is not an interactive session." >&3 || ((1))
  return 1 2>/dev/null || builtin exit 1
elif ! [[ -t 4 && -t 5 ]]; then
  builtin echo "ble.sh: cannot find the correct TTY/PTY in this session." >&3
  return 1 2>/dev/null || builtin exit 1
fi 3>&2 4<&0 5>&1 &>/dev/null # set -x 対策 #D0930

function ble/base/adjust-bash-options {
  [[ $_ble_bash_options_adjusted ]] && return 1 || :
  _ble_bash_options_adjusted=1

  _ble_bash_sete=; [[ -o errexit ]] && _ble_bash_sete=1 && set +e
  _ble_bash_setx=; [[ -o xtrace  ]] && _ble_bash_setx=1 && set +x
  _ble_bash_setv=; [[ -o verbose ]] && _ble_bash_setv=1 && set +v
  _ble_bash_setu=; [[ -o nounset ]] && _ble_bash_setu=1 && set +u
  _ble_bash_setk=; [[ -o keyword ]] && _ble_bash_setk=1 && set +k
  _ble_bash_setB=; [[ -o braceexpand ]] && _ble_bash_setB=1 || set -B

  # Note: nocasematch は bash-3.0 以上
  _ble_bash_nocasematch=
  shopt -q nocasematch 2>/dev/null &&
    _ble_bash_nocasematch=1 && shopt -u nocasematch

  # locale 待避
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
} &>/dev/null # set -x 対策 #D0930
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
  [[ ! $_ble_bash_setB && -o braceexpand ]] && set +B
  [[ $_ble_bash_setk && ! -o keyword ]] && set -k
  [[ $_ble_bash_setu && ! -o nounset ]] && set -u
  [[ $_ble_bash_setv && ! -o verbose ]] && set -v
  [[ $_ble_bash_setx && ! -o xtrace  ]] && set -x
  [[ $_ble_bash_sete && ! -o errexit ]] && set -e
} 2>/dev/null # set -x 対策 #D0930
{
  _ble_bash_options_adjusted=
  ble/base/adjust-bash-options
} &>/dev/null # set -x 対策 #D0930

## @var _ble_bash_POSIXLY_CORRECT_adjusted
##   現在 POSIXLY_CORRECT 状態を待避した状態かどうかを保持します。
## @var _ble_bash_POSIXLY_CORRECT_set
##   待避した POSIXLY_CORRECT の設定・非設定状態を保持します。
## @var _ble_bash_POSIXLY_CORRECT_set
##   待避した POSIXLY_CORRECT の値を保持します。
_ble_bash_POSIXLY_CORRECT_adjusted=
_ble_bash_POSIXLY_CORRECT_set=
_ble_bash_POSIXLY_CORRECT=
function ble/base/workaround-POSIXLY_CORRECT {
  # This function will be overwritten by ble-decode
  true
}
function ble/base/unset-POSIXLY_CORRECT {
  if [[ ${POSIXLY_CORRECT+set} ]]; then
    unset -v POSIXLY_CORRECT
    ble/base/workaround-POSIXLY_CORRECT
  fi
}
function ble/base/adjust-POSIXLY_CORRECT {
  [[ $_ble_bash_POSIXLY_CORRECT_adjusted ]] && return
  _ble_bash_POSIXLY_CORRECT_adjusted=1
  _ble_bash_POSIXLY_CORRECT_set=${POSIXLY_CORRECT+set}
  _ble_bash_POSIXLY_CORRECT=$POSIXLY_CORRECT
  unset -v POSIXLY_CORRECT

  # ユーザが触ったかもしれないので何れにしても workaround を呼び出す。
  ble/base/workaround-POSIXLY_CORRECT
}
function ble/base/restore-POSIXLY_CORRECT {
  if [[ ! $_ble_bash_POSIXLY_CORRECT_adjusted ]]; then return; fi # Note: set -e の為 || は駄目
  _ble_bash_POSIXLY_CORRECT_adjusted=
  if [[ $_ble_bash_POSIXLY_CORRECT_set ]]; then
    POSIXLY_CORRECT=$_ble_bash_POSIXLY_CORRECT
  else
    ble/base/unset-POSIXLY_CORRECT
  fi
}
ble/base/adjust-POSIXLY_CORRECT

function ble/base/is-POSIXLY_CORRECT {
  if [[ $_ble_bash_POSIXLY_CORRECT_adjusted ]]; then
    [[ $_ble_bash_POSIXLY_CORRECT_set ]]
  else
    [[ ${POSIXLY_CORRECT+set} ]]
  fi
}

# From src/util.sh
function ble/variable#copy-state {
  local src=$1 dst=$2
  if [[ ${!src+set} ]]; then
    builtin eval -- "$dst=\${$src}"
  else
    builtin unset -v "$dst[0]" 2>/dev/null || builtin unset -v "$dst"
  fi
}

builtin bind &>/dev/null # force to load .inputrc
if [[ ! -o emacs && ! -o vi ]]; then
  echo "ble.sh: ble.sh is not intended to be used with the line-editing mode disabled (--noediting)." >&2
  return 1
fi

if shopt -q restricted_shell; then
  echo "ble.sh: ble.sh is not intended to be used in restricted shells (--restricted)." >&2
  return 1
fi

if [[ ${BASH_EXECUTION_STRING+set} ]]; then
  # echo "ble.sh: ble.sh will not be activated for Bash started with '-c' option." >&2
  return 1 2>/dev/null || builtin exit 1
fi

_ble_init_original_IFS_set=${IFS+set}
_ble_init_original_IFS=$IFS
IFS=$' \t\n'

#------------------------------------------------------------------------------
# Initialize version information

# DEBUG version の Bash では遅いという通知
case ${BASH_VERSINFO[4]} in
(alp*|bet*|dev*|rc*|releng*|maint*)
  printf '%s\n' \
    "ble.sh may become very slow because this is a debug version of Bash" \
    "  (version '$BASH_VERSION', release status: '${BASH_VERSINFO[4]}')." \
    "  We recommend using ble.sh with a release version of Bash." >&2 ;;
esac

_ble_bash=$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))
_ble_bash_loaded_in_function=0
[[ ${FUNCNAME+set} ]] && _ble_bash_loaded_in_function=1

_ble_version=0
#%$ echo "BLE_VERSION=$FULLVER+$(git show -s --format=%h)"
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
    ble/util/print "ble.sh: Insane environment: \$USER is empty." >&2
    if USER=$(id -un 2>/dev/null) && [[ $USER ]]; then
      export USER
      ble/util/print "ble.sh: modified USER=$USER" >&2
    fi
  fi
  _ble_base_env_USER=$USER

  if [[ ! $HOSTNAME ]]; then
    ble/util/print "ble.sh: suspicious environment: \$HOSTNAME is empty."
    if HOSTNAME=$(uname -n 2>/dev/null) && [[ $HOSTNAME ]]; then
      export HOSTNAME
      ble/util/print "ble.sh: fixed HOSTNAME=$HOSTNAME" >&2
    fi
  fi
  _ble_base_env_HOSTNAME=$HOSTNAME

  # 暫定的な ble/bin/$cmd 設定
  ble/bin/.default-utility-path "${_ble_init_posix_command_list[@]}"

  return 0
}
if ! ble/.check-environment; then
  _ble_bash=
  return 1
fi

if [[ $_ble_base ]]; then
  if ! ble/base/unload-for-reload; then
    echo "ble.sh: ble.sh seems to be already loaded." >&2
    return 1
  fi
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
  builtin unset -v _ble_bash BLE_VERSION BLE_VERSINFO
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
    if ! builtin kill -0 "$pid" &>/dev/null; then
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

  local ver=${BLE_VERSINFO[0]}.${BLE_VERSINFO[1]}
  ble/base/.create-user-directory _ble_base_cache "$cache_dir/blesh/$ver"
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
function ble-reload { source "$_ble_base/ble.sh" --attach=prompt --rcfile="${_ble_base_rcfile:-/dev/null}"; }
#%$ pwd=$(pwd) q=\' Q="'\''" bash -c 'echo "_ble_base_repository=$q${pwd//$q/$Q}$q"'
function ble-update {
  if (($#)); then
    ble/base/print-usage-for-no-argument-command 'Update and reload ble.sh.' "$@"
    return
  fi

  # check make
  local MAKE=
  if type gmake &>/dev/null; then
    MAKE=gmake
  elif type make &>/dev/null && make --version 2>&1 | grep -qiF 'GNU Make'; then
    MAKE=make
  else
    echo "ble-update: GNU Make is not available." >&2
    return 1
  fi

  # check git, gawk
  if ! ble/bin#has git gawk &>/dev/null; then
    local command
    for command in git gawk; do
      type "$command" ||
        echo "ble-update: '$command' command is not available." >&2
    done
    return 1
  fi

  if [[ $_ble_base_repository == release:* ]]; then
    # release version
    local branch=${_ble_base_repository#*:}
    ( ble/bin/mkdir -p "$_ble_base/src" && builtin cd "$_ble_base/src" &&
        git clone --depth 1 https://github.com/akinomyoga/ble.sh "$_ble_base/src/ble.sh" -b "$branch" &&
        builtin cd ble.sh && "$MAKE" all && "$MAKE" INSDIR="$_ble_base" install ) &&
      ble-reload
    return
  fi

  if [[ $_ble_base_repository && -d $_ble_base_repository/.git ]]; then
    ( echo "cd into $_ble_base_repository..." >&2 &&
        builtin cd "$_ble_base_repository" &&
        git pull && { ! "$MAKE" -q || builtin exit 6; } && "$MAKE" all &&
        if [[ $_ble_base != "$_ble_base_repository"/out ]]; then
          "$MAKE" INSDIR="$_ble_base" install
        fi ); local ext=$?
    ((ext==6)) && return
    ((ext==0)) && ble-reload
    return "$ext"
  fi

  echo 'ble-update: git repository not found' >&2
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
# Solaris: .freeze-utility-path で上書きされた awk を戻す
ble/bin/awk.use-solaris-xpg4

#%x inc.r|@|src/decode|
#%x inc.r|@|src/color|
#%x inc.r|@|src/canvas|
#%x inc.r|@|src/edit|
#%x inc.r|@|lib/core-complete-def|
#%x inc.r|@|lib/core-syntax-def|
#------------------------------------------------------------------------------

_ble_attached=
function ble-attach {
  if (($#)); then
    ble/base/print-usage-for-no-argument-command 'Attach to ble.sh.' "$@"
    return
  fi

  # when detach flag is present
  if [[ $_ble_edit_detach_flag ]]; then
    case $_ble_edit_detach_flag in
    (exit) return 0 ;;
    (*) _ble_edit_detach_flag= ;; # cancel "detach"
    esac
  fi

  [[ $_ble_attached ]] && return
  _ble_attached=1

  # 特殊シェル設定を待避
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
  ble-decode/initialize # 7ms
  ble-decode/reset-default-keymap # 264ms (keymap/vi.sh)
  if ! ble-decode/attach; then # 53ms
    _ble_attached=
    ble-edit/detach
    return 1
  fi

  ble-edit/reset-history # 27s for bash-3.0

  # Note: ble-decode/{initialize,reset-default-keymap} 内で
  #   info を設定する事があるので表示する。
  ble-edit/info/default
  ble-edit/bind/.tail
}

function ble-detach {
  if (($#)); then
    ble/base/print-usage-for-no-argument-command 'Detach from ble.sh.' "$@"
    return
  fi

  [[ $_ble_attached && ! $_ble_edit_detach_flag ]] || return

  # Note: 実際の detach 処理は ble-edit/bind/.check-detach で実行される
  _ble_edit_detach_flag=${1:-detach} # schedule detach
}
function ble-detach/impl {
  [[ $_ble_attached ]] || return
  _ble_attached=

  ble-edit/detach
  ble-decode/detach
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
    echo "${_ble_term_setaf[12]}[ble: reload]$_ble_term_sgr0" 1>&2
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
  ble/util/openat/finalize
  ble/util/import/finalize
  ble-edit/bind/clear-keymap-definition-loader
  ble/bin/rm -f "$_ble_base_run/$$".*
  return 0
}
trap ble/base/unload EXIT

_ble_base_attach_PROMPT_COMMAND=
_ble_base_attach_from_prompt=
function ble/base/attach-from-PROMPT_COMMAND {
  # 後続の設定によって PROMPT_COMMAND が置換された場合にはそれを保持する
  [[ $PROMPT_COMMAND == ble/base/attach-from-PROMPT_COMMAND ]] || local PROMPT_COMMAND
  PROMPT_COMMAND=$_ble_base_attach_PROMPT_COMMAND
  ble-edit/prompt/update/.eval-prompt_command

  # 既に attach 状態の時は処理はスキップ
  [[ $_ble_base_attach_from_prompt ]] || return 0
  _ble_base_attach_from_prompt=
  ble-attach

  # Note: 何故か分からないが PROMPT_COMMAND から ble-attach すると
  # ble/bin/stty や ble/bin/mkfifo や tty 2>/dev/null などが
  # ジョブとして表示されてしまう。joblist.flush しておくと平気。
  # これで取り逃がすジョブもあるかもしれないが仕方ない。
  ble/util/joblist.flush &>/dev/null
  ble/util/joblist.check
}

function ble/base/process-blesh-arguments {
  local opt_attach=attach
  local opt_error=
  while (($#)); do
    local arg=$1; shift
    case $arg in
    (--noattach|noattach)
      opt_attach=none ;;
    (--attach=*) opt_attach=${arg#*=} ;;
    (--attach)   opt_attach=$1; shift ;;
    (--rcfile=*|--init-file=*|--rcfile|--init-file)
      if [[ $arg != *=* ]]; then
        local rcfile=$1; shift
      else
        local rcfile=${arg#*=}
      fi
      _ble_base_rcfile=${rcfile:-/dev/null}
      if [[ ! $rcfile || ! -e $rcfile ]]; then
        ble/util/print "ble.sh ($arg): '$rcfile' does not exist." >&2
        opt_error=1
      elif [[ ! -r $rcfile ]]; then
        ble/util/print "ble.sh ($arg): '$rcfile' is not readable." >&2
        opt_error=1
      fi ;;
    (--norc)
      _ble_base_rcfile=/dev/null ;;
    (*)
      echo "ble.sh: unrecognized argument '$arg'" >&2
      opt_error=1
    esac
  done

  if [[ ! $_ble_base_rcfile ]]; then
    { _ble_base_rcfile=$HOME/.blerc; [[ -f $_ble_base_rcfile ]]; } ||
      { _ble_base_rcfile=${XDG_CONFIG_HOME:-$HOME/.config}/blesh/init.sh; [[ -f $_ble_base_rcfile ]]; } ||
      _ble_base_rcfile=$HOME/.blerc
  fi
  [[ -s $_ble_base_rcfile ]] && source "$_ble_base_rcfile"
  case $opt_attach in
  (attach) ble-attach ;;
  (prompt) _ble_base_attach_PROMPT_COMMAND=$PROMPT_COMMAND
           _ble_base_attach_from_prompt=1
           PROMPT_COMMAND=ble/base/attach-from-PROMPT_COMMAND
           [[ $_ble_edit_detach_flag == reload ]] &&
             _ble_edit_detach_flag=prompt-attach ;;
  esac
  [[ ! $opt_error ]]
}

ble/base/process-blesh-arguments "$@"

# 状態復元
if [[ $_ble_init_original_IFS_set ]]; then
  IFS=$_ble_init_original_IFS
else
  builtin unset -v IFS
fi
builtin unset -v _ble_init_original_IFS_set
builtin unset -v _ble_init_original_IFS
if [[ ! $_ble_attached ]]; then
  ble/base/restore-bash-options
  ble/base/restore-POSIXLY_CORRECT
fi &>/dev/null # set -x 対策 #D0930

#%if measure_load_time
}
#%end

{ return 0; } &>/dev/null # set -x 対策 #D0930
###############################################################################
