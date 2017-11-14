#!/bin/bash
#%begin

_ble_util_array_prototype=()
function _ble_util_array_prototype.reserve {
  local n="$1"
  for ((i=${#_ble_util_array_prototype[@]};i<n;i++)); do
    _ble_util_array_prototype[i]=
  done
}

source ble-color.sh

_ble_stackdump_title=stackdump
function ble-stackdump {
  # builtin echo "${BASH_SOURCE[1]} (${FUNCNAME[1]}): assertion failure $*" >&2
  local i nl=$'\n'
  local message="$_ble_term_sgr0$_ble_stackdump_title: $*$nl"
  for ((i=1;i<${#FUNCNAME[*]};i++)); do
    message="$message  @ ${BASH_SOURCE[i]}:${BASH_LINENO[i]} (${FUNCNAME[i]})$nl"
  done
  builtin echo -n "$message" >&2
}
function ble-assert {
  local expr="$1"
  local _ble_stackdump_title='assertion failure'
  if ! builtin eval -- "$expr"; then
    shift
    ble-stackdump "$expr$_ble_term_nl$*"
    return 1
  else
    return 0
  fi
}

#%end
#%m main (

## 関数 ble-syntax/urange#update prefix p1 p2
## 関数 ble-syntax/wrange#update prefix p1 p2
##   @param[in]   prefix
##   @param[in]   p1 p2
##   @var[in,out] {prefix}umin {prefix}umax
##
##   ble-syntax/urange#update に関しては、
##   ble/urange#update --prefix=prefix p1 p2 に等価である。
##   ble-syntax/wrange#update に対応するものはない。
##
function ble-syntax/urange#update {
  local prefix="$1"
  local -i p1="$2" p2="${3:-$2}"
  ((0<=p1&&p1<p2)) || return
  (((${prefix}umin<0||${prefix}umin>p1)&&(${prefix}umin=p1),
    (${prefix}umax<0||${prefix}umax<p2)&&(${prefix}umax=p2)))
}
function ble-syntax/wrange#update {
  local prefix="$1"
  local -i p1="$2" p2="${3:-$2}"
  ((0<=p1&&p1<=p2)) || return
  (((${prefix}umin<0||${prefix}umin>p1)&&(${prefix}umin=p1),
    (${prefix}umax<0||${prefix}umax<p2)&&(${prefix}umax=p2)))
}

## 関数 ble-syntax/urange#shift prefix
## 関数 ble-syntax/wrange#shift prefix
##   @param[in]   prefix
##   @var[in]     beg end end0 shift
##   @var[in,out] {prefix}umin {prefix}umax
##
##   ble-syntax/urange#shift に関しては、
##   ble/urange#shift --prefix=prefix "$beg" "$end" "$end0" "$shift" に等価である。
##   ble-syntax/wrange#shift に対応するものはない。
##
function ble-syntax/urange#shift {
  local prefix="$1"
  ((${prefix}umin>=end0?(${prefix}umin+=shift):(
      ${prefix}umin>=beg&&(${prefix}umin=end)),
    ${prefix}umax>end0?(${prefix}umax+=shift):(
      ${prefix}umax>beg&&(${prefix}umax=beg)),
    ${prefix}umin>=${prefix}umax&&
      (${prefix}umin=${prefix}umax=-1)))
}
function ble-syntax/wrange#shift {
  local prefix="$1"

  # ※以下の不等号について (動作を見ながら)
  # もう一度考え直した方が良いかも。
  ((${prefix}umin>=end0?(${prefix}umin+=shift):(
       ${prefix}umin>beg&&(${prefix}umin=end)),
    ${prefix}umax>=end0?(${prefix}umax+=shift):(
      ${prefix}umax>=beg&&(${prefix}umax=beg)),
    ${prefix}umin==0&&++${prefix}umin,
    ${prefix}umin>${prefix}umax&&
      (${prefix}umin=${prefix}umax=-1)))
}

_ble_syntax_VARNAMES=(_ble_syntax_{text,lang,{attr,word,vanishing_word}_u{min,max},d{beg,end}})
_ble_syntax_ARRNAMES=(_ble_syntax_{stat,nest,tree,attr})

## @var _ble_syntax_text
##   解析対象の文字列を保持する。
## @var _ble_syntax_lang
##   解析対象の言語を保持する。
##
## @var _ble_syntax_stat[i]
##   文字 #i を解釈しようとする直前の状態を記録する。
##   各要素は "ctx wlen wtype nlen tclen tplen nparam" の形式をしている。
##   @var ctx         = int; 現在の文脈。
##   @var wlen        = int; 現在のシェル単語の継続している長さ。
##   @var nlen        = int; 現在の入れ子状態が継続している長さ。
##   @var tclen,tplen = int; tchild, tprev の負オフセット。
##   @var nparam      = string
##     その入れ子レベルに特有のデータ一般を記録する文字列。
##     ヒアドキュメントの開始情報を記録するのに使用する。
##     将来的に `{ .. }` や `do .. done` の対応を取るのにも使うかもしれない。
##
## @var _ble_syntax_nest[inest]
##   入れ子の情報
##   各要素は "ctx wlen wtype inest tclen tplen nparam ntype" の形式をしている。
##   ctx wbegin inest wtype nparam は入れ子を抜けた時の状態を表す。
##   ntype は入れ子の種類を表す文字列。
##   nparam は復帰時の入れ子レベルにおける nparam 値を保持する。
##   nparam 値が空文字列の場合には代わりに none という文字列が格納される。
##
## @var _ble_syntax_tree[i-1]
##   境界 #i で終わる単語についての情報を保持する。
##   各要素は "( wtype wlen tclen tplen - )*" の形式をしている。
## @var BLE_SYNTAX_TREE_WIDTH
##   _ble_syntax_tree に格納される
## @var _ble_syntax_attr[i]
##   文脈・属性の情報
_ble_syntax_text=
_ble_syntax_lang=bash
_ble_syntax_stat=()
_ble_syntax_nest=()
_ble_syntax_tree=()
_ble_syntax_attr=()

BLE_SYNTAX_TREE_WIDTH=5

#--------------------------------------
# ble-syntax/tree-enumerate proc
# ble-syntax/tree-enumerate-children proc
# ble-syntax/tree-enumerate-in-range beg end proc

## 関数 ble-syntax/tree-enumerate/.initialize
##   @var[in]  iN
##   @var[out] tree,i,nofs
function ble-syntax/tree-enumerate/.initialize {
  if [[ ! ${_ble_syntax_stat[iN]} ]]; then
    tree= i=-1 nofs=0
    return
  fi

  local -a stat nest
  stat=(${_ble_syntax_stat[iN]})
  local wtype="${stat[2]}"
  local wlen="${stat[1]}"
  local nlen="${stat[3]}" inest
  ((inest=nlen<0?nlen:iN-nlen))
  local tclen="${stat[4]}"
  local tplen="${stat[5]}"

  tree=
  ((iN>0)) && tree="${_ble_syntax_tree[iN-1]}"

  while
    if ((wlen>=0)); then
      tree="$wtype $wlen $tclen $tplen -- ${tree[@]}"
      tclen=0
    fi
    ((inest>=0))
  do
    ble-assert '[[ ${_ble_syntax_nest[inest]} ]]' "$FUNCNAME/FATAL1" || break

    nest=(${_ble_syntax_nest[inest]})

    local olen="$((iN-inest))"
    tplen="${nest[4]}"
    ((tplen>=0&&(tplen+=olen)))

    tree="${nest[7]} $olen $tclen $tplen -- ${tree[@]}"

    wtype="${nest[2]}" wlen="${nest[1]}" nlen="${nest[3]}" tclen=0 tplen="${nest[5]}"
    ((wlen>=0&&(wlen+=olen),
      tplen>=0&&(tplen+=olen),
      nlen>=0&&(nlen+=olen),
      inest=nlen<0?nlen:iN-nlen))

    ble-assert '((nlen<0||nlen>olen))' "$FUNCNAME/FATAL2" || break
  done

  if [[ $tree ]]; then
    ((i=iN))
  else
    ((i=tclen>=0?iN-tclen:tclen))
  fi
  ((nofs=0))
}

## 関数 ble-syntax/tree-enumerate/.impl command...
##   @param[in] command...
##     各ノードについて呼び出すコマンドを指定します。
##     コマンドは以下のシェル変数を入力・出力とします。
##     @var[in]     wtype,wbegin,wlen,attr,tchild
##     @var[in,out] tprev
##       列挙を中断する時は ble-syntax/tree-enumerate-break
##       を呼び出す事によって、tprev=-1 を設定します。
##   @var[in] iN
##   @var[in] tree,i,nofs
function ble-syntax/tree-enumerate/.impl {
  local islast=1
  while ((i>0)); do
    local -a node
    if ((i<iN)); then
      node=(${_ble_syntax_tree[i-1]})
    else
      node=(${tree:-${_ble_syntax_tree[iN-1]}})
    fi

    ble-assert '((nofs<${#node[@]}))' "$FUNCNAME(i=$i,iN=$iN,nofs=$nofs,node=${node[*]},command=$@)/FATAL1" || break

    local wtype="${node[nofs]}" wlen="${node[nofs+1]}" tclen="${node[nofs+2]}" tplen="${node[nofs+3]}" attr="${node[nofs+4]}"
    local wbegin="$((wlen<0?wlen:i-wlen))"
    local tchild="$((tclen<0?tclen:i-tclen))"
    local tprev="$((tplen<0?tplen:i-tplen))"
    "$@"

    ble-assert '((tprev<i))' "$FUNCNAME/FATAL2" || break

    ((i=tprev,nofs=0,islast=0))
  done
}

## @var[in] iN
## @var[in] tree,i,nofs
## @var[in] tchild
function ble-syntax/tree-enumerate-children {
  ((0<tchild&&tchild<=i)) || return
  local nofs="$((i==tchild?nofs+BLE_SYNTAX_TREE_WIDTH:0))"
  local i="$tchild"
  ble-syntax/tree-enumerate/.impl "$@"
}
function ble-syntax/tree-enumerate-break () ((tprev=-1))

## 関数 ble-syntax/tree-enumerate command...
##   現在の解析状態 _ble_syntax_tree に基いて、
##   指定したコマンド command... を
##   トップレベルの各ノードに対して末尾にあるノードから順に呼び出します。
## @param[in] command...
##   呼び出すコマンドを指定します。
## @var[in] iN
##   解析の起点を指定します。_ble_syntax_stat が設定されている必要があります。
##   指定を省略した場合は _ble_syntax_stat の末尾が使用されます。
function ble-syntax/tree-enumerate {
  local tree i nofs
  [[ ${iN:+set} ]] || local iN="${#_ble_syntax_text}"
  ble-syntax/tree-enumerate/.initialize
  ble-syntax/tree-enumerate/.impl "$@"
}

## r関数 ble-syntax/tree-enumerate-in-range beg end proc
##   入れ子構造に従わず或る範囲内に登録されている節を列挙します。
## @param[in] beg,end
## @param[in] proc 以下の変数を使用する関数を指定します。
##   @var[in]     wtype,wlen,wbeg,wend
##   @var[in,out] node,flagUpdateNode
##   @var[in]     nofs
function ble-syntax/tree-enumerate-in-range {
  local -i beg="$1" end="$2"
  local proc="$3"
  local -a node
  local i nofs
  for ((i=end;i>=beg;i--)); do
    ((i>0)) && [[ ${_ble_syntax_tree[i-1]} ]] || continue
    node=(${_ble_syntax_tree[i-1]})
    local flagUpdateNode=
    for ((nofs=0;nofs<${#node[@]};nofs+=BLE_SYNTAX_TREE_WIDTH)); do
      local wtype="${node[nofs]}" wlen="${node[nofs+1]}"
      local wbeg="$((wlen<0?wlen:i-wlen))" wend="$i"
      "${@:3}"
    done

    [[ $flagUpdateNode ]] && _ble_syntax_tree[i-1]="${node[*]}"
  done
}

#--------------------------------------
# ble-syntax/print-status

function ble-syntax/print-status/.graph {
  local char="$1"
  if ble/util/isprint+ "$char"; then
    graph="'$char'"
    return
  else
    local ret
    ble/util/s2c "$char" 0
    local code="$ret"
    if ((code<32)); then
      ble/util/c2s "$((code+64))"
      graph="$_ble_term_rev^$ret$_ble_term_sgr0"
    elif ((code==127)); then
      graph="$_ble_term_rev^?$_ble_term_sgr0"
    elif ((128<=code&&code<160)); then
      ble/util/c2s "$((code-64))"
      graph="${_ble_term_rev}M-^$ret$_ble_term_sgr0"
    else
      graph="'$char' ($code)"
    fi
  fi
}

## @var[in,out] word
function ble-syntax/print-status/.tree-prepend {
  local -i j="$1"
  local value="$2${tree[j]}"
  tree[j]="$value"
  ((max_tree_width<${#value}&&(max_tree_width=${#value})))
}

function ble-syntax/print-status/.dump-arrays/.append-attr-char {
  if (($?==0)); then
    attr="${attr}$1"
  else
    attr="${attr} "
  fi
}

function ble-syntax/print-status/ctx#get-text {
  eval "$ble_util_upvar_setup"

  local sgr
  ble-syntax/ctx#get_name -v ret "$1"
  ret=${ret#BLE_}
  if [[ ! $ret ]]; then
    ble-color-face2sgr syntax_error
    ret="${sgr}CTX$1$_ble_term_sgr0"
  fi

  eval "$ble_util_upvar"
}
## 関数 ble-syntax/print-status/word.get-text index
##   _ble_syntax_tree[index] の内容を文字列にします。
##   @param[in] index
##   @var[out]  word
function ble-syntax/print-status/word.get-text {
  local index=$1
  word=(${_ble_syntax_tree[index]})
  local ret=
  if [[ $word ]]; then
    local nofs="$((${#word[@]}/BLE_SYNTAX_TREE_WIDTH*BLE_SYNTAX_TREE_WIDTH))"
    while (((nofs-=BLE_SYNTAX_TREE_WIDTH)>=0)); do
      local axis=$((index+1))

      local wtype=${word[nofs]}
      if [[ $wtype =~ ^[0-9]+$ ]]; then
        ble-syntax/print-status/ctx#get-text -v wtype "$wtype"
      elif [[ $wtype =~ ^n* ]]; then
        # Note: nest-pop 時の tree-append では prefix n を付けている。
        wtype=$sgr_quoted\"${wtype:1}\"$_ble_term_sgr0
      else
        wtype=$sgr_error${wtype}$_ble_term_sgr0
      fi

      local b="$((axis-word[nofs+1]))" e="$axis"
      local _prev="${word[nofs+3]}" _child="${word[nofs+2]}"
      if ((_prev>=0)); then
        _prev="@$((axis-_prev-1))>"
      else
        _prev=
      fi
      if ((_child>=0)); then
        _child=">@$((axis-_child-1))"
      else
        _child=
      fi

      ret=" word=$wtype:$_prev$b-$e$_child$ret"
      for ((;b<index;b++)); do
        ble-syntax/print-status/.tree-prepend b '|'
      done
      ble-syntax/print-status/.tree-prepend index '+'
    done
    word=$ret
  fi
}
## 関数 ble-syntax/print-status/nest.get-text index
##   _ble_syntax_nest[index] の内容を文字列にします。
##   @param[in] index
##   @var[out]  nest
function ble-syntax/print-status/nest.get-text {
  local index=$1
  nest=(${_ble_syntax_nest[index]})
  if [[ $nest ]]; then
    local nctx
    ble-syntax/print-status/ctx#get-text -v nctx 'nest[0]'

    local nword=-
    if ((nest[1]>=0)); then
      local swtype
      ble-syntax/print-status/ctx#get-text -v swtype 'nest[2]'
      local wbegin=$((index-nest[1]))
      nword="$swtype:$wbegin-"
    fi

    local nnest=-
    ((nest[3]>=0)) && nnest="'${nest[7]}':$((index-nest[3]))-"

    local nchild=-
    if ((nest[4]>=0)); then
      local tchild=$((index-nest[4]))
      nchild='$'$tchild
      if ! ((0<tchild&&tchild<=index)) || [[ ! ${_ble_syntax_tree[tchild-1]} ]]; then
        nchild=$sgr_error$nchild$_ble_term_sgr0
      fi
    fi

    local nprev=-
    if ((nest[5]>=0)); then
      local tprev=$((index-nest[5]))
      nprev='$'$tprev
      if ! ((0<tprev&&tprev<=index)) || [[ ! ${_ble_syntax_tree[tprev-1]} ]]; then
        nprev=$sgr_error$nprev$_ble_term_sgr0
      fi
    fi

    local nparam=${nest[6]}
    if [[ $nparam == none ]]; then
      nparam=
    else
      nparam=" nparam=${nparam//$_ble_term_fs/$'\e[7m^\\\e[m'}"
    fi

    nest=" nest=($nctx w=$nword n=$nnest t=$nchild:$nprev$nparam)"
  fi
}
## 関数 ble-syntax/print-status/stat.get-text index
##   _ble_syntax_stat[index] の内容を文字列にします。
##   @param[in] index
##   @var[out]  stat
function ble-syntax/print-status/stat.get-text {
  local index=$1
  stat=(${_ble_syntax_stat[index]})
  if [[ $stat ]]; then
    local stat_ctx
    ble-syntax/print-status/ctx#get-text -v stat_ctx 'stat[0]'

    local stat_word=-
    if ((stat[1]>=0)); then
      local stat_wtype
      ble-syntax/print-status/ctx#get-text -v stat_wtype 'stat[2]'
      stat_word="$stat_wtype:$((index-stat[1]))-"
    fi

    local stat_inest=-
    if ((stat[3]>=0)); then
      local inest=$((index-stat[3]))
      stat_inest="@$inest"
      if ((inest<0)) || [[ ! ${_ble_syntax_nest[inest]} ]]; then
        stat_inest=$sgr_error$stat_inest$_ble_term_sgr0
      fi
    fi

    local stat_child=-
    if ((stat[4]>=0)); then
      local tchild=$((index-stat[4]))
      stat_child='$'$tchild
      if ! ((0<tchild&&tchild<=index)) || [[ ! ${_ble_syntax_tree[tchild-1]} ]]; then
        stat_child=$sgr_error$stat_child$_ble_term_sgr0
      fi
    fi

    local stat_prev=-
    if ((stat[5]>=0)); then
      local tprev=$((index-stat[5]))
      stat_prev='$'$tprev
      if ! ((0<tprev&&tprev<=index)) || [[ ! ${_ble_syntax_tree[tprev-1]} ]]; then
        stat_prev=$sgr_error$stat_prev$_ble_term_sgr0
      fi
    fi

    local snparam=${stat[6]}
    if [[ $snparam == none ]]; then
      snparam=
    else
      snparam=" nparam=${snparam//"$_ble_term_fs"/$'\e[7m^\\\e[m'}"
    fi

    stat=" stat=($stat_ctx w=$stat_word n=$stat_inest t=$stat_child:$stat_prev$snparam)"
  fi
}

## @var[out] resultA
## @var[in]  iN
function ble-syntax/print-status/.dump-arrays {
  local -a tree char line
  tree=()
  char=()
  line=()

  local sgr
  ble-color-face2sgr syntax_error
  local sgr_error=$sgr
  ble-color-face2sgr syntax_quoted
  local sgr_quoted=$sgr

  local i max_tree_width=0
  for ((i=0;i<=iN;i++)); do
    local attr="  ${_ble_syntax_attr[i]:-|}"
    if ((_ble_syntax_attr_umin<=i&&i<_ble_syntax_attr_umax)); then
      attr="${attr:${#attr}-2:2}*"
    else
      attr="${attr:${#attr}-2:2} "
    fi

    local ret
    [[ ${_ble_highlight_layer_syntax1_table[i]} ]] && ble-color-g2sgr "${_ble_highlight_layer_syntax1_table[i]}"
    ble-syntax/print-status/.dump-arrays/.append-attr-char "${ret}a${_ble_term_sgr0}"
    [[ ${_ble_highlight_layer_syntax2_table[i]} ]] && ble-color-g2sgr "${_ble_highlight_layer_syntax2_table[i]}"
    ble-syntax/print-status/.dump-arrays/.append-attr-char "${ret}w${_ble_term_sgr0}"
    [[ ${_ble_highlight_layer_syntax3_table[i]} ]] && ble-color-g2sgr "${_ble_highlight_layer_syntax3_table[i]}"
    ble-syntax/print-status/.dump-arrays/.append-attr-char "${ret}e${_ble_term_sgr0}"

    [[ ${_ble_syntax_stat_shift[i]} ]]
    ble-syntax/print-status/.dump-arrays/.append-attr-char s

    local index="000$i"
    index="${index:${#index}-3:3}"

    local word nest stat
    ble-syntax/print-status/word.get-text "$i"
    ble-syntax/print-status/nest.get-text "$i"
    ble-syntax/print-status/stat.get-text "$i"

    local graph=
    ble-syntax/print-status/.graph "${_ble_syntax_text:i:1}"
    char[i]="$attr $index $graph"
    line[i]="$word$nest$stat"
  done

  resultA='_ble_syntax_attr/tree/nest/stat?'$'\n'
  _ble_util_string_prototype.reserve max_tree_width
  for ((i=0;i<=iN;i++)); do
    local t="${tree[i]}${_ble_util_string_prototype::max_tree_width}"
    resultA="$resultA${char[i]} ${t::max_tree_width}${line[i]}"$'\n'
  done
}

## 関数 ble-syntax/print-status/.dump-tree/proc1
## @var[out] resultB
## @var[in]  prefix
## @var[in]  nl
function ble-syntax/print-status/.dump-tree/proc1 {
  local tip="| "; tip="${tip:islast:1}"
  prefix="$prefix$tip   " ble-syntax/tree-enumerate-children ble-syntax/print-status/.dump-tree/proc1
  resultB="$prefix\_ '${_ble_syntax_text:wbegin:wlen}'$nl$resultB"
}

## 関数 ble-syntax/print-status/.dump-tree
## @var[out] resultB
## @var[in]  iN
function ble-syntax/print-status/.dump-tree {
  resultB=

  local nl="$_ble_term_nl"
  local prefix=
  ble-syntax/tree-enumerate ble-syntax/print-status/.dump-tree/proc1
}

function ble-syntax/print-status {
  local iN="${#_ble_syntax_text}"

  local resultA
  ble-syntax/print-status/.dump-arrays

  local resultB
  ble-syntax/print-status/.dump-tree

  local result="$resultA$_ble_term_NL$resultB"
  if [[ $1 == -v && $2 ]]; then
    local "${2%%\[*\]}" && ble/util/upvar "$2" "$result"
  else
    builtin echo "$result"
  fi
}

#--------------------------------------

function ble-syntax/parse/generate-stat {
  _stat="$ctx $((wbegin<0?wbegin:i-wbegin)) $wtype $((inest<0?inest:i-inest)) $((tchild<0?tchild:i-tchild)) $((tprev<0?tprev:i-tprev)) ${nparam:-none}"
}

# 構文木の管理 (_ble_syntax_tree)

## 関数 ble-syntax/parse/tree-append
## 要件 解析位置を進めてから呼び出す必要があります (要件: i>=p1+1)。
function ble-syntax/parse/tree-append {
#%if !release
  [[ $debug_p1 ]] && { ((i-1>=debug_p1)) || ble-stackdump "Wrong call of tree-append: Condition violation (p1=$debug_p1 i=$i iN=$iN)."; }
#%end
  local type="$1"
  local beg="$2" end="$i"
  local len="$((end-beg))"
  ((len==0)) && return

  local tchild="$3" tprev="$4"

  # 子情報・兄情報
  local ochild=-1 oprev=-1
  ((tchild>=0&&(ochild=i-tchild)))
  ((tprev>=0&&(oprev=i-tprev)))

  [[ $type =~ ^[0-9]+$ ]] && ble-syntax/parse/touch-updated-word "$i"

  # 追加する要素の数は BLE_SYNTAX_TREE_WIDTH と一致している必要がある。
  _ble_syntax_tree[i-1]="$type $len $ochild $oprev - ${_ble_syntax_tree[i-1]}"
}

function ble-syntax/parse/word-push {
  wtype="$1" wbegin="$2" tprev="$tchild" tchild=-1
}
## 関数 ble-syntax/parse/word-pop
## 要件 解析位置を進めてから呼び出す必要があります (要件: i>=p1+1)。
# 仮定: 1つ上の level は nest-push による level か top level のどちらかである。
#   この場合に限って ble-syntax/parse/nest-reset-tprev を用いて、tprev
#   を適切な値に復元することができる。
function ble-syntax/parse/word-pop {
  ble-syntax/parse/tree-append "$wtype" "$wbegin" "$tchild" "$tprev"
  ((wbegin=-1,wtype=-1,tchild=i))
  ble-syntax/parse/nest-reset-tprev
}
## '[[' 専用の関数:
##   word-push/word-pop と nest-push の順序を反転させる為に。
##   具体的にどう使われているかは使っている箇所を参照すると良い。
##   ※本当は [[ が見付かった時点でコマンドとして読み取るのではなく、
##     特別扱いするべきな気もするが、面倒なので今の実装になっている。
## 仮定: 一番最後に設置されたのが単語である事。
##   かつ、キャンセルされる単語は今回の解析ステップで設置された物である事。
function ble-syntax/parse/word-cancel {
  local -a word
  word=(${_ble_syntax_tree[i-1]})
  local tclen=${word[3]}
  tchild=$((tclen<0?tclen:i-tclen))
  _ble_syntax_tree[i-1]=
}

# 入れ子構造の管理

## 関数 ble-syntax/parse/nest-push newctx ntype
##   @param[in]     newctx 新しい ctx を指定します。
##   @param[in,opt] ntype  文法要素の種類を指定します。
##   @var  [in]     i      現在の位置を指定します。
##   @var  [in out] inest  親 nest の位置を指定します。新しい nest の位置 (i) を返します。
##   @var  [in,out] ctx    復帰時の ctx を指定します。新しい ctx (newctx) を返します。
##   @var  [in,out] wbegin 復帰時の wbegin を指定します。新しい wbegin (-1) を返します。
##   @var  [in,out] wtype  復帰時の wtype を指定します。新しい wtype (-1) を返します。
##   @var  [in,out] tchild 復帰時の tchild を指定します。新しい tchild (-1) を返します。
##   @var  [in,out] tprev  復帰時の tprev を指定します。新しい tprev (tchild) を返します。
##   @var  [in,out] nparam 復帰時の nparam を指定します。新しい nparam (空文字列) を返します。
function ble-syntax/parse/nest-push {
  local wlen=$((wbegin<0?wbegin:i-wbegin))
  local nlen=$((inest<0?inest:i-inest))
  local tclen=$((tchild<0?tchild:i-tchild))
  local tplen=$((tprev<0?tprev:i-tprev))
  _ble_syntax_nest[i]="$ctx $wlen $wtype $nlen $tclen $tplen ${nparam:-none} ${2:-none}"
  ((ctx=$1,inest=i,wbegin=-1,wtype=-1,tprev=tchild,tchild=-1))
  nparam=
}
## 関数 ble-syntax/parse/nest-pop
## 要件 解析位置を進めてから呼び出す必要があります (要件: i>=p1+1)。
##   現在の入れ子を閉じます。現在の入れ子情報を記録して、一つ上の入れ子情報を復元します。
##   @var[   out] ctx      上の入れ子階層の ctx を復元します。
##   @var[   out] wbegin   上の入れ子階層の wbegin を復元します。
##   @var[   out] wtype    上の入れ子階層の wtype を復元します。
##   @var[in,out] inest    記録する入れ子情報を指定します。上の入れ子階層の inest を復元します。
##   @var[in,out] tchild   記録する入れ子情報を指定します。上の入れ子階層の tchild を復元します。
##   @var[in,out] tprev    記録する入れ子情報を指定します。上の入れ子階層の tprev を復元します。
##   @var[   out] nparam   上の入れ子階層の nparam を復元します。
function ble-syntax/parse/nest-pop {
  ((inest<0)) && return 1

  local -a parentNest
  parentNest=(${_ble_syntax_nest[inest]})

  local ntype="${parentNest[7]}" nbeg="$inest"
  ble-syntax/parse/tree-append "n$ntype" "$nbeg" "$tchild" "$tprev"

  local wlen="${parentNest[1]}" nlen="${parentNest[3]}" tplen="${parentNest[5]}"
  ((ctx=parentNest[0]))
  ((wtype=parentNest[2]))
  ((wbegin=wlen<0?wlen:nbeg-wlen,
    inest=nlen<0?nlen:nbeg-nlen,
    tchild=i,
    tprev=tplen<0?tplen:nbeg-tplen))
  nparam=${parentNest[6]}
  [[ $nparam == none ]] && nparam=
}
function ble-syntax/parse/nest-type {
  local _var=ntype
  [[ $1 == -v ]] && _var="$2"
  if ((inest<0)); then
    eval "$_var="
    return 1
  else
    eval "$_var=\"\${_ble_syntax_nest[inest]##* }\""
  fi
}
function ble-syntax/parse/nest-reset-tprev {
  if ((inest<0)); then
    tprev=-1
  else
    local -a nest
    nest=(${_ble_syntax_nest[inest]})
    local tclen="${nest[4]}"
    ((tprev=tclen<0?tclen:inest-tclen))
  fi
}
## 関数 ble-syntax/parse/nest-equals
##   現在のネスト状態と前回のネスト状態が一致するか判定します。
## @var i1                     更新開始点
## @var i2                     更新終了点
## @var _tail_syntax_stat[i-i2] i2 以降の更新前状態
## @var _ble_syntax_stat[i]    新しい状態
function ble-syntax/parse/nest-equals {
  local parent_inest="$1"
  while :; do
    ((parent_inest<i1)) && return 0 # 変更していない範囲 または -1
    ((parent_inest<i2)) && return 1 # 変更によって消えた範囲

    local _onest="${_tail_syntax_nest[parent_inest-i2]}"
    local _nnest="${_ble_syntax_nest[parent_inest]}"
    [[ $_onest != $_nnest ]] && return 1

    local -a onest
    onest=($_onest)
#%if !release
    ((onest[3]!=0&&onest[3]<=parent_inest)) || { ble-stackdump "invalid nest onest[3]=${onest[3]} parent_inest=$parent_inest text=$text" && return 0; }
#%end
    ((onest[3]<0?(parent_inest=onest[3]):(parent_inest-=onest[3])))
  done
}

# 属性値の変更範囲

## @var _ble_syntax_attr_umin, _ble_syntax_attr_umax は更新された文法属性の範囲を記録する。
## @var _ble_syntax_word_umin, _ble_syntax_word_umax は更新された単語の先頭位置の範囲を記録する。
##   attr については [_ble_syntax_attr_umin, _ble_syntax_attr_umax) が範囲である。
##   word については [_ble_syntax_word_umin, _ble_syntax_word_umax] が範囲である。
_ble_syntax_attr_umin=-1 _ble_syntax_attr_umax=-1
_ble_syntax_word_umin=-1 _ble_syntax_word_umax=-1
function ble-syntax/parse/touch-updated-attr {
  (((_ble_syntax_attr_umin<0||_ble_syntax_attr_umin>$1)&&(
      _ble_syntax_attr_umin=$1)))
}
function ble-syntax/parse/touch-updated-word {
#%if !release
  (($1>0)) || ble-stackdump "invalid word position $1"
#%end
  (((_ble_syntax_word_umin<0||_ble_syntax_word_umin>$1)&&(
      _ble_syntax_word_umin=$1)))
  (((_ble_syntax_word_umax<0||_ble_syntax_word_umax<$1)&&(
      _ble_syntax_word_umax=$1)))
}

#==============================================================================
#
# 文脈値
#

# 文脈値達 from ble-syntax-ctx.def
#%$ sed 's/[[:space:]]*#.*//;/^$/d' ble-syntax-ctx.def | awk '$2 ~ /^[0-9]+$/ {print $1 "=" $2;}'

# for debug
_ble_syntax_bash_ctx_names=(
#%$ sed 's/[[:space:]]*#.*//;/^$/d' ble-syntax-ctx.def | awk '$2 ~ /^[0-9]+$/ {print "  [" $2 "]=" $1;}'
)
function ble-syntax/ctx#get_name {
  if [[ $1 == -v ]]; then
    eval "$2=\${_ble_syntax_bash_ctx_names[\$3]}"
  else
    ble-syntax/ctx#get_name -v ret "$1"
  fi
}

# @var _BLE_SYNTAX_FCTX[]
# @var _BLE_SYNTAX_FEND[]
#   以上の二つの配列を通して文法要素は最終的に登録される。
#   (逆に言えば上の二つの配列を弄れば別の文法の解析を実行する事もできる)
_BLE_SYNTAX_FCTX=()
_BLE_SYNTAX_FEND=()

#==============================================================================
#
# 空文法
#
#------------------------------------------------------------------------------

function ble-syntax:text/ctx-unspecified {
  ((i+=${#tail}))
  return 0
}
_BLE_SYNTAX_FCTX[CTX_UNSPECIFIED]=ble-syntax:text/ctx-unspecified

function ble-syntax:text/initialize-ctx { ctx=$CTX_UNSPECIFIED; }
function ble-syntax:text/initialize-vars { :; }

#==============================================================================
#
# Bash Script 文法
#
#------------------------------------------------------------------------------

_ble_syntax_bash_IFS=$' \t\n'
_ble_syntax_bash_rex_spaces=$'[ \t]+'
_ble_syntax_bash_rex_IFSs="[$_ble_syntax_bash_IFS]+"
_ble_syntax_bash_rex_delimiters="[$_ble_syntax_bash_IFS;|&<>()]"
_ble_syntax_bash_rex_redirect='((\{[a-zA-Z_][a-zA-Z_0-9]+\}|[0-9]+)?(&?>>?|>[|&]|<[>&]?|<<[-<]?))[ 	]*'

## @var _ble_syntax_bashc[]
##   特定の役割を持つ文字の集合。Bracket expression [～] に入れて使う為の物。
##   histchars に依存しているので変化があった時に更新する。
_ble_syntax_bashc=()
_ble_syntax_bashc_seed=
{
  # default values
  _ble_syntax_bashc_def=()
  _ble_syntax_bashc_def[CTX_ARGI]="$_ble_syntax_bash_IFS;|&()<>\$\"\`\\'!^"
  _ble_syntax_bashc_def[CTX_PATN]="\$\"\`\\'(|)?*@+!"
  _ble_syntax_bashc_def[CTX_QUOT]="\$\"\`\\!"       # 文字列 "～" で特別な意味を持つのは $ ` \ " のみ。+履歴展開の ! も。
  _ble_syntax_bashc_def[CTX_EXPR]="][}()\$\"\`\\'!" # ()[] は入れ子を数える為。} は ${var:ofs:len} の為。
  _ble_syntax_bashc_def[CTX_PWORD]="}\$\"\`\\'!"    # パラメータ展開 ${～}
  _ble_syntax_bashc_def[CTX_RDRH]="$_ble_syntax_bash_IFS;|&()<>$\"\`\\'"

  # templates
  _ble_syntax_bashc_fmt=()
  _ble_syntax_bashc_fmt[CTX_ARGI]="$_ble_syntax_bash_IFS;|&()<>\$\"\`\\'@h@q"
  _ble_syntax_bashc_fmt[CTX_PATN]="\$\"\`\\'(|)?*@+@h"
  _ble_syntax_bashc_fmt[CTX_QUOT]="\$\"\`\\@h"
  _ble_syntax_bashc_fmt[CTX_EXPR]="][}()\$\"\`\\'@h"
  _ble_syntax_bashc_fmt[CTX_PWORD]="}\$\"\`\\'@h"
  _ble_syntax_bashc_fmt[CTX_RDRH]=${_ble_syntax_bashc_def[CTX_RDRH]}

  _ble_syntax_bashc_simple=${_ble_syntax_bashc_def[CTX_ARGI]}

  function ble-syntax:bash/.update-_ble_syntax_bashc/reorder {
    eval "local a=\"\${$1}\""

    # Bracket expression として安全な順に並び替える
    [[ $a == *']'* ]] && a="]${a//]}"
    [[ $a == *'-'* ]] && a="${a//-}-"

    eval "$1=\"\$a\""
  }

  ## @var[in] histc1 histc2 histc12
  ## @var[in,out] _ble_syntax_bashc_seed
  ## @var[in,out] _ble_syntax_bashc[]
  function ble-syntax:bash/.update-_ble_syntax_bashc {
    local seed=$histc12
    shopt -q extglob && seed="${seed}x"
    [[ $seed == "$_ble_syntax_bashc_seed" ]] && return
    _ble_syntax_bashc_seed=$seed

    local key modified=
    if [[ $histc12 == '!^' ]]; then
      for key in "${!_ble_syntax_bashc_def[@]}"; do
        _ble_syntax_bashc[key]="${_ble_syntax_bashc_def[key]}"
      done
    else
      modified=1
      for key in "${!_ble_syntax_bashc_fmt[@]}"; do
        local a="${_ble_syntax_bashc_fmt[key]}"
        a="${a//@h/$histc1}"
        a="${a//@q/$histc2}"
        _ble_syntax_bashc[key]="$a"
      done
    fi

    _ble_syntax_bashc_simple=${_ble_syntax_bashc[CTX_ARGI]}
    if [[ $seed == *x ]]; then
      # extglob: ?() *() +() @() !()
      _ble_syntax_bashc[CTX_ARGI]="${_ble_syntax_bashc[CTX_ARGI]}?*+@!"
    fi

    if [[ $modified ]]; then
      for key in "${!_ble_syntax_bashc[@]}"; do
        ble-syntax:bash/.update-_ble_syntax_bashc/reorder _ble_syntax_bashc[key]
      done
      ble-syntax:bash/.update-_ble_syntax_bashc/reorder _ble_syntax_bashc_simple
    fi
  }

  histc12='!^' ble-syntax:bash/.update-_ble_syntax_bashc
}

## @var _ble_syntax_rex_simple_word
## @var _ble_syntax_rex_simple_word_element
##   単純な単語のパターンとその構成要素を表す正規表現
##   histchars に依存しているので変化があった時に更新する。
_ble_syntax_rex_simple_word=
_ble_syntax_rex_simple_word_element=
{
  function ble-syntax:bash/.update-rex_simple_word {
    local quot="'"
    local rex_squot='"[^"]*"|\$"([^"\]|\\.)*"'; rex_squot="${rex_squot//\"/$quot}"
    local rex_dquot='\$?"([^'"${_ble_syntax_bashc[CTX_QUOT]}"']|\\.)*"'
    local rex_param='\$([-*@#?$!0_]|[1-9][0-9]*|[a-zA-Z_][a-zA-Z_0-9]*)'
    local rex_param2='\$\{(#?[-*@#?$!0]|[#!]?([1-9][0-9]*|[a-zA-Z_][a-zA-Z_0-9]*))\}' # ${!!} ${!$} はエラーになる。履歴展開の所為?
    local rex_letter='[^'"${_ble_syntax_bashc_simple}"']'
    _ble_syntax_rex_simple_word_element='('"$rex_letter"'|\\.|'"$rex_squot"'|'"$rex_dquot"'|'"$rex_param"'|'"$rex_param2"')'
    _ble_syntax_rex_simple_word='^'"$_ble_syntax_rex_simple_word_element"'+$'
  }
  ble-syntax:bash/.update-rex_simple_word
}

function ble-syntax:bash/initialize-ctx {
  ctx="$CTX_CMDX" # CTX_CMDX が ble-syntax:bash の最初の文脈
}

_ble_syntax_bash_histc12=
_ble_syntax_bash_vars=(histc1 histc2 histc12 histstop)
function ble-syntax:bash/initialize-vars {
  # シェル変数 histchars の解釈について
  #
  # - 1文字目 [既定値 !] は履歴展開の開始を表す。
  #   イベント指示子の中に含まれる ! も対象となる。
  #   但し、histchars の 1 文字目が既に別の意味を持っている場合 ([-#?0-9^$%*]) は、
  #   そちらの方が優先される様だ。
  # - 2文字目 [既定値 ^] は履歴展開(置換)の開始を表す。
  #   ^aaa^bbb^ は =aaa=bbb= となる。
  # - 3文字目 [既定値 #] は .bash_history
  #   に時刻を出力する時の区切り文字に使われる。
  #   ここでは関係ない。
  #
  if [[ ${histchars+set} ]]; then
    histc1="${histchars::1}"
    histc2="${histchars:1:1}"
  else
    histc1='!'
    histc2='^'
  fi

  histc12="$histc1$histc2"
  if [[ $histc12 != $_ble_syntax_bash_histc12 ]]; then
    _ble_syntax_bash_histc12="$histc12"
    ble-syntax:bash/.update-_ble_syntax_bashc
    ble-syntax:bash/.update-rex_simple_word
  fi

  histstop=$' \t\n='
  shopt -q extglob && histstop="$histstop("
}


#------------------------------------------------------------------------------
# 共通の字句の一致判定

function ble-syntax:bash/check-dollar {
  [[ $tail == '$'* ]] || return 1

  local rex
  if [[ $tail == '${'* ]]; then
    # ■中で許される物: 決まったパターン + 数式や文字列に途中で切り替わる事も
    if rex='^(\$\{[#!]?)([-*@#?$!0]|[1-9][0-9]*|[a-zA-Z_][a-zA-Z_0-9]*)(\[?)' && [[ $tail =~ $rex ]]; then
      # <parameter> = [-*@#?-$!0] | [1-9][0-9]* | <varname> | <varname> [ ... ] | <varname> [ <@> ]
      # <@> = * | @
      # ${<parameter>} ${#<parameter>} ${!<parameter>}
      # ${<parameter>:-<word>} ${<parameter>:=<word>} ${<parameter>:+<word>} ${<parameter>:?<word>}
      # ${<parameter>-<word>} ${<parameter>=<word>} ${<parameter>+<word>} ${<parameter>?<word>}
      # ${<parameter>:expr} ${<parameter>:expr:expr} etc
      # ${!head<@>} ${!varname[<@>]}

      # for bash-3.1 ${#arr[n]} bug
      local rematch1="${BASH_REMATCH[1]}"
      local rematch2="${BASH_REMATCH[2]}"
      local rematch3="${BASH_REMATCH[3]}"

      local ntype='${'
      if ((ctx==CTX_QUOT)); then
        ntype='"${'
      elif ((ctx==CTX_PWORD||ctx==CTX_EXPR)); then
        local ntype2; ble-syntax/parse/nest-type -v ntype2
        [[ $ntype2 == '"${' ]] && ntype='"${'
      fi

      ble-syntax/parse/nest-push "$CTX_PARAM" "$ntype"
      ((_ble_syntax_attr[i]=ctx,
        i+=${#rematch1},
        _ble_syntax_attr[i]=ATTR_VAR,
        i+=${#rematch2}))
      if [[ $rematch3 ]]; then
        ble-syntax/parse/nest-push "$CTX_EXPR" 'v['
        ((_ble_syntax_attr[i]=CTX_EXPR,
          i+=${#rematch3}))
      fi
      return 0
    else
      ((_ble_syntax_attr[i]=ATTR_ERR,i+=2))
      return 0
    fi
  elif [[ $tail == '$(('* ]]; then
    ((_ble_syntax_attr[i]=CTX_PARAM))
    ble-syntax/parse/nest-push "$CTX_EXPR" '$(('
    ((i+=3))
    return 0
  elif [[ $tail == '$['* ]]; then
    ((_ble_syntax_attr[i]=CTX_PARAM))
    ble-syntax/parse/nest-push "$CTX_EXPR" '$['
    ((i+=2))
    return 0
  elif [[ $tail == '$('* ]]; then
    ((_ble_syntax_attr[i]=CTX_PARAM))
    ble-syntax/parse/nest-push "$CTX_CMDX" '$('
    ((i+=2))
    return 0
  elif rex='^\$([-*@#?$!0_]|[1-9][0-9]*|[a-zA-Z_][a-zA-Z_0-9]*)' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=CTX_PARAM,
      _ble_syntax_attr[i+1]=ATTR_VAR,
      i+=${#BASH_REMATCH}))
    return 0
  else
    # if dollar doesn't match any patterns it is treated as a normal character
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi
}

function ble-syntax:bash/check-quotes {
  local rex aqdel=$ATTR_QDEL aquot=$CTX_QUOT

  # 字句的に解釈されるが除去はされない場合
  if ((ctx==CTX_EXPR)); then
    local ntype
    ble-syntax/parse/nest-type -v ntype
    if [[ $ntype == '${' || $ntype == '$[' || $ntype == '$((' || $ntype == 'NQ(' ]]; then
      # $[...] / $((...)) / ${var:...} の中では
      # 如何なる quote も除去されない (字句的には解釈される)。
      # 除去されない quote は算術式エラーである。
      ((aqdel=ATTR_ERR,aquot=CTX_EXPR))
    elif [[ $ntype == '"${' ]] && ! { [[ $tail == '$'[\'\"]* ]] && shopt -q extquote; }; then
      # "${var:...}" の中では 〈extquote が設定されている時の $'' $""〉 を例外として
      # quote は除去されない (字句的には解釈される)。
      ((aqdel=ATTR_ERR,aquot=CTX_EXPR))
    fi
  elif ((ctx==CTX_PWORD)); then
    # "${var ～}" の中では $'' $"" は ! shopt -q extquote の時除去されない。
    if [[ $tail == '$'[\'\"]* ]] && ! shopt -q extquote; then
      local ntype
      ble-syntax/parse/nest-type -v ntype
      if [[ $ntype == '"${' ]]; then
        ((aqdel=CTX_PWORD,aquot=CTX_PWORD))
      fi
    fi
  fi

  if rex='^`([^`\]|\\(.|$))*(`?)|^'\''[^'\'']*('\''?)' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=aqdel,
      _ble_syntax_attr[i+1]=aquot,
      i+=${#BASH_REMATCH},
      _ble_syntax_attr[i-1]=${#BASH_REMATCH[3]}||${#BASH_REMATCH[4]}?aqdel:ATTR_ERR))
    return 0
  fi

  if ((ctx!=CTX_QUOT)); then
    if rex='^(\$?")([^'"${_ble_syntax_bashc[CTX_QUOT]}"']|\\.)*("?)' && [[ $tail =~ $rex ]]; then
      local rematch1="${BASH_REMATCH[1]}" # for bash-3.1 ${#arr[n]} bug
      if [[ ${BASH_REMATCH[3]} ]]; then
        # 終端まで行った場合
        ((_ble_syntax_attr[i]=aqdel,
          _ble_syntax_attr[i+${#rematch1}]=aquot,
          i+=${#BASH_REMATCH},
          _ble_syntax_attr[i-1]=aqdel))
      else
        # 中に構造がある場合
        ble-syntax/parse/nest-push "$CTX_QUOT"
        if ((ctx==CTX_PWORD&&aqdel!=ATTR_QDEL)); then
          # CTX_PWORD (パラメータ展開) でクォート除去が有効でない文脈の場合、
          # 「$」 だけ aqdel で着色し、「" ... "」 は通常通り着色する。
          ((_ble_syntax_attr[i]=aqdel,
            _ble_syntax_attr[i+${#rematch1}-1]=ATTR_QDEL,
            _ble_syntax_attr[i+${#rematch1}]=CTX_QUOT,
            i+=${#BASH_REMATCH}))
        else
          ((_ble_syntax_attr[i]=aqdel,
            _ble_syntax_attr[i+${#rematch1}]=CTX_QUOT,
            i+=${#BASH_REMATCH}))
        fi
      fi
      return 0
    elif rex='^\$'\''([^'\''\]|\\(.|$))*('\''?)' && [[ $tail =~ $rex ]]; then
      ((_ble_syntax_attr[i]=aqdel,
        _ble_syntax_attr[i+2]=aquot,
        i+=${#BASH_REMATCH},
        _ble_syntax_attr[i-1]=${#BASH_REMATCH[3]}?aqdel:ATTR_ERR))
      return 0
    fi
  fi

  return 1
}

function ble-syntax:bash/check-process-subst {
  # プロセス置換
  if [[ $tail == ['<>']'('* ]]; then
    ble-syntax/parse/nest-push "$CTX_CMDX" '('
    ((_ble_syntax_attr[i]=ATTR_DEL,i+=2))
    return 0
  fi

  return 1
}

function ble-syntax:bash/check-comment {
  # コメント
  if shopt -q interactive_comments; then
    if ((wbegin<0||wbegin==i)) && local rex=$'^#[^\n]*' && [[ $tail =~ $rex ]]; then
      # 空白と同様に ctx は変えずに素通り (末端の改行は残す)
      ((_ble_syntax_attr[i]=ATTR_COMMENT,
        i+=${#BASH_REMATCH}))
      return 0
    fi
  fi

  return 1
}

function ble-syntax:bash/check-glob {
  if [[ $tail == ['?*@+!()|']* ]]; then
    local attr=$((ctx==CTX_VRHS?ctx:ATTR_GLOB))
    if [[ $tail == ['?*@+!']'('* ]] && shopt -q extglob; then
      ble-syntax/parse/nest-push "$CTX_PATN" "ctx=$attr"
      ((_ble_syntax_attr[i]=attr,i+=2))
      return 0
    fi

    # 履歴展開の解釈の方が強い
    [[ $histc1 && $tail == "$histc1"* ]] && return 1

    if [[ $tail == ['?*']* ]]; then
      ((_ble_syntax_attr[i++]=attr))
      return 0
    elif [[ $tail == ['@+!']* ]]; then
      ((_ble_syntax_attr[i++]=ctx))
      return 0
    elif ((ctx==CTX_PATN)); then
      local ntype
      ble-syntax/parse/nest-type -v ntype
      if [[ $ntype == nest ]]; then
        attr=$ctx
      elif [[ $ntype == "ctx=$CTX_VRHS" ]]; then
        attr=$CTX_VRHS
      fi

      if [[ $tail == '('* ]]; then
        ble-syntax/parse/nest-push "$CTX_PATN" nest
        ((_ble_syntax_attr[i++]=ctx))
        return 0
      elif [[ $tail == ')'* ]]; then
        ((_ble_syntax_attr[i++]=attr))
        ble-syntax/parse/nest-pop
        return 0
      elif [[ $tail == '|'* ]]; then
        ((_ble_syntax_attr[i++]=attr))
        return 0
      fi
    fi
  fi

  return 1
}

_ble_syntax_rex_histexpand_event=
_ble_syntax_rex_histexpand_word=
_ble_syntax_rex_histexpand_mods=
_ble_syntax_rex_histexpand_quicksub=
function _ble_syntax_rex_histexpand.init {
  local spaces=$' \t\n' nl=$'\n'
  local rex_event='-?[0-9]+|[!#]|[^-$^*%:'"$spaces"'=?!#;&|<>()]+|\?[^?'"$nl"']*\??'
  _ble_syntax_rex_histexpand_event='^!('"$rex_event"')'

  local rex_word1='([0-9]+|[$%^])'
  local rex_wordsA=':('"$rex_word1"'?-'"$rex_word1"'?|\*|'"$rex_word1"'\*?)'
  local rex_wordsB='([$%^]?-'"$rex_word1"'?|\*|[$^%][*-]?)'
  _ble_syntax_rex_histexpand_word='('"$rex_wordsA|$rex_wordsB"')?'

  # ※本当は /s(.)([^\]|\\.)*?\1([^\]|\\.)*?\1/ 等としたいが *? は ERE にない。
  #   正しく対応しようと思ったら一回の正規表現でやろうとせずに繰り返し適用する?
  local rex_modifier=':[htrepqx&gG]|:s(/([^\/]|\\.)*){0,2}(/|$)'
  _ble_syntax_rex_histexpand_mods='('"$rex_modifier"')*'

  _ble_syntax_rex_histexpand_quicksub='\^([^^\]|\\.)*\^([^^\]|\\.)*\^'

  # for histchars
  _ble_syntax_rex_histexpand_quicksub_template='@A([^@C\]|\\.)*@A([^@C\]|\\.)*@A'
  _ble_syntax_rex_histexpand_event_template='^@A('"$rex_event"'|@A)'
}

## 関数 ble-syntax:bash/histexpand/initialize-event
##
function ble-syntax:bash/histexpand/initialize-event {
  if [[ $histc1 == '!' ]]; then
    rex_event="$_ble_syntax_rex_histexpand_event"
  else
    local A="[$histc1]"
    [[ $histc1 == '^' ]] && A='\^'
    rex_event="$_ble_syntax_rex_histexpand_event_template"
    rex_event="${rex_event//@A/$A}"
  fi
}

function ble-syntax:bash/histexpand/initialize-quicksub {
  if [[ $histc2 == '^' ]]; then
    rex_quicksub="$_ble_syntax_rex_histexpand_quicksub"
  else
    rex_quicksub="$_ble_syntax_rex_histexpand_quicksub_template"
    rex_quicksub="${rex_quicksub//@A/[$histc2]}"
    rex_quicksub="${rex_quicksub//@C/$histc2}"
  fi
}

_ble_syntax_rex_histexpand.init

function ble-syntax:bash/check-history-expansion {
  [[ -o histexpand ]] || return 1

  if [[ $histc1 && $tail == "$histc1"[^"$histstop"]* ]]; then

    # "～" 文字列中では一致可能範囲を制限する。
    if ((ctx==CTX_QUOT)); then
      local tail=${tail%%'"'*}
      [[ $tail == '!' ]] && return 1
    fi

    ((_ble_syntax_attr[i]=ATTR_HISTX))
    local rex_event
    ble-syntax:bash/histexpand/initialize-event
    if [[ $tail =~ $rex_event ]]; then
      ((i+=${#BASH_REMATCH}))
    elif [[ $tail == "$histc1"['-:0-9^$%*']* ]]; then
      ((_ble_syntax_attr[i]=ATTR_HISTX,i++))
    else
      # ErrMsg 'unrecognized event'
      ((_ble_syntax_attr[i+1]=ATTR_ERR,i+=2))
      return 0
    fi

    # word-designator
    [[ ${text:i} =~ $_ble_syntax_rex_histexpand_word ]] &&
      ((i+=${#BASH_REMATCH}))

    # modifiers
    [[ ${text:i} =~ $_ble_syntax_rex_histexpand_mods ]] &&
      ((i+=${#BASH_REMATCH}))

    # ErrMsg 'unrecognized modifier'
    [[ ${text:i} == ':'* ]] &&
      ((_ble_syntax_attr[i]=ATTR_ERR,i++))
    return 0
  elif ((i==0)) && [[ $histc2 && $tail == "$histc2"* ]]; then
    ((_ble_syntax_attr[i]=ATTR_HISTX))
    local rex_quicksub
    ble-syntax:bash/histexpand/initialize-quicksub
    if [[ $tail =~ $rex_quicksub ]]; then
      ((i+=${#BASH_REMATCH}))

      # modifiers
      [[ ${text:i} =~ $_ble_syntax_rex_histexpand_mods ]] &&
        ((i+=${#BASH_REMATCH}))

      # ErrMsg 'unrecognized modifier'
      [[ ${text:i} == ':'* ]] &&
        ((_ble_syntax_attr[i]=ATTR_ERR,i++))
      return 0
    else
      # 末端まで
      ((i+=${#tail}))
      return 0
    fi
  fi

  return 1
}


#------------------------------------------------------------------------------
# 文脈: 各種文脈

_BLE_SYNTAX_FCTX[CTX_QUOT]=ble-syntax:bash/ctx-quot
function ble-syntax:bash/ctx-quot {
  # 文字列の中身
  local rex
  if rex='^([^'"${_ble_syntax_bashc[CTX_QUOT]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif [[ $tail == '"'* ]]; then
    ((_ble_syntax_attr[i]=ATTR_QDEL,
      i+=1))
    ble-syntax/parse/nest-pop
    return 0
  elif ble-syntax:bash/check-quotes; then
    return 0
  elif ble-syntax:bash/check-dollar; then
    return 0
  elif [[ $histc12 && $tail == ["$histc12"]* ]]; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

_BLE_SYNTAX_FCTX[CTX_CASE]=ble-syntax:bash/ctx-case
function ble-syntax:bash/ctx-case {
  if [[ $tail =~ ^$_ble_syntax_bash_rex_IFSs ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif [[ $tail == '('* ]]; then
    ((ctx=CTX_CMDX))
    ble-syntax/parse/nest-push "$CTX_PATN"
    ((_ble_syntax_attr[i++]=ATTR_GLOB))
    return 0
  elif [[ $tail == 'esac'$_ble_syntax_bash_rex_delimiters* || $tail == 'esac' ]]; then
    ((ctx=CTX_CMDX1))
    ble-syntax:bash/ctx-command
  else
    ((ctx=CTX_CMDX))
    ble-syntax/parse/nest-push "$CTX_PATN"
    ble-syntax:bash/ctx-globpat
  fi
}

_BLE_SYNTAX_FCTX[CTX_PATN]=ble-syntax:bash/ctx-globpat
function ble-syntax:bash/ctx-globpat {
  # glob () の中身 (extglob @(...) や case in (...) の中)
  local rex
  if rex='^([^'"${_ble_syntax_bashc[CTX_PATN]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif ble-syntax:bash/check-process-subst; then
    return 0
  elif ble-syntax:bash/check-quotes; then
    return 0
  elif ble-syntax:bash/check-dollar; then
    return 0
  elif ble-syntax:bash/check-glob; then
    return 0
  elif [[ $histc12 && $tail == ["$histc12"]* ]]; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

_BLE_SYNTAX_FCTX[CTX_PARAM]=ble-syntax:bash/ctx-param
_BLE_SYNTAX_FCTX[CTX_PWORD]=ble-syntax:bash/ctx-pword
function ble-syntax:bash/ctx-param {
  # パラメータ展開 - パラメータの直後

  if [[ $tail == :[^-?=+]* ]]; then
    ((_ble_syntax_attr[i]=CTX_EXPR,
      ctx=CTX_EXPR,i++))
    return 0
  elif [[ $tail == '}'* ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
    ((i+=1))
    ble-syntax/parse/nest-pop
    return 0
  else
    ((ctx=CTX_PWORD))
    ble-syntax:bash/ctx-pword
    return
  fi
}
function ble-syntax:bash/ctx-pword {
  # パラメータ展開 - word 部
  local rex
  if rex='^([^'"${_ble_syntax_bashc[ctx]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif [[ $tail == '}'* ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
    ((i+=1))
    ble-syntax/parse/nest-pop
    return 0
  elif ble-syntax:bash/check-quotes; then
    return 0
  elif ble-syntax:bash/check-dollar; then
    return 0
  elif [[ $histc12 && $tail == ["$histc12"]* ]]; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

## @const CTX_EXPR
##   算術式の文脈値
##
##   対応する nest types (ntype) の一覧
##
##   NTYPE   NEST-PUSH LOCATION       QUOTE  DESC
##   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##   '$((' @ check-dollar                 x  算術式展開 $(()) の中身
##   '$['  @ check-dollar                 x  算術式展開 $[] の中身
##   '(('  @ .check-delimiter-or-redirect o  算術式評価コマンド (()) の中身
##   'a['  @ .check-assign                o  a[...]= の中身
##   'd['  @ ctx-values                   o  a=([...]=) の中身
##   'v['  @ check-dollar                 o  ${a[...]} の中身
##   '${'  @ check-dollar                 o  ${v:...} の中身
##   '"${' @ check-dollar                 x  "${v:...}" の中身
##   '('   @ .count-paren                 o  () によるネスト (quote 除去有効)
##   'NQ(' @ .count-paren                 x  () によるネスト (quote 除去無効)
##   '['   @ .count-bracket               o  [] によるネスト (quote 除去常時有効)
##
##   QUOTE = o ... 内部で quote 除去が有効
##   QUOTE = x ... 内部で quote 除去は無効
##
_BLE_SYNTAX_FCTX[CTX_EXPR]=ble-syntax:bash/ctx-expr
## 関数 ble-syntax:bash/ctx-expr/.count-paren
##   算術式中の括弧の数 () を数えます。
##   @var ntype 現在の算術式の入れ子の種類を指定します。
##   @var char  括弧文字を指定します。
function ble-syntax:bash/ctx-expr/.count-paren {
  if [[ $char == ')' ]]; then
    if [[ $ntype == '((' || $ntype == '$((' ]]; then
      if [[ $tail == '))'* ]]; then
        ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
        ((i+=2))
        ble-syntax/parse/nest-pop
      else
        # ((echo) > /dev/null) や $((echo) > /dev/null) などの
        # 紛らわしいサブシェル・コマンド置換だったとみなす。
        # それまでに算術式と思っていた部分については仕方がないのでそのまま。
        ((ctx=CTX_ARGX0,
          _ble_syntax_attr[i++]=_ble_syntax_attr[inest]))
      fi
      return 0
    elif [[ $ntype == '(' || $ntype == 'NQ(' ]]; then
      ((_ble_syntax_attr[i++]=ctx))
      ble-syntax/parse/nest-pop
      return 0
    fi
  elif [[ $char == '(' ]]; then
    local ntype2='('
    [[ $ntype == '$((' || $ntype == 'NQ(' ]] && ntype2='NQ('
    ble-syntax/parse/nest-push "$CTX_EXPR" "$ntype2"
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}
## 関数 ble-syntax:bash/ctx-expr/.count-bracket
##   算術式中の括弧の数 [] を数えます。
##   @var ntype 現在の算術式の入れ子の種類を指定します。
##   @var char  括弧文字を指定します。
function ble-syntax:bash/ctx-expr/.count-bracket {
  if [[ $char == ']' ]]; then
    if [[ $ntype == '[' || $ntype == '$[' ]]; then
      # 算術式展開 $[...] や入れ子 ((a[...]=123)) などの場合。
      ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
      ((i++))
      ble-syntax/parse/nest-pop
      return 0
    elif [[ $ntype == [ad]'[' ]]; then
      ((_ble_syntax_attr[i++]=CTX_EXPR))
      ble-syntax/parse/nest-pop
      if [[ $tail == ']='* ]]; then
        # a[...]=, a=([...]=) の場合
        ((i++))
      elif ((_ble_bash>=30100)) && [[ $tail == ']+'* ]]; then
        if [[ $tail == ']+='* ]]; then
          # a[...]+=, a+=([...]+=) の場合
          ((i+=2))
        else
          # 曖昧状態
          ((parse_suppressNextStat=1))
        fi
      else
        if [[ $ntype == 'a[' ]]; then
          # a[...]... という唯のコマンドの場合。
          ((ctx=CTX_CMDI,wtype=CTX_CMDI))
        else
          # '[...]...' という唯の値の場合。
          ((ctx=CTX_VALI,wtype=CTX_VALI))
        fi
      fi
      return 0
    elif [[ $ntype == 'v[' ]]; then
      # ${v[]...} などの場合。
      ((_ble_syntax_attr[i++]=CTX_EXPR))
      ble-syntax/parse/nest-pop
      return 0
    fi
  elif [[ $char == '[' ]]; then
    ble-syntax/parse/nest-push "$CTX_EXPR" '['
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}
## 関数 ble-syntax:bash/ctx-expr/.count-brace
##   算術式中に閉じ波括弧 '}' が来たら算術式を抜けます。
##   @var ntype 現在の算術式の入れ子の種類を指定します。
##   @var char  括弧文字を指定します。
function ble-syntax:bash/ctx-expr/.count-brace {
  if [[ $char == '}' ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
    ((i++))
    ble-syntax/parse/nest-pop
    return 0
  fi

  return 1
}
function ble-syntax:bash/ctx-expr {
  # 式の中身
  local rex
  if rex='^([^'"${_ble_syntax_bashc[ctx]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif [[ $tail == ['][()}']* ]]; then
    local char=${tail::1} ntype
    ble-syntax/parse/nest-type -v ntype
    if [[ $ntype == *'(' ]]; then
      # ntype = '(('  # ((...))
      #       = '$((' # $((...))
      #       = '('   # 式中の (..)
      ble-syntax:bash/ctx-expr/.count-paren && return
    elif [[ $ntype == *'[' ]]; then
      # ntype = 'a[' # ${a[...]}
      #       = 'v[' # v[...]=
      #       = 'd[' # a=([...]=)
      #       = '$[' # $[...]
      #       = '['  # 式中の [...]
      ble-syntax:bash/ctx-expr/.count-bracket && return
    elif [[ $ntype == '${' || $ntype == '"${' ]]; then
      # ntype = '${'  # ${var:offset:length}
      #       = '"${' # "${var:offset:length}"
      ble-syntax:bash/ctx-expr/.count-brace && return
    else
      ble-stackdump "unexpected ntype=$ntype for arithmetic expression"
    fi

    # 入れ子処理されなかった文字は通常文字として処理
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  elif ble-syntax:bash/check-quotes; then
    return 0
  elif ble-syntax:bash/check-dollar; then
    return 0
  elif [[ $histc12 && $tail == ["$histc12"]* ]]; then
    # 恐ろしい事に数式中でも履歴展開が有効…。
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

#------------------------------------------------------------------------------
# 文脈: コマンドライン

_BLE_SYNTAX_FCTX[CTX_ARGX]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGX0]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDX]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXV]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDX1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXC]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXE]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXD]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGI]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDI]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_VRHS]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FEND[CTX_CMDI]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_ARGI]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_VRHS]=ble-syntax:bash/ctx-command/check-word-end

# declare var=value
_BLE_SYNTAX_FCTX[CTX_ARGVX]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGVI]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FEND[CTX_ARGVI]=ble-syntax:bash/ctx-command/check-word-end

# for var in ... / case arg in
_BLE_SYNTAX_FCTX[CTX_FARGX1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_SARGX1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_FARGI1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_FARGX2]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_FARGI2]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CARGX1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CARGI1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CARGX2]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CARGI2]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FEND[CTX_FARGI1]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_FARGI2]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_CARGI1]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_CARGI2]=ble-syntax:bash/ctx-command/check-word-end

## 関数 ble-syntax:bash/starts-with-delimiter-or-redirect
function ble-syntax:bash/starts-with-delimiter-or-redirect {
  local delimiters=$_ble_syntax_bash_rex_delimiters
  local redirect=$_ble_syntax_bash_rex_redirect
  [[ ( $tail =~ ^$delimiters || $wbegin -lt 0 && $tail =~ ^$redirect ) && $tail != ['<>']'('* ]]
}

## 関数 ble-syntax:bash/check-here-document-from spaces
##   @param[in] spaces
function ble-syntax:bash/check-here-document-from {
  local spaces=$1
  [[ $nparam && $spaces == *$'\n'* ]] || return 1
  local rex="$_ble_term_fs@([RI][QH][^$_ble_term_fs]*)(.*$)" && [[ $nparam =~ $rex ]] || return 1

  # ヒアドキュメントの開始
  local rematch1=${BASH_REMATCH[1]}
  local rematch2=${BASH_REMATCH[2]}
  local padding=${spaces%%$'\n'*}
  ((_ble_syntax_attr[i]=ctx,i+=${#padding}))
  nparam=${nparam::${#nparam}-${#BASH_REMATCH}}${nparam:${#nparam}-${#rematch2}}
  ble-syntax/parse/nest-push "$CTX_HERE0"
  ((i++))
  nparam=$rematch1
  return 0
}

## 配列 _ble_syntax_bash_command_ectx
##   単語が終了した後の次の文脈値を設定する。
##   check-word-end で用いる。
_ble_syntax_bash_command_ectx=()
_ble_syntax_bash_command_ectx[CTX_ARGI]=$CTX_ARGX
_ble_syntax_bash_command_ectx[CTX_ARGVI]=$CTX_ARGVX
_ble_syntax_bash_command_ectx[CTX_VRHS]=$CTX_CMDXV
_ble_syntax_bash_command_ectx[CTX_FARGI1]=$CTX_FARGX2
_ble_syntax_bash_command_ectx[CTX_FARGI2]=$CTX_ARGX
_ble_syntax_bash_command_ectx[CTX_CARGI1]=$CTX_CARGX2
_ble_syntax_bash_command_ectx[CTX_CARGI2]=$CTX_CASE
## 配列 _ble_syntax_bash_command_expect
##   許容するコマンドの種類を表す正規表現を設定する。
##   check-word-end で用いる。
##   配列 _ble_syntax_bash_command_bwtype の設定と対応している必要がある。
_ble_syntax_bash_command_expect=()
_ble_syntax_bash_command_expect[CTX_CMDXC]='^(\(|\{|\(\(|\[\[|for|select|case|if|while|until)$'
_ble_syntax_bash_command_expect[CTX_CMDXE]='^(\}|fi|done|esac|then|elif|else|do)$'
_ble_syntax_bash_command_expect[CTX_CMDXD]='^(\{|do)$'
## 配列 _ble_syntax_bash_command_opt
##   その場でコマンドが終わっても良いかどうかを設定する。
##   .check-delimiter-or-redirect で用いる。
_ble_syntax_bash_command_opt=()
_ble_syntax_bash_command_opt[CTX_ARGX]=1
_ble_syntax_bash_command_opt[CTX_ARGX0]=1
_ble_syntax_bash_command_opt[CTX_ARGVX]=1
_ble_syntax_bash_command_opt[CTX_CMDXV]=1
_ble_syntax_bash_command_opt[CTX_CMDXE]=1
_ble_syntax_bash_command_opt[CTX_CMDXD]=1

## 関数 ble-syntax:bash/ctx-command/check-word-end
##   @var[in,out] ctx
##   @var[in,out] wbegin
##   @var[in,out] 他
function ble-syntax:bash/ctx-command/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  local tail="${text:i}"
  [[ $tail == [^"$_ble_syntax_bash_IFS;|&<>()"]* || $tail == ['<>']'('* ]] && return 1

  local wbeg="$wbegin" wlen="$((i-wbegin))" wend="$i"
  local word="${text:wbegin:wlen}"
  local wt="$wtype"

  # 特定のコマンドのみを受け付ける文脈
  local rex_expect_command=${_ble_syntax_bash_command_expect[wt]}
  if [[ $rex_expect_command ]]; then
    if [[ $word =~ $rex_expect_command ]]; then
      ((wtype=CTX_CMDI))
    else
      ((wtype=ATTR_ERR))
    fi
  fi

  ble-syntax/parse/word-pop

  if ((ctx==CTX_CMDI)); then
    case "$word" in
    ('[[')
      # 条件コマンド開始
      ble-syntax/parse/touch-updated-attr "$wbeg"
      ((_ble_syntax_attr[wbeg]=ATTR_DEL,
        ctx=CTX_ARGX0))

      # work-around: 一旦 word "[[" を削除
      ble-syntax/parse/word-cancel

      i="$wbeg" ble-syntax/parse/nest-push "$CTX_CONDX"

      # work-around: word "[[" を nest 内部に設置し直す
      i="$wbeg" ble-syntax/parse/word-push "$CTX_CMDI" "$wbeg"
      ble-syntax/parse/word-pop

      return 0 ;;
    ('time')
      ((ctx=CTX_CMDX1,parse_suppressNextStat=1))
      if [[ ${text:i} =~ ^$_ble_syntax_bash_rex_spaces ]]; then
        ((_ble_syntax_attr[i]=CTX_CMDX,
          i+=${#BASH_REMATCH}))
      fi

      if [[ ${text:i} == -p* ]] &&
           tail=${text:i+2} ble-syntax:bash/starts-with-delimiter-or-redirect
      then
        ble-syntax/parse/word-push "$CTX_ARGI" "$i"
        ((_ble_syntax_attr[i]=CTX_ARGI,i+=2))
        ble-syntax/parse/word-pop
      fi ;;
    (['!{']|'do'|'if'|'then'|'elif'|'else'|'while'|'until')
      ((ctx=CTX_CMDX1)) ;;
    ('for')    ((ctx=CTX_FARGX1)) ;;
    ('select') ((ctx=CTX_SARGX1)) ;;
    ('case')   ((ctx=CTX_CARGX1)) ;;
    ('}'|'done'|'fi'|'esac')
      ((ctx=CTX_CMDXE)) ;;
    ('declare'|'readonly'|'typeset'|'local'|'export'|'alias')
      ((ctx=CTX_ARGVX)) ;;
    ('function')
      ((ctx=CTX_ARGX))
      local processed=0
      local isfuncsymx=$'\t\n'' "$&'\''();<>\`|' rex_space=$'[ \t]' rex
      if rex="^$rex_space+" && [[ ${text:i} =~ $rex ]]; then
        ((_ble_syntax_attr[i]=CTX_ARGX,i+=${#BASH_REMATCH},ctx=CTX_ARGX))
        if rex="^([^#$isfuncsymx][^$isfuncsymx]*)($rex_space*)(\(\(|\($rex_space*\)?)?" && [[ ${text:i} =~ $rex ]]; then
          local rematch1="${BASH_REMATCH[1]}"
          local rematch2="${BASH_REMATCH[2]}"
          local rematch3="${BASH_REMATCH[3]}"
          ((_ble_syntax_attr[i]=ATTR_FUNCDEF,i+=${#rematch1},
            ${#rematch2}&&(_ble_syntax_attr[i]=CTX_CMDX1,i+=${#rematch2})))

          if [[ $rematch3 == '('*')' ]]; then
            ((_ble_syntax_attr[i]=ATTR_DEL,i+=${#rematch3},ctx=CTX_CMDXC))
          elif [[ $rematch3 == '('* && $rematch3 != '((' ]]; then
            ((_ble_syntax_attr[i]=ATTR_ERR,ctx=CTX_ARGX0))
            ble-syntax/parse/nest-push "$CTX_CMDX1" '('
            ((${#rematch3}>=2&&(_ble_syntax_attr[i+1]=CTX_CMDX1),i+=${#rematch3}))
          else
            ((ctx=CTX_CMDXC))
          fi
          ((processed=1))
        fi
      fi
      ((processed||(_ble_syntax_attr[i-1]=ATTR_ERR))) ;;
    (*)
      # 関数定義である可能性を考え stat を置かず読み取る
      ((ctx=CTX_ARGX))
      if local rex='^([ 	]*)(\([ 	]*\)?)?' && [[ ${text:i} =~ $rex ]]; then

        # for bash-3.1 ${#arr[n]} bug
        local rematch1="${BASH_REMATCH[1]}"
        local rematch2="${BASH_REMATCH[2]}"

        if [[ $rematch2 == '('*')' ]]; then
          # case: /hoge ( *)/ 関数定義 (単語の種類を変更)
          #   上方の ble-syntax/parse/word-pop で設定した値を書き換え。
          _ble_syntax_tree[i-1]="$ATTR_FUNCDEF ${_ble_syntax_tree[i-1]#* }"

          ((_ble_syntax_attr[i]=CTX_CMDX1,i+=${#rematch1},
            _ble_syntax_attr[i]=ATTR_DEL,i+=${#rematch2},
            ctx=CTX_CMDXC))
        elif [[ $rematch2 == '('* ]]; then
          # case: /hoge \( */ 括弧が閉じていない場合:
          #   仕方がないので extglob 括弧と思って取り敢えず解析する
          ((_ble_syntax_attr[i]=CTX_ARGX0,i+=${#rematch1},
            _ble_syntax_attr[i]=ATTR_ERR,
            ctx=CTX_ARGX0))
          ble-syntax/parse/nest-push "$CTX_PATN"
          ((${#rematch2}>=2&&(_ble_syntax_attr[i+1]=CTX_CMDXC),
            i+=${#rematch2}))
          return 0
        else
          # case: /hoge */ 恐らくコマンド
          ((_ble_syntax_attr[i]=CTX_ARGX,i+=${#rematch1}))
        fi
      fi ;;
    esac
    return 0
  fi

  if ((ctx==CTX_FARGI2)); then
    # for name do ...; done
    if [[ $word == do ]]; then
      ((ctx=CTX_CMDX1))
      return 0
    fi
  fi

  if ((ctx==CTX_FARGI2||ctx==CTX_CARGI2)); then
    if [[ $word != in ]];  then
      ble-syntax/parse/touch-updated-attr "$wbeg"
      ((_ble_syntax_attr[wbeg]=ATTR_ERR))
    fi
  fi

  if ((_ble_syntax_bash_command_ectx[ctx])); then
    ((ctx=_ble_syntax_bash_command_ectx[ctx]))
  fi

  return 0
}

function ble-syntax:bash/ctx-command/.check-delimiter-or-redirect {
  if [[ $tail =~ ^$_ble_syntax_bash_rex_IFSs ]]; then
    # 空白

    # 改行がある場合: ヒアドキュメントの確認 / 改行による文脈更新
    local spaces=$BASH_REMATCH
    if [[ $spaces == *$'\n'* ]]; then
      ble-syntax:bash/check-here-document-from "$spaces" && return 0
      ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||ctx==CTX_CMDXV)) && ((ctx=CTX_CMDX))
    fi

    # ctx はそのままで素通り
    ((_ble_syntax_attr[i]=ctx,i+=${#spaces}))
    return 0

  elif [[ $tail =~ ^$_ble_syntax_bash_rex_redirect ]]; then
    # リダイレクト (& 単体の解釈より優先する)

    # for bash-3.1 ${#arr[n]} bug ... 一旦 rematch1 に入れてから ${#rematch1} で文字数を得る。
    local len=${#BASH_REMATCH}
    local rematch1=${BASH_REMATCH[1]}
    local rematch3=${BASH_REMATCH[3]}
    ((_ble_syntax_attr[i]=ATTR_DEL,
      ${#rematch1}<len&&(_ble_syntax_attr[i+${#rematch1}]=CTX_ARGX)))
    if ((ctx==CTX_CMDX||ctx==CTX_CMDX1)); then
      ((ctx=CTX_CMDXV))
    elif ((ctx==CTX_CMDXC||ctx==CTX_CMDXD)); then
      ((ctx=CTX_CMDXV,
        _ble_syntax_attr[i]=ATTR_ERR))
    elif ((ctx==CTX_CMDXE)); then
      ((ctx=CTX_ARGX0))
    fi

    if [[ $rematch1 == *'&' ]]; then
      ble-syntax/parse/nest-push "$CTX_RDRD" "$rematch3"
    elif [[ $rematch1 == *'<<<' ]]; then
      ble-syntax/parse/nest-push "$CTX_RDRS" "$rematch3"
    elif [[ $rematch1 == *\<\< ]]; then
      # Note: emacs bug workaround
      #   '<<' と書くと何故か Emacs がヒアドキュメントと
      #   勘違いする様になったので仕方なく \<\< とする。
      ble-syntax/parse/nest-push "$CTX_RDRH" "$rematch3"
    elif [[ $rematch1 == *\<\<- ]]; then
      ble-syntax/parse/nest-push "$CTX_RDRI" "$rematch3"
    else
      ble-syntax/parse/nest-push "$CTX_RDRF" "$rematch3"
    fi
    ((i+=len))
    return 0
  elif local rex='^(&&|\|[|&]?)|^;(;&?|&)|^[;&]' && [[ $tail =~ $rex ]]; then
    # 制御演算子 && || | & ; |& ;; ;;&

    # for bash-3.1 ${#arr[n]} bug
    local rematch1="${BASH_REMATCH[1]}" rematch2="${BASH_REMATCH[2]}"
    ((_ble_syntax_attr[i]=ATTR_DEL,
      (_ble_syntax_bash_command_opt[ctx]||ctx==CTX_CMDX&&${#rematch2})||
        (_ble_syntax_attr[i]=ATTR_ERR)))
    ((ctx=${#rematch1}?CTX_CMDX1:(
         ${#rematch2}?CTX_CASE:
         CTX_CMDX)))
    ((i+=${#BASH_REMATCH}))
    return 0
  elif local rex='^\(\(?' && [[ $tail =~ $rex ]]; then
    # サブシェル (, 算術コマンド ((
    local m="${BASH_REMATCH[0]}"
    if ((ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXC)); then
      ((_ble_syntax_attr[i]=ATTR_DEL))
      ((ctx=CTX_ARGX0))
      [[ $is_command_form_for && $tail == '(('* ]] && ((ctx=CTX_CMDXD))
      ble-syntax/parse/nest-push "$((${#m}==1?CTX_CMDX1:CTX_EXPR))" "$m"
      ((i+=${#m}))
    else
      ble-syntax/parse/nest-push "$CTX_PATN"
      ((_ble_syntax_attr[i++]=ATTR_ERR))
    fi
    return 0
  elif [[ $tail == ')'* ]]; then
    local ntype
    ble-syntax/parse/nest-type -v ntype
    local attr=
    if [[ $ntype == '(' || $ntype == '$(' || $ntype == '((' || $ntype == '$((' ]]; then
      # 1 $ntype == '('
      #   ( sub shell )
      #   <( process substitution )
      #   func ( invalid )
      # 2 $ntype== '$('
      #   $(command substitution)
      # 3 $ntype == '((', '$(('
      #   ((echo) >/dev/null) / $((echo) >/dev/null)
      #   ※これは当初は算術式だと思っていたら実はサブシェルだったというパターン
      ((attr=_ble_syntax_attr[inest]))
    fi

    if [[ $attr ]]; then
      ((_ble_syntax_attr[i]=(ctx==CTX_CMDX||ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||ctx==CTX_CMDXV)?attr:ATTR_ERR,
        i+=1))
      ble-syntax/parse/nest-pop
      return 0
    fi
  fi

  return 1
}

## 関数 ble-syntax:bash/ctx-command/.check-word-begin
##   単語が未開始の場合に開始します。
##   @var[in,out] i,ctx,wtype,wbegin
##   @return 引数が来てはならない所に引数が来た時に 1 を返します。
_ble_syntax_bash_command_bctx=()
_ble_syntax_bash_command_bctx[CTX_ARGX]=$CTX_ARGI
_ble_syntax_bash_command_bctx[CTX_ARGX0]=$CTX_ARGI
_ble_syntax_bash_command_bctx[CTX_ARGVX]=$CTX_ARGVI
_ble_syntax_bash_command_bctx[CTX_CMDX]=$CTX_CMDI
_ble_syntax_bash_command_bctx[CTX_CMDX1]=$CTX_CMDI
_ble_syntax_bash_command_bctx[CTX_CMDXC]=$CTX_CMDI
_ble_syntax_bash_command_bctx[CTX_CMDXE]=$CTX_CMDI
_ble_syntax_bash_command_bctx[CTX_CMDXD]=$CTX_CMDI
_ble_syntax_bash_command_bctx[CTX_CMDXV]=$CTX_CMDI
_ble_syntax_bash_command_bctx[CTX_FARGX1]=$CTX_FARGI1
_ble_syntax_bash_command_bctx[CTX_SARGX1]=$CTX_FARGI1
_ble_syntax_bash_command_bctx[CTX_FARGX2]=$CTX_FARGI2
_ble_syntax_bash_command_bctx[CTX_CARGX1]=$CTX_CARGI1
_ble_syntax_bash_command_bctx[CTX_CARGX2]=$CTX_CARGI2
_ble_syntax_bash_command_bwtype[CTX_CMDXC]=$CTX_CMDXC # check-word-end で処理する
_ble_syntax_bash_command_bwtype[CTX_CMDXE]=$CTX_CMDXE # check-word-end で処理する
_ble_syntax_bash_command_bwtype[CTX_CMDXD]=$CTX_CMDXD # check-word-end で処理する
_ble_syntax_bash_command_bwtype[CTX_CARGX1]=$CTX_ARGI
#%if !release
_ble_syntax_bash_command_isARGI[CTX_CMDI]=1
_ble_syntax_bash_command_isARGI[CTX_ARGI]=1
_ble_syntax_bash_command_isARGI[CTX_ARGVI]=1
_ble_syntax_bash_command_isARGI[CTX_VRHS]=1
_ble_syntax_bash_command_isARGI[CTX_FARGI1]=1
_ble_syntax_bash_command_isARGI[CTX_FARGI2]=1
_ble_syntax_bash_command_isARGI[CTX_CARGI1]=1
_ble_syntax_bash_command_isARGI[CTX_CARGI2]=1
#%end
function ble-syntax:bash/ctx-command/.check-word-begin {
  if ((wbegin<0)); then
    local octx
    ((octx=ctx,
      ctx=_ble_syntax_bash_command_bctx[ctx]))
    ((wtype=_ble_syntax_bash_command_bwtype[octx])) || ((wtype=ctx))
#%if !release
    if ((ctx==0)); then
      ((ctx=wtype=CTX_ARGI))
      ble-stackdump "invalid ctx=$octx at the beginning of words"
    fi
#%end
    ble-syntax/parse/word-push "$wtype" "$i"

    ((ctx!=CTX_ARGX0)); return # return unexpectedWbegin
  fi

#%if !release
  ((_ble_syntax_bash_command_isARGI[ctx])) || ble-stackdump "invalid ctx=$ctx in words"
#%end
  return 0
}

## 関数 ble-syntax:bash/ctx-command/.check-assign
## @var[in] tail
function ble-syntax:bash/ctx-command/.check-assign {
  ((wbegin==i)) || return 1
  ((ctx==CTX_CMDI||ctx==CTX_ARGVI)) || return 1

  # パターン一致 (var= var+= arr[ のどれか)
  local suffix='=|\+=?'
  ((_ble_bash<30100)) && suffix='='
  if ((ctx==CTX_CMDI)); then
    suffix="$suffix|\["
  elif ((ctx==CTX_ARGVI)); then
    suffix="$suffix|"
  fi
  local rex_assign="^[a-zA-Z_][a-zA-Z_0-9]*($suffix)"
  [[ $tail =~ $rex_assign ]] || return 1
  local rematch1="${BASH_REMATCH[1]}" # for bash-3.1 ${#arr[n]} bug
  if [[ $rematch1 == '+' ]]; then
    # var+... 曖昧状態
    ((parse_suppressNextStat=1))
    return 1
  fi

  ((wtype=ATTR_VAR,
    _ble_syntax_attr[i]=ATTR_VAR,
    i+=${#BASH_REMATCH},
    ${#rematch1}&&(_ble_syntax_attr[i-${#rematch1}]=CTX_EXPR)))
  ((ctx==CTX_CMDI&&(ctx=CTX_VRHS)))
  if [[ $rematch1 == '[' ]]; then
    # arr[
    i=$((i-1)) ble-syntax/parse/nest-push "$CTX_EXPR" 'a['
  elif [[ $rematch1 == *'=' && ${text:i} == '('* ]]; then
    # var=( var+=(

    # * nest-pop した直後は未だ CTX_VRHS, CTX_ARGVI の続きになっている。
    #   例: a=(1 2)b=1 は a='(1 2)b=1' と解釈される。
    #   従って ctx (nest-pop 時の文脈) はそのまま (CTX_VRHS, CTX_ARGVI) にする。

    ble-syntax:bash/ctx-values/enter
    ((_ble_syntax_attr[i++]=ATTR_DEL))
  fi

  return 0
}

# コマンド・引数部分
function ble-syntax:bash/ctx-command {
  local is_command_form_for=
  if ble-syntax:bash/starts-with-delimiter-or-redirect; then
    if ((ctx==CTX_FARGX1||ctx==CTX_SARGX1||ctx==CTX_CARGX1||ctx==CTX_FARGX2||ctx==CTX_CARGX2)); then
      # "for var in ... / case arg in" を処理している途中で delimiter が来た場合。
      if ((ctx==CTX_FARGX2)) && [[ $tail == [$';\n']* ]]; then
        # for var in ... の in 以降が省略された形である。
        # ここで return せずに以降の CTX_ARGX 用の処理に任せる
        ((ctx=CTX_ARGX))
      elif ((ctx==CTX_FARGX1)) && [[ $tail == '(('* ]]; then
        # for ((...)) の場合
        # ここで return せずに以降の CTX_CMDX1 用の処理に任せる
        ((ctx=CTX_CMDX1,is_command_form_for=1))
      elif [[ $tail == $'\n'* ]]; then
        if ((ctx==CTX_CARGX2)); then
          ((_ble_syntax_attr[i++]=CTX_ARGX))
        else
          ((_ble_syntax_attr[i++]=ATTR_ERR,ctx=CTX_ARGX))
        fi
        return 0
      elif [[ $tail =~ ^$_ble_syntax_bash_rex_spaces ]]; then
        ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
        return 0
      else
        local i0=$i
        ((ctx=CTX_ARGX))
        ble-syntax:bash/ctx-command/.check-delimiter-or-redirect || ((i++))
        ((_ble_syntax_attr[i0]=ATTR_ERR))
        return 0
      fi
    fi

#%if !release
    ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||
        ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXC||ctx==CTX_CMDXE||ctx==CTX_CMDXD||ctx==CTX_CMDXV)) || ble-stackdump "invalid ctx=$ctx @ i=$i"
    ((wbegin<0&&wtype<0)) || ble-stackdump "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
#%end
    ble-syntax:bash/ctx-command/.check-delimiter-or-redirect; return
  fi

  if local i0=$i; ble-syntax:bash/check-comment; then
    if ((ctx==CTX_FARGX1||ctx==CTX_SARGX1||ctx==CTX_CARGX1)); then
      # "for var / select var / case arg" を処理している途中でコメントが来た場合
      ((_ble_syntax_attr[i0]=ATTR_ERR))
    fi
    return 0
  fi

  local unexpectedWbegin=-1
  ble-syntax:bash/ctx-command/.check-word-begin || ((unexpectedWbegin=i))

  local flagConsume=0 rex
  if ble-syntax:bash/ctx-command/.check-assign; then
    flagConsume=1
  elif rex='^([^'"${_ble_syntax_bashc[CTX_ARGI]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    flagConsume=1
  elif ble-syntax:bash/check-process-subst; then
    flagConsume=1
  elif ble-syntax:bash/check-quotes; then
    flagConsume=1
  elif ble-syntax:bash/check-dollar; then
    flagConsume=1
  elif ble-syntax:bash/check-glob; then
    flagConsume=1
  elif [[ $histc12 && $tail == ["$histc12"]* ]]; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    flagConsume=1
  fi

  if ((flagConsume)); then
    if ((unexpectedWbegin>=0)); then
      ble-syntax/parse/touch-updated-attr "$unexpectedWbegin"
      ((_ble_syntax_attr[unexpectedWbegin]=ATTR_ERR))
    fi
    return 0
  else
    return 1
  fi
}

#------------------------------------------------------------------------------
# 文脈: 配列値リスト
#

_BLE_SYNTAX_FCTX[CTX_VALX]=ble-syntax:bash/ctx-values
_BLE_SYNTAX_FCTX[CTX_VALI]=ble-syntax:bash/ctx-values
_BLE_SYNTAX_FEND[CTX_VALI]=ble-syntax:bash/ctx-values/check-word-end

## 文脈値 ctx-values
##
##   arr=() arr+=() から抜けた時にまた元の文脈値に復帰する必要があるので
##   nest-push, nest-pop で入れ子構造を一段作成する事にする。
##
##   但し、外側で設定されたヒアドキュメントを処理する為に工夫が必要である。
##   外側の nparam をそのまま利用しまた抜ける場合には外側の nparam に変更結果を適用する。
##   ble-syntax:bash/ctx-values/enter, leave はこの nparam の持ち越しに使用する。
##

## 関数 ble-syntax:bash/ctx-values/enter
##   @remarks この関数は ble-syntax:bash/ctx-command/.check-assign から呼ばれる。
function ble-syntax:bash/ctx-values/enter {
  local outer_nparam=$nparam
  ble-syntax/parse/nest-push "$CTX_VALX"
  nparam=$outer_nparam
}
## 関数 ble-syntax:bash/ctx-values/leave
function ble-syntax:bash/ctx-values/leave {
  local inner_nparam=$nparam
  ble-syntax/parse/nest-pop
  nparam=$inner_nparam
}

## 関数 ble-syntax:bash/ctx-values/check-word-end
function ble-syntax:bash/ctx-values/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  [[ ${text:i:1} == [^"$_ble_syntax_bash_IFS;|&<>()"] ]] && return 1

  local wbeg="$wbegin" wlen="$((i-wbegin))" wend="$i"
  local word="${text:wbegin:wlen}"

  ble-syntax/parse/word-pop

  ble-assert '((ctx==CTX_VALI))' 'invalid context'
  ((ctx=CTX_VALX))

  return 0
}

function ble-syntax:bash/ctx-values {
  # コマンド・引数部分
  local rex_delimiters="^$_ble_syntax_bash_rex_delimiters"
  if [[ $tail =~ $rex_delimiters && $tail != ['<>']'('* ]]; then
#%if !release
    ((ctx==CTX_VALX)) || ble-stackdump "invalid ctx=$ctx @ i=$i"
    ((wbegin<0&&wtype<0)) || ble-stackdump "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
#%end

    if [[ $tail =~ ^$_ble_syntax_bash_rex_IFSs ]]; then
      local spaces=$BASH_REMATCH
      ble-syntax:bash/check-here-document-from "$spaces" && return 0

      # 空白 (ctx はそのままで素通り)
      ((_ble_syntax_attr[i]=ctx,i+=${#spaces}))
      return 0
    elif [[ $tail == ')'* ]]; then
      # 配列定義の終了
      ((_ble_syntax_attr[i++]=ATTR_DEL))
      ble-syntax:bash/ctx-values/leave
      return 0
    elif [[ $type == ';'* ]]; then
      ((_ble_syntax_attr[i++]=ATTR_ERR))
      return 0
    else
      ((_ble_syntax_attr[i++]=ATTR_ERR))
      return 0
    fi
  fi

  if ble-syntax:bash/check-comment; then
    return 0
  fi

  if ((wbegin<0)); then
    ((ctx=CTX_VALI))
    ble-syntax/parse/word-push "$ctx" "$i"
  fi

#%if !release
  ble-assert '((ctx==CTX_VALI))' "invalid context ctx=$ctx"
#%end

  local rex
  if ((wbegin==i)) && [[ $tail == '['* ]]; then
    ble-syntax/parse/nest-push "$CTX_EXPR" 'd['
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  elif rex='^([^'"${_ble_syntax_bashc[CTX_ARGI]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif ble-syntax:bash/check-process-subst; then
    return 0
  elif ble-syntax:bash/check-quotes; then
    return 0
  elif ble-syntax:bash/check-dollar; then
    return 0
  elif ble-syntax:bash/check-glob; then
    return 0
  elif [[ $histc12 && $tail == ["$histc12"]* ]]; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

#------------------------------------------------------------------------------
# 文脈: [[ 条件式 ]]

_BLE_SYNTAX_FCTX[CTX_CONDX]=ble-syntax:bash/ctx-conditions
_BLE_SYNTAX_FCTX[CTX_CONDI]=ble-syntax:bash/ctx-conditions
_BLE_SYNTAX_FEND[CTX_CONDI]=ble-syntax:bash/ctx-conditions/check-word-end

## 関数 ble-syntax:bash/ctx-values/check-word-end
function ble-syntax:bash/ctx-conditions/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  [[ ${text:i:1} == [^"$_ble_syntax_bash_IFS;|&<>()"] ]] && return 1

  local wbeg="$wbegin" wlen="$((i-wbegin))" wend="$i"
  local word="${text:wbegin:wlen}"

  ble-syntax/parse/word-pop

  ble-assert '((ctx==CTX_CONDI))' 'invalid context'
  if [[ $word == ']]' ]]; then
    ble-syntax/parse/touch-updated-attr "$wbeg"
    ((_ble_syntax_attr[wbeg]=ATTR_CMD_KEYWORD))
    ble-syntax/parse/nest-pop
  else
    ((ctx=CTX_CONDX))
  fi
  return 0
}

function ble-syntax:bash/ctx-conditions {
  # コマンド・引数部分
  if [[ $tail =~ ^$_ble_syntax_bash_rex_delimiters && $tail != ['<>']'('* ]]; then
#%if !release
    ((ctx==CTX_CONDX)) || ble-stackdump "invalid ctx=$ctx @ i=$i"
    ((wbegin<0&&wtype<0)) || ble-stackdump "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
#%end

    if [[ $tail =~ ^$_ble_syntax_bash_rex_IFSs ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      return 0
    else
      # [(<>;|&] など
      ((_ble_syntax_attr[i++]=ATTR_CONDI))
      return 0
    fi
  fi

  if ble-syntax:bash/check-comment; then
    return 0
  fi

  if ((wbegin<0)); then
    ((ctx=CTX_CONDI))
    ble-syntax/parse/word-push "$ctx" "$i"
  fi

#%if !release
  ble-assert '((ctx==CTX_CONDI))' "invalid context ctx=$ctx"
#%end

  local rex
  if rex='^([^'"${_ble_syntax_bashc[CTX_ARGI]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif ble-syntax:bash/check-process-subst; then
    return 0
  elif ble-syntax:bash/check-quotes; then
    return 0
  elif ble-syntax:bash/check-dollar; then
    return 0
  elif ble-syntax:bash/check-glob; then
    return 0
  elif [[ $histc12 && $tail == ["$histc12"]* ]]; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i++]=ctx))
    return 0
  else
    # 条件コマンドの時は $ や ) 等を許す。。
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}


#------------------------------------------------------------------------------
# 文脈: リダイレクト

_BLE_SYNTAX_FCTX[CTX_RDRF]=ble-syntax:bash/ctx-redirect
_BLE_SYNTAX_FCTX[CTX_RDRD]=ble-syntax:bash/ctx-redirect
_BLE_SYNTAX_FCTX[CTX_RDRS]=ble-syntax:bash/ctx-redirect
_BLE_SYNTAX_FEND[CTX_RDRF]=ble-syntax:bash/ctx-redirect/check-word-end
_BLE_SYNTAX_FEND[CTX_RDRD]=ble-syntax:bash/ctx-redirect/check-word-end
_BLE_SYNTAX_FEND[CTX_RDRS]=ble-syntax:bash/ctx-redirect/check-word-end
function ble-syntax:bash/ctx-redirect/check-word-begin {
  if ((wbegin<0)); then
    # ※解析の段階では CTX_RDRF/CTX_RDRD/CTX_RDRS の間に区別はない。
    #   但し、↓の行で解析に用いられた ctx が保存される。
    #   この情報は後で補完候補を生成するのに用いられる。
    ble-syntax/parse/word-push "$ctx" "$i"
    ble-syntax/parse/touch-updated-word "$i" #■これは不要では?
  fi
}
function ble-syntax:bash/ctx-redirect/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  local tail="${text:i}"
  [[ $tail == [^"$_ble_syntax_bash_IFS;|&<>()"]* || $tail == ['<>']'('* ]] && return 1

  # 単語の登録
  ble-syntax/parse/word-pop

  # pop
  ble-syntax/parse/nest-pop
#%if !release
  # ここで終端の必要のある ctx (CMDI や ARGI などの単語中の文脈) になる事は無い。
  # 何故なら push した時は CMDX か ARGX の文脈にいたはずだから。
  ((!_ble_syntax_bash_command_isARGI[ctx])) || ble-stackdump "invalid ctx=$ctx in words"
#%end
  return 0
}
function ble-syntax:bash/ctx-redirect {
  # redirect の直後にコマンド終了や別の redirect があってはならない
  if ble-syntax:bash/starts-with-delimiter-or-redirect; then
    ((_ble_syntax_attr[i++]=ATTR_ERR))
    [[ ${tail:1} =~ ^$_ble_syntax_bash_rex_spaces ]] &&
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
    return 0
  fi

  if local i0=$i; ble-syntax:bash/check-comment; then
    ((_ble_syntax_attr[i0]=ATTR_ERR))
    return 0
  fi

  # 単語開始の設置
  ble-syntax:bash/ctx-redirect/check-word-begin

  local rex
  if rex='^([^'"${_ble_syntax_bashc[CTX_ARGI]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif ble-syntax:bash/check-process-subst; then
    return 0
  elif ble-syntax:bash/check-quotes; then
    return 0
  elif ble-syntax:bash/check-dollar; then
    return 0
  elif ble-syntax:bash/check-glob; then
    return 0
  elif [[ $histc12 && $tail == ["$histc12"]* ]]; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

#------------------------------------------------------------------------------
# 文脈: ヒアドキュメント
#
# | <<[-] word
# | contents
# | delimiter
#
# ctx-heredoc-word (word の解析) は ctx-redirect を参考にして作成する。
#

_ble_syntax_bash_heredoc_escSP='\040'
_ble_syntax_bash_heredoc_escHT='\011'
_ble_syntax_bash_heredoc_escLF='\012'
_ble_syntax_bash_heredoc_escFS='\034'
function ble-syntax:bash/ctx-heredoc-word/initialize {
  local ret
  ble/util/s2c ' '
  ble/util/sprintf _ble_syntax_bash_heredoc_escSP '\\%03o' "$ret"
  ble/util/s2c $'\t'
  ble/util/sprintf _ble_syntax_bash_heredoc_escHT '\\%03o' "$ret"
  ble/util/s2c $'\n'
  ble/util/sprintf _ble_syntax_bash_heredoc_escLF '\\%03o' "$ret"
  ble/util/s2c "$_ble_term_fs"
  ble/util/sprintf _ble_syntax_bash_heredoc_escFS '\\%03o' "$ret"
}
ble-syntax:bash/ctx-heredoc-word/initialize

## 関数 ble-syntax:bash/ctx-heredoc-word/remove-quotes word
##   @var[out] delimiter
function ble-syntax:bash/ctx-heredoc-word/remove-quotes {
  local text=$1 result=

  local rex1='^[^\$"'\'']+|^\$?["'\'']|^\\.?|^.'
  while [[ $text && $text =~ $rex1 ]]; do
    local rematch=$BASH_REMATCH
    if [[ $rematch == \" || $rematch == \$\" ]]; then
      if rex='^\$?"(([^\"]|\\.)*)(\\?$|")'; [[ $text =~ $rex ]]; then
        local str=${BASH_REMATCH[1]}
        local a b
        b='\`' a='`'; str="${str//"$b"/$a}"
        b='\"' a='"'; str="${str//"$b"/$a}"
        b='\$' a='$'; str="${str//"$b"/$a}"
        b='\\' a='\'; str="${str//"$b"/$a}"
        result=$result$str
        text=${text:${#BASH_REMATCH}}
        continue
      fi
    elif [[ $rematch == \' ]]; then
      if rex="^('[^']*)'?"; [[ $text =~ $rex ]]; then
        eval "result=\$result${BASH_REMATCH[1]}'"
        text=${text:${#BASH_REMATCH}}
        continue
      fi
    elif [[ $rematch == \$\' ]]; then
      if rex='^(\$'\''([^\'\'']|\\.)*)('\''|\\?$)'; [[ $text =~ $rex ]]; then
        eval "result=\$result${BASH_REMATCH[1]}'"
        text=${text:${#BASH_REMATCH}}
        continue
      fi
    elif [[ $rematch == \\* ]]; then
      result=$result${rematch:1}
      text=${text:${#rematch}}
      continue
    fi

    result=$result$rematch
    text=${text:${#rematch}}
  done

  delimiter=$result$text
}

## 関数 ble-syntax:bash/ctx-heredoc-word/remove-quotes delimiter
##   @var[out] escaped
function ble-syntax:bash/ctx-heredoc-word/escape-delimiter {
  local ret=$1
  if [[ $ret == *[\\\'$_ble_syntax_bash_IFS$_ble_term_fs]* ]]; then
    local a b fs=$_ble_term_fs
    a=\\   ; b="\\$a"; ret="${ret//"$a"/$b}"
    a=\'   ; b="\\$a"; ret="${ret//"$a"/$b}"
    a=' '  ; b="$_ble_syntax_bash_heredoc_escSP"; ret="${ret//"$a"/$b}"
    a=$'\t'; b="$_ble_syntax_bash_heredoc_escHT"; ret="${ret//"$a"/$b}"
    a=$'\n'; b="$_ble_syntax_bash_heredoc_escLF"; ret="${ret//"$a"/$b}"
    a=$fs  ; b="$_ble_syntax_bash_heredoc_escFS"; ret="${ret//"$a"/$b}"
  fi
  escaped=$ret
}
function ble-syntax:bash/ctx-heredoc-word/unescape-delimiter {
  eval "delimiter=\$'$1'"
}

## 文脈値 CTX_RDRH
##
##   @remarks
##     redirect と同様に nest-push と同時にこの文脈に入る事を想定する。
##
_BLE_SYNTAX_FCTX[CTX_RDRH]=ble-syntax:bash/ctx-heredoc-word
_BLE_SYNTAX_FEND[CTX_RDRH]=ble-syntax:bash/ctx-heredoc-word/check-word-end
_BLE_SYNTAX_FCTX[CTX_RDRI]=ble-syntax:bash/ctx-heredoc-word
_BLE_SYNTAX_FEND[CTX_RDRI]=ble-syntax:bash/ctx-heredoc-word/check-word-end
function ble-syntax:bash/ctx-heredoc-word/check-word-end {
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  local tail="${text:i}"
  [[ $tail == [^"$_ble_syntax_bash_IFS;|&<>()"]* || $tail == ['<>']'('* ]] && return 1

  # word = "EOF" 等の終端文字列
  local octx=$ctx word=${text:wbegin:i-wbegin}

  # 終了処理
  ble-syntax/parse/word-pop
  ble-syntax/parse/nest-pop
  
  local I
  if ((octx==CTX_RDRI)); then I=I; else I=R; fi

  local Q delimiter
  if [[ $word == *[\'\"\\]* ]]; then
    Q=Q; ble-syntax:bash/ctx-heredoc-word/remove-quotes "$word"
  else
    Q=H; delimiter=$word
  fi

  local escaped; ble-syntax:bash/ctx-heredoc-word/escape-delimiter "$delimiter"
  nparam="$nparam$_ble_term_fs@$I$Q$escaped"
  return 0
}
function ble-syntax:bash/ctx-heredoc-word {
  ble-syntax:bash/ctx-redirect
}

## 文脈値 CTX_HERE0, CTX_HERE1
##
##   nest-push された環境で評価される。
##   nparam =~ [RI][QH]delimiter の形式を持つ。
##
_BLE_SYNTAX_FCTX[CTX_HERE0]=ble-syntax:bash/ctx-heredoc-content
_BLE_SYNTAX_FCTX[CTX_HERE1]=ble-syntax:bash/ctx-heredoc-content
function ble-syntax:bash/ctx-heredoc-content {
  local indented= quoted= delimiter=
  ble-syntax:bash/ctx-heredoc-word/unescape-delimiter "${nparam:2}"
  [[ ${nparam::1} == I ]] && indented=1
  [[ ${nparam:1:1} == Q ]] && quoted=1

  local rex ht=$'\t' lf=$'\n'
  if ((ctx==CTX_HERE0)); then
    rex="^${indented:+$ht*}"$'([^\n]+\n?|\n)'
    [[ $tail =~ $rex ]] || return 1

    # ヒアドキュメント終了判定
    # ※前後の空白も含めて行が delimiter と一致していなければならない。
    local line=${BASH_REMATCH%"$lf"}
    local rematch1=${BASH_REMATCH[1]}
    if [[ ${rematch1%"$lf"} == "$delimiter" ]]; then
      local indent
      ((indent=${#BASH_REMATCH}-${#rematch1},
        _ble_syntax_attr[i]=CTX_HERE0,
        _ble_syntax_attr[i+indent]=CTX_RDRH,
        i+=${#line}))
      ble-syntax/parse/nest-pop
      return 0
    fi
  fi

  if [[ $quoted ]]; then
    ble-assert '((ctx==CTX_HERE0))'
    ((_ble_syntax_attr[i]=CTX_HERE0,i+=${#BASH_REMATCH}))
    return 0
  else
    ((ctx=CTX_HERE1))

    # \? 及び $? ${} $(()) $[] $() ``
    if rex='^([^$`\'"$lf"']|\\.)+'"$lf"'?|^'"$lf" && [[ $tail =~ $rex ]]; then
      ((_ble_syntax_attr[i]=CTX_HERE0,
        i+=${#BASH_REMATCH}))
      [[ $BASH_REMATCH == *"$lf" ]] && ((ctx=CTX_HERE0))
      return 0
    fi

    if ble-syntax:bash/check-dollar; then
      return 0
    elif [[ $tail == '`'* ]] && ble-syntax:bash/check-quotes; then
      return 0
    else
      # 単独の $ や終端の \ など?
      ((_ble_syntax_attr[i]=CTX_HERE0,i++))
      return 0
    fi
  fi
}

#==============================================================================

# 解析部

_ble_syntax_vanishing_word_umin=-1
_ble_syntax_vanishing_word_umax=-1
function ble-syntax/vanishing-word/register {
  local tree_array="$1" tofs="$2"
  local -i beg="$3" end="$4" lbeg="$5" lend="$6"
  (((beg<=0)&&(beg=1)))

  local node i nofs
  for ((i=end;i>=beg;i--)); do
    builtin eval "node=(\${$tree_array[tofs+i-1]})"
    ((${#node[@]})) || continue
    for ((nofs=0;nofs<${#node[@]};nofs+=BLE_SYNTAX_TREE_WIDTH)); do
      local wtype="${node[nofs]}" wlen="${node[nofs+1]}"
      local wbeg="$((wlen<0?wlen:i-wlen))" wend="$i"

      ((wbeg<lbeg&&(wbeg=lbeg),
        wend>lend&&(wend=lend)))
      ble-syntax/urange#update _ble_syntax_vanishing_word_ "$wbeg" "$wend"
    done
  done
}

#----------------------------------------------------------
# shift

## @var[in] j
## @var[in] beg,end,end0,shift
function ble-syntax/parse/shift.stat {
  if [[ ${_ble_syntax_stat[j]} ]]; then
    local -a stat
    stat=(${_ble_syntax_stat[j]})

    local k klen kbeg
    for k in 1 3 4 5; do
      (((klen=stat[k])<0)) && continue
      ((kbeg=j-klen))
      if ((kbeg<beg)); then
        ((stat[k]+=shift))
      elif ((kbeg<end0)); then
        ((stat[k]-=end0-kbeg))
      fi
    done

    _ble_syntax_stat[j]="${stat[*]}"
  fi
}

## @var[in] node,j,nofs
## @var[in] beg,end,end0,shift
function ble-syntax/parse/shift.tree/1 {
  local k klen kbeg
  for k in 1 2 3; do
    ((klen=node[nofs+k]))
    ((klen<0||(kbeg=j-klen)>end0)) && continue
    # 長さが変化した時 (k==1)、または構文木の距離変化があった時 (k==2, k==3) にここへ来る。

    # (1) 単語の中身が変化した事を記録
    #   node の中身が書き換わった時 (wbegin < end0 の時):
    #   dirty 拡大の代わりに _ble_syntax_word_umax に登録するに留める。
    if [[ $k == 1 && ${node[nofs]} =~ ^[0-9]$ ]]; then
      ble-syntax/parse/touch-updated-word "$j"

      # 着色情報を clear
      node[nofs+4]='-'
    fi

    # (1) 長さ・相対位置の補正
    if ((kbeg<beg)); then
      ((node[nofs+k]+=shift))
    elif ((kbeg<end0)); then
      ((node[nofs+k]-=end0-kbeg))
    fi
  done
}

## @var[in] j
## @var[in] beg,end,end0,shift
function ble-syntax/parse/shift.tree {
  [[ ${_ble_syntax_tree[j-1]} ]] || return
  local -a node
  node=(${_ble_syntax_tree[j-1]})

  local nofs
  if [[ $1 ]]; then
    nofs="$1" ble-syntax/parse/shift.tree/1
  else
    for ((nofs=0;nofs<${#node[@]};nofs+=BLE_SYNTAX_TREE_WIDTH)); do
      ble-syntax/parse/shift.tree/1
    done
  fi

  _ble_syntax_tree[j-1]="${node[*]}"
}

## @var[in] j
## @var[in] beg,end,end0,shift
function ble-syntax/parse/shift.nest {
  # stat の先頭以外でも nest-push している
  #   @ ctx-command/check-word-begin の "関数名 ( " にて。
  if [[ ${_ble_syntax_nest[j]} ]]; then
    local -a nest
    nest=(${_ble_syntax_nest[j]})

    local k klen kbeg
    for k in 1 3 4 5; do
      (((klen=nest[k])))
      ((klen<0||(kbeg=j-klen)<0)) && continue
      if ((kbeg<beg)); then
        ((nest[k]+=shift))
      elif ((kbeg<end0)); then
        ((nest[k]-=end0-kbeg))
      fi
    done

    _ble_syntax_nest[j]="${nest[*]}"
  fi
}

function ble-syntax/parse/shift.impl2/.shift-until {
  local limit="$1"
  while ((j>=limit)); do
#%if !release
    [[ $ble_debug ]] && _ble_syntax_stat_shift[j+shift]=1
#%end
    ble-syntax/parse/shift.stat
    ble-syntax/parse/shift.nest
    ((j--))
  done
}

## 関数 ble-syntax/parse/shift.impl2/.proc1
##
## @var[in] i
##   tree-enumerate によって設定される変数です。
##   現在処理している単語の終端境界を表します。
##   単語の情報は _ble_syntax_tree[i-1] に格納されています。
##
## @var[in,out] _shift2_j  何処まで処理したかを格納します。
##
## @var[in]     i1,i2,j2,iN
## @var[in]     beg,end,end0,shift
##   これらの変数は更に子関数で使用されます。
##
function ble-syntax/parse/shift.impl2/.proc1 {
  local j="$_shift2_j"
  if ((i<j2)); then
    ((tprev=-1)) # 中断
    return
  fi

  ble-syntax/parse/shift.impl2/.shift-until "$((i+1))"
  ble-syntax/parse/shift.tree "$nofs"
  ((_shift2_j=j))

  if ((tprev>end0&&wbegin>end0)); then
    # skip 可能
    #   tprev<=end0 の場合、stat の中の tplen が shift 対象の可能性がある事に注意する。
#%if !release
    [[ $ble_debug ]] && _ble_syntax_stat_shift[j+shift]=1
#%end
    ble-syntax/parse/shift.stat
    ble-syntax/parse/shift.nest
    ((_shift2_j=wbegin)) # skip
  elif ((tchild>=0)); then
    ble-syntax/tree-enumerate-children ble-syntax/parse/shift.impl2/.proc1
  fi
}

function ble-syntax/parse/shift.method1 {
  # shift (shift は毎回やり切る。途中状態で抜けたりはしない)
  local i j
  for ((i=i2,j=j2;i<=iN;i++,j++)); do
    # 注意: データの範囲
    #   stat[i]   は i in [0,iN]
    #   attr[i]   は i in [0,iN)
    #   tree[i-1] は i in (0,iN]
    ble-syntax/parse/shift.stat
    ((j>0))  && ble-syntax/parse/shift.tree
    ((i<iN)) && ble-syntax/parse/shift.nest
  done
}

function ble-syntax/parse/shift.method2 {
#%if !release
  [[ $ble_debug ]] && _ble_syntax_stat_shift=()
#%end

  local iN="${#_ble_syntax_text}" # tree-enumerate 起点は (古い text の長さ) である
  local _shift2_j="$iN" # proc1 に渡す変数
  ble-syntax/tree-enumerate ble-syntax/parse/shift.impl2/.proc1
  local j="$_shift2_j"
  ble-syntax/parse/shift.impl2/.shift-until "$j2" # 未処理部分
}

## @var[in] i1,i2,j2,iN
## @var[in] beg,end,end0,shift
function ble-syntax/parse/shift {
  # ※shift==0 でも更新で消滅した部分を縮める必要があるので
  #   shift 実行する必要がある。

  # ble-syntax/parse/shift.method1 # 直接探索
  ble-syntax/parse/shift.method2 # tree-enumerate による skip

  if ((shift!=0)); then
    # 更新範囲の shift
    ble-syntax/urange#shift _ble_syntax_attr_
    ble-syntax/wrange#shift _ble_syntax_word_
    ble-syntax/urange#shift _ble_syntax_vanishing_word_
  fi
}

#----------------------------------------------------------
# parse

_ble_syntax_dbeg=-1 _ble_syntax_dend=-1

## 関数 ble-syntax/parse text beg end
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
## @var  [in,out] _ble_syntax_tree[] シェル単語の情報を記録
##   これらの変数には解析結果が格納される。
##
## @var  [in,out] _ble_syntax_attr_umin
## @var  [in,out] _ble_syntax_attr_umax
## @var  [in,out] _ble_syntax_word_umin
## @var  [in,out] _ble_syntax_word_umax
##   今回の呼出によって文法的な解釈の変更が行われた範囲を更新します。
##
function ble-syntax/parse {
  local -r text="$1"
  local beg="${2:-0}" end="${3:-${#text}}"
  local -r end0="${4:-$end}"
  ((end==beg&&end0==beg&&_ble_syntax_dbeg<0)) && return

  local -ir iN="${#text}" shift=end-end0
#%if !release
  if ! ((0<=beg&&beg<=end&&end<=iN&&beg<=end0)); then
    ble-stackdump "X1 0 <= beg:$beg <= end:$end <= iN:$iN, beg:$beg <= end0:$end0 (shift=$shift text=$text)"
    ((beg=0,end=iN))
  fi
#%else
  ((0<=beg&&beg<=end&&end<=iN&&beg<=end0)) || ((beg=0,end=iN))
#%end

  # 解析予定範囲の更新
  local i1 i2 j2 flagSeekStat=0
  ((i1=_ble_syntax_dbeg,i1>=end0&&(i1+=shift),
    i2=_ble_syntax_dend,i2>=end0&&(i2+=shift),
    (i1<0||beg<i1)&&(i1=beg,flagSeekStat=1),
    (i2<0||i2<end)&&(i2=end),
    (i2>iN)&&(i2=iN),
    j2=i2-shift))
  if ((flagSeekStat)); then
    # beg より前の最後の stat の位置まで戻る
    while ((i1>0)) && ! [[ ${_ble_syntax_stat[--i1]} ]]; do :;done
  fi

#%if !release
  ((0<=i1&&i1<=beg&&end<=i2&&i2<=iN)) || ble-stackdump "X2 0 <= $i1 <= $beg <= $end <= $i2 <= $iN"
#%end

  ble-syntax/vanishing-word/register _ble_syntax_tree 0 i1 j2 0 i1

  ble-syntax/parse/shift

  # 解析途中状態の復元
  local ctx wbegin wtype inest tchild tprev nparam
  if [[ i1 -gt 0 && ${_ble_syntax_stat[i1]} ]]; then
    local -a stat
    stat=(${_ble_syntax_stat[i1]})
    local wlen="${stat[1]}" nlen="${stat[3]}" tclen="${stat[4]}" tplen="${stat[5]}"
    ctx="${stat[0]}"
    wbegin="$((wlen<0?wlen:i1-wlen))"
    wtype="${stat[2]}"
    inest="$((nlen<0?nlen:i1-nlen))"
    tchild="$((tclen<0?tclen:i1-tclen))"
    tprev="$((tplen<0?tplen:i1-tplen))"
    nparam="${stat[6]}"; [[ $nparam == none ]] && nparam=
  else
    # 初期値
    ctx="$CTX_UNSPECIFIED" ##!< 現在の解析の文脈 
    ble-syntax:"$_ble_syntax_lang"/initialize-ctx # ctx 初期化
    wbegin=-1       ##!< シェル単語内にいる時、シェル単語の開始位置
    wtype=-1        ##!< シェル単語内にいる時、シェル単語の種類
    inest=-1        ##!< 入れ子の時、親の開始位置
    tchild=-1
    tprev=-1
    nparam=
  fi

  # 前回までに解析が終わっている部分 [0,i1), [i2,iN)
  local -a _tail_syntax_stat _tail_syntax_tree _tail_syntax_nest _tail_syntax_attr
  _tail_syntax_stat=("${_ble_syntax_stat[@]:j2:iN-i2+1}")
  _tail_syntax_tree=("${_ble_syntax_tree[@]:j2:iN-i2}")
  _tail_syntax_nest=("${_ble_syntax_nest[@]:j2:iN-i2}")
  _tail_syntax_attr=("${_ble_syntax_attr[@]:j2:iN-i2}")
  _ble_util_array_prototype.reserve $iN
  _ble_syntax_stat=("${_ble_syntax_stat[@]::i1}" "${_ble_util_array_prototype[@]:i1:iN-i1}") # 再開用データ
  _ble_syntax_tree=("${_ble_syntax_tree[@]::i1}" "${_ble_util_array_prototype[@]:i1:iN-i1}") # 単語
  _ble_syntax_nest=("${_ble_syntax_nest[@]::i1}" "${_ble_util_array_prototype[@]:i1:iN-i1}") # 入れ子の親
  _ble_syntax_attr=("${_ble_syntax_attr[@]::i1}" "${_ble_util_array_prototype[@]:i1:iN-i1}") # 文脈・色とか

  local "${_ble_syntax_bash_vars[@]}"
  ble-syntax:"$_ble_syntax_lang"/initialize-vars

  # 解析
  _ble_syntax_text="$text"
  local i _stat tail parse_suppressNextStat=
#%if !release
  local debug_p1
#%end
  for ((i=i1;i<iN;)); do
    ble-syntax/parse/generate-stat
    if ((i>=i2)) && [[ ${_tail_syntax_stat[i-i2]} == $_stat ]]; then
      if ble-syntax/parse/nest-equals "$inest"; then
        # 前回の解析と同じ状態になった時 → 残りは前回の結果と同じ
        _ble_syntax_stat=("${_ble_syntax_stat[@]::i}" "${_tail_syntax_stat[@]:i-i2}")
        _ble_syntax_tree=("${_ble_syntax_tree[@]::i}" "${_tail_syntax_tree[@]:i-i2}")
        _ble_syntax_nest=("${_ble_syntax_nest[@]::i}" "${_tail_syntax_nest[@]:i-i2}")
        _ble_syntax_attr=("${_ble_syntax_attr[@]::i}" "${_tail_syntax_attr[@]:i-i2}")
        break
      fi
    fi

    if [[ $parse_suppressNextStat ]]; then
      parse_suppressNextStat=
    else
      _ble_syntax_stat[i]="$_stat"
    fi
    tail="${text:i}"
#%if !release
    debug_p1="$i"
#%end
    # 処理
    "${_BLE_SYNTAX_FCTX[ctx]}" || ((_ble_syntax_attr[i]=ATTR_ERR,i++))

    # nest-pop で CMDI/ARGI になる事もあるし、
    # また単語終端な文字でも FCTX が失敗する事もある (unrecognized な場合) ので、
    # (FCTX の中や直後ではなく) ここで単語終端をチェック
    [[ ${_BLE_SYNTAX_FEND[ctx]} ]] && "${_BLE_SYNTAX_FEND[ctx]}"
  done
#%if !release
  unset debug_p1
#%end

  ble-syntax/vanishing-word/register _tail_syntax_tree -i2 i2+1 i 0 i

  ble-syntax/urange#update _ble_syntax_attr_ i1 i

  (((i>=i2)?(
      _ble_syntax_dbeg=_ble_syntax_dend=-1
    ):(
      _ble_syntax_dbeg=i,_ble_syntax_dend=i2)))
  
  # 終端の状態の記録
  if ((i>=iN)); then
    ((i=iN))
    ble-syntax/parse/generate-stat
    _ble_syntax_stat[i]="$_stat"

    # ネスト開始点のエラー表示は +syntax 内で。
    # ここで設定すると部分更新の際に取り消しできないから。
    if ((inest>0)); then
      ((_ble_syntax_attr[iN-1]=ATTR_ERR))
      while ((inest>=0)); do
        ((i=inest))
        ble-syntax/parse/nest-pop
        ((inest>=i&&(inest=i-1)))
      done
    fi
  fi

#%if !release
  ((${#_ble_syntax_stat[@]}==iN+1)) ||
    ble-stackdump "unexpected array length #arr=${#_ble_syntax_stat[@]} (expected to be $iN), #proto=${#_ble_util_array_prototype[@]} should be >= $iN"
#%end
}

#==============================================================================
#
# syntax-complete
#
#==============================================================================

# ## 関数 ble-syntax/getattr index
# function ble-syntax/getattr {
#   local i
#   attr=
#   for ((i=$1;i>=0;i--)); do
#     if [[ ${_ble_syntax_attr[i]} ]]; then
#       ((attr=_ble_syntax_attr[i]))
#       return
#     fi
#   done
# }

# ## 関数 ble-syntax/getstat index
# function ble-syntax/getstat {
#   local i
#   for ((i=$1;i>=0;i--)); do
#     if [[ ${_ble_syntax_stat[i]} ]]; then
#       stat=(${_ble_syntax_stat[i]})
#       return
#     fi
#   done
# }

function ble-syntax/completion-context/add {
  local source="$1"
  local comp1="$2"
  context[${#context[*]}]="$source $comp1"
}

function ble-syntax/completion-context/check/parameter-expansion {
  local rex_paramx='^(\$(\{[!#]?)?)([a-zA-Z_][a-zA-Z_0-9]*)?$'
  if [[ ${text:i:index-i} =~ $rex_paramx ]]; then
    local rematch1="${BASH_REMATCH[1]}"
    ble-syntax/completion-context/add variable $((i+${#rematch1}))
  fi
}

## 関数 ble-syntax/completion-context/check-prefix
##   @var[in] text
##   @var[in] index
##   @var[out] context
function ble-syntax/completion-context/check-prefix {
  local rex_param='^[a-zA-Z_][a-zA-Z_0-9]*$'

  local i
  local -a stat=()
  for ((i=index-1;i>=0;i--)); do
    if [[ ${_ble_syntax_stat[i]} ]]; then
      stat=(${_ble_syntax_stat[i]})
      break
    fi
  done

  if [[ ${stat[0]} ]]; then
    local ctx="${stat[0]}" wlen="${stat[1]}"
    local wbeg="$((wlen<0?wlen:i-wlen))"
    if ((ctx==CTX_CMDI)); then
      if ((wlen>=0)); then
        # CTX_CMDI  → コマンドの続き
        ble-syntax/completion-context/add command "$wbeg"
        if [[ ${text:wbeg:index-wbeg} =~ $rex_param ]]; then
          ble-syntax/completion-context/add variable:= "$wbeg"
        fi
      fi
      ble-syntax/completion-context/check/parameter-expansion
    elif ((ctx==CTX_ARGI||ctx==CTX_ARGVI||ctx==CTX_VALI||ctx==CTX_CONDI||ctx==CTX_CARGI1||ctx==CTX_FARGI1)); then
      # CTX_ARGI  → 引数の続き
      if ((wlen>=0)); then
        local source=file
        if ((ctx==CTX_ARGI)); then
          source=argument
        elif ((ctx==CTX_ARGVI)); then
          source=variable:=
        elif ((ctx==CTX_FARGI1)); then
          source=variable
        fi
        ble-syntax/completion-context/add "$source" "$wbeg"

        local sub="${text:wbeg:index-wbeg}"
        if [[ $sub == *[=:]* ]]; then
          sub="${sub##*[=:]}"
          ble-syntax/completion-context/add file "$((index-${#sub}))"
        fi
      fi
      ble-syntax/completion-context/check/parameter-expansion
    elif ((ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXV)); then
      # 直前の再開点が CMDX だった場合、
      # 現在地との間にコマンド名があればそれはコマンドである。
      # スペースや ;&| 等のコマンド以外の物がある可能性もある事に注意する。
      local word="${text:i:index-i}"

      # コマンドのチェック
      if [[ $word =~ $_ble_syntax_rex_simple_word ]]; then
        # 単語が i から開始している場合
        ble-syntax/completion-context/add command "$i"

        # 変数・代入のチェック
        if local rex='^[a-zA-Z_][a-zA-Z_0-9]*(\+?=)?$' && [[ $word =~ $rex ]]; then
          if [[ $word == *= ]]; then
            if ((_ble_bash>=30100)) || [[ $word != *+= ]]; then
              # VAR=<argument>: 現在位置から argument 候補を生成する
              ble-syntax/completion-context/add argument "$index"
            fi
          else
            # VAR<+variable>: 単語を変数名の一部と思って変数名を生成する
            ble-syntax/completion-context/add variable:= "$i"
          fi
        fi
      elif [[ $word =~ ^$_ble_syntax_bash_rex_spaces$ ]]; then
        # 単語が未だ開始していない時 (空白)
        shopt -q no_empty_cmd_completion ||
          ble-syntax/completion-context/add command "$index"
      fi

      ble-syntax/completion-context/check/parameter-expansion
    elif ((ctx==CTX_CMDXC)); then
      local rex word="${text:i:index-i}"
      if [[ ${text:i:index-i} =~ $rex_param ]]; then
        ble-syntax/completion-context/add wordlist:'for:select:case:if:while:until' "$i"
      elif rex='^[[({]+$'; [[ $word =~ $rex ]]; then
        ble-syntax/completion-context/add wordlist:'(:{:((:[[' "$i"
      fi
    elif ((ctx==CTX_CMDXE)); then
      if [[ ${text:i:index-i} =~ $rex_param ]]; then
        ble-syntax/completion-context/add wordlist:fi:done:esac:then:elif:else:do "$i"
      fi
    elif ((ctx==CTX_CMDXD)); then
      if [[ ${text:i:index-i} =~ $rex_param ]]; then
        ble-syntax/completion-context/add wordlist:';:{:do' "$i"
      fi
    elif ((ctx==CTX_FARGX1||ctx==CTX_SARGX1)); then
      # CTX_FARGX1 → (( でなければ 変数名
      if [[ ${text:i:index-i} =~ $rex_param ]]; then
        ble-syntax/completion-context/add variable "$i"
      fi
    elif ((ctx==CTX_CARGX2||ctx==CTX_CARGI2)); then
      if [[ ${text:i:index-i} =~ $rex_param ]]; then
        ble-syntax/completion-context/add wordlist:in "$i"
      fi
    elif ((ctx==CTX_FARGX2||ctx==CTX_FARGI2)); then
      if [[ ${text:i:index-i} =~ $rex_param ]]; then
        ble-syntax/completion-context/add wordlist:in:do "$i"
      fi
    elif ((ctx==CTX_ARGX||ctx==CTX_ARGVX||ctx==CTX_CARGX1||ctx==CTX_VALX||ctx==CTX_CONDX||ctx==CTX_RDRS)); then
      local source=file
      if ((ctx==CTX_ARGX||ctx==CTX_CARGX1)); then
        source=argument
      elif ((ctx==CTX_ARGVX)); then
        source=variable:=
      fi

      local word="${text:i:index-i}"
      if [[ $word =~ $_ble_syntax_rex_simple_word ]]; then
        # 単語が i から開始している場合
        ble-syntax/completion-context/add "$source" "$i"
        local rex="^([^'\"\$\\]|\\.)*="
        if [[ $word =~ $rex ]]; then
          word="${word:${#BASH_REMATCH}}"
          ble-syntax/completion-context/add "$source" "$((index-${#word}))"
        fi
      elif [[ $word =~ ^$_ble_syntax_bash_rex_spaces$ ]]; then
        # 単語が未だ開始していない時 (空白)
        ble-syntax/completion-context/add "$source" "$index"
      fi
      ble-syntax/completion-context/check/parameter-expansion
    elif ((ctx==CTX_RDRF||ctx==CTX_VRHS)); then
      # CTX_RDRF: redirect の filename 部分
      # CTX_VRHS: VAR=value の value 部分
      local sub="${text:i:index-i}"
      if [[ $sub =~ $_ble_syntax_rex_simple_word ]]; then
        ble-syntax/completion-context/add file "$i"
      fi
    elif ((ctx==CTX_QUOT)); then
      ble-syntax/completion-context/check/parameter-expansion
    fi
  fi
}

## 関数 ble-syntax/completion-context/check-here
##   現在地点を開始点とする補完の可能性を列挙します
##   @var[in]  text
##   @var[in]  index
##   @var[out] context
function ble-syntax/completion-context/check-here {
  ((${#context[*]})) && return
  local -a stat
  stat=(${_ble_syntax_stat[index]})
  if [[ ${stat[0]} ]]; then
    # ここで CTX_CMDI や CTX_ARGI は処理しない。
    # 既に check-prefix で引っかかっている筈だから。
    local ctx=${stat[0]}
    
    if ((ctx==CTX_CMDX||ctx==CTX_CMDXV||ctx==CTX_CMDX1)); then
      if ! shopt -q no_empty_cmd_completion; then
        ble-syntax/completion-context/add command "$index"
        ble-syntax/completion-context/add variable:= "$index"
      fi
    elif ((ctx==CTX_CMDXC)); then
      ble-syntax/completion-context/add wordlist:'(:{:((:[[:for:select:case:if:while:until' "$index"
    elif ((ctx==CTX_CMDXE)); then
      ble-syntax/completion-context/add wordlist:'}:fi:done:esac:then:elif:else:do' "$index"
    elif ((ctx==CTX_CMDXD)); then
      ble-syntax/completion-context/add wordlist:';:{:do' "$index"
    elif ((ctx==CTX_ARGX||ctx==CTX_CARGX1)); then
      ble-syntax/completion-context/add argument "$index"
    elif ((ctx==CTX_FARGX1||ctx==CTX_SARGX1)); then
      ble-syntax/completion-context/add variable "$index"
    elif ((ctx==CTX_CARGX2)); then
      ble-syntax/completion-context/add wordlist:in "$index"
    elif ((ctx==CTX_FARGX2)); then
      ble-syntax/completion-context/add wordlist:in:do "$index"
    elif ((ctx==CTX_RDRF||ctx==CTX_RDRS||ctx==CTX_VRHS)); then
      ble-syntax/completion-context/add file "$index"
    fi
  fi
}

## 関数 ble-syntax/completion-context
##   @var[out] context[]
function ble-syntax/completion-context {
  local text="$1" index="$2"
  context=()
  ((index<0&&(index=0)))

  ble-syntax/completion-context/check-prefix
  ble-syntax/completion-context/check-here
}

## 関数 ble-syntax:bash/extract-command/.register-word
## @var[in,out] comp_words, comp_line, comp_point, comp_cword
## @var[in]     _ble_syntax_text, pos
## @var[in]     wbegin, wlen
function ble-syntax:bash/extract-command/.register-word {
  local wtxt="${_ble_syntax_text:wbegin:wlen}"
  if [[ ! $comp_cword ]] && ((wbegin<=pos)); then
    if ((pos<=wbegin+wlen)); then
      comp_cword="${#comp_words[@]}"
      comp_point="$((${#comp_line}+wbegin+wlen-pos))"
      comp_line="$wtxt$comp_line"
      ble/array#push comp_words "$wtxt"
    else
      comp_cword="${#comp_words[@]}"
      comp_point="${#comp_line}"
      comp_line="$wtxt $comp_line"
      ble/array#push comp_words "" "$wtxt"
    fi
  else
    comp_line="$wtxt$comp_line"
    ble/array#push comp_words "$wtxt"
  fi
}

function ble-syntax:bash/extract-command/.construct-proc {
  if [[ $wtype =~ ^[0-9]+$ ]]; then
    if ((wtype==CTX_CMDI)); then
      if ((pos<wbegin)); then
        comp_line= comp_point= comp_cword= comp_words=()
      else
        ble-syntax:bash/extract-command/.register-word
        ble-syntax/tree-enumerate-break
        return
      fi
    elif ((wtype==CTX_ARGI||wtype==CTX_ARGVI)); then
      ble-syntax:bash/extract-command/.register-word
      comp_line=" $comp_line"
    fi
  fi
}

function ble-syntax:bash/extract-command/.construct {
  comp_line= comp_point= comp_cword= comp_words=()

  if [[ $1 == nested ]]; then
    ble-syntax/tree-enumerate-children \
      ble-syntax:bash/extract-command/.construct-proc
  else
    ble-syntax/tree-enumerate \
      ble-syntax:bash/extract-command/.construct-proc
  fi

  ble/array#reverse comp_words
  comp_cword="$((${#comp_words[@]}-1-comp_cword))"
  comp_point="$((${#comp_line}-comp_point))"
}

## (tree-enumerate-proc) ble-syntax:bash/extract-command/.scan
function ble-syntax:bash/extract-command/.scan {
  ((pos<wbegin)) && return

  if ((wbegin+wlen<pos)); then
    ble-syntax/tree-enumerate-break
  else
    ble-syntax/tree-enumerate-children \
      ble-syntax:bash/extract-command/.scan

    if [[ $isword && ! $iscommand ]]; then
      iscommand=1
      ble-syntax:bash/extract-command/.construct nested
      ble-syntax/tree-enumerate-break
    fi
  fi

  if [[ $wtype =~ ^[0-9]+$ && ! $isword ]]; then
    isword="$wtype"
    return
  fi
}

## 関数 ble-syntax:bash/extract-command index
## @var[out] comp_cword comp_words comp_line comp_point
function ble-syntax:bash/extract-command {
  local pos="$1"
  local isword= iscommand=

  ble-syntax/tree-enumerate \
    ble-syntax:bash/extract-command/.scan

  [[ ! $isword ]] && return 1

  if [[ ! $iscommand ]]; then
    iscommand=1
    ble-syntax:bash/extract-command/.construct
  fi

  # {
  #   echo "pos=$pos w=$isword c=$iscommand"
  #   declare -p comp_words comp_cword comp_line comp_point
  # } >> ~/a.txt
}

#==============================================================================
#
# syntax-highlight
#
#==============================================================================

# filetype
ATTR_CMD_BOLD=101
ATTR_CMD_BUILTIN=102
ATTR_CMD_ALIAS=103
ATTR_CMD_FUNCTION=104
ATTR_CMD_FILE=105
ATTR_CMD_KEYWORD=106
ATTR_CMD_JOBS=107
ATTR_CMD_DIR=112
ATTR_FILE_DIR=108
ATTR_FILE_LINK=109
ATTR_FILE_EXEC=110
ATTR_FILE_FILE=111
ATTR_FILE_FIFO=114
ATTR_FILE_CHR=115
ATTR_FILE_BLK=116
ATTR_FILE_SOCK=117
ATTR_FILE_WARN=113

# 遅延初期化対象
_ble_syntax_attr2iface=()
function ble-syntax/attr2g { ble-color/faces/initialize && ble-syntax/attr2g "$@"; }

# 遅延初期化子
function ble-syntax/faces-onload-hook {
  function _ble_syntax_attr2iface.define {
    ((_ble_syntax_attr2iface[$1]=_ble_faces__$2))
  }

  function ble-syntax/attr2g {
    local iface="${_ble_syntax_attr2iface[$1]:-_ble_faces__syntax_default}"
    g="${_ble_faces[iface]}"
  }

  ble-color-defface syntax_default           none
  ble-color-defface syntax_command           red
  ble-color-defface syntax_quoted            fg=green
  ble-color-defface syntax_quotation         fg=green,bold
  ble-color-defface syntax_expr              fg=navy
  ble-color-defface syntax_error             bg=203,fg=231 # bg=224
  ble-color-defface syntax_varname           fg=202
  ble-color-defface syntax_delimiter         bold
  ble-color-defface syntax_param_expansion   fg=purple
  ble-color-defface syntax_history_expansion bg=94,fg=231
  ble-color-defface syntax_function_name     fg=92,bold # fg=purple
  ble-color-defface syntax_comment           fg=gray
  ble-color-defface syntax_glob              fg=198,bold
  ble-color-defface syntax_document          fg=94
  ble-color-defface syntax_document_begin    fg=94,bold

  ble-color-defface command_builtin_dot fg=red,bold
  ble-color-defface command_builtin     fg=red
  ble-color-defface command_alias       fg=teal
  ble-color-defface command_function    fg=92 # fg=purple
  ble-color-defface command_file        fg=green
  ble-color-defface command_keyword     fg=blue
  ble-color-defface command_jobs        fg=red
  ble-color-defface command_directory   fg=navy,underline
  ble-color-defface filename_directory  fg=navy,underline
  ble-color-defface filename_link       fg=teal,underline
  ble-color-defface filename_executable fg=green,underline
  ble-color-defface filename_other      underline
  ble-color-defface filename_socket     fg=cyan,bg=black,underline
  ble-color-defface filename_pipe       fg=lime,bg=black,underline
  ble-color-defface filename_character  fg=white,bg=black,underline
  ble-color-defface filename_block      fg=yellow,bg=black,underline
  ble-color-defface filename_warning    fg=red,underline

  _ble_syntax_attr2iface.define CTX_ARGX     syntax_default
  _ble_syntax_attr2iface.define CTX_ARGX0    syntax_default
  _ble_syntax_attr2iface.define CTX_ARGI     syntax_default
  _ble_syntax_attr2iface.define CTX_ARGVX    syntax_default
  _ble_syntax_attr2iface.define CTX_ARGVI    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDX     syntax_default
  _ble_syntax_attr2iface.define CTX_CMDX1    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDXC    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDXE    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDXD    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDXV    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDI     syntax_command
  _ble_syntax_attr2iface.define CTX_VRHS     syntax_default
  _ble_syntax_attr2iface.define CTX_QUOT     syntax_quoted
  _ble_syntax_attr2iface.define CTX_EXPR     syntax_expr
  _ble_syntax_attr2iface.define ATTR_ERR     syntax_error
  _ble_syntax_attr2iface.define ATTR_VAR     syntax_varname
  _ble_syntax_attr2iface.define ATTR_QDEL    syntax_quotation
  _ble_syntax_attr2iface.define ATTR_DEF     syntax_default
  _ble_syntax_attr2iface.define ATTR_DEL     syntax_delimiter
  _ble_syntax_attr2iface.define CTX_PARAM    syntax_param_expansion
  _ble_syntax_attr2iface.define CTX_PWORD    syntax_default
  _ble_syntax_attr2iface.define ATTR_HISTX   syntax_history_expansion
  _ble_syntax_attr2iface.define ATTR_FUNCDEF syntax_function_name
  _ble_syntax_attr2iface.define CTX_VALX     syntax_default
  _ble_syntax_attr2iface.define CTX_VALI     syntax_default
  _ble_syntax_attr2iface.define CTX_CONDX    syntax_default
  _ble_syntax_attr2iface.define CTX_CONDI    syntax_default
  _ble_syntax_attr2iface.define ATTR_COMMENT syntax_comment
  _ble_syntax_attr2iface.define CTX_CASE     syntax_default
  _ble_syntax_attr2iface.define CTX_PATN     syntax_default
  _ble_syntax_attr2iface.define ATTR_GLOB    syntax_glob

  # for var in ... / case arg in
  _ble_syntax_attr2iface.define CTX_FARGX1   syntax_default
  _ble_syntax_attr2iface.define CTX_SARGX1   syntax_default
  _ble_syntax_attr2iface.define CTX_FARGX2   syntax_default
  _ble_syntax_attr2iface.define CTX_CARGX1   syntax_default
  _ble_syntax_attr2iface.define CTX_CARGX2   syntax_default
  _ble_syntax_attr2iface.define CTX_FARGI1   syntax_varname
  _ble_syntax_attr2iface.define CTX_FARGI2   command_keyword
  _ble_syntax_attr2iface.define CTX_CARGI1   syntax_default
  _ble_syntax_attr2iface.define CTX_CARGI2   command_keyword

  # here documents
  _ble_syntax_attr2iface.define CTX_RDRH    syntax_document_begin
  _ble_syntax_attr2iface.define CTX_RDRI    syntax_document_begin
  _ble_syntax_attr2iface.define CTX_HERE0   syntax_document
  _ble_syntax_attr2iface.define CTX_HERE1   syntax_document

  _ble_syntax_attr2iface.define ATTR_CMD_BOLD     command_builtin_dot
  _ble_syntax_attr2iface.define ATTR_CMD_BUILTIN  command_builtin
  _ble_syntax_attr2iface.define ATTR_CMD_ALIAS    command_alias
  _ble_syntax_attr2iface.define ATTR_CMD_FUNCTION command_function
  _ble_syntax_attr2iface.define ATTR_CMD_FILE     command_file
  _ble_syntax_attr2iface.define ATTR_CMD_KEYWORD  command_keyword
  _ble_syntax_attr2iface.define ATTR_CMD_JOBS     command_jobs
  _ble_syntax_attr2iface.define ATTR_CMD_DIR      command_directory
  _ble_syntax_attr2iface.define ATTR_FILE_DIR     filename_directory
  _ble_syntax_attr2iface.define ATTR_FILE_LINK    filename_link
  _ble_syntax_attr2iface.define ATTR_FILE_EXEC    filename_executable
  _ble_syntax_attr2iface.define ATTR_FILE_FILE    filename_other
  _ble_syntax_attr2iface.define ATTR_FILE_WARN    filename_warning
  _ble_syntax_attr2iface.define ATTR_FILE_FIFO    filename_pipe
  _ble_syntax_attr2iface.define ATTR_FILE_SOCK    filename_socket
  _ble_syntax_attr2iface.define ATTR_FILE_BLK     filename_block
  _ble_syntax_attr2iface.define ATTR_FILE_CHR     filename_character
}

ble-color/faces/addhook-onload ble-syntax/faces-onload-hook

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
    ble/util/joblist.check
    if jobs "$cmd" &>/dev/null; then
      ((type=ATTR_CMD_JOBS))
    else
      ((type=ATTR_ERR))
    fi ;;
  (*)
    if [[ -d "$cmd" ]] && shopt -q autocd &>/dev/null; then
      ((type=ATTR_CMD_DIR))
    else
      ((type=ATTR_ERR))
    fi ;;
  esac
}

function ble-syntax/highlight/cmdtype2 {
  local cmd="$1" _0="$2"
  local btype; ble/util/type btype "$cmd"
  ble-syntax/highlight/cmdtype1 "$btype" "$cmd"
  if [[ $type == $ATTR_CMD_ALIAS && "$cmd" != "$_0" ]]; then
    # alias を \ で無効化している場合
    # → unalias して再度 check (2fork)
    type=$(
      unalias "$cmd"
      ble/util/type btype "$cmd"
      ble-syntax/highlight/cmdtype1 "$btype" "$cmd"
      builtin echo -n "$type")
  elif [[ $type = $ATTR_CMD_KEYWORD && "$cmd" != "$_0" ]]; then
    # keyword (time do if function else elif fi の類) を \ で無効化している場合
    # →file, function, builtin, jobs のどれかになる。以下 3fork+2exec
    ble/util/joblist.check
    if [[ ! ${cmd##%*} ]] && jobs "$cmd" &>/dev/null; then
      # %() { :; } として 関数を定義できるが jobs の方が優先される。
      # (% という名の関数を呼び出す方法はない?)
      # でも % で始まる物が keyword になる事はそもそも無いような。
      ((type=ATTR_CMD_JOBS))
    elif ble/util/isfunction "$cmd"; then
      ((type=ATTR_CMD_FUNCTION))
    elif enable -p | command grep -q -F -x "enable $cmd" &>/dev/null; then
      ((type=ATTR_CMD_BUILTIN))
    elif which "$cmd" &>/dev/null; then
      ((type=ATTR_CMD_FILE))
    else
      ((type=ATTR_ERR))
    fi
  fi
}

if ((_ble_bash>=40200||_ble_bash>=40000&&_ble_bash_loaded_in_function&&!_ble_bash_loaded_in_function)); then
  if ((_ble_bash>=40200)); then
    declare -gA _ble_syntax_highlight_filetype=()
  else
    declare -A _ble_syntax_highlight_filetype=()
  fi
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
  _ble_syntax_highlight_filetype=()
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
  type=
  [[ ( $file == '~' || $file == '~/'* ) && ! ( -e $file || -h $file ) ]] && file="$HOME${file:1}"
  if [[ -e $file ]]; then
    if [[ -d $file ]]; then
      ((type=ATTR_FILE_DIR))
    elif [[ -h $file ]]; then
      ((type=ATTR_FILE_LINK))
    elif [[ -x $file ]]; then
      ((type=ATTR_FILE_EXEC))
    elif [[ -f $file ]]; then
      ((type=ATTR_FILE_FILE))
    elif [[ -c $file ]]; then
      ((type=ATTR_FILE_CHR))
    elif [[ -p $file ]]; then
      ((type=ATTR_FILE_FIFO))
    elif [[ -S $file ]]; then
      ((type=ATTR_FILE_SOCK))
    elif [[ -b $file ]]; then
      ((type=ATTR_FILE_BLK))
    fi
  elif [[ -h $file ]]; then
    # dangling link
    ((type=ATTR_FILE_LINK))
  fi
}

# adapter に頼らず直接実装したい
function ble-highlight-layer:syntax/touch-range {
  ble-syntax/urange#update '' "$@"
}
function ble-highlight-layer:syntax/fill {
  local _i _arr="$1" _i1="$2" _i2="$3" _v="$4"
  for ((_i=_i1;_i<_i2;_i++)); do
    eval "$_arr[_i]=\"\$_v\""
  done
}

_ble_highlight_layer_syntax_buff=()
_ble_highlight_layer_syntax1_table=()
_ble_highlight_layer_syntax2_table=()
_ble_highlight_layer_syntax3_list=()
_ble_highlight_layer_syntax3_table=() # errors

function ble-highlight-layer:syntax/update-attribute-table {
  ble-highlight-layer/update/shift _ble_highlight_layer_syntax1_table
  if ((_ble_syntax_attr_umin>=0)); then
    ble-highlight-layer:syntax/touch-range _ble_syntax_attr_umin _ble_syntax_attr_umax

    local i g=0
    ((_ble_syntax_attr_umin>0)) &&
      ((g=_ble_highlight_layer_syntax1_table[_ble_syntax_attr_umin-1]))

    for ((i=_ble_syntax_attr_umin;i<_ble_syntax_attr_umax;i++)); do
      if ((${_ble_syntax_attr[i]})); then
        ble-syntax/attr2g "${_ble_syntax_attr[i]}"
      fi
      _ble_highlight_layer_syntax1_table[i]="$g"
    done

    _ble_syntax_attr_umin=-1 _ble_syntax_attr_umax=-1
  fi
}

function ble-highlight-layer:syntax/word/.update-attributes/.proc {
  [[ ${node[nofs]} =~ ^[0-9]+$ ]] || return
  [[ ${node[nofs+4]} == - ]] || return
  ble-syntax/urange#update color_ "$wbeg" "$wend"

  local type=
  if ((wtype==CTX_RDRH||wtype==CTX_RDRI)); then
    # ヒアドキュメントのキーワード指定部分は、
    # 展開・コマンド置換などに従った解析が行われるが、
    # 実行は一切起こらないので一色で塗りつぶす。
    ((type=wtype))
  elif local wtxt="${text:wbeg:wlen}"; [[ $wtxt =~ $_ble_syntax_rex_simple_word ]]; then

    # 単語を展開
    local value
    if [[ $wtxt == ['[#']* ]]; then
      # 先頭に [ があると配列添字と解釈されて失敗するので '' を前置する。
      eval "value=(''$wtxt)"
    else
      # 先頭が [ 以外の時は tilde expansion 等が有効になる様に '' は前置しない。
      eval "value=($wtxt)"
    fi

    if ((wtype==CTX_CMDI)); then
      ble-syntax/highlight/cmdtype "$value" "$wtxt"
    elif ((wtype==ATTR_FUNCDEF||wtype==ATTR_ERR)); then
      ((type=wtype))
    elif ((wtype==CTX_ARGI||wtype==CTX_RDRF||wtype==CTX_RDRS)); then
      ble-syntax/highlight/filetype "$value" "$wtxt"

      # check values
      if ((wtype==CTX_RDRF)); then
        if ((type==ATTR_FILE_DIR)); then
          # ディレクトリにリダイレクトはできない
          type=$ATTR_ERR
        elif ((BLE_SYNTAX_TREE_WIDTH<=nofs)); then
          # noclobber の時は既存ファイルを > または <> で上書きできない
          #
          # 仮定: _ble_syntax_word に於いてリダイレクトとファイルは同じ位置で終了すると想定する。
          #   この時、リダイレクトの情報の次にファイル名の情報が格納されている筈で、
          #   リダイレクトの情報は node[nofs-BLE_SYNTAX_TREE_WIDTH] に入っていると考えられる。
          #
          local redirect_ntype=${node[nofs-BLE_SYNTAX_TREE_WIDTH]:1}
          if [[ ( $redirect_ntype == *'>' || $redirect_ntype == '>|' ) ]]; then
            if [[ -e $value || -h $value ]]; then
              if [[ -d $value || ! -w $value ]]; then
                # ディレクトリまたは書き込み権限がない
                type=$ATTR_ERR
              elif [[ ( $redirect_ntype == [\<\&]'>' || $redirect_ntype == '>' ) && -f $value ]]; then
                if [[ -o noclobber ]]; then
                  # 上書き禁止
                  type=$ATTR_ERR
                else
                  # 上書き注意
                  type=$ATTR_FILE_WARN
                fi
              fi
            elif [[ $value == */* && ! -w ${value%/*}/ || $value != */* && ! -w ./ ]]; then
              # ディレクトリに書き込み権限がない
              type=$ATTR_ERR
            fi
          elif [[ $redirect_ntype == '<' && ! -r $value ]]; then
            # ファイルがないまたは読み取り権限がない
            type=$ATTR_ERR
          fi
        fi
      fi
    fi
  fi

  if [[ $type ]]; then
    local g
    ble-syntax/attr2g "$type"
    node[nofs+4]="$g"
  else
    node[nofs+4]='d'
  fi
  flagUpdateNode=1
}

## 関数 ble-highlight-layer:syntax/word/.update-attributes
## @var[in] _ble_syntax_word_umin,_ble_syntax_word_umax
## @var[in,out] color_umin,color_umax
function ble-highlight-layer:syntax/word/.update-attributes {
  ((_ble_syntax_word_umin>=0)) || return

  ble-syntax/tree-enumerate-in-range _ble_syntax_word_umin _ble_syntax_word_umax \
    ble-highlight-layer:syntax/word/.update-attributes/.proc
}

function ble-highlight-layer:syntax/word/.apply-attribute {
  local wbeg="$1" wend="$2" attr="$3"
  ((wbeg<color_umin&&(wbeg=color_umin),
    wend>color_umax&&(wend=color_umax),
    wbeg<wend)) || return

  if [[ $attr =~ ^[0-9]+$ ]]; then
    ble-highlight-layer:syntax/fill _ble_highlight_layer_syntax2_table "$wbeg" "$wend" "$attr"
  else
    ble-highlight-layer:syntax/fill _ble_highlight_layer_syntax2_table "$wbeg" "$wend" ''
  fi
}

function ble-highlight-layer:syntax/word/.proc-childnode {
  if [[ $wtype =~ ^[0-9]+$ ]]; then
    local wbeg="$wbegin" wend="$i"
    ble-highlight-layer:syntax/word/.apply-attribute "$wbeg" "$wend" "$attr"
  fi

  ((tchild>=0)) && ble-syntax/tree-enumerate-children "$proc_children"
}

## @var[in,out] _ble_syntax_word_umin,_ble_syntax_word_umax
function ble-highlight-layer:syntax/update-word-table {
  # update table2 (単語の削除に関しては後で考える)

  # (1) 単語色の計算
  local color_umin=-1 color_umax=-1 iN="${#_ble_syntax_text}"
  ble-highlight-layer:syntax/word/.update-attributes

  # (2) 色配列 shift
  ble-highlight-layer/update/shift _ble_highlight_layer_syntax2_table

  # 2015-08-16 暫定 (本当は入れ子構造を考慮に入れたい)
  ble-syntax/wrange#update _ble_syntax_word_ _ble_syntax_vanishing_word_umin _ble_syntax_vanishing_word_umax
  ble-syntax/wrange#update color_ _ble_syntax_vanishing_word_umin _ble_syntax_vanishing_word_umax
  _ble_syntax_vanishing_word_umin=-1 _ble_syntax_vanishing_word_umax=-1

  # (3) 色配列に登録
  ble-highlight-layer:syntax/word/.apply-attribute 0 "$iN" '' # clear word color
  local i
  for ((i=_ble_syntax_word_umax;i>=_ble_syntax_word_umin;)); do
    if ((i>0)) && [[ ${_ble_syntax_tree[i-1]} ]]; then
      local -a node
      node=(${_ble_syntax_tree[i-1]})

      local wlen="${node[1]}"
      local wbeg="$((i-wlen))" wend="$i"

      if [[ ${node[0]} =~ ^[0-9]+$ ]]; then
        local attr="${node[4]}"
        ble-highlight-layer:syntax/word/.apply-attribute "$wbeg" "$wend" "$attr"
      fi

      local tclen="${node[2]}"
      if ((tclen>=0)); then
        local tchild="$((i-tclen))"
        local tree= nofs=0 proc_children=ble-highlight-layer:syntax/word/.proc-childnode
        ble-syntax/tree-enumerate-children "$proc_children"
      fi

      ((i=wbeg))
    else
      ((i--))
    fi
  done
  ((color_umin>=0)) && ble-highlight-layer:syntax/touch-range "$color_umin" "$color_umax"

  _ble_syntax_word_umin=-1 _ble_syntax_word_umax=-1
}

function ble-highlight-layer:syntax/update-error-table/set {
  local i1="$1" i2="$2" g="$3"
  if ((i1<i2)); then
    ble-highlight-layer:syntax/touch-range "$i1" "$i2"
    ble-highlight-layer:syntax/fill _ble_highlight_layer_syntax3_table "$i1" "$i2" "$g"
    _ble_highlight_layer_syntax3_list[${#_ble_highlight_layer_syntax3_list[@]}]="$i1 $i2"
  fi
}
function ble-highlight-layer:syntax/update-error-table {
  ble-highlight-layer/update/shift _ble_highlight_layer_syntax3_table

  # clear old errors
  #   shift の前の方が簡単に更新できるが、
  #   umin umax を更新する為に shift の後で処理する。
  local j=0 jN="${#_ble_highlight_layer_syntax3_list[*]}"
  if ((jN)); then
    for ((j=0;j<jN;j++)); do
      local -a range
      range=(${_ble_highlight_layer_syntax3_list[j]})

      local a="${range[0]}" b="${range[1]}"
      ((a>=DMAX0?(a+=DMAX-DMAX0):(a>=DMIN&&(a=DMIN)),
        b>=DMAX0?(b+=DMAX-DMAX0):(b>=DMIN&&(b=DMIN))))
      if ((a<b)); then
        ble-highlight-layer:syntax/fill _ble_highlight_layer_syntax3_table "$a" "$b" ''
        ble-highlight-layer:syntax/touch-range "$a" "$b"
      fi
    done
    _ble_highlight_layer_syntax3_list=()
  fi

  # この実装では毎回全てのエラーを設定するので
  # 実は下の様にすれば良いだけ…
  #_ble_highlight_layer_syntax3_table=()

  # set errors
  if ((iN>0)) && [[ ${_ble_syntax_stat[iN]} ]]; then
    # iN==0 の時は実行しない。face 遅延初期化のため(最初は iN==0)。
    local g; ble-color-face2g syntax_error

    # 入れ子が閉じていないエラー
    local -a stat
    stat=(${_ble_syntax_stat[iN]})
    local ctx="${stat[0]}" nlen="${stat[3]}" nparam="${stat[6]}"
    [[ $nparam == none ]] && nparam=
    local i inest
    if ((nlen>0)) || [[ $nparam ]]; then
      # 終端点の着色
      ble-highlight-layer:syntax/update-error-table/set "$((iN-1))" "$iN" "$g"

      if ((nlen>0)); then
        ((inest=iN-nlen))
        while ((inest>=0)); do
          # 開始字句の着色
          local inest2
          for((inest2=inest+1;inest2<iN;inest2++)); do
            [[ ${_ble_syntax_attr[inest2]} ]] && break
          done
          ble-highlight-layer:syntax/update-error-table/set "$inest" "$inest2" "$g"

          ((i=inest))
          local wtype wbegin tchild tprev
          ble-syntax/parse/nest-pop
          ((inest>=i&&(inest=i-1)))
        done
      fi
    fi

    # コマンド欠落・引数の欠落
    if ((ctx==CTX_CMDX1||ctx==CTX_CMDXC||ctx==CTX_FARGX1||ctx==CTX_SARGX1||ctx==CTX_FARGX2||ctx==CTX_CARGX1||ctx==CTX_CARGX2)); then
      # 終端点の着色
      ble-highlight-layer:syntax/update-error-table/set "$((iN-1))" "$iN" "$g"
    fi
  fi
}

function ble-highlight-layer:syntax/update {
  local text="$1" player="$2"
  local i iN="${#text}"

  _ble_edit_str.update-syntax

  #--------------------------------------------------------

  local umin=-1 umax=-1
  # 少なくともこの範囲は文字が変わっているので再描画する必要がある
  ((DMIN>=0)) && umin="$DMIN" umax="$DMAX"

#%if !release
  if [[ $ble_debug ]]; then
    local debug_attr_umin="$_ble_syntax_attr_umin"
    local debug_attr_uend="$_ble_syntax_attr_umax"
  fi
#%end

  ble-highlight-layer:syntax/update-attribute-table
  ble-highlight-layer:syntax/update-word-table
  ble-highlight-layer:syntax/update-error-table

  # shift&sgr 設定
  if ((DMIN>=0)); then
    ble-highlight-layer/update/shift _ble_highlight_layer_syntax_buff
    if ((DMAX>0)); then
      local g sgr ch
      ble-highlight-layer:syntax/getg "$DMAX"
      ble-color-g2sgr -v sgr "$g"
      ch="${_ble_highlight_layer_plain_buff[DMAX]}"
      _ble_highlight_layer_syntax_buff[DMAX]="$sgr$ch"
    fi
  fi

  local i j g gprev=0
  if ((umin>0)); then
    ble-highlight-layer:syntax/getg "$((umin-1))"
    gprev="$g"
  fi

  local sgr
  for ((i=umin;i<umax;i++)); do
    local ch="${_ble_highlight_layer_plain_buff[i]}"
    ble-highlight-layer:syntax/getg "$i"
    [[ $g ]] || ble-highlight-layer/update/getg "$i"
    if ((gprev!=g)); then
      ble-color-g2sgr -v sgr "$g"
      ch="$sgr$ch"
      ((gprev=g))
    fi
    _ble_highlight_layer_syntax_buff[i]="$ch"
  done

  PREV_UMIN="$umin" PREV_UMAX="$umax"
  PREV_BUFF=_ble_highlight_layer_syntax_buff

#%if !release
  if [[ $ble_debug ]]; then
    local status buff= nl=$'\n'
    _ble_syntax_attr_umin="$debug_attr_umin" _ble_syntax_attr_umax="$debug_attr_uend" ble-syntax/print-status -v status
    ble/util/assign buff 'declare -p _ble_highlight_layer_plain_buff _ble_highlight_layer_syntax_buff | cat -A'; status="$status${buff%$nl}$nl"
    ble/util/assign buff 'declare -p _ble_highlight_layer_disabled_buff _ble_highlight_layer_region_buff _ble_highlight_layer_overwrite_mode_buff | cat -A'; status="$status${buff%$nl}$nl"
    #ble/util/assign buff 'declare -p _ble_textarea_bufferName $_ble_textarea_bufferName | cat -A'; status="$status$buff"
    ble-edit/info/show raw "$status"
  fi
#%end

  # # 以下は単語の分割のデバグ用
  # local -a words=() word
  # for ((i=1;i<=iN;i++)); do
  #   if [[ ${_ble_syntax_tree[i-1]} ]]; then
  #     word=(${_ble_syntax_tree[i-1]})
  #     local wtxt="${text:i-word[1]:word[1]}" value
  #     if [[ $wtxt =~ $_ble_syntax_rex_simple_word ]]; then
  #       eval "value=$wtxt"
  #     else
  #       value="? ($wtxt)"
  #     fi
  #     ble/array#push words "[$value ${word[*]}]"
  #   fi
  # done
  # ble-edit/info/show text "${words[*]}"
}

function ble-highlight-layer:syntax/getg {
  local i="$1"
  if [[ ${_ble_highlight_layer_syntax3_table[i]} ]]; then
    g="${_ble_highlight_layer_syntax3_table[i]}"
  elif [[ ${_ble_highlight_layer_syntax2_table[i]} ]]; then
    g="${_ble_highlight_layer_syntax2_table[i]}"
  elif [[ ${_ble_highlight_layer_syntax1_table[i]} ]]; then
    g="${_ble_highlight_layer_syntax1_table[i]}"
  else
    g=
  fi
}

#%#----------------------------------------------------------------------------
#%# test codes
#%#----------------------------------------------------------------------------
#%(

attrg[CTX_ARGX]=$'\e[m'
attrg[CTX_ARGX0]=$'\e[m'
attrg[CTX_ARGI]=$'\e[m'
attrg[CTX_ARGVX]=$'\e[m'
attrg[CTX_ARGVI]=$'\e[m'
attrg[CTX_CMDX]=$'\e[m'
attrg[CTX_CMDX1]=$'\e[m'
attrg[CTX_CMDXC]=$'\e[m'
attrg[CTX_CMDXV]=$'\e[m'
attrg[CTX_CMDI]=$'\e[;91m'
attrg[CTX_VRHS]=$'\e[m'
attrg[CTX_RDRD]=$'\e[4m'
attrg[CTX_RDRF]=$'\e[4m'
attrg[CTX_RDRS]=$'\e[4m'
attrg[CTX_QUOT]=$'\e[;32m'
attrg[CTX_EXPR]=$'\e[;34m'
attrg[ATTR_ERR]=$'\e[;101;97m'
attrg[ATTR_VAR]=$'\e[;38;5;202m'
attrg[ATTR_QDEL]=$'\e[;1;32m'
attrg[ATTR_DEF]=$'\e[m'
attrg[ATTR_DEL]=$'\e[;1m'
attrg[CTX_PARAM]=$'\e[;94m'
attrg[CTX_PWORD]=$'\e[m'

attrg[CTX_VALX]=$'\e[m'
attrg[CTX_VALI]=$'\e[34m'
attrg[ATTR_CMD_KEYWORD]=$'\e[94m'

attrg[CTX_FARGX1]=$'\e[m'
attrg[CTX_SARGX1]=$'\e[m'
attrg[CTX_FARGX2]=$'\e[m'
attrg[CTX_FARGI1]=$'\e[;38;5;202m'
attrg[CTX_FARGI2]=$'\e[;94m'
attrg[CTX_CARGX1]=$'\e[m'
attrg[CTX_CARGX2]=$'\e[m'
attrg[CTX_CARGI1]=$'\e[m'
attrg[CTX_CARGI2]=$'\e[;94m'

function mytest/put {
  buff[${#buff[@]}]="$*"
}
function mytest/fflush {
  IFS= eval 'builtin echo -n "${buff[*]}"'
  buff=()
}
function mytest/print {
  local -a buff=()

  # echo "$text"
  local ctxg=$'\e[m'
  for ((i=0;i<${#text};i++)); do
    if ((${_ble_syntax_attr[i]})); then
      ctxg="${attrg[_ble_syntax_attr[i]]:-[40;97m}"
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
    # local ret
    # ble/util/s2c "$text" "$i"
    # ble/util/c2w "$ret"
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
function mytest {
  local text="$1"
  ble-syntax/parse "$text"
  mytest/print

  # update test
  if ((${#text}>=16)); then
    ble-syntax/parse "$text" 15 16
    mytest/print
  fi

  # insertion test
  if ((${#text}>=5)); then
    text="${text::5}""hello; echo""${text:5}"
    ble-syntax/parse "$text" 5 16 5
    builtin echo update $_ble_syntax_attr_umin-$_ble_syntax_attr_umax
    mytest/print
  fi

  # delete test
  if ((${#text}>=10)); then
    text="${text::5}""${text:10}"
    ble-syntax/parse "$text" 5 5 10
    builtin echo update $_ble_syntax_attr_umin-$_ble_syntax_attr_umax
    mytest/print
  fi

  echo -------------------
}
# mytest 'echo hello world'
# mytest 'echo "hello world"'
# mytest 'echo a"hed"a "aa"b b"aa" aa'

mytest 'echo a"$"a a"\$\",$*,$var,$12"a $*,$var,$12'
mytest 'echo a"---$((1+a[12]*3))---$(echo hello)---"a'
mytest 'a=1 b[x[y]]=1234 echo <( world ) >> hello; ( sub shell); ((1+2*3));'
mytest 'a=${#hello} b=${world[10]:1:(5+2)*3} c=${arr[*]%%"test"$(cmd).cpp} d+=12'
mytest 'for ((i=0;i<10;i++)); do echo hello; done; { : '"'worlds'\\'' record'"'; }'
mytest '[[ echo == echo ]]; echo hello'

# ble-syntax/parse "echo hello"
# for ((i=0;i<${#_ble_syntax_stat[@]};i++)); do
#   if [[ ${_ble_syntax_stat[i]} ]]; then
#     echo "$i ${_ble_syntax_stat[i]}"
#   fi
# done

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
