#!/bin/bash

#%m main (

_ble_syntax_array_prototype=()
function _ble_syntax_array_prototype.reserve {
  local n=$i
  for ((i=${#_ble_syntax_array[@]};i<n;i++)); do
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
BLE_CTX_UNSPECIFIED=0
BLE_CTX_CMDX=1 # context,attr: expecting a command
BLE_CTX_CMDI=2 # context,attr: in a command
BLE_CTX_ARGX=3 # context,attr: expecting an argument
BLE_CTX_ARGI=4 # context,attr: in an argument
BLE_CTX_QUOT=5 # context,attr: in double quotations
BLE_CTX_EXPR=8 # context,attr: in expression
ATTR_ERR=6 # attr: error
ATTR_VAR=7 # attr: variable
ATTR_QDEL=9 # attr: delimiters for quotation
ATTR_DEF=10 # attr: default (currently not used)
BLE_CTX_VRHS=11 # context,attr: var=rhs
ATTR_DEL=12 # attr: delimiters
BLE_CTX_CMDN=13 # not used
BLE_CTX_PARAM=14 # context,attr: inside of parameter expansion
BLE_CTX_PWORD=15 # context,attr: inside of parameter expansion

attrc=()
attrc[BLE_CTX_CMDX]=' '
attrc[BLE_CTX_CMDI]='c'
attrc[BLE_CTX_ARGX]=' '
attrc[BLE_CTX_ARGI]='a'
attrc[BLE_CTX_QUOT]=$'\e[48;5;255mq\e[m'
attrc[BLE_CTX_EXPR]='x'
attrc[ATTR_ERR]=$'\e[101;97me\e[m'
attrc[ATTR_VAR]=$'\e[35mv\e[m'
attrc[ATTR_QDEL]=$'\e[1;48;5;255;94m\"\e[m' # '
attrc[ATTR_DEF]='_'
attrc[BLE_CTX_VRHS]='r'
attrc[ATTR_DEL]=$'\e[1m|\e[m'

attrg[BLE_CTX_CMDX]=$'\e[m'
attrg[BLE_CTX_CMDI]=$'\e[;91m'
attrg[BLE_CTX_ARGX]=$'\e[m'
attrg[BLE_CTX_ARGI]=$'\e[m'
attrg[BLE_CTX_QUOT]=$'\e[;32m'
attrg[BLE_CTX_EXPR]=$'\e[;34m'
attrg[ATTR_ERR]=$'\e[;101;97m'
attrg[ATTR_VAR]=$'\e[;38;5;202m'
attrg[ATTR_QDEL]=$'\e[;1;32m'
attrg[ATTR_DEF]=$'\e[m'
attrg[BLE_CTX_VRHS]=$'\e[m'
attrg[ATTR_DEL]=$'\e[;1m'
attrg[BLE_CTX_PARAM]=$'\e[;94m'
attrg[BLE_CTX_PWORD]=$'\e[m'

_BLE_SYNTAX_CSPACE=$' \t\n'
_BLE_SYNTAX_CSPECIAL=()
_BLE_SYNTAX_CSPECIAL[BLE_CTX_CMDI]="$_BLE_SYNTAX_CSPACE;|&()<>\$\"\`\\'"
_BLE_SYNTAX_CSPECIAL[BLE_CTX_ARGI]="${_BLE_SYNTAX_CSPECIAL[BLE_CTX_CMDI]}"
_BLE_SYNTAX_CSPECIAL[BLE_CTX_VRHS]="${_BLE_SYNTAX_CSPECIAL[BLE_CTX_CMDI]}"
_BLE_SYNTAX_CSPECIAL[BLE_CTX_QUOT]="\$\"\`\\"   # 文字列 "～" で特別な意味を持つのは $ ` \ " のみ
_BLE_SYNTAX_CSPECIAL[BLE_CTX_EXPR]="][}()\$\"\`\\'" # ()[] は入れ子を数える為。} は ${var:ofs:len} の為。
_BLE_SYNTAX_CSPECIAL[BLE_CTX_PWORD]="}\$\"\`\\" # パラメータ展開 ${～}

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
      ble-syntax/parse/nest-push "$BLE_CTX_PARAM" '${'
      ((_ble_syntax_attr[i]=ctx,
        i+=${#BASH_REMATCH[1]},
        _ble_syntax_attr[i]=ATTR_VAR,
        i+=${#BASH_REMATCH[2]}))
      if ((${#BASH_REMATCH[3]})); then
        ble-syntax/parse/nest-push "$BLE_CTX_EXPR" 'v['
        ((_ble_syntax_attr[i]=BLE_CTX_EXPR,
          i+=${#BASH_REMATCH[3]}))
      fi
      return 0
    else
      ((_ble_syntax_attr[i]=ATTR_ERR,i+=2))
      return 0
    fi
  elif [[ $tail =~ ^\$\(\( ]]; then
    ((_ble_syntax_attr[i]=ctx))
    ble-syntax/parse/nest-push "$BLE_CTX_EXPR" '(('
    ((i+=${#BASH_REMATCH[0]}))
    return 0
  elif [[ $tail =~ ^\$\( ]]; then
    ((_ble_syntax_attr[i]=ctx))
    ble-syntax/parse/nest-push "$BLE_CTX_CMDX" '('
    ((i+=${#BASH_REMATCH[0]}))
    return 0
  elif [[ $tail =~ ^\$(['-*@#?$!0'_]|[1-9][0-9]*|[a-zA-Z_][a-zA-Z_0-9]*) ]]; then
    ((_ble_syntax_attr[i]=ctx,
      _ble_syntax_attr[i+1]=ATTR_VAR,
      i+=${#BASH_REMATCH[0]}))
    return 0
  fi

  return 1
}

function ble-syntax/parse/check-quotes {
  if [[ $tail =~ ^\"([^"${_BLE_SYNTAX_CSPECIAL[BLE_CTX_QUOT]}"]|\\.)*(\"?) ]]; then
    if ((${#BASH_REMATCH[2]})); then
      # 終端まで行った場合
      ((_ble_syntax_attr[i]=ATTR_QDEL,
        _ble_syntax_attr[i+1]=BLE_CTX_QUOT,
        i+=${#BASH_REMATCH[0]},
        _ble_syntax_attr[i-1]=ATTR_QDEL))
    else
      # 中に構造がある場合
      ble-syntax/parse/nest-push "$BLE_CTX_QUOT"
      ((_ble_syntax_attr[i]=ATTR_QDEL,
        _ble_syntax_attr[i+1]=BLE_CTX_QUOT,
        i+=${#BASH_REMATCH[0]}))
    fi
    return 0
  elif [[ $tail =~ ^\`([^\`\\]|\\.)*(\`?)|^\'[^\']*(\'?) ]]; then
    ((_ble_syntax_attr[i]=ATTR_QDEL,
      _ble_syntax_attr[i+1]=BLE_CTX_QUOT,
      i+=${#BASH_REMATCH[0]},
      _ble_syntax_attr[i-1]=${#BASH_REMATCH[2]}||${#BASH_REMATCH[3]}?ATTR_QDEL:ATTR_ERR))
    return 0
  elif ((ctx!=BLE_CTX_QUOT)) && [[ $tail =~ ^\$\'([^\'\\]|\\.)*(\'?) ]]; then
    ((_ble_syntax_attr[i]=ATTR_QDEL,
      _ble_syntax_attr[i+2]=BLE_CTX_QUOT,
      i+=${#BASH_REMATCH[0]},
      _ble_syntax_attr[i-1]=${#BASH_REMATCH[2]}?ATTR_QDEL:ATTR_ERR))
    return 0
  fi
  
  return 1
}

_BLE_SYNTAX_FCTX=()

_BLE_SYNTAX_FCTX[BLE_CTX_QUOT]=ble-syntax/parse/ctx-quot
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

_BLE_SYNTAX_FCTX[BLE_CTX_PARAM]=ble-syntax/parse/ctx-param
_BLE_SYNTAX_FCTX[BLE_CTX_PWORD]=ble-syntax/parse/ctx-pword
function ble-syntax/parse/ctx-param {
  # パラメータ展開 - パラメータの直後

  if [[ $tail =~ ^:[^'-?=+'] ]]; then
    ((_ble_syntax_attr[i]=BLE_CTX_EXPR,
      ctx=BLE_CTX_EXPR,i++))
    return 0
  elif [[ $tail =~ ^\} ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest],
     i+=${#BASH_REMATCH[0]}))
    ble-syntax/parse/nest-pop
    return 0
  else
    ((ctx=BLE_CTX_PWORD))
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

_BLE_SYNTAX_FCTX[BLE_CTX_EXPR]=ble-syntax/parse/ctx-expr
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
          ((_ble_syntax_attr[i]=BLE_CTX_EXPR,
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

            # コマンド
            ((_ble_syntax_attr[wbegin]=BLE_CTX_CMDI,
              i++))

            ble-syntax/parse/updated-touch "$wbegin"
          fi
        fi
        return 0
      elif [[ $type == 'v[' ]]; then
        # ${v[]...} などの場合。
        ble-syntax/parse/nest-pop
        ((_ble_syntax_attr[i]=BLE_CTX_EXPR,
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
      ble-syntax/parse/nest-push "$BLE_CTX_EXPR" "${BASH_REMATCH[0]}"
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


## @var[in,out] ctx
##   out: BLE_CTX_CMDX | BLE_CTX_ARGX # BLE_CTX_CMDN? | BLE_CTX_COND?
function ble-syntax/parse/word-end {
  ((wbegin<0)) && return 1

  local word="${text:wbegin:i-wbegin}"

  if ((ctx==BLE_CTX_CMDI)); then
    case "$word" in
    ('[[')
      # 条件コマンド開始 (■BLE_CTX_COND (~ ARGX/ARGI) 的な物を作った方が良い。中での改行など色々違う)
      ble-syntax/parse/updated-touch "$wbegin"
      ((_ble_syntax_attr[wbegin]=ATTR_DEL))
      i="$wbegin" ctx="$BLE_CTX_ARGX" ble-syntax/parse/nest-push "$BLE_CTX_ARGX" '[[' ;;
    (['!{']|'time'|'do'|'if'|'then'|'else'|'while'|'until')
      ((ctx=BLE_CTX_CMDX)) ;;
    ('for')
      # for の場合は for(()) or for ... in ... の何れか:
      #   '((' があれば BLE_CTX_CMDX という事にすれば良い。
      if [[ $tail =~ ^(["$_BLE_SYNTAX_CSPACE"]*)'((' ]]; then
        ((ctx=BLE_CTX_CMDX))

        # 先読みをしているので挿入時などに不整合になる。
        # そこで即座に (( を解釈する様に空白を跳ばす。
        ((_ble_syntax_attr[i]=BLE_CTX_CMDX))
        tail="${tail:${#BASH_REMATCH[1]}}"
        ((i+=${#BASH_REMATCH[1]}))
      else
        ((ctx=BLE_CTX_ARGX))
      fi ;;
    (*)
      ((ctx=BLE_CTX_ARGX)) ;;
    esac
  elif ((ctx==BLE_CTX_ARGI)); then
    case "$word" in
    (']]')
      # 条件コマンド終了
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == '[[' ]]; then
        ble-syntax/parse/updated-touch "$wbegin"
        ((_ble_syntax_attr[wbegin]=ATTR_DEL))
        ble-syntax/parse/nest-pop
      fi ;;
    (*)
      ((ctx=BLE_CTX_ARGX)) ;;
    esac
  elif ((ctx==BLE_CTX_VRHS)); then
    # BLE_CTX_VRHS の次には必ずしもコマンドが来なくてもOK
    #■ > word を正しくスキップするには? BLE_CTX_CMDN を実装する?
    local _CNOTCMD=$';|&<>)\n'
    if [[ $tail =~ ^[' 	']*(["$_CNOTCMD"]|[0-9]+[<>]|$) ]]; then
      ((ctx=BLE_CTX_ARGX))
    else
      ((ctx=BLE_CTX_CMDX))
    fi
  fi

  _ble_syntax_word[wbegin]+=" $((i-wbegin))"
  ((wbegin=-1))
  return 1
}

_BLE_SYNTAX_FCTX[BLE_CTX_CMDX]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[BLE_CTX_CMDI]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[BLE_CTX_ARGX]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[BLE_CTX_ARGI]=ble-syntax/parse/ctx-command
_BLE_SYNTAX_FCTX[BLE_CTX_VRHS]=ble-syntax/parse/ctx-command
function ble-syntax/parse/ctx-command {
  # コマンド・引数部分
  if [[ $tail =~ ^["$_BLE_SYNTAX_CSPACE;|&<>()"]+ ]]; then
    ble-syntax/parse/word-end && return 0
    if [[ $tail =~ ^["$_BLE_SYNTAX_CSPACE"]+ ]]; then
      # 空白
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH[0]}))
      [[ ${#BASH_REMATCH[0]} =~ $'\n' ]] && ((ctx=BLE_CTX_CMDX))
      # if [[ ${#BASH_REMATCH[0]} =~ $'\n' ]]; then
      #   local type
      #   ble-syntax/parse/nest-type -v type
      #   [[ $type != '[[' ]] && ((ctx=BLE_CTX_CMDX))
      # fi
      return 0
    elif [[ $tail =~ ^\&\&?|^\|['|&']?|^\;\;\&|^\;\;? ]]; then
      # 制御演算子 && || | & ; |& ;; ;;&
      ((_ble_syntax_attr[i]=ctx==BLE_CTX_CMDX?ATTR_ERR:ATTR_DEL,
        ctx=BLE_CTX_CMDX,i+=${#BASH_REMATCH[0]}))
      return 0
    elif [[ $tail =~ ^[\(][\(]? ]]; then
      # サブシェル (, 算術コマンド ((
      local m="${BASH_REMATCH[0]}"
      ((_ble_syntax_attr[i]=ctx==BLE_CTX_CMDX?ATTR_DEL:ATTR_ERR))
      ((ctx=BLE_CTX_ARGX))
      ble-syntax/parse/nest-push "$((${#m}==1?BLE_CTX_CMDX:BLE_CTX_EXPR))" "$m"
      ((i+=${#m}))
      return 0
    elif [[ $tail =~ ^\) ]]; then
      ble-syntax/parse/nest-type -v type
      if [[ $type == '(' ]]; then
        ((_ble_syntax_attr[i]=_ble_syntax_attr[inest],
          i+=${#BASH_REMATCH[0]}))
        ble-syntax/parse/nest-pop
        return 0
      fi
    elif [[ $tail =~ ^['<>']'(' ]]; then
      # プロセス置換
      ((_ble_syntax_attr[i]=ATTR_DEL))
      ble-syntax/parse/nest-push "$BLE_CTX_CMDX" '('
      ((i+=${#BASH_REMATCH[0]}))
      return 0
    elif [[ $tail =~ ^(&?>>?|<>?|[<>]\&) ]]; then
      # リダイレクト
      ((_ble_syntax_attr[i]=ATTR_DEL,i+=${#BASH_REMATCH[0]}))
      return 0
    fi
  fi

  # ■"#" の場合にはコメント

  if ((wbegin<0)); then
    ((wbegin=i,
      ctx==BLE_CTX_CMDX?(ctx=BLE_CTX_CMDI):(
        ctx==BLE_CTX_ARGX&&(ctx=BLE_CTX_ARGI)),
      _ble_syntax_word[i]=ctx))
  fi

  if ((wbegin==i&&ctx==BLE_CTX_CMDI)) && [[ $tail =~ ^[a-zA-Z_][a-zA-Z_0-9]*(['=[']|'+=') ]]; then
    ((_ble_syntax_attr[i]=ATTR_VAR,
      i+=${#BASH_REMATCH[0]},
      _ble_syntax_attr[i-${#BASH_REMATCH[1]}]=BLE_CTX_EXPR,
      ctx=BLE_CTX_VRHS))
    if [[ ${BASH_REMATCH[1]} == '[' ]]; then
      i=$((i-1)) ble-syntax/parse/nest-push "$BLE_CTX_EXPR" 'a['
    fi
    return 0
  elif [[ $tail =~ ^([^"${_BLE_SYNTAX_CSPECIAL[ctx]}"]|\\.)+ ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH[0]}))
    return 0
  elif ble-syntax/parse/check-quotes; then
    return 0
  elif ble-syntax/parse/check-dollar; then
    return 0
  fi

  return 1
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
## @param[in]     end0               ■未実装 長さが変わった時用 (既定値 = end)
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
  local text="$1" beg="${2:-0}" end="${3:-${#text}}"
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
  ((0<=beg&&beg<=end&&end<=iN&&beg<=end0)) || return 2
  ((0<=i1&&i1<=beg&&end&&end<=i2)) || return 2
#%)

  local i j j2 iwbegin iinest
  for ((i=i2,j=j2=i2-shift;i<iinest;i++,j++)); do
    if [[ ${_ble_syntax_stat[j]} ]]; then
      # (1) shift の修正
      # (2) [i1,i2) 内を参照している場合 dirty を拡大
      local stat=(${_ble_syntax_stat[j]}) iwbegin iinest
      ((iwbegin=${stat[1]},iwbegin>=end0&&(iwbegin+=shift),
        iinest=${stat[2]},iinest>=end0&&(iinest+=shift),
        (i1<=iwbegin&&iwbegin<i2||i1<=iinest&&iinest<i2)&&(i2=i+1,j2=j+1)))
      _ble_syntax_stat[j]="${stat[0]} $iwbegin $iinest"
    fi
  done

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
    ctx="$BLE_CTX_CMDX"     ##!< 現在の解析の文脈
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
  #■履歴展開
  #■case構文の中?
  #■a=(arr) b=([x]=123 [y]=321) a+=
  for ((i=i1;i<iN;)); do
    #local _stat="$ctx $((wbegin>=0?i-wbegin:-1)) $((inest>=0?i-inest:-1))"
    local _stat="$ctx $wbegin $inest"
    if ((i>=i2)) && [[ ${_tail_syntax_stat[i-i2]} == $_stat ]]; then
      # 前回の解析と同じ状態になった時 → 残りは前回の結果と同じ
      # ■挿入・削除の時は old から読み取る時に wbegin, inest を shiftする
      _ble_syntax_stat=("${_ble_syntax_stat[@]::i}" "${_tail_syntax_stat[@]:i-i2}")
      _ble_syntax_word=("${_ble_syntax_word[@]::i}" "${_tail_syntax_word[@]:i-i2}")
      _ble_syntax_nest=("${_ble_syntax_nest[@]::i}" "${_tail_syntax_nest[@]:i-i2}")
      _ble_syntax_attr=("${_ble_syntax_attr[@]::i}" "${_tail_syntax_attr[@]:i-i2}")
      #echo "partial update $i1-$i"
      break
    fi
    _ble_syntax_stat[i]="$_stat"
    local tail="${text:i}"

    # 処理
    "${_BLE_SYNTAX_FCTX[ctx]}" && continue

    # fallback
    ((_ble_syntax_attr[i]=ATTR_ERR,i++))
  done

  (((_ble_syntax_ubeg<0||_ble_syntax_ubeg>i1)&&(_ble_syntax_ubeg=i1),
    (_ble_syntax_uend<0||_ble_syntax_uend<i)&&(_ble_syntax_uend=i),
    (i>=i2)?(
      _ble_syntax_dbeg=_ble_syntax_dend=-1
    ):(
      _ble_syntax_dbeg=i,_ble_syntax_dend=i2)))
  
  # error: unterminated nests
  if ((i>=iN)); then
    tail= ble-syntax/parse/word-end
    while ((inest>=0)); do
      _ble_syntax_attr[inest]=ATTR_ERR
      _ble_syntax_attr[iN-1]=ATTR_ERR
      ((i=inest))
      ble-syntax/parse/nest-pop
      ((inest>=i&&(inest=i-1)))
    done
  fi
}

#%(
.ble-shopt-extglob-push() { shopt -s extglob;}
.ble-shopt-extglob-pop()  { shopt -u extglob;}
source ble-color.sh
#%)

_ble_syntax_attr2g=()
ble-color-gspec2g -v _ble_syntax_attr2g[BLE_CTX_CMDX] none
ble-color-gspec2g -v _ble_syntax_attr2g[BLE_CTX_CMDI] fg=9
ble-color-gspec2g -v _ble_syntax_attr2g[BLE_CTX_ARGX] none
ble-color-gspec2g -v _ble_syntax_attr2g[BLE_CTX_ARGI] none
ble-color-gspec2g -v _ble_syntax_attr2g[BLE_CTX_QUOT] fg=2
ble-color-gspec2g -v _ble_syntax_attr2g[BLE_CTX_EXPR] fg=4
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_ERR] bg=224
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_VAR] fg=202
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_QDEL] fg=2,bold
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_DEF] none
ble-color-gspec2g -v _ble_syntax_attr2g[BLE_CTX_VRHS] none
ble-color-gspec2g -v _ble_syntax_attr2g[ATTR_DEL] bold
ble-color-gspec2g -v _ble_syntax_attr2g[BLE_CTX_PARAM] fg=12
ble-color-gspec2g -v _ble_syntax_attr2g[BLE_CTX_PWORD] none

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

function ble-syntax/highlight/fillg {
  local g="$1"
  for ((i=$2;i<$3;i++)); do
    _ble_region_highlight_table[i]="$g"
  done
}

function ble-syntax-highlight+syntax {
  [[ $dirty ]] && ble-syntax/parse "$text" "$((dirty<0?0:dirty))"
  #[[ $dirty ]] && ble-syntax/parse "$text"
  local i iN=${#text} g=0
  for ((i=0;i<iN;i++)); do
    if ((${_ble_syntax_attr[i]})); then
      g="${_ble_syntax_attr2g[_ble_syntax_attr[i]]:-0}"
    fi
    _ble_region_highlight_table[i]="$g"
  done

  for ((i=0;i<iN;i++)); do
    if [[ ${_ble_syntax_word[i]} ]]; then
      local wrec=(${_ble_syntax_word[i]})
      local word="${text:i:wrec[1]}"
      if [[ $word =~ ^([^"${_BLE_SYNTAX_CSPECIAL[BLE_CTX_ARGI]}"]|\\.|\'([^\'])*\')+$ ]]; then
        local value type=
        eval "value=$word"
        if ((wrec[0]==BLE_CTX_CMDI)); then
          ble-syntax/highlight/cmdtype "$value" "$word"
        elif ((wrec[0]==BLE_CTX_ARGI)); then
          ble-syntax/highlight/filetype "$value" "$word"
        fi
        if [[ $type ]]; then
          g="${_ble_syntax_attr2g[type]}"
          ble-syntax/highlight/fillg "$g" "$i" "$((i+wrec[1]))"
        fi
      fi
    fi
  done

  ble-syntax-highlight+region "$@"
}

#%(

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
      ctxg="${attrg[_ble_syntax_attr[i]]:-'?'}"
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

#%)

#%)
#%m main main.r/\<ATTR_/BLE_ATTR_/
#%x main
