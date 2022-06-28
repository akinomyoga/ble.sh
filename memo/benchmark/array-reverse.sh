#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  printf '%s\r' 'loading ble.sh...'
  source ../../out/ble.sh --lib
  printf '%s\n' 'loading ble.sh... done'
fi

S=({1..10000})

S1=({1..10})
S2=({1..100})
S3=({1..1000})
S4=({1..10000})
S5=({1..100000})

# 総評:
#
#   他の行列にコピーする場合には reverse3 が最速である。
#   in-place の時は reverse5.1 が最速である。
#
#   インターフェイスを少し変えると reverse7.2b が最速である。
#
#   改行が含まれている要素がないと保証できる場合は
#   ある程度以上の要素数の時に外部コマンドを呼び出した方が速くなる。
#

## @var measure_reverse_flags
##
##   measure_reverse_flags に含まれる文字に該当する
##   reverse について計測を行います。
##
measure_reverse_flags=01234567C

_ble_measure_count=1

#------------------------------------------------------------------------------
# reverse
#
#   bash では同時に二つ以上の配列に触ると遅くなる。
#   更に逆順にループを回した場合も遅くなる。
#   この様な場合にどう reverse を実装するのがよいか。
#

function copy.0 {
  local -a A=()
  A=("${S[@]}")
}
ble-measure copy.0 # 55072us for 10k (何と reverse.2 よりも遅い... [@] は [*] より遅い様だ)

#------------------------------------------------------------------------------
# 2016-07-07 愚直な実装 O(N^2)
#
#   function reverse.0 {
#     local -a A=()
#     local e N=${#S[@]}
#     for ((i=0;i<N;i++)); do
#       A[i]="${S[N-1-i]}"
#     done
#   }

