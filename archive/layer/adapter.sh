#!/bin/bash

##
## レイヤー ble/highlight/layer:adapter
##
##   古い枠組みに依る色つけのアダプターを
##   レイヤーの実装のサンプルとして此処に残す。
##   使う場合は例えば以下の様にする。
##
##   _ble_highlight_layer__list=(plain adapter)
##
##

bleopt/declare -v syntax_highlight_mode default

_ble_region_highlight_table=()

## 古い実装からの adapter
_ble_highlight_layer_adapter_buff=()
_ble_highlight_layer_adapter_table=()
function ble/highlight/layer:adapter/update {
  local text=$1 player=$2

  # update g table
  local LAYER_UMIN LAYER_UMAX
  local -a _ble_region_highlight_table
  ble/highlight/layer/update/shift _ble_region_highlight_table _ble_highlight_layer_adapter_table
  if [[ $bleopt_syntax_highlight_mode ]]; then
    # LAYER_UMIN を設定しない highlight_mode の場合はそのまま。
    # LAYER_UMIN を設定する highlight_mode の場合は参照せずに上書きされる。
    LAYER_UMIN=0 LAYER_UMAX=$iN
    "ble/syntax-highlight+$bleopt_syntax_highlight_mode" "$text"
  else
    LAYER_UMIN=$iN LAYER_UMAX=0
  fi
  _ble_highlight_layer_adapter_table=("${_ble_region_highlight_table[@]}")

  # 描画文字を更新する範囲 [i1,i2]
  #   text[i2] (更新範囲の次の文字) の SGR に影響を与えない為、
  #   実際の更新は text[i2] に対しても行う。
  ((PREV_UMIN>=0&&LAYER_UMIN>PREV_UMIN&&(LAYER_UMIN=PREV_UMIN),
    PREV_UMAX>=0&&LAYER_UMAX<PREV_UMAX&&(LAYER_UMAX=PREV_UMAX)))
  local i1=$LAYER_UMIN i2=$LAYER_UMAX
  ((i2>=iN&&(i2=iN-1)))

  # update char buffer
  ble/highlight/layer/update/shift _ble_highlight_layer_adapter_buff
  local i g gprev=0 ctx=0 ret
  ((i1>0)) && { ble/highlight/layer/getg "$((i1-1))"; gprev=$g; }
  # ble/edit/info/show text "layer:adapter u = $i1-$i2"
  for ((i=i1;i<=i2;i++)); do
    local ch
    if [[ ${_ble_region_highlight_table[i]} ]]; then
      ch=${_ble_highlight_layer_plain_buff[i]}
      ((g=_ble_region_highlight_table[i]))
      if ((ctx!=0||g!=gprev)); then
        ((ctx=0,gprev=g))
        ble/color/g2sgr "$g"
        ch=$ret$ch
      fi
    else
      builtin eval "ch=\${$PREV_BUFF[i]}"
      if ((ctx!=1)); then
        ((ctx=1,gprev=-1))
        ble/highlight/layer/update/getg
        ble/color/g2sgr "$g"
        ch=$ret$ch
      fi
    fi

    _ble_highlight_layer_adapter_buff[i]=$ch
  done

  PREV_BUFF=_ble_highlight_layer_adapter_buff
  if ((LAYER_UMIN<LAYER_UMAX)); then
    ((PREV_UMIN=LAYER_UMIN,PREV_UMAX=LAYER_UMAX))
  else
    ((PREV_UMIN=-1,PREV_UMAX=-1))
  fi
}
function ble/highlight/layer:adapter/getg {
  # 描画属性がない時は _ble_region_highlight_table[i]
  # には空文字列が入っているのでOK
  g=${_ble_highlight_layer_adapter_table[$1]}
}


#------------------------------------------------------------------------------

