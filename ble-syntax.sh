#!/bin/bash
#%[debug=1]
#%if debug(
function .ble-assert {
  echo "${BASH_SOURCE[1]} (${FUNCNAME[1]}): assertion failure $*" >&2
}
#%)
#%m main (
_ble_syntax_array_prototype=()
function _ble_syntax_array_prototype.reserve {
  local n="$1"
  for ((i=${#_ble_syntax_array_prototype[@]};i<n;i++)); do
    _ble_syntax_array_prototype[i]=
  done
}

## @var _ble_syntax_stat[i]
##   文字 #i を解釈しようとする直前の状態を記録する。
##   各要素は "ctx wbegin inest" の形式をしている。
##   ctx は現在の文脈。
##   wbegin は現在の解析位置が属するシェル単語の開始位置。
##   inest は現在の入れ子状態の親の開始位置。
## @var _ble_syntax_nest[inest]
##   入れ子の情報
##   各要素は "ctx wbegin inest type" の形式をしている。
##   ctx wbegin inest は入れ子を抜けた時の状態を表す。
##   type は入れ子の種類を表す文字列。
## @var _ble_syntax_word[i]
##   文字 #i から単語が始まる際にその長さを記録する
## @var _ble_syntax_attr[i]
##   文脈・属性の情報
_ble_syntax_stat=()
_ble_syntax_nest=()
_ble_syntax_word=()
_ble_syntax_attr=()

# 文脈値達
CTX_UNSPECIFIED=0
CTX_ARGX=3   # context,attr: expecting an argument
CTX_ARGX0=18 # context: 文脈的には引数が来そうだがもう引数が来てはならない
CTX_CMDX=1   # context,attr: 次にコマンドが来る
CTX_CMDXF=16 # context: 直後が (( だったら CTX_CMDI に、他の時は CTX_CMDI に。(for の直後)
CTX_CMDX1=17 # context: コマンドが少なくとも一つ来なければならない。例えば ( や && や while の直後。
CTX_CMDXV=13 # not used
CTX_CMDI=2   # context,attr: in a command
CTX_ARGI=4 # context,attr: in an argument
CTX_VRHS=11 # context,attr: var=rhs
CTX_QUOT=5 # context,attr: in double quotations
CTX_EXPR=8 # context,attr: in expression
ATTR_ERR=6 # attr: error
ATTR_VAR=7 # attr: variable
ATTR_QDEL=9 # attr: delimiters for quotation
ATTR_DEF=10 # attr: default (currently not used)
ATTR_DEL=12 # attr: delimiters
CTX_PARAM=14 # context,attr: inside of parameter expansion
CTX_PWORD=15 # context,attr: inside of parameter expansion

_BLE_SYNTAX_CSPACE=$' \t\n'
_BLE_SYNTAX_CSPECIAL=()
_BLE_SYNTAX_CSPECIAL[CTX_ARGI]="$_BLE_SYNTAX_CSPACE;|&()<>\$\"\`\\'"
_BLE_SYNTAX_CSPECIAL[CTX_QUOT]="\$\"\`\\"   # 文字列 "～" で特別な意味を持つのは $ ` \ " のみ
_BLE_SYNTAX_CSPECIAL[CTX_EXPR]="][}()\$\"\`\\'" # ()[] は入れ子を数える為。} は ${var:ofs:len} の為。
_BLE_SYNTAX_CSPECIAL[CTX_PWORD]="}\$\"\`\\" # パラメータ展開 ${～}

## 関数 ble-syntax/parse/nest-push newctx type
## @param[in]     newctx 新しい ctx を指定します。
## @param[in,opt] type   文法要素の種類を指定します。
## @var  [in]     i      現在の位置を指定します。
## @var  [in,out] ctx    復帰時の ctx を指定します。新しい ctx (newctx) を返します。
## @var  [in,out] wbegin 復帰時の wbegin を指定します。新しい wbegin (-1) を返します。
## @var  [in,out] inest  復帰時の inest を指定します。新しい inest (i) を返します。
function ble-syntax/parse/nest-push {
  _ble_syntax_nest[i]="$ctx $wbegin $inest ${2:-none}"
  ((ctx=$1,inest=i,wbegin=-1))
  #echo "push inest=$inest @${FUNCNAME[*]:1}"
}
function ble-syntax/parse/nest-pop {
  ((inest<0)) && return 1
  local parent=(${_ble_syntax_nest[inest]})
  ((ctx=parent[0],wbegin=parent[1],inest=parent[2]))
  #echo pop inest=$inest
}
function ble-syntax/parse/nest-type {
  local _var=type
  [[ $1 == -v ]] && _var="$2"
  if ((inest<0)); then
    eval $_var=
    return 1
  else
    eval $_var'="${_ble_syntax_nest[inest]##* }"'
  fi
}
## 関数 ble-syntax/parse/nest-equals
##   現在のネスト状態と前回のネスト状態が一致するか判定します。
## @var i1                     更新開始点
## @var i2                     更新終了点
## @var tail_syntax_stat[i-i2] i2 以降の更新前状態
## @var _ble_syntax_stat[i]    新しい状態
function ble-syntax/parse/nest-equals {
  local parent_inest="$1"
  while :; do
    ((parent_inest<i1)) && return 0 # 変更していない範囲 または -1
    ((parent_inest<i2)) && return 1 # 変更によって消えた範囲

    local _onest="${tail_syntax_nest[parent_inest-i2]}"
    local _nnest="${_ble_syntax_nest[parent_inest]}"
    [[ $_onest != $_nnest ]] && return 1

    local onest=($_onest)
#%if debug (
    ((onest[2]<parent_inest)) || .ble-assert 'invalid nest' && return 0
#%)
    parent_inest="${onest[2]}"
  done
}


function ble-syntax/parse/check-dollar {
  if [[ $tail =~ ^\$\{ ]]; then
    # ■中で許される物: 決まったパターン + 数式や文字列に途中で切り替わる事も
    if [[ $tail =~ ^(\$\{[#!]?)(['-*@#?$!0']|[1-9][0-9]*|[a-zA-Z_][a-zA-Z_0-9]*)(['[']?) ]]; then
      # <parameter> = [-*@#?-$!0] | [1-9][0-9]* | <varname> | <varname> [ ... ] | <varname> [ <@> ]
      # <@> = * | @
      # ${<parameter>} ${#<parameter>} ${!<parameter>}
      # ${<parameter>:-<word>} ${<parameter>:=<word>} ${<parameter>:+<word>} ${<parameter>:?<word>}
      # ${<parameter>-<word>} ${<parameter>=<word>} ${<parameter>+<word>} ${<parameter>?<word>}
      # ${<parameter>:expr} ${<parameter>:expr:expr} etc
      # ${!head<@>} ${!varname[<@>]}
      ble-syntax/parse/nest-push "$CTX_PARAM" '${'
      ((_ble_syntax_attr[i]=ctx,
        i+=${#BASH_REMATCH[1]},
        _ble_syntax_attr[i]=ATTR_VAR,
        i+=${#BASH_REMATCH[2]}))
      if ((${#BASH_REMATCH[3]})); then
        ble-syntax/parse/nest-push "$CTX_EXPR" 'v['
        ((_ble_syntax_attr[i]=CTX_EXPR,
          i+=${#BASH_REMATCH[3]}))
      fi
      return 0
    else
      ((_ble_syntax_attr[i]=ATTR_ERR,i+=2))
      return 0
    fi
  elif [[ $tail =~ ^\$\(\( ]]; then
    ((_ble_syntax_attr[i]=ctx))
    ble-syntax/parse/nest-push "$CTX_EXPR" '(('
    ((i+=${#BASH_REMATCH[0]}))
    return 0
  elif [[ $tail =~ ^\$\( ]]; then
    ((_ble_syntax_attr[i]=ctx))
    ble-syntax/parse/nest-push "$CTX_CMDX" '('
    ((i+=${#BASH_REMATCH[0]}))
    return 0
  elif [[ $tail =~ ^\$(['-*@#?$!0_']|[1-9][0-9]*|[a-zA-Z_][a-zA-Z_0-9]*) ]]; then
    ((_ble_syntax_attr[i]=ctx,
      _ble_syntax_attr[i+1]=ATTR_VAR,
      i+=${#BASH_REMATCH[0]}))
    return 0
  fi

  return 1
}

function ble-syntax/parse/check-quotes {
  if [[ $tail =~ ^(\$?\")([^"${_BLE_SYNTAX_CSPECIAL[CTX_QUOT]}"]|\\.)*(\"?) ]]; then
    if ((${#BASH_REMATCH[3]})); then
      # 終端まで行った場合
      ((_ble_syntax_attr[i]=ATTR_QDEL,
        _ble_syntax_attr[i+${#BASH_REMATCH[1]}]=CTX_QUOT,
        i+=${#BASH_REMATCH[0]},
        _ble_syntax_attr[i-1]=ATTR_QDEL))
    else
      # 中に構造がある場合
      ble-syntax/parse/nest-push "$CTX_QUOT"
      ((_ble_syntax_attr[i]=ATTR_QDEL,
        _ble_syntax_attr[i+1]=CTX_QUOT,
        i+=${#BASH_REMATCH[0]}))
    fi
    return 0
  elif [[ $tail =~ ^\`([^\`\\]|\\.)*(\`?)|^\'[^\']*(\'?) ]]; then
    ((_ble_syntax_attr[i]=ATTR_QDEL,
      _ble_syntax_attr[i+1]=CTX_QUOT,
      i+=${#BASH_REMATCH[0]},
      _ble_syntax_attr[i-1]=${#BASH_REMATCH[2]}||${#BASH_REMATCH[3]}?ATTR_QDEL:ATTR_ERR))
    return 0
  elif ((ctx!=CTX_QUOT)) && [[ $tail =~ ^\$\'([^\'\\]|\\.)*(\'?) ]]; then
    ((_ble_syntax_attr[i]=ATTR_QDEL,
      _ble_syntax_attr[i+2]=CTX_QUOT,
      i+=${#BASH_REMATCH[0]},
      _ble_syntax_attr[i-1]=${#BASH_REMATCH[2]}?ATTR_QDEL:ATTR_ERR))
    return 0
  fi
  
  return 1
}

_BLE_SYNTAX_FCTX=()

_BLE_SYNTAX_FCTX[CTX_QUOT]=ble-syntax/parse/ctx-quot
function ble-syntax/parse/ctx-quot {
  # 文字列の中身

  if [[ $tail =~ ^([^"${_BLE_SYNTAX_CSPECIAL[ctx]}"]|\\.)+ ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH[0]}))
    return 0
  elif [[ $tail =~ ^\" ]]; then
    ((_ble_syntax_attr[i]=ATTR_QDEL,
      i+=${#BASH_REMATCH[0]}))
    ble-syntax/parse/nest-pop
    return 0
  elif ble-syntax/parse/check-quotes; then
    return 0
  elif ble-syntax/parse/check-dollar; then
    return 0
  fi

  return 1
}

_BLE_SYNTAX_FCTX[CTX_PARAM]=ble-syntax/parse/ctx-param
_BLE_SYNTAX_FCTX[CTX_PWORD]=ble-syntax/parse/ctx-pword
function ble-syntax/parse/ctx-param {
  # パラメータ展開 - パラメータの直後

  if [[ $tail =~ ^:[^'-?=+'] ]]; then
    ((_ble_syntax_attr[i]=CTX_EXPR,
      ctx=CTX_EXPR,i++))
    return 0
  elif [[ $tail =~ ^\} ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest],
     i+=${#BASH_REMATCH[0]}))
    ble-syntax/parse/nest-pop
    return 0
  else
    ((ctx=CTX_PWORD))
    ble-syntax/parse/ctx-pword
    return
  fi
}
function ble-syntax/parse/ctx-pword {
  # パラメータ展開 - word 部

  if [[ $tail =~ ^([^"${_BLE_SYNTAX_CSPECIAL[ctx]}"]|\\.)+ ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH[0]}))
    return 0
  elif [[ $tail =~ ^\} ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest],
     i+=${#BASH_REMATCH[0]}))
    ble-syntax/parse/nest-pop
    return 0
  elif ble-syntax/parse/check-quotes; then
    return 0
  elif ble-syntax/parse/check-dollar; then
    return 0
  fi

  return 1
}

_BLE_SYNTAX_FCTX[CTX_EXPR]=ble-syntax/parse/ctx-expr
function ble-syntax/parse/ctx-expr {
  # 式の中身

  if [[ $tail =~ ^([^"${_BLE_SYNTAX_CSPECIAL[ctx]}"]|\\.)+ ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH[0]}))
    return 0
  elif [[ $tail =~ ^['][()}'] ]]; then
    if [[ ${BASH_REMATCH[0]} == ')' ]]; then
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == '((' ]]; then
        if [[ ${tail::2} == '))' ]]; then
          ((_ble_syntax_attr[i]=_ble_syntax_attr[inest],
            i+=2))
          ble-syntax/parse/nest-pop
        else
          ble-syntax/parse/nest-pop
          ((_ble_syntax_attr[i]=ATTR_ERR,
            i+=1))
        fi
        return 0
      elif [[ $type == '(' ]]; then
        ble-syntax/parse/nest-pop
        ((_ble_syntax_attr[i]=ctx,i+=1))
        return 0
      else
        return 1
      fi
    elif [[ ${BASH_REMATCH[0]} == ']' ]]; then
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == '[' ]]; then
        ble-syntax/parse/nest-pop
        ((_ble_syntax_attr[i]=ctx,
          i++))
        return 0
      elif [[ $type == 'a[' ]]; then
        if [[ ${tail::2} == ']=' ]]; then
          # a[...]= の場合。配列代入
          ble-syntax/parse/nest-pop
          ((_ble_syntax_attr[i]=CTX_EXPR,
            i+=2))
        else
          # a[...]... という唯のコマンドの場合。
          if ((wbegin>=0)); then
            # 式としての解釈を取り消し。
            local j
            for ((j=wbegin+1;j<i;j++)); do
              _ble_syntax_stat[j]=
              _ble_syntax_word[j]=
              _ble_syntax_attr[j]=
            done

            ble-syntax/parse/updated-touch "$wbegin"
          fi

          # コマンド
          ((_ble_syntax_attr[wbegin]=CTX_CMDI,i++))
        fi
        return 0
      elif [[ $type == 'v[' ]]; then
        # ${v[]...} などの場合。
        ble-syntax/parse/nest-pop
        ((_ble_syntax_attr[i]=CTX_EXPR,
          i+=1))
        return 0
      else
        return 1
      fi
    elif [[ ${BASH_REMATCH[0]} == '}' ]]; then
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == '${' ]]; then
        ((_ble_syntax_attr[i]=_ble_syntax_attr[inest],i++))
        ble-syntax/parse/nest-pop
        return 0
      else
        return 1
      fi
    else
      ble-syntax/parse/nest-push "$CTX_EXPR" "${BASH_REMATCH[0]}"
      ((_ble_syntax_attr[i]=ctx,
        i+=${#BASH_REMATCH[0]}))
      return 0
    fi
  elif ble-syntax/parse/check-quotes; then
    return 0
  elif ble-syntax/parse/check-dollar; then
    return 0
  fi

  return 1
}

## 関数 ble-syntax/parse/ctx-command/check-word-end
## @var[in,out] ctx
## @var[in,out] wbegin
## @var[in,out] 他
function ble-syntax/parse/ctx-command/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  [[ ${text:i} =~ ^[^"$_BLE_SYNTAX_CSPACE;|&<>()"] ]] && return 1

  local wlen="$((i-wbegin))" wend="$i"
  local word="${text:wbegin:wlen}"
  if ((ctx==CTX_CMDI)); then
    case "$word" in
    ('[[')
      # 条件コマンド開始 (■CTX_COND (~ ARGX/ARGI) 的な物を作った方が良い。中での改行など色々違う)
      ble-syntax/parse/updated-touch "$wbegin"
      ((_ble_syntax_attr[wbegin]=ATTR_DEL,
        ctx=CTX_ARGX0))
      i="$wbegin" ble-syntax/parse/nest-push "$CTX_ARGX" '[[' ;;
    (['!{']|'time'|'do'|'if'|'then'|'else'|'while'|'until')
      ((ctx=CTX_CMDX1)) ;;
    ('for')
      ((ctx=CTX_CMDXF)) ;;
    (*)
      ((ctx=CTX_ARGX)) ;;
    esac
  elif ((ctx==CTX_ARGI)); then
    case "$word" in
    (']]')
      # 条件コマンド終了
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == '[[' ]]; then
        ble-syntax/parse/updated-touch "$wbegin"
        ((_ble_syntax_attr[wbegin]=_ble_syntax_attr[inest]))
        ble-syntax/parse/nest-pop
      else
        ((ctx=CTX_ARGX0))
      fi ;;
    (*)
      ((ctx=CTX_ARGX)) ;;
    esac
  elif ((ctx==CTX_VRHS)); then
    ((ctx=CTX_CMDXV))
  fi

  if [[ ${_ble_syntax_word[wbegin]} ]]; then
    local word=(${_ble_syntax_word[wbegin]})
    ((word[1]=wlen))
    _ble_syntax_word[wbegin]="${word[*]}"
  else
    # 本来ここには来ないはず
    _ble_syntax_word[wbegin]="0 $wlen"
  fi

  ((wbegin=-1))
  return 0
}

_BLE_SYNTAX_FCTX[CTX_ARGX]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGX0]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDX]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDX1]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXF]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXV]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGI]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDI]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[CTX_VRHS]=ble-syntax/parse/ctx-command
function ble-syntax/parse/ctx-command {
  # コマンド・引数部分
  if [[ $tail =~ ^["$_BLE_SYNTAX_CSPACE;|&<>()"] ]]; then
#%if debug (
    ((ctx==CTX_ARGX||ctx==CTX_ARGX0||
         ctx==CTX_CMDX||ctx==CTX_CMDXF||
         ctx==CTX_CMDX1||ctx==CTX_CMDXV)) || .ble-assert "invalid ctx=$ctx @ i=$i"
#%)
    
    if [[ $tail =~ ^["$_BLE_SYNTAX_CSPACE"]+ ]]; then
      # 空白 (ctx はそのままで素通り)
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH[0]}))
      ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_CMDXV)) && [[ ${#BASH_REMATCH[0]} =~ $'\n' ]] && ((ctx=CTX_CMDX))
      return 0
    elif [[ $tail =~ ^(\&\&|\|['|&']?)|^\;\;\&?|^[\;\&] ]]; then
      # 制御演算子 && || | & ; |& ;; ;;&
      ((_ble_syntax_attr[i]=ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_CMDXV?ATTR_DEL:ATTR_ERR,
        ctx=${#BASH_REMATCH[1]}?CTX_CMDX1:CTX_CMDX,
        i+=${#BASH_REMATCH[0]}))
      #■;; ;;& の次に来るのは CTX_CMDX ではなくて CTX_CASE? 的な物では?
      #■;; ;;& の場合には CTX_ARGX CTX_CMDXV に加え CTX_CMDX でも ERR ではない。
      return 0
    elif [[ $tail =~ ^[\(][\(]? ]]; then
      # サブシェル (, 算術コマンド ((
      local m="${BASH_REMATCH[0]}"
      ((_ble_syntax_attr[i]=(ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXF&&${#m}==2)?ATTR_DEL:ATTR_ERR))
      ((ctx=CTX_ARGX0))
      ble-syntax/parse/nest-push "$((${#m}==1?CTX_CMDX1:CTX_EXPR))" "$m"
      ((i+=${#m}))
      return 0
    elif [[ $tail =~ ^\) ]]; then
      ble-syntax/parse/nest-type -v type
      if [[ $type == '(' ]]; then
        ((_ble_syntax_attr[i]=(ctx==CTX_CMDX||ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_CMDXV)?_ble_syntax_attr[inest]:ATTR_ERR,
          i+=${#BASH_REMATCH[0]}))
        ble-syntax/parse/nest-pop
        return 0
      fi
    elif [[ $tail =~ ^['<>']'(' ]]; then
      # プロセス置換
      ((_ble_syntax_attr[i]=ATTR_DEL))
      ble-syntax/parse/nest-push "$CTX_CMDX" '('
      ((i+=${#BASH_REMATCH[0]}))
      return 0
    elif [[ $tail =~ ^(&?>>?|<>?|[<>]\&) ]]; then
      # リダイレクト
      ((_ble_syntax_attr[i]=ATTR_DEL,i+=${#BASH_REMATCH[0]}))
      return 0

      #■リダイレクト&プロセス置換では直前の ctx を覚えて置いて後で復元する。
    else
      return 1
    fi
  fi

  # ■"#" の場合にはコメント

  local flagWbeginErr=0
  if ((wbegin<0)); then
    # case CTX_ARGX | CTX_ARGX0 | CTX_CMDXF
    #   ctx=CTX_ARGI
    # case CTX_CMDX | CTX_CMDX1 | CTX_CMDXV
    #   ctx=CTX_CMDI
    # case CTX_ARGI | CTX_CMDI | CTX_VRHS
    #   エラー...
    ((flagWbeginErr=ctx==CTX_ARGX0,
      wbegin=i,
      ctx=(ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_CMDXF)?CTX_ARGI:CTX_CMDI))
    _ble_syntax_word[i]="$ctx 0"
  fi

#%if debug (
  ((ctx==CTX_CMDI||ctx==CTX_ARGI||ctx==CTX_VRHS)) || .ble-assert 2
#%)

  local flagConsume=0
  if ((wbegin==i&&ctx==CTX_CMDI)) && [[ $tail =~ ^[a-zA-Z_][a-zA-Z_0-9]*(['=[']|'+=') ]]; then
    _ble_syntax_word[i]="$ATTR_VAR 0"
    ((_ble_syntax_attr[i]=ATTR_VAR,
      i+=${#BASH_REMATCH[0]},
      _ble_syntax_attr[i-${#BASH_REMATCH[1]}]=CTX_EXPR,
      ctx=CTX_VRHS))
    if [[ ${BASH_REMATCH[1]} == '[' ]]; then
      i=$((i-1)) ble-syntax/parse/nest-push "$CTX_EXPR" 'a['
    fi
    flagConsume=1
  elif [[ $tail =~ ^([^"${_BLE_SYNTAX_CSPECIAL[CTX_ARGI]}"]|\\.)+ ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH[0]}))
    flagConsume=1
  elif ble-syntax/parse/check-quotes; then
    flagConsume=1
  elif ble-syntax/parse/check-dollar; then
    flagConsume=1
  fi

  if ((flagConsume)); then
    ((flagWbeginErr&&(_ble_syntax_attr[wbegin]=ATTR_ERR)))
    return 0
  else
    return 1
  fi
}

_ble_syntax_ubeg=-1 _ble_syntax_uend=-1
function ble-syntax/parse/updated-touch {
  (((_ble_syntax_ubeg<0||_ble_syntax_ubeg>$1)&&(
      _ble_syntax_ubeg=$1)))
}

_ble_syntax_dbeg=-1 _ble_syntax_dend=-1

## @fn ble-syntax/parse text beg end
##
## @param[in]     text
##   解析対象の文字列を指定する。
##
## @param[in]     beg                text変更範囲 開始点 (既定値 = text先頭)
## @param[in]     end                text変更範囲 終了点 (既定値 = text末端)
## @param[in]     end0               長さが変わった時用 (既定値 = end)
##   これらの引数はtextに変更があった場合にその範囲を伝達するのに用いる。
##
## @var  [in,out] _ble_syntax_dbeg   解析予定範囲 開始点 (初期値 -1 = 解析予定無し)
## @var  [in,out] _ble_syntax_dend   解析予定範囲 終了点 (初期値 -1 = 解析予定無し)
##   これらの変数はどの部分を解析する必要があるかを記録している。
##   beg end beg2 end2 を用いてtextの変更範囲を指定しても、
##   その変更範囲に対する解析を即座に完了させる訳ではなく逐次更新していく。
##   ここには前回の parse 呼出でやり残した解析範囲の情報が格納される。
##
## @var  [in,out] _ble_syntax_stat[] (内部使用) 解析途中状態を記録
## @var  [in,out] _ble_syntax_nest[] (内部使用) 入れ子の構造を記録
## @var  [in,out] _ble_syntax_attr[] 各文字の属性
## @var  [in,out] _ble_syntax_word[] シェル単語の情報を記録
##   これらの変数には解析結果が格納される。
##
## @var  [out]    _ble_syntax_ubeg
## @var  [out]    _ble_syntax_uend
##   今回の呼出によって文法的な解釈の変更が行われた範囲を返します。
##
function ble-syntax/parse {
  _ble_syntax_ubeg=-1 _ble_syntax_uend=-1
  local -r text="$1" beg="${2:-0}" end="${3:-${#text}}"
  local end0="${4:-$end}"
  ((end==beg&&end0==beg&&_ble_syntax_dbeg<0)) && return

  # 解析予定範囲の更新
  local iN shift i1 i2 flagSeekStat=0
  ((iN=${#text},shift=end-end0,
    i1=_ble_syntax_dbeg,i1>=end0&&(i1+=shift),
    i2=_ble_syntax_dend,i2>=end0&&(i2+=shift),
    (i1<0||beg<i1)&&(i1=beg,flagSeekStat=1),
    (i2<0||i2<end)&&(i2=end),
    (i2>iN)&&(i2=iN)))
  if ((flagSeekStat)); then
    # beg より前の最後の stat の位置まで戻る
    while ((i1>0)) && ! [[ ${_ble_syntax_stat[--i1]} ]]; do :;done
  fi
#%if debug (
  ((0<=beg&&beg<=end&&end<=iN&&beg<=end0)) || .ble-assert "X1 0 <= $beg <= $end <= $iN, $beg <= $end0"
  ((0<=i1&&i1<=beg&&end<=i2&&i2<=iN)) || .ble-assert "X2 0 <= $i1 <= $beg <= $end <= $i2 <= $iN"
#%)

  # shift (shift は毎回やり切る。途中状態で抜けたりはしない)
  local i j j2 iwbegin iinest
  for ((i=i2,j=j2=i2-shift;i<iN;i++,j++)); do
    if [[ ${_ble_syntax_stat[j]} ]]; then
      # (1) shift の修正
      # (2) [i1,i2) 内を参照している場合 dirty を拡大
      local stat=(${_ble_syntax_stat[j]})
      ((stat[1]>=end0&&(stat[1]+=shift),
        stat[2]>=end0&&(stat[2]+=shift)))
      _ble_syntax_stat[j]="${stat[*]}"

      local nest=(${_ble_syntax_nest[j]})
      ((nest[1]>=end0&&(nest[1]+=shift),
        nest[2]>=end0&&(nest[2]+=shift)))
      _ble_syntax_nest[j]="${nest[*]}"

      (((i1<=stat[1]&&stat[1]<=i2||i1<=stat[2]&&stat[2]<=i2)&&(i2=i+1,j2=j+1)))
    fi
  done
  if ((end!=end0)); then
    # 単語の長さの更新
    for ((i=0;i<beg;i++)); do
      if [[ ${_ble_syntax_word[i]} ]]; then
        local word=(${_ble_syntax_word[i]})
        if ((end0<i+word[1])); then
          ((word[1]+=end-end0))
          _ble_syntax_word[i]="${word[*]}"
          #echo "word [$((word[1]-end+end0)) -> ${word[1]}]" >&2
        fi
      fi
    done
  fi

  # 解析途中状態の復元
  local _stat="${_ble_syntax_stat[i1]}"
  local ctx wbegin inest
  if [[ $_stat ]]; then
    local stat=($_stat)
    ctx="${stat[0]}"
    wbegin="${stat[1]}"
    inest="${stat[2]}"
  else
    # 初期値
    ctx="$CTX_CMDX"     ##!< 現在の解析の文脈
    wbegin=-1           ##!< シェル単語内にいる時、シェル単語の開始位置
    inest=-1            ##!< 入れ子の時、親の開始位置
  fi

  # 前回までに解析が終わっている部分 [0,i1), [i2,iN)
  local _tail_syntax_stat=("${_ble_syntax_stat[@]:j2:iN-i2}")
  local _tail_syntax_word=("${_ble_syntax_word[@]:j2:iN-i2}")
  local _tail_syntax_nest=("${_ble_syntax_nest[@]:j2:iN-i2}")
  local _tail_syntax_attr=("${_ble_syntax_attr[@]:j2:iN-i2}")
  _ble_syntax_array_prototype.reserve $iN
  _ble_syntax_stat=("${_ble_syntax_stat[@]::i1}" "${_ble_syntax_array_prototype[@]:i1:iN-i1}") # 再開用データ
  _ble_syntax_word=("${_ble_syntax_word[@]::i1}" "${_ble_syntax_array_prototype[@]:i1:iN-i1}") # 単語
  _ble_syntax_nest=("${_ble_syntax_nest[@]::i1}" "${_ble_syntax_array_prototype[@]:i1:iN-i1}") # 入れ子の親
  _ble_syntax_attr=("${_ble_syntax_attr[@]::i1}" "${_ble_syntax_array_prototype[@]:i1:iN-i1}") # 文脈・色とか

  # 解析
  for ((i=i1;i<iN;)); do
    #local _stat="$ctx $((wbegin>=0?i-wbegin:-1)) $((inest>=0?i-inest:-1))"
    local _stat="$ctx $wbegin $inest"
    if ((i>=i2)) && [[ ${_tail_syntax_stat[i-i2]} == $_stat ]]; then
      if ble-syntax/parse/nest-equals "$inest"; then

        # 前回の解析と同じ状態になった時 → 残りは前回の結果と同じ
        _ble_syntax_stat=("${_ble_syntax_stat[@]::i}" "${_tail_syntax_stat[@]:i-i2}")
        _ble_syntax_word=("${_ble_syntax_word[@]::i}" "${_tail_syntax_word[@]:i-i2}")
        _ble_syntax_nest=("${_ble_syntax_nest[@]::i}" "${_tail_syntax_nest[@]:i-i2}")
        _ble_syntax_attr=("${_ble_syntax_attr[@]::i}" "${_tail_syntax_attr[@]:i-i2}")

        #■中断に纏わるバグ:
        #  ネスト内部で中断した時のシェル単語の更新に問題有り。というかシェル単語の長さが更新されない。
        break
      fi
    fi
    _ble_syntax_stat[i]="$_stat"
    local tail="${text:i}"

    # 処理
    "${_BLE_SYNTAX_FCTX[ctx]}" || ((_ble_syntax_attr[i]=ATTR_ERR,i++))

    # nest-pop で CMDI/ARGI になる事もあるし、
    # また単語終端な文字でも FCTX が失敗する事もある (unrecognized な場合) ので、
    # ここでチェック
    ((ctx==CTX_CMDI||ctx==CTX_ARGI||ctx==CTX_VRHS)) &&
      ble-syntax/parse/ctx-command/check-word-end
  done

#%if debug (
  ((${#_ble_syntax_stat[@]}==iN)) ||
    .ble-assert "unexpected array length #arr=${#_ble_syntax_stat[@]} (expected to be $iN), #proto=${#_ble_syntax_array_prototype[@]} should be >= $iN"
#%)

  (((_ble_syntax_ubeg<0||_ble_syntax_ubeg>i1)&&(_ble_syntax_ubeg=i1),
    (_ble_syntax_uend<0||_ble_syntax_uend<i)&&(_ble_syntax_uend=i),
    (i>=i2)?(
      _ble_syntax_dbeg=_ble_syntax_dend=-1
    ):(
      _ble_syntax_dbeg=i,_ble_syntax_dend=i2)))

  # 終端の状態の記録
  if ((i>=iN)); then
    _ble_syntax_stat[iN]="$ctx $wbegin $inest"

    # ネスト開始点のエラー表示は +syntax 内で。
    # ここで設定すると部分更新の際に取り消しできないから。
    if ((inest>0)); then
      _ble_syntax_attr[iN-1]=ATTR_ERR
      while ((inest>=0)); do
        ((i=inest))
        ble-syntax/parse/nest-pop
        ((inest>=i&&(inest=i-1)))
      done
    fi
  fi
}

#%(
.ble-shopt-extglob-push() { shopt -s extglob;}
.ble-shopt-extglob-pop()  { shopt -u extglob;}
source ble-color.sh
#%)

_ble_syntax_attr2g=()
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_ARGX]  none
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_ARGX0] none
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_CMDX]  none
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_CMDXF] none
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_CMDX1] none
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_CMDXV] none
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_ARGI] none
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_CMDI] fg=9
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_VRHS] none
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_QUOT] fg=2
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_EXPR] fg=4
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_ERR] bg=203,fg=231 # bg=224
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_VAR] fg=202
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_QDEL] fg=2,bold
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_DEF] none
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_DEL] bold
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_PARAM] fg=12
ble-color-gspec2g -v _ble_syntax_attr2g[CTX_PWORD] none

#------------------------------------------------
# filetype

ATTR_CMD_BOLD=101
ATTR_CMD_BUILTIN=102
ATTR_CMD_ALIAS=103
ATTR_CMD_FUNCTION=104
ATTR_CMD_FILE=105
ATTR_CMD_KEYWORD=106
ATTR_CMD_JOBS=107
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_CMD_BOLD]     fg=red,bold
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_CMD_BUILTIN]  fg=red
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_CMD_ALIAS]    fg=teal
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_CMD_FUNCTION] fg=navy
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_CMD_FILE]     fg=green
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_CMD_KEYWORD]  fg=blue
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_CMD_JOBS]     fg=red

ATTR_FILE_DIR=108
ATTR_FILE_LINK=109
ATTR_FILE_EXEC=110
ATTR_FILE_FILE=111
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_FILE_DIR]  fg=navy,underline
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_FILE_LINK] fg=teal,underline
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_FILE_EXEC] fg=green,underline
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_FILE_FILE] underline

function ble-syntax/highlight/cmdtype1 {
  type="$1"
  local cmd="$2"
  case "$type:$cmd" in
  (builtin::|builtin:.)
    # 見にくいので太字にする
    ((type=ATTR_CMD_BOLD)) ;;
  (builtin:*)
    ((type=ATTR_CMD_BUILTIN)) ;;
  (alias:*)
    ((type=ATTR_CMD_ALIAS)) ;;
  (function:*)
    ((type=ATTR_CMD_FUNCTION)) ;;
  (file:*)
    ((type=ATTR_CMD_FILE)) ;;
  (keyword:*)
    ((type=ATTR_CMD_KEYWORD)) ;;
  (*:%*)
    # jobs
    if jobs "$cmd" &>/dev/null; then
      ((type=ATTR_CMD_JOBS))
    else
      ((type=ATTR_ERR))
    fi ;;
  (*)
    ((type=ATTR_ERR)) ;;
  esac
}

function ble-syntax/highlight/cmdtype2 {
  local cmd="$1" _0="$2"
  ble-syntax/highlight/cmdtype1 "$(builtin type -t "$cmd" 2>/dev/null)" "$cmd"
  if [[ $type == $ATTR_CMD_ALIAS && "$cmd" != "$_0" ]]; then
    # alias を \ で無効化している場合
    # → unalias して再度 check (2fork)
    type=$(
      unalias "$cmd"
      ble-syntax/highlight/cmdtype1 "$(builtin type -t "$cmd" 2>/dev/null)" "$cmd"
      echo -n "$type")
  elif [[ $type = $ATTR_CMD_KEYWORD && "$cmd" != "$_0" ]]; then
    # keyword (time do if function else elif fi の類) を \ で無効化している場合
    # →file, function, builtin, jobs のどれかになる。以下 3fork+2exec
    if test -z "${cmd##%*}" && jobs "$cmd" &>/dev/null; then
      # %() { :; } として 関数を定義できるが jobs の方が優先される。
      # (% という名の関数を呼び出す方法はない?)
      # でも % で始まる物が keyword になる事はそもそも無いような。
      ((type=ATTR_CMD_JOBS))
    elif declare -f "$cmd" &>/dev/null; then
      ((type=ATTR_CMD_FUNCTION))
    elif enable -p | fgrep -xq "enable $cmd" &>/dev/null; then
      ((type=ATTR_CMD_BUILTIN))
    elif which "$cmd" &>/dev/null; then
      ((type=ATTR_CMD_FILE))
    else
      ((type=ATTR_ERR))
    fi
  fi
}

if ((_ble_bash>=40000)); then
  declare -A _ble_syntax_highlight_filetype=()
  _ble_syntax_highlight_filetype_version=-1
  ## @var type[out]
  function ble-syntax/highlight/cmdtype {
    local cmd="$1" _0="$2"

    # check cache
    if [[ $_ble_syntax_highlight_filetype_version != $_ble_edit_LINENO ]]; then
      _ble_syntax_highlight_filetype=()
      _ble_syntax_highlight_filetype_version="$_ble_edit_LINENO"
    fi

    type="${_ble_syntax_highlight_filetype[x$_0]}"
    [[ $type ]] && return

    ble-syntax/highlight/cmdtype2 "$cmd" "$_0"
    _ble_syntax_highlight_filetype["x$_0"]="$type"
  }
else
  declare -a _ble_syntax_highlight_filetype=()
  _ble_syntax_highlight_filetype_version=-1
  function ble-syntax/highlight/cmdtype {
    local cmd="$1" _0="$2"

    # check cache
    if [[ $_ble_syntax_highlight_filetype_version != $_ble_edit_LINENO ]]; then
      _ble_syntax_highlight_filetype=()
      _ble_syntax_highlight_filetype_version="$_ble_edit_LINENO"
    fi

    local i iN
    for ((i=0,iN=${#_ble_syntax_highlight_filetype[@]}/2;i<iN;i++)); do
      if [[ ${_ble_syntax_highlight_filetype[2*i]} == x$_0 ]]; then
        type="${_ble_syntax_highlight_filetype[2*i+1]}"
        return
      fi
    done

    ble-syntax/highlight/cmdtype2 "$cmd" "$_0"
    _ble_syntax_highlight_filetype[2*iN]="x$_0"
    _ble_syntax_highlight_filetype[2*iN+1]="$type"
  }
fi

function ble-syntax/highlight/filetype {
  local file="$1" _0="$2"
  [[ ! -e "$file" && "$file" =~ ^\~ ]] && file="$HOME${file:1}"
  if test -d "$file"; then
    ((type=ATTR_FILE_DIR))
  elif test -h "$file"; then
    ((type=ATTR_FILE_LINK))
  elif test -x "$file"; then
    ((type=ATTR_FILE_EXEC))
  elif test -f "$file"; then
    ((type=ATTR_FILE_FILE))
  else
    type=
  fi
}

#------------------------------------------------
# highlighter

function ble-syntax/highlight/fill-g {
  local g="$1" i
  for ((i=$2;i<$3;i++)); do
    _ble_region_highlight_table[i]="$g"
  done
}

function ble-syntax-highlight+syntax {
  if ((BLELINE_RANGE_UPDATE[0]>=0)); then
    ble-syntax/parse "$text" "${BLELINE_RANGE_UPDATE[0]}" "${BLELINE_RANGE_UPDATE[1]}" "${BLELINE_RANGE_UPDATE[2]}"
  fi

  # [[ $dirty ]] && ble-syntax/parse "$text" "$((dirty<0?0:dirty))"
  #[[ $dirty ]] && ble-syntax/parse "$text"
  local i iN=${#text} g=0
  for ((i=0;i<iN;i++)); do
    if ((${_ble_syntax_attr[i]})); then
      g="${_ble_syntax_attr2g[_ble_syntax_attr[i]]:-0}"
    fi
    _ble_region_highlight_table[i]="$g"
  done

  # 末端の非終端エラー
  if [[ ${_ble_syntax_stat[iN]} ]]; then
    local stat=(${_ble_syntax_stat[iN]})
    local i ctx="${stat[0]}" wbegin="${stat[1]}" inest="${stat[2]}"
    local gErr="${_ble_syntax_attr2g[ATTR_ERR]}"
    if((inest>=0)); then
      _ble_region_highlight_table[iN-1]="$gErr"
      while ((inest>=0)); do
        _ble_region_highlight_table[inest]="$gErr"
        ((i=inest))
        ble-syntax/parse/nest-pop
        ((inest>=i&&(inest=i-1)))
      done
    fi
    if ((ctx==CTX_CMDX1||ctx==CTX_CMDXF)); then
      _ble_region_highlight_table[iN-1]="$gErr"
    fi
  fi

  for ((i=0;i<iN;i++)); do
    if [[ ${_ble_syntax_word[i]} ]]; then
      local wrec=(${_ble_syntax_word[i]})
      local word="${text:i:wrec[1]}"
      if [[ $word =~ ^([^"${_BLE_SYNTAX_CSPECIAL[CTX_ARGI]}"]|\\.|\'([^\'])*\')+$ ]]; then
        local value type=
        eval "value=$word"
        if ((wrec[0]==CTX_CMDI)); then
          ble-syntax/highlight/cmdtype "$value" "$word"
        elif ((wrec[0]==CTX_ARGI)); then
          ble-syntax/highlight/filetype "$value" "$word"
        fi
        if [[ $type ]]; then
          g="${_ble_syntax_attr2g[type]}"
          ble-syntax/highlight/fill-g "$g" "$i" "$((i+wrec[1]))"
        fi
      fi
    fi
  done

  ble-syntax-highlight+region "$@"

  # # 以下は単語の分割のデバグ用
  # local words=()
  # for ((i=0;i<iN;i++)); do
  #   if [[ ${_ble_syntax_word[i]} ]]; then
  #     local wrec=(${_ble_syntax_word[i]})
  #     local word="${text:i:wrec[1]}"
  #     if [[ $word =~ ^([^"${_BLE_SYNTAX_CSPECIAL[CTX_ARGI]}"]|\\.|\'([^\'])*\')+$ ]]; then
  #       eval "value=$word"
  #     else
  #       local value="? ($word)"
  #     fi
  #     words+=("[$value ${wrec[*]}]")
  #   fi
  # done
  # .ble-line-info.draw "${words[*]}"

  # 以下は check code for BLELINE_RANGE_UPDATE
  # if ((BLELINE_RANGE_UPDATE[0]>=0)); then
  #   local g
  #   ble-color-gspec2g -v g standout
  #   ble-syntax/highlight/fill-g "$g" "${BLELINE_RANGE_UPDATE[0]}" "${BLELINE_RANGE_UPDATE[1]}"
  #   .ble-line-info.draw "range_update=${BLELINE_RANGE_UPDATE[*]} g=$g"
  # fi
}

#%#----------------------------------------------------------------------------
#%# test codes
#%#----------------------------------------------------------------------------
#%(

attrc=()
attrc[CTX_CMDX]=' '
attrc[CTX_ARGX]=' '
attrc[CTX_CMDI]='c'
attrc[CTX_ARGI]='a'
attrc[CTX_QUOT]=$'\e[48;5;255mq\e[m'
attrc[CTX_EXPR]='x'
attrc[ATTR_ERR]=$'\e[101;97me\e[m'
attrc[ATTR_VAR]=$'\e[35mv\e[m'
attrc[ATTR_QDEL]=$'\e[1;48;5;255;94m\"\e[m' # '
attrc[ATTR_DEF]='_'
attrc[CTX_VRHS]='r'
attrc[ATTR_DEL]=$'\e[1m|\e[m'

attrg[CTX_ARGX]=$'\e[m'
attrg[CTX_ARGX0]=$'\e[m'
attrg[CTX_CMDX]=$'\e[m'
attrg[CTX_CMDXF]=$'\e[m'
attrg[CTX_CMDX1]=$'\e[m'
attrg[CTX_CMDXV]=$'\e[m'
attrg[CTX_ARGI]=$'\e[m'
attrg[CTX_CMDI]=$'\e[;91m'
attrg[CTX_VRHS]=$'\e[m'
attrg[CTX_QUOT]=$'\e[;32m'
attrg[CTX_EXPR]=$'\e[;34m'
attrg[ATTR_ERR]=$'\e[;101;97m'
attrg[ATTR_VAR]=$'\e[;38;5;202m'
attrg[ATTR_QDEL]=$'\e[;1;32m'
attrg[ATTR_DEF]=$'\e[m'
attrg[ATTR_DEL]=$'\e[;1m'
attrg[CTX_PARAM]=$'\e[;94m'
attrg[CTX_PWORD]=$'\e[m'

function mytest/put {
  buff[${#buff[@]}]="$*"
}
function mytest/fflush {
  IFS= eval 'echo -n "${buff[*]}"'
  buff=()
}
function mytest {
  local text="$1"
  ble-syntax/parse "$text"

  # # update test
  # ble-syntax/parse "$text" 15 16

  # # insertion test
  # text="${text::5}""hello; echo""${text:5}"
  # ble-syntax/parse "$text" 5 16 5
  # echo update $_ble_syntax_ubeg-$_ble_syntax_uend

  # # delete test
  # text="${text::5}""${text:10}"
  # ble-syntax/parse "$text" 5 5 10
  # echo update $_ble_syntax_ubeg-$_ble_syntax_uend

  local buff=()

  # echo "$text"
  local ctxg=$'\e[m'
  for ((i=0;i<${#text};i++)); do
    if ((${_ble_syntax_attr[i]})); then
      ctxg="${attrg[_ble_syntax_attr[i]]:-[101;97m}"
    fi
    mytest/put "$ctxg${text:i:1}"
  done
  mytest/put $'\e[m\n'

  for ((i=0;i<${#text};i++)); do
    if ((${_ble_syntax_stat[i]%% *})); then
      mytest/put '>'
    else
      mytest/put ' '
    fi
  done
  mytest/put $'\n'
  mytest/fflush

  # local ctxc=' '
  # for ((i=0;i<${#text};i++)); do
  #   if ((${_ble_syntax_attr[i]})); then
  #     ctxc="${attrc[_ble_syntax_attr[i]]:-'?'}"
  #   fi
  #   mytest/put "$ctxc"
  # done
  # mytest/put $'\n'
}
# mytest 'echo hello world'
# mytest 'echo "hello world"'
# mytest 'echo a"hed"a "aa"b b"aa" aa'

mytest 'echo a"$"a a"\$\",$*,$var,$12"a $*,$var,$12'
mytest 'echo a"---$((1+a[12]*3))---$(echo hello)---"a'
mytest 'a=1 b[x[y]]=1234 echo <( world ) > hello; ( sub shell); ((1+2*3));'
mytest 'a=${#hello} b=${world[10]:1:(5+2)*3} c=${arr[*]%%"test"$(cmd).cpp} d+=12'
mytest 'for ((i=0;i<10;i++)); do echo hello; done; { : '"'worlds'\\'' record'"'; }'

# 関数名に使える文字?
#
# 全く使えない文字 |&;<>()!$\'"`
#
# name() の形式だと
#   { } をコマンドとして定義できない。function の形式なら可能
#
# set -H だと
#   ! を履歴展開の構文で含む関数は定義できない。
#   set +H にしておけば定義する事ができる。
#   name() の形式では ^ で始まる関数は定義できない。
#
# extglob on だと
#   ? * @ + ! は name() の形式で定義できない。
#   一応 name () と間に空白を挟めば定義できる。
#   function ?() *() などとすると "?()" という名前で関数が作られる。
# 

#%)
#%#----------------------------------------------------------------------------
#%)
#%m main main.r/\<ATTR_/BLE_ATTR_/
#%m main main.r/\<CTX_/BLE_CTX_/
#%x main
