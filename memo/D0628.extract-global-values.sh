#!/bin/bash

_ble_bash=$((BASH_VERSINFO[0]*10000+BASH_VERSINFO[1]*100+BASH_VERSINFO[2]))

mode=test5d

#------------------------------------------------------------------------------
# 1 declare -g var とする事でローカル変数を飛び越して
#   グローバル変数に読み書きできる様になるか?
#
# →declare -g var=value でグローバル変数に値を設定することはできるが、
# この後で $var としても元々あったローカル変数が読み出せる様になるだけである。
#

if [[ $mode == test1 ]]; then
  var=0

  function call2 {
    declare -g var=2
    echo call2: $var
  }

  function call1 {
    local var=1
    call2
    echo call1: $var
  }

  echo global: $var
  call1
  echo global: $var
fi

#------------------------------------------------------------------------------
# 2 所で export キーワードを用いてもローカル変数になるのだろうか。
#
# export キーワードを用いた時にはローカル変数にはならない。
# local -x を用いればその時限りの環境変数になる。
#

if [[ $mode == test2 ]]; then
  function call1a {
    export var=1
    echo call1: $var
  }
  function call1b {
    local -x var=1
    echo call1b: $var
  }

  var=0
  echo global: $var
  call1a
  echo global: $var
  var=0
  echo global: $var
  call1b
  echo global: $var
fi

#------------------------------------------------------------------------------
# 3 本題に戻る。declare -pg でどの様に出力されるか。
#
# 何と駄目だ。ローカルの値が出力される。declare -pg でも駄目だし、
# また declare -p -g でも駄目だった。
# declare -g とすれば -p を指定しなくても全変数の内容が表示される。
# と思って試してみたが、この方法でもローカル変数の値が出力される。
# というか普通にローカルでしか定義していない変数も出力されている。
#

if [[ $mode == test3 ]]; then
  var=0

  function call2 {
    #declare -gp var
    #declare -pg var
    declare -p -g var
    #declare -g
  }

  function call1 {
    local var=1
    local local_var=1
    call2
    echo call1: $var
  }

  echo global: $var
  call1
  echo global: $var
fi

#------------------------------------------------------------------------------
# 4 シグナルハンドラから出力させる方法
#
# うーん。シグナルハンドラの中から見てもローカル変数が定義されている。
#

if [[ $mode == test4 ]]; then
  function call2 {
    echo call2: $var
    declare -p -g var
  }
  trap -- 'call2' USR1

  function call1 {
    local var=1
    kill -USR1 $BASHPID
    echo call1: $var
  }

  var=0
  echo global: $var
  call1
  echo global: $var
fi

#------------------------------------------------------------------------------
# 5 サブシェルで unset を繰り返す方法
#
# これでアクセスすることができた。
# 但し、fork を一回するので遅いという問題はあるが仕方がない。
#
#

if [[ $mode == test5 ]]; then
  function call2 {
    ( unset -v var
      echo call2: $var)
  }

  function call1 {
    local var=1
    call2
    echo call1: $var
  }

  var=123
  echo global: $var
  call1
  echo global: $var
fi

# 複数階層の場合に正しく var を掘り出せるか。
# → OK ちゃんと掘り出せている。
if [[ $mode == test5a ]]; then
  function f1a {
    (
      while [[ ${var+set} ]]; do
        echo "    f1a: var=$var"
        unset -v var
      done
    )
  }

  function f1b {
    local var=f1b
    echo "   f1b: var=$var"
    f1a
    echo "   f1b: var=$var"
  }

  function f1c {
    local var=f1c
    echo "  f1c: var=$var"
    f1b
    echo "  f1c: var=$var"
  }

  function f1d {
    local var=f1d
    echo " f1d: var=$var"
    f1c
    echo " f1d: var=$var"
  }

  var=global
  echo "global: var=$var"
  f1d
  echo "global: var=$var"
fi


# 途中のローカル変数が -r になっていた時、掘り出せるのか?
# →駄目。エラーになる。しかも対策しないと無限ループになる。
if [[ $mode == test5b ]]; then
  function f1a {
    (
      count=0
      count_max=10
      while [[ ${var+set} ]]; do
        ((count++<count_max)) || break
        echo "   f1a: var=$var"
        unset -v var
      done
    )
  }

  function f1b {
    local -r var=f1b
    echo "  f1b: var=$var"
    f1a
    echo "  f1b: var=$var"
  }

  function f1c {
    local -r var=f1c
    echo " f1c: var=$var"
    f1b
    echo " f1c: var=$var"
  }

  var=global
  echo "global: var=$var"
  f1c
  echo "global: var=$var"
fi

# 途中で空の変数定義が存在すると、一番上にまで達したと勘違いして止まるのでは。
#
# →うーん。一回目・二回目は止まらないけれど、その次には止まる。
# つまり local var であっても ${var+set} は反応するが、
# それも unset を二回実行すると効かなくなるということ。
#