function ble/array#reverse0 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  if [[ $__ble_dst != $__ble_src ]]; then
    builtin eval "
    local __ble_i __ble_len=\${#$__ble_src[@]}
    $__ble_dst=()
    for ((__ble_i=0;__ble_i<__ble_len;__ble_i++)); do
      $__ble_dst[__ble_i]=\${$__ble_src[__ble_len-1-__ble_i]}
    done"
  else
    builtin eval "
    local __ble_i=0 __ble_j=\$((\${#$__ble_src[@]}-1)) __ble_tmp
    while ((__ble_i<__ble_j)); do
      __ble_tmp=\${$__ble_src[__ble_i]}
      $__ble_src[__ble_i]=\${$__ble_src[__ble_j]}
      $__ble_src[__ble_j]=\$__ble_tmp
      ((__ble_i++,__ble_j--))
    done"
  fi
}

if [[ $measure_reverse_flags == *0* ]]; then
  # (a) $__ble_dst=() なし
  # (b) $__ble_dst=() あり    ... N が大きい時に速くなるので採用
  # (c) $__ble_dst+=() で追記 ... 却って遅いので却下

  # ----------------------------------- # (a)           (b)          (c)
  ble-measure 'ble/array#reverse0 A S'  # 1101969.90 us 671970.00 us 787970.10 us
  ble-measure 'ble/array#reverse0 A S1' #     533.60 us    543.00 us    657.10 us
  ble-measure 'ble/array#reverse0 A S2' #    3509.60 us   3490.00 us   4620.10 us
  ble-measure 'ble/array#reverse0 A S3' #   40569.60 us  35770.00 us  47570.10 us
  ble-measure 'ble/array#reverse0 A S4' # 1031969.60 us 618970.00 us 738970.10 us
fi

#------------------------------------------------------------------------------
# 2016-07-07 external commands (改行が含まれていると駄目)
#    
#   # ～ O(N)
#   # 外部コマンド呼び出し
#   # 改行が含まれていると駄目
#   function reverse.1 {
#     local -a A=()
#     A=($(printf '%s\n' "${S[@]}" | tac))
#   }
#   # ～ O(N)
#   # 外部コマンド呼び出し
#   # 改行が含まれていると駄目
#   function reverse.2 {
#     local -a A=()
#     IFS=$'\n' eval 'A=($(echo "${S[*]}" | tac))'
#   }
#   ble-measure reverse.1 # 99972us for 10k
#   ble-measure reverse.2 # 44372us for 10k ***

function ble/array#reverse1 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  ble/util/assign-array "$__ble_dst" "printf '%s\n' \"\${$__ble_src[@]}\" | tac"
}
function ble/array#reverse2 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  IFS=$'\n' ble/util/assign-array "$__ble_dst" "tac <<< \"\${$__ble_src[*]}\""
}

if [[ $measure_reverse_flags == *1* ]]; then
  ble-measure 'ble/array#reverse1 A S1' #  13970.00 us
  ble-measure 'ble/array#reverse1 A S2' #  13470.00 us
  ble-measure 'ble/array#reverse1 A S3' #  18370.00 us
  ble-measure 'ble/array#reverse1 A S4' #  86950.00 us
  ble-measure 'ble/array#reverse1 A S5' # 824000.00 us
fi

if [[ $measure_reverse_flags == *2* ]]; then
  ble-measure 'ble/array#reverse2 A S1' #   9120.00 us
  ble-measure 'ble/array#reverse2 A S2' #  10570.00 us
  ble-measure 'ble/array#reverse2 A S3' #  13370.00 us
  ble-measure 'ble/array#reverse2 A S4' #  35160.00 us
  ble-measure 'ble/array#reverse2 A S5' # 286000.00 us
fi

#------------------------------------------------------------------------------
# 2016-07-07 for ～ O(N)
#
#   function reverse.3 {
#     local -a A=()
#     local e i=${#S[@]}
#     for e in "${S[@]}"; do
#       A[--i]="$e"
#     done
#   }
#   ble-measure reverse.3 # 204972us for 10k ***
#
# Note:
#
#   * dst[--i] する前に dst をクリアした方が速い。
#     クリアしないと O(N ln N) の様な感じの応答である。
#

function ble/array#reverse3 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  eval "
  [[ \$__ble_dst != \$__ble_src ]] && $__ble_dst=()
  local __ble_elem __ble_ind=\${#$__ble_src[@]}
  for __ble_elem in \"\${$__ble_src[@]}\"; do
    $__ble_dst[--__ble_ind]=\$__ble_elem
  done"
}

if [[ $measure_reverse_flags == *3* ]]; then
  ble-measure 'ble/array#reverse3 A S'  #  183970.00 us
  ble-measure 'ble/array#reverse3 A S1' #     378.00 us
  ble-measure 'ble/array#reverse3 A S2' #    1920.00 us
  ble-measure 'ble/array#reverse3 A S3' #   17970.00 us
  ble-measure 'ble/array#reverse3 A S4' #  181970.00 us
  ble-measure 'ble/array#reverse3 A S5' # 1879970.00 us
fi

#------------------------------------------------------------------------------
# 2016-07-07 brace-expansion O(N)
#
#   ブレース展開を用いて A=([0]=${S[9]} ... [9]=${S[0]}) などの文字列を生成し、
#   それを eval するという方法。
#
#   # O(N)
#   function reverse.4.1 {
#     local -a A=()
#     local m="$((${#S[@]}-1))"
#     eval "A=($(eval "printf '[$m-%d]=\"\${S[%d]}\" ' {0..$m}{,}"))"
#   }
#   # O(N^2)
#   function reverse.4.2 {
#     local -a A=()
#     local m="$((${#S[@]}-1))"
#     eval "A=($(eval "printf '[%d]=\"\${S[$m-%d]}\" ' {0..$m}{,}"))"
#   }
#   ble-measure reverse.4.1 # 369972us for 10k
#   ble-measure reverse.4.2 # 632972us for 10k

function ble/array#reverse4.1 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  eval "local __ble_max=\$((\${#$__ble_src[@]}-1))"
  eval "$__ble_dst=($(eval "printf '[$__ble_max-%d]=\${$__ble_src[%d]} ' {0..$__ble_max}{,}"))"
}
function ble/array#reverse4.1a {
  local __ble_dst=$1 __ble_src=${2:-$1}
  eval "local __ble_max=\$((\${#$__ble_src[@]}-1)) __ble_init"
  ble/util/assign __ble_init "printf '[$__ble_max-%d]=\${$__ble_src[%d]} ' {0..$__ble_max}{,}"
  eval "$__ble_dst=($__ble_init)"
}
function ble/array#reverse4.2 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  eval "local __ble_max=\$((\${#$__ble_src[@]}-1))"
  eval "$__ble_dst=($(eval "printf '[%d]=\${$__ble_src[$__ble_max-%d]} ' {0..$__ble_max}{,}"))"
}

if [[ $measure_reverse_flags == *4* ]]; then
  # 計測コマンド                           # reverse4.1     reverse4.1a    reverse4.2
  #--------------------------------------- # -------------  -------------  --------------
  ble-measure 'ble/array#reverse4.1a A S'  #  346970.00 us   371969.90 us    686970.00 us
  ble-measure 'ble/array#reverse4.1a A S1' #    7320.00 us      728.90 us      7350.00 us
  ble-measure 'ble/array#reverse4.1a A S2' #   12270.00 us     3469.90 us     12270.00 us
  ble-measure 'ble/array#reverse4.1a A S3' #   39670.00 us    33569.90 us     42270.00 us
  ble-measure 'ble/array#reverse4.1a A S4' #  355970.00 us   371969.90 us    640970.00 us
  ble-measure 'ble/array#reverse4.1a A S5' # 3810970.00 us  4104969.90 us  76781970.00 us
