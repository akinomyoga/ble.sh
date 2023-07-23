#!/bin/bash

function erasedupA.1 {
  local line="$1" i j
  for((i=0;i<${#hist[@]};i++)); do
    if test "${hist[$i]}" != "$line"; then
      hist[j++]="${hist[$i]}"
    fi
  done
  for((i=${#hist[@]}-1;i>=j;i--)); do
    unset "hist[$i]"
  done  
}

# + 今迄に同じ物は二つ以上ないと考えると、一つ見つければ OK
#   一つだけ削除すればよいのであれば、
#   パラメータ展開の配列の添字範囲指定で削除する項目の前後の系列を取り出せる。
# + 複数実行されたコマンドは最近実行された方が残されているので、
#   末尾から探索した方が速いはずである。
# + また、複数回実行されていなくても、同じコマンドは同じ時期に実行される傾向があるはずだから、
#   その点からも末尾から探索した方が良い。
function erasedupA.2 {
  local line="$1" i
  for((i=${#hist[@]}-1;i>=0;i--)); do
    if test "${hist[$i]}" = "$line"; then
      hist=("${hist[@]::i}" "${hist[@]:i+1}")
      break
    fi
  done
}

function erasedupA {
  local -a hist=()
  local n=0
  while read -r line; do
    echo "# = ${#hist[@]} / $((++n))" 1>&2
    erasedup2.1 "$line"
    hist+=("$line")
  done < ~/.bash_history

  for((i=0;i<${#hist[@]};i++)); do
    echo "${hist[$i]}"
  done >| bash_history.erasedupA
}

# + というか逆順に探索すれば初見の物だけ登録するだけでは?
#   配列の中で要素を移動させる必要はない。
function erasedupB {
  echo load... >&2
  declare -a hist1=()
  while read -r line; do
    hist1+=("$line")
  done < ~/.bash_history

  echo uniq... >&2
  declare -A buff=()
  declare -a hist2=()
  for ((i=${#hist1[@]}-1;i>=0;i--)); do
    local line="${hist1[$i]}"
    #echo "$line"
    test -n "${buff[x$line]}" && continue
    buff[x$line]=1
    hist2+=("$line")
  done

  echo output... >&2
  for ((i=${#hist2[@]}-1;i>=0;i--)); do
    echo "${hist2[$i]}"
  done >| bash_history.erasedup
}

erasedupB