## @fn _ble_region_highlight_table;  ble/syntax-highlight/append triplets ; _ble_region_highlight_table
function ble/syntax-highlight/append {
  while (($#)); do
    local -a triplet
    triplet=($1)
    local ret; ble/color/gspec2g "${triplet[2]}"; local g=$ret
    local i=${triplet[0]} iN=${triplet[1]}
    for ((;i<iN;i++)); do
      _ble_region_highlight_table[$i]=$g
    done
    shift
  done
}

function ble/syntax-highlight+region {
  if [[ $_ble_edit_mark_active ]]; then
    if ((_ble_edit_mark>_ble_edit_ind)); then
      ble/syntax-highlight/append "$_ble_edit_ind $_ble_edit_mark bg=60,fg=white"
    elif ((_ble_edit_mark<_ble_edit_ind)); then
      ble/syntax-highlight/append "$_ble_edit_mark $_ble_edit_ind bg=60,fg=white"
    fi
  fi
}

function ble/syntax-highlight+test {
  local text=$1
  local i iN=${#text} w
  local mode=cmd
  for ((i=0;i<iN;)); do
    local tail=${text:i} rex
    if [[ $mode == cmd ]]; then
      if rex='^[_a-zA-Z][_a-zA-Z0-9]*=' && [[ $tail =~ $rex ]]; then
        # 変数への代入
        local var=${tail%%=*}
        ble/syntax-highlight/append "$i $((i+${#var})) fg=orange"
        ((i+=${#var}+1))
  
        mode=rhs
      elif rex='^[_a-zA-Z][_a-zA-Z0-9]*\[[^]]+\]=' && [[ $tail =~ $rex ]]; then
        # 配列変数への代入
        local var="${tail%%\[*}"
        ble/syntax-highlight/append "$i $((i+${#var})) fg=orange"
        ((i+=${#var}+1))
  
        local tmp="${tail%%\]=*}"
        local ind="${tmp#*\[}"
        ble/syntax-highlight/append "$i $((i+${#ind})) fg=green"
        ((i+=${#var}+1))
  
        mode=rhs
      elif rex='^[^ 	"'\'']+([ 	]|$)' && [[ $tail =~ $rex ]]; then
        local cmd="${tail%%[	 ]*}" cmd_type
        ble/util/type cmd_type "$cmd"
        case $cmd_type:$cmd in
        builtin:*)
          ble/syntax-highlight/append "$i $((i+${#cmd})) fg=red" ;;
        alias:*)
          ble/syntax-highlight/append "$i $((i+${#cmd})) fg=teal" ;;
        function:*)
          ble/syntax-highlight/append "$i $((i+${#cmd})) fg=navy" ;;
        file:*)
          ble/syntax-highlight/append "$i $((i+${#cmd})) fg=green" ;;
        keyword:*)
          ble/syntax-highlight/append "$i $((i+${#cmd})) fg=blue" ;;
        *)
          ble/syntax-highlight/append "$i $((i+${#cmd})) bg=224" ;;
        esac
        ((i+=${#cmd}))
        mode=arg
      else
        ((i++))
      fi
    else
      ((i++))
    fi
  done

  ble/syntax-highlight+region "$@"

  # ble/syntax-highlight/append "${#text1} $((${#text1}+1)) standout"
}

function ble/syntax-highlight+default/type {
  type=$1
  local cmd=$2
  case $type:$cmd in
  (builtin::|builtin:.)
    # 見にくいので太字にする
    type=builtin_bold ;;
  (builtin:*)
    type=builtin ;;
  (alias:*)
    type=alias ;;
  (function:*)
    type=function ;;
  (file:*)
    type=file ;;
  (keyword:*)
    type=keyword ;;
  (*:%*)
    # jobs
    ble/util/joblist.check
    if jobs "$cmd" &>/dev/null; then
      type=jobs
    else
      type=error
    fi ;;
  (*)
    type=error ;;
  esac
}

function ble/syntax-highlight+default {
  local rex IFS=$_ble_term_IFS
  local text=$1
  local i iN=${#text} w
  local mode=cmd
  for ((i=0;i<iN;)); do
    local tail=${text:i}
    if [[ $mode == cmd ]]; then
      if rex='^([_a-zA-Z][_a-zA-Z0-9]*)\+?=' && [[ $tail =~ $rex ]]; then
        # for bash-3.1 ${#arr[n]} bug
        local rematch1="${BASH_REMATCH[1]}"

        # local var="${BASH_REMATCH[0]::-1}"
        ble/syntax-highlight/append "$i $((i+$rematch1)) fg=orange"
        ((i+=${#BASH_REMATCH}))
        mode=rhs
        continue
      elif rex='^([^'"$IFS"'|&;()<>'\''"\]|\\.)+' && [[ $tail =~ $rex ]]; then
        # ■ time'hello' 等の場合に time だけが切り出されてしまう

        local word=${BASH_REMATCH[0]}
        builtin eval "local cmd=${word}"

        # この部分の判定で fork を沢山する \if 等に対しては 4fork+2exec になる。
        # ■キャッシュ(accept-line 時に clear)するなどした方が良いかもしれない。
        local type; ble/util/type type "$cmd"
        ble/syntax-highlight+default/type "$type" "$cmd" # -> type
        if [[ $type = alias && $cmd != "$word" ]]; then
          # alias を \ で無効化している場合
          # → unalias して再度 check (2fork)
          type=$(
            builtin unalias "$cmd"
            ble/util/type type "$cmd"
            ble/syntax-highlight+default/type "$type" "$cmd" # -> type
            ble/util/put "$type")
        elif [[ "$type" = keyword && "$cmd" != "$word" ]]; then
          # keyword (time do if function else elif fi の類) を \ で無効化している場合
          # →file, function, builtin, jobs のどれかになる。以下 3fork+2exec
          ble/util/joblist.check
          if [[ ! ${cmd##%*} ]] && jobs "$cmd" &>/dev/null; then
            # %() { :; } として 関数を定義できるが jobs の方が優先される。
            # (% という名の関数を呼び出す方法はない?)
            # でも % で始まる物が keyword になる事はそもそも無いような。
            type=jobs
          elif ble/is-function "$cmd"; then
            type=function
          elif enable -p | ble/bin/grep -q -F -x "enable $cmd" &>/dev/null; then
            type=builtin
          elif which "$cmd" &>/dev/null; then
            type=file
          else
            type=error
          fi
        fi

        case $type in
        (file)
          ble/syntax-highlight/append "$i $((i+${#word})) fg=green" ;;
        (alias)
          ble/syntax-highlight/append "$i $((i+${#word})) fg=teal" ;;
        (function)
          ble/syntax-highlight/append "$i $((i+${#word})) fg=navy" ;;
        (builtin)
          ble/syntax-highlight/append "$i $((i+${#word})) fg=red" ;;
        (builtin_bold)
          ble/syntax-highlight/append "$i $((i+${#word})) fg=red,bold" ;;
        (keyword)
          ble/syntax-highlight/append "$i $((i+${#word})) fg=blue" ;;
        (jobs)
          ble/syntax-highlight/append "$i $((i+1)) fg=red" ;;
        (error|*)
          ble/syntax-highlight/append "$i $((i+${#word})) bg=224" ;;
        esac

        ((i+=${#BASH_REMATCH}))
        if rex='^keyword:([!{]|time|do|if|then|else|while|until)$|^builtin:eval$' && [[ $type:$cmd =~ $rex ]]; then
          mode=cmd
        else
          mode=arg
        fi

        continue
      fi
    elif [[ $mode == arg ]]; then
      if rex='^([^"$'"$IFS"'|&;()<>'\''"`\]|\\.)+' && [[ $tail =~ $rex ]]; then
        # ■ time'hello' 等の場合に time だけが切り出されてしまう
        local arg=${BASH_REMATCH[0]}

        local file=$arg
        [[ ( $file == '~' || $file = '~/'* ) && ! ( -e $file || -h $file ) ]] && file=$HOME${file:1}
        if [[ -d $file ]]; then
          ble/syntax-highlight/append "$i $((i+${#arg})) fg=navy,underline"
        elif [[ -h $file ]]; then
          ble/syntax-highlight/append "$i $((i+${#arg})) fg=teal,underline"
        elif [[ -x $file ]]; then
          ble/syntax-highlight/append "$i $((i+${#arg})) fg=green,underline"
        elif [[ -f $file ]]; then
          ble/syntax-highlight/append "$i $((i+${#arg})) underline"
        fi

        ((i+=${#arg}))
        continue
      fi
    fi

    # /^'([^'])*'|^\$'([^\']|\\.)*'|^`([^\`]|\\.)*`|^\\./
    if rex='^'\''([^'\''])*'\''|^\$'\''([^\'\'']|\\.)*'\''|^`([^\`]|\\.)*`|^\\.' && [[ $tail =~ $rex ]]; then
      ble/syntax-highlight/append "$i $((i+${#BASH_REMATCH})) fg=green"
      ((i+=${#BASH_REMATCH}))
      mode=arg_
      continue
    elif rex='^['"$IFS"']+' && [[ $tail =~ $rex ]]; then
      ((i+=${#BASH_REMATCH}))
      local spaces=${BASH_REMATCH[0]}
      if [[ $spaces =~ $'\n' ]]; then
        mode=cmd
      else
        [[ $mode = arg_ ]] && mode=arg
      fi
      continue
    elif rex='^;;?|^;;&$|^&&?|^\|\|?' && [[ $tail =~ $rex ]]; then
      if [[ $mode = cmd ]]; then
        ble/syntax-highlight/append "$i $((i+${#BASH_REMATCH})) bg=224"
      fi
      ((i+=${#BASH_REMATCH}))
      mode=cmd
      continue
    elif rex='^(&?>>?|<>?|[<>]&)' && [[ $tail =~ $rex ]]; then
      ble/syntax-highlight/append "$i $((i+${#BASH_REMATCH})) bold"
      ((i+=${#BASH_REMATCH}))
      mode=arg
      continue
    elif rex='^(' && [[ $tail =~ $rex ]]; then
      ((i+=${#BASH_REMATCH}))
      mode=cmd
      continue
    fi
    # 他 "...", ${}, $... arg と共通

    ((i++))
    # a[]=... の引数は、${} や "" を考慮に入れるだけでなく [] の数を数える。
  done

  ble/syntax-highlight+region "$@"
}