if [[ $mode == test5c ]]; then
  function f1a {
    (
      while [[ ${var+set} ]]; do
        echo "    f1a: var=$var"
        unset -v var
      done
    )
  }

  function f1b {
    local var
    echo "   f1b: var=$var"
    f1a
    echo "   f1b: var=$var"
  }

  function f1c {
    local var
    echo "  f1c: var=$var"
    f1b
    echo "  f1c: var=$var"
  }

  function f1d {
    local var
    echo " f1d: var=$var"
    f1c
    echo " f1d: var=$var"
  }

  var=global
  echo "global: var=$var"
  f1d
  echo "global: var=$var"
fi


# declare -g -r を用いてグローバル変数が存在するか分かるのでは?
if [[ $mode == test5d ]]; then

  # 先ず、存在しない変数名で declare -g -r すると、
  # 変数は存在しないことになっているが、unset できなくなる。

  echo $'\e[1m0: test for var1\e[m'
  declare -g -r var1
  [[ ${var1+set} ]] && echo "var1 is set; var1=$var1"
  unset -v var1

  # 存在する変数名では自然な振る舞いをする。
  # 値が消えるという事もない。unset できなくなる。

  echo $'\e[1m0: test for var2\e[m'
  var2=
  declare -g -r var2
  [[ ${var2+set} ]] && echo "var2 is set; var2=$var2"
  unset -v var2

  if ((_ble_bash>=40200)); then
    # 制限: 途中に readonly なローカル変数があるとその変数の値を返す。
    #   しかし、そもそも readonly な変数には問題が多いので ble.sh では使わない。
    # 注意: bash-4.2 にはバグがあって、グローバル変数が存在しない時に
    #   declare -g -r var とすると、ローカルに新しく読み取り専用の var 変数が作られる。
    #   現在の実装では問題にならない。
    function get_global_value {
      (
        __ble_error=
        __ble_q="'" __ble_Q="'\''"
        # 補完で 20 階層も関数呼び出しが重なることはなかろう
        __ble_MaxLoop=20

        for __ble_name; do
          ((__ble_processed_$__ble_name)) && continue
          ((__ble_processed_$__ble_name=1))

          declare -g -r "$__ble_name"

          for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
            # echo "get_global_value: $__ble_name=${!__ble_name}"
            __ble_value=${!__ble_name}
            unset -v "$__ble_name" || break
          done 2>/dev/null

          ((__ble_i==__ble_MaxLoop)) && __ble_error=1 __ble_value=NOT_FOUND

          echo "declare $__ble_name='${__ble_value//$__ble_q/$__ble_Q}'"
        done
        
        [[ ! $__ble_error ]]
      )
    }
  else
    # 制限: グローバル変数が定義されずローカル変数が定義されているとき、
    #   ローカル変数の値が取得されてしまう。
    function get_global_value {
      (
        __ble_error=
        __ble_q="'" __ble_Q="'\''"
        # 補完で 20 階層も関数呼び出しが重なることはなかろう
        __ble_MaxLoop=20

        for __ble_name; do
          ((__ble_processed_$__ble_name)) && continue
          ((__ble_processed_$__ble_name=1))

          __ble_value= __ble_found=0
          for ((__ble_i=0;__ble_i<__ble_MaxLoop;__ble_i++)); do
            # echo "get_global_value: $__ble_name=${!__ble_name}"
            [[ ${!__ble_name+set} ]] && __ble_value=${!__ble_name} __ble_found=1
            unset -v "$__ble_name" 2>/dev/null
          done

          ((__ble_found)) || __ble_error= __ble_value=NOT_FOUND

          echo "declare $__ble_name='${__ble_value//$__ble_q/$__ble_Q}'"
        done
        
        [[ ! $__ble_error ]]
      )
    }
  fi


  function f1a {
    local var=f1a
    get_global_value var
    [[ $var == f1a ]] || echo "   f1a: var is broken"
  }
  function f1b {
    local var=f1b
    f1a
    [[ $var == f1b ]] || echo "   f1b: var is broken"
  }
  function f1c {
    local var=f1c
    f1b
    [[ $var == f1c ]] || echo "   f1c: var is broken"
  }

  function f2a {
    local var
    get_global_value var
    [[ $var == '' ]] || echo "   f2a: var is broken"
  }
  function f2b {
    local var
    f2a
    [[ $var == '' ]] || echo "   f2b: var is broken"
  }
  function f2c {
    local var
    f2b
    [[ $var == '' ]] || echo "   f2c: var is broken"
  }

  echo $'\e[1m1: var is unset\e[m'
  f1c
  f2c
  echo $'\e[1m2: var is empty\e[m'
  var=
  f1c
  f2c
  echo $'\e[1m3: var is "global1"\e[m'
  var=global1
  f1c
  f2c
  echo $'\e[1m4: var is "global2" readonly\e[m'
  declare -r var=global2
  f1c
  f2c
fi
