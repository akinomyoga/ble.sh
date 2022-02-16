#! bash config

shopt -s extglob
#opts=builtin-elapsed
#opts=no-timer

#type=none
type=initial
#type=initial-prompt
#type=final
#type=final-prompt

#type=check-DEBUG-behavior
#type=unset-self-func
#type=check-bashbug-tmpenv
#type=check-unset-trap-DEBUG

#set -T

if [[ $type == initial ]]; then
  source out/ble.sh --attach=none
elif [[ $type == initial-prompt ]]; then
  source out/ble.sh
fi

if [[ ${BLE_VERSION-} && :$opts: == *:builtin-elapsed:* ]]; then
  ble-import contrib/prompt-elapsed
  _ps1_time='\q{contrib/elapsed}'
elif [[ :$opts: != *:no-timer:* ]]; then
  function timer_start {
#echo $FUNCNAME >/dev/tty
    timer=${timer:-$SECONDS}
  }

  function timer_stop {
#echo $FUNCNAME >/dev/tty
    timer_show=$(($SECONDS - $timer))
    #timer_show=$(($SECONDS - timer))
    unset timer
  }

  trap 'timer_start "$BASH_COMMAND"' DEBUG

  if [ "$PROMPT_COMMAND" == "" ]; then
    PROMPT_COMMAND="timer_stop"
  else
    PROMPT_COMMAND="$PROMPT_COMMAND; timer_stop"
  fi

  _ps1_time='${timer_show}s'
fi

case $type in
(check-DEBUG-behavior)
  echo "direct:1"
  builtin trap -p DEBUG
  echo "direct:2"

  # Q サブシェルの中でも DEBUG trap の定義を参照できるか?
  # A 参照できる。
  echo "subshell:1"
  echo "[$(builtin trap -p DEBUG)]"
  echo "subshell:2"

  # Q 関数の中でも DEBUG trap の定義を参照できるか?
  # A 参照できない。-t を付加していれば見られる。
  function inside-function {
    echo "$FUNCNAME:1"
    builtin trap -p DEBUG
    echo "$FUNCNAME:2"
  } >/dev/tty
  declare -ft inside-function
  inside-function

  # Q 関数内サブシェルでも DEBUG trap の定義を参照できるか?
  # A できない。-t を付加していれば見られる。
  function inside-func-subshell {
    echo "$FUNCNAME[$(builtin trap -p DEBUG)]"
  } >/dev/tty
  declare -ft inside-func-subshell
  inside-func-subshell

  # Q 関数内 eval でも DEBUG trap の定義を参照できるか?
  # A できない。-t を付加していれば見られる。
  function inside-func-eval {
    echo "$FUNCNAME:1"
    eval 'builtin trap -p DEBUG'
    echo "$FUNCNAME:2"
  } >/dev/tty
  declare -ft inside-func-eval
  inside-func-eval

  # Q 関数の更に内側の関数で DEBUG trap の定義を参照できるか?
  # A できない。外側と内側の両方に -t を指定して初めて見られる。
  function inside-func-nest/1 {
    builtin trap -p DEBUG
  }
  function inside-func-nest {
    echo "$FUNCNAME:1"
    inside-func-nest/1
    echo "$FUNCNAME:2"
  } >/dev/tty
  declare -ft inside-func-nest/1
  declare -ft inside-func-nest
  inside-func-nest

  # Q 関数の中でリダイレクトした時に DEBUG trap の定義を参照できるか。
  # A できない。-t を付加していれば見られる。
  function inside-func-redir {
    builtin trap -p DEBUG > a.tmp
    echo "$FUNCNAME[$(<a.tmp)]"
  } >/dev/tty
  declare -ft inside-func-redir
  inside-func-redir

  # Q 内側の関数から呼び出された後で外側の関数に対して -t 属性を付加して参照できる様になるだろうか。
  # A ならない。
  function nest-afterward-trace/1 {
    declare -ft "${FUNCNAME[1]}"
    builtin trap -p DEBUG
  }
  function nest-afterward-trace {
    echo "$FUNCNAME:1"
    nest-afterward-trace/1
    echo "$FUNCNAME:2"
  }
  declare -ft nest-afterward-trace/1
  nest-afterward-trace

  # Q 内側の関数で set -o functrace を設定して見られる様になるだろうか。
  # A ならない。
  function nest-afterward-functrace/1 {
    set -o functrace
    builtin trap -p DEBUG
    set +o functrace
  }
  function nest-afterward-functrace {
    echo "$FUNCNAME:1"
    nest-afterward-functrace/1
    echo "$FUNCNAME:2"
  }
  nest-afterward-functrace

  # Q source xxx の中から DEBUG trap は見えるだろうか。
  # A 見えない。但し set -T (-o functrace) が設定されていれば見える。
  #set -T
  {
    echo echo inside-source:1
    echo builtin trap -p DEBUG
    echo echo inside-source:2
  } >| a.tmp
  source ./a.tmp

  exit ;;

(unset-self-func)
  function test-unset-self-function {
    unset -f "$FUNCNAME"
    echo hello
    echo world
  }
  test-unset-self-function

  if declare -f test-unset-self-function; then
    echo $'test-unset-self-function: \e[1;31mfound\e[m (unexpected)'
  else
    echo $'test-unset-self-function: \e[1;32mnot found\e[m (expected)'
  fi

  exit ;;

(check-bashbug-tmpenv)
  set +T

  function hello {
    echo "result1:$a"
    echo "result2:$a"
  }
  a=value hello
  a=value eval hello
  a=value builtin eval hello

  function print { echo "v=${v:-(not found)}"; }
  function trapdebug { echo "$FUNCNAME:1:v=($v)"; }
  builtin trap 'trapdebug' DEBUG
  v=xxxx builtin eval 'echo v=${v:-(not found)}'
  v=xxxx eval 'echo v=${v:-(not found)}'
  echo "[print with debugtrap]"
  v=xxxx print
  v=xxxx eval print
  v=xxxx builtin eval print

  exit ;;

(check-unset-trap-DEBUG)
  # Q trace 属性のついた関数内から DEBUG trap を削除する事は可能か?
  # A 削除できる。
  function unset-trap {
    builtin trap - DEBUG
  }
  declare -ft unset-trap

  echo check-unset-trap-DEBUG:1
  builtin trap -p DEBUG
  echo check-unset-trap-DEBUG:2
  unset-trap
  echo check-unset-trap-DEBUG:3
  builtin trap -p DEBUG
  echo check-unset-trap-DEBUG:4

  exit ;;
esac

if [[ $type == final ]]; then
  source out/ble.sh --attach=none
elif [[ $type == final-prompt ]]; then
  source out/ble.sh
fi
PS1='[last: '$_ps1_time'][\w]$ '

if [[ ${BLE_VERSION-} && $type == @(final|initial) ]]; then
  ble-attach
  # { echo A
  #   builtin trap -p DEBUG
  #   echo B
  #   trap -p DEBUG 
  #   echo C
  # } >/dev/tty
fi