fi

#------------------------------------------------------------------------------
# 2016-07-07 improvements for in-place reverse
#
#   予め $__ble_dst=() として置かないと $__ble_dst[--__ble_i] が遅くなる。
#   in-place の時は $__ble_dst=() としておく事ができないので遅い。
#
#   A=("${S[@]}")
#   function reverseD.swap { # ble/array#reverse0 A A
#     local i j t
#     for ((i=0,j=${#A[@]}-1;i<j;i++,j--)); do
#       t="${A[i]}"
#       A[i]="${A[j]}"
#       A[j]="$t"
#     done
#   }
#   function reverseD.for-in { # ble/array#reverse3 A A
#     local e i="${#A[@]}"
#     for e in "${A[@]}"; do
#       A[--i]="$e"
#     done
#   }
#   function reverseD.set-for { # ble/array#reverse5.1 A A
#     set -- "${A[@]}"
#     local e i="$#"
#     A=()
#     for e; do A[--i]="$e"; done
#   }
#   function reverseD.for-copy { # ble/array#reverse5.2 A A
#     local -a B=()
#     local e i="${#A[@]}"
#     for e in "${A[@]}"; do B[--i]="$e"; done
#     A=("${B[@]}")
#   }
#   ble-measure reverseD.swap # 693972us for 10k
#   ble-measure reverseD.for-in # 495972us for 10k
#   ble-measure reverseD.set-for # 258971us for 10k
#   ble-measure reverseD.for-copy # 256972us for 10k

# set で __ble_src の内容を待避する方法
function ble/array#reverse5.1 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  eval "set -- \"\${$__ble_src[@]}\"
  local __ble_i=\$#
  $__ble_dst=()
  for __ble_tmp; do $__ble_dst[--__ble_i]=\$__ble_tmp; done"
}

# 別の配列に reverse してから __ble_dst にコピーする方法
function ble/array#reverse5.2 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  eval "
  local __ble_i=\${#$__ble_src[@]}
  local -a __ble_arr=()
  for __ble_tmp in \"\${$__ble_src[@]}\"; do
    __ble_arr[--__ble_i]=\$__ble_tmp
  done
  $__ble_dst=(\"\${__ble_arr[@]}\")"
}

# 初回ループで $__ble_dst=() を実行する方法 (A)
function ble/array#reverse5.3 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  eval "
  local __ble_elem __ble_ind=\${#$__ble_src[@]} __ble_flag=0
  for __ble_elem in \"\${$__ble_src[@]}\"; do
    ((__ble_flag)) || __ble_flag=1 $__ble_dst=()
    $__ble_dst[--__ble_ind]=\$__ble_elem
  done"
}

# 初回ループで $__ble_dst=() を実行する方法 (B) eval による方法
#   遅くなった。cf ble-measure "eval ''" → 10.50 us/eval で増分が説明できる。
function ble/array#reverse5.4 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  eval "
  local __ble_elem __ble_ind=\${#$__ble_src[@]} __ble_init='$__ble_dst=() __ble_init='
  for __ble_elem in \"\${$__ble_src[@]}\"; do
    eval \"\$__ble_init\"
    $__ble_dst[--__ble_ind]=\$__ble_elem
  done"
}

if [[ $measure_reverse_flags == *5* ]]; then
  # 計測方法                              # reverse5.1     reverse5.2     reverse5.3     reverse5.4
  # ------------------------------------- # -------------  -------------  -------------  -------------
  ble-measure 'ble/array#reverse5.1 A S'  #  238970.00 us   241970.10 us   252970.00 us   348970.10 us
  ble-measure 'ble/array#reverse5.1 A S1' #     370.00 us      442.10 us      453.00 us      562.10 us
  ble-measure 'ble/array#reverse5.1 A S2' #    2350.00 us     2440.10 us     2660.00 us     3640.10 us
  ble-measure 'ble/array#reverse5.1 A S3' #   23370.00 us    23770.10 us    25570.00 us    34970.10 us
  ble-measure 'ble/array#reverse5.1 A S4' #  239970.00 us   243970.10 us   251970.00 us   348970.10 us
  ble-measure 'ble/array#reverse5.1 A S5' # 2518970.00 us  2561970.10 us  2723970.00 us  3506970.10 us
fi

#------------------------------------------------------------------------------
# 2018-07-15 BASH_ARGV を用いた実装。
#
# * 元々のコードは https://github.com/dylanaraps/pure-bash-bible#reverse-an-array より。
#   しかし、其処に載っているコードは壊れている。
#
#   reverse_array() {
#     shopt -s extdebug
#     f()(printf '%s\n' "${BASH_ARGV[@]}"); f "$@"
#     shopt -u extdebug
#   }
#
#   $ reverse_array A B C
#   C
#   B
#   A
#   array-reverse.sh <-- Broken
#
#   BASH_ARGV には呼び出し元で設定されていた引数が末尾に続くようである。
#
# * BASH_ARGV の性質について。
#   試してみた所 shift や set -- をしても BASH_ARGV は更新されない様である。
#   従って、関数呼び出しは何れにしても必要である。
#
# * 元のコードを修正して実装する。
#   実際に計測してみると O(N^2) である。

function ble/array#reverse6/.helper {
  eval "$__ble_dst=(\"\${BASH_ARGV[@]::$__ble_len}\")"
}
function ble/array#reverse6 {
  local __ble_dst=$1 __ble_src=${2:-$1}
  [[ ! -o extdebug ]]; local __ble_extdebug=$?
  ((__ble_extdebug)) || shopt -s extdebug
  eval "local __ble_len=\${#$__ble_src[@]}"
  eval "ble/array#reverse6/.helper \"\${$__ble_src[@]}\""
  ((__ble_extdebug)) || shopt -u extdebug
  return 0
}

if [[ $measure_reverse_flags == *6* ]]; then
  ble-measure 'ble/array#reverse6 A S'  # 1026969.70 usec/eval (copy0 = 55369.70us)
  ble-measure 'ble/array#reverse6 A S1' #       416.60 usec/eval
  ble-measure 'ble/array#reverse6 A S2' #      1450.60 usec/eval
  ble-measure 'ble/array#reverse6 A S3' #     23070.60 usec/eval
  ble-measure 'ble/array#reverse6 A S4' #   1015970.60 usec/eval
  # ble-measure 'ble/array#reverse6 A S5' # 208812970.60 usec/eval
fi

#------------------------------------------------------------------------------
# 2018-07-15 別の方針: 初めから引数に指定してもらう方法

function ble/array#reverse7.1 {
  local __ble_dst=$1; shift
  eval "$__ble_dst=(); while ((\$#)); do $__ble_dst[\$#-1]=\$1; shift; done"
}

function ble/array#reverse7.2 {
  local __ble_dst=$1; shift
  eval "local __ble_i=\$# __ble_e; $__ble_dst=(); for __ble_e; do $__ble_dst[--__ble_i]=\$__ble_e; done"
}

function ble/array#reverse7.2b {
  eval "shift; local i$1=\$# e$1; $1=(); for e$1; do $1[--i$1]=\$e$1; done"
}


if [[ $measure_reverse_flags == *7* ]]; then
  # 計測方法                                      # reverse7.1     reverse7.2     reverse7.2b
  # --------------------------------------------- # -------------  -------------  -------------
  ble-measure 'ble/array#reverse7.2 A "${S[@]}"'  # 1511970.00 us   229969.50 us   221969.50 us
  ble-measure 'ble/array#reverse7.2 A "${S1[@]}"' #     396.00 us      331.50 us      296.50 us
  ble-measure 'ble/array#reverse7.2 A "${S2[@]}"' #    3170.00 us     2279.50 us     2169.50 us
  ble-measure 'ble/array#reverse7.2 A "${S3[@]}"' #   45170.00 us    22369.50 us    21569.50 us
  ble-measure 'ble/array#reverse7.2 A "${S4[@]}"' # 1512970.00 us   231969.50 us   224969.50 us
  ble-measure 'ble/array#reverse7.2 A "${S5[@]}"' # -------.-- us  2467969.50 us  2377969.50 us
fi

if [[ $measure_reverse_flags == *C* ]]; then
  echo -n 'reverse0   : '; A=(); ble/array#reverse0    A S1; declare -p A
  echo -n 'reverse1   : '; A=(); ble/array#reverse1    A S1; declare -p A
  echo -n 'reverse2   : '; A=(); ble/array#reverse2    A S1; declare -p A
  echo -n 'reverse3   : '; A=(); ble/array#reverse3    A S1; declare -p A
  echo -n 'reverse4.1a: '; A=(); ble/array#reverse4.1a A S1; declare -p A
  echo -n 'reverse5.1 : '; A=(); ble/array#reverse5.1  A S1; declare -p A
  echo -n 'reverse6   : '; A=(); ble/array#reverse6    A S1; declare -p A
  echo -n 'reverse7.2b: '; A=(); ble/array#reverse7.2b A "${S1[@]}"; declare -p A
fi
