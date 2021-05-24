#!/bin/bash
#%[release = 0]
#%m main (

# exported variables
_ble_syntax_VARNAMES=(
  _ble_syntax_text
  _ble_syntax_lang
  _ble_syntax_attr_umin
  _ble_syntax_attr_umax
  _ble_syntax_word_umin
  _ble_syntax_word_umax
  _ble_syntax_vanishing_word_umin
  _ble_syntax_vanishing_word_umax
  _ble_syntax_dbeg
  _ble_syntax_dend)
_ble_syntax_ARRNAMES=(
  _ble_syntax_stat
  _ble_syntax_nest
  _ble_syntax_tree
  _ble_syntax_attr)
_ble_syntax_lang=bash

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
  local prefix=$1
  local -i p1=$2 p2=${3:-$2}
  ((0<=p1&&p1<p2)) || return
  (((${prefix}umin<0||${prefix}umin>p1)&&(${prefix}umin=p1),
    (${prefix}umax<0||${prefix}umax<p2)&&(${prefix}umax=p2)))
}
function ble-syntax/wrange#update {
  local prefix=$1
  local -i p1=$2 p2=${3:-$2}
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
  local prefix=$1
  ((${prefix}umin>=end0?(${prefix}umin+=shift):(
      ${prefix}umin>=beg&&(${prefix}umin=end)),
    ${prefix}umax>end0?(${prefix}umax+=shift):(
      ${prefix}umax>beg&&(${prefix}umax=beg)),
    ${prefix}umin>=${prefix}umax&&
      (${prefix}umin=${prefix}umax=-1)))
}
function ble-syntax/wrange#shift {
  local prefix=$1

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

## @var _ble_syntax_text
##   解析対象の文字列を保持する。
## @var _ble_syntax_lang
##   解析対象の言語を保持する。
##
## @var _ble_syntax_stat[i]
##   文字 #i を解釈しようとする直前の状態を記録する。
##   各要素は "ctx wlen wtype nlen tclen tplen nparam lookahead" の形式をしている。
##
##   @var ctx         = int (stat[0])
##     現在の文脈。
##   @var wlen        = int (stat[1])
##     現在のシェル単語の継続している長さ。
##   @var wtype       = string (stat[2])
##     現在のシェル単語の種類。
##   @var nlen        = int (stat[3])
##     現在の入れ子状態が継続している長さ。
##   @var tclen,tplen = int (stat[4], stat[5])
##     tchild, tprev の負オフセット。
##   @var nparam      = string (stat[6])
##     その入れ子レベルに特有のデータ一般を記録する文字列。
##     ヒアドキュメントの開始情報を記録するのに使用する。
##     将来的に `{ .. }` や `do .. done` の対応を取るのにも使うかもしれない。
##     解析変数の nparam が空文字列のときは "none" という値を格納する。
##   @var lookahead   = int (stat[7])
##     先読みの文字数を指定します。通常は 1 です。
##     この _ble_syntax_stat 要素の情報に影響を与えた、
##     対応する点以降の文字数を格納します。文字列末端も 1 文字と数えます。
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
##   境界 #i で終端した範囲 (単語・入れ子) についての情報を保持する。
##   同じ位置で複数の階層の範囲が終端した場合は、それらの情報が連結されて格納される。
##   各要素は "( wtype wlen tclen tplen - )*" の形式をしている。
##   より外側の範囲の情報はより左側に格納される。
##
##   tclen tplen を用いて他の _ble_syntax_tree 要素を参照する。
##   別の位置から或る位置を参照するとき、一番左側の範囲情報を参照する。
##   或る位置から自分自身を参照するとき、同じ要素の一つ右の範囲情報を参照する。
##
##   wtype (ntype)
##     範囲の種類を保持する。範囲が単語のとき、文脈値を整数で保持する。
##     範囲が入れ子範囲のとき、整数以外の文字列になる。
##
##   wlen (nlen)
##     範囲の長さを保持する。範囲の開始点は i-wlen である。
##
##   tclen
##     0 以上の時、一つ内側の要素の終端位置までの offset を保持する。
##     _ble_syntax_tree[i-1-tclen] に子要素の情報が格納されている。
##     子要素がないとき負の値。
##
##   tplen
##     0 以上の時、一つ前の兄弟要素までの offset を保持する。
##     _ble_syntax_tree[i-1-tplen] に兄要素の情報が格納されている。
##     兄要素が同じ位置で終端することはないので必ず正の値になるはず。
##     兄要素がないとき (自分が長男要素のとき) 負の値。
##
##   - (または --)
##     第五要素は現在は使われていない。
##
## @var BLE_SYNTAX_TREE_WIDTH
##   _ble_syntax_tree に格納される一つの範囲情報のフィールドの数。
##
## @var _ble_syntax_attr[i]
##   文脈・属性の情報
_ble_syntax_text=
: ${_ble_syntax_lang:=bash}
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
##
##   @var[in]  iN
##     文字列の長さ、つまり現在の解析終端位置を指定します。
##
##   @var[out] root
##     ${_ble_syntax_tree[iN-1]} を調整して返します。
##     閉じていない範囲 (word, nest) を終端位置で閉じたときの値を計算します。
##
##   @var[out] i
##     一番最後の範囲の終端位置を返します。
##     解析情報がない場合は -1 を返します。
##
##   @var[out] nofs
##     0 に初期化します。
##
function ble-syntax/tree-enumerate/.initialize {
  if [[ ! ${_ble_syntax_stat[iN]} ]]; then
    root= i=-1 nofs=0
    return
  fi

  local -a stat nest
  ble/string#split-words stat "${_ble_syntax_stat[iN]}"
  local wtype=${stat[2]}
  local wlen=${stat[1]}
  local nlen=${stat[3]} inest
  ((inest=nlen<0?nlen:iN-nlen))
  local tclen=${stat[4]}
  local tplen=${stat[5]}

  root=
  ((iN>0)) && root=${_ble_syntax_tree[iN-1]}

  while
    if ((wlen>=0)); then
      root="$wtype $wlen $tclen $tplen -- $root"
      tclen=0
    fi
    ((inest>=0))
  do
    ble-assert '[[ ${_ble_syntax_nest[inest]} ]]' "$FUNCNAME/FATAL1" || break

    ble/string#split-words nest "${_ble_syntax_nest[inest]}"

    local olen=$((iN-inest))
    tplen=${nest[4]}
    ((tplen>=0&&(tplen+=olen)))

    root="${nest[7]} $olen $tclen $tplen -- $root"

    wtype=${nest[2]} wlen=${nest[1]} nlen=${nest[3]} tclen=0 tplen=${nest[5]}
    ((wlen>=0&&(wlen+=olen),
      tplen>=0&&(tplen+=olen),
      nlen>=0&&(nlen+=olen),
      inest=nlen<0?nlen:iN-nlen))

    ble-assert '((nlen<0||nlen>olen))' "$FUNCNAME/FATAL2" || break
  done

  if [[ $root ]]; then
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
##   @var[in] root,i,nofs
function ble-syntax/tree-enumerate/.impl {
  local islast=1
  while ((i>0)); do
    local -a node
    if ((i<iN)); then
      ble/string#split-words node "${_ble_syntax_tree[i-1]}"
    else
      ble/string#split-words node "${root:-${_ble_syntax_tree[iN-1]}}"
    fi

    ble-assert '((nofs<${#node[@]}))' "$FUNCNAME(i=$i,iN=$iN,nofs=$nofs,node=${node[*]},command=$@)/FATAL1" || break

    local wtype=${node[nofs]} wlen=${node[nofs+1]} tclen=${node[nofs+2]} tplen=${node[nofs+3]} attr=${node[nofs+4]}
    local wbegin=$((wlen<0?wlen:i-wlen))
    local tchild=$((tclen<0?tclen:i-tclen))
    local tprev=$((tplen<0?tplen:i-tplen))
    "$@"

    ble-assert '((tprev<i))' "$FUNCNAME/FATAL2" || break

    ((i=tprev,nofs=0,islast=0))
  done
}

## @var[in] iN
## @var[in] root,i,nofs
## @var[in] tchild
function ble-syntax/tree-enumerate-children {
  ((0<tchild&&tchild<=i)) || return
  local nofs=$((i==tchild?nofs+BLE_SYNTAX_TREE_WIDTH:0))
  local i=$tchild
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
  local root i nofs
  [[ ${iN:+set} ]] || local iN=${#_ble_syntax_text}
  ble-syntax/tree-enumerate/.initialize
  ble-syntax/tree-enumerate/.impl "$@"
}

## 関数 ble-syntax/tree-enumerate-in-range beg end proc
##   入れ子構造に従わず或る範囲内に登録されている節を列挙します。
## @param[in] beg,end
## @param[in] proc 以下の変数を使用する関数を指定します。
##   @var[in]     wtype,wlen,wbeg,wend
##   @var[in,out] node,flagUpdateNode
##   @var[in]     nofs
function ble-syntax/tree-enumerate-in-range {
  local -i beg=$1 end=$2
  local proc=$3
  local -a node
  local i nofs
  for ((i=end;i>=beg;i--)); do
    ((i>0)) && [[ ${_ble_syntax_tree[i-1]} ]] || continue
    ble/string#split-words node "${_ble_syntax_tree[i-1]}"
    local flagUpdateNode=
    for ((nofs=0;nofs<${#node[@]};nofs+=BLE_SYNTAX_TREE_WIDTH)); do
      local wtype=${node[nofs]} wlen=${node[nofs+1]}
      local wbeg=$((wlen<0?wlen:i-wlen)) wend=$i
      "${@:3}"
    done

    [[ $flagUpdateNode ]] && _ble_syntax_tree[i-1]="${node[*]}"
  done
}

#--------------------------------------
# ble-syntax/print-status

function ble-syntax/print-status/.graph {
  local char=$1
  if ble/util/isprint+ "$char"; then
    graph="'$char'"
    return
  else
    local ret
    ble/util/s2c "$char" 0
    local code=$ret
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
  local -i j=$1
  local value=$2${tree[j]}
  tree[j]=$value
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
  ble/string#split-words word "${_ble_syntax_tree[index]}"
  local ret=
  if [[ $word ]]; then
    local nofs=$((${#word[@]}/BLE_SYNTAX_TREE_WIDTH*BLE_SYNTAX_TREE_WIDTH))
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

      local b=$((axis-word[nofs+1])) e=$axis
      local _prev=${word[nofs+3]} _child=${word[nofs+2]}
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
  ble/string#split-words nest "${_ble_syntax_nest[index]}"
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
      nparam=" nparam=${nparam//$_ble_term_FS/$'\e[7m^\\\e[m'}"
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
  ble/string#split-words stat "${_ble_syntax_stat[index]}"
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
      snparam=" nparam=${snparam//"$_ble_term_FS"/$'\e[7m^\\\e[m'}"
    fi

    local stat_lookahead=
    ((stat[7]!=1)) && stat_lookahead=" >>${stat[7]}"
    stat=" stat=($stat_ctx w=$stat_word n=$stat_inest t=$stat_child:$stat_prev$snparam$stat_lookahead)"
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

    local index=000$i
    index=${index:${#index}-3:3}

    local word nest stat
    ble-syntax/print-status/word.get-text "$i"
    ble-syntax/print-status/nest.get-text "$i"
    ble-syntax/print-status/stat.get-text "$i"

    local graph=
    ble-syntax/print-status/.graph "${_ble_syntax_text:i:1}"
    char[i]="$attr $index $graph"
    line[i]=$word$nest$stat
  done

  resultA='_ble_syntax_attr/tree/nest/stat?'$'\n'
  _ble_util_string_prototype.reserve max_tree_width
  for ((i=0;i<=iN;i++)); do
    local t=${tree[i]}${_ble_util_string_prototype::max_tree_width}
    resultA="$resultA${char[i]} ${t::max_tree_width}${line[i]}"$'\n'
  done
}

## 関数 ble-syntax/print-status/.dump-tree/proc1
## @var[out] resultB
## @var[in]  prefix
## @var[in]  nl
function ble-syntax/print-status/.dump-tree/proc1 {
  local tip="| "; tip=${tip:islast:1}
  prefix="$prefix$tip   " ble-syntax/tree-enumerate-children ble-syntax/print-status/.dump-tree/proc1
  resultB="$prefix\_ '${_ble_syntax_text:wbegin:wlen}'$nl$resultB"
}

## 関数 ble-syntax/print-status/.dump-tree
## @var[out] resultB
## @var[in]  iN
function ble-syntax/print-status/.dump-tree {
  resultB=

  local nl=$_ble_term_nl
  local prefix=
  ble-syntax/tree-enumerate ble-syntax/print-status/.dump-tree/proc1
}

function ble-syntax/print-status {
  local iN=${#_ble_syntax_text}

  local resultA
  ble-syntax/print-status/.dump-arrays

  local resultB
  ble-syntax/print-status/.dump-tree

  local result=$resultA$resultB
  if [[ $1 == -v && $2 ]]; then
    local "${2%%\[*\]}" && ble/util/upvar "$2" "$result"
  else
    builtin echo "$result"
  fi
}

#--------------------------------------

function ble-syntax/parse/generate-stat {
  ((ilook<=i&&(ilook=i+1)))
  _stat="$ctx $((wbegin<0?wbegin:i-wbegin)) $wtype $((inest<0?inest:i-inest)) $((tchild<0?tchild:i-tchild)) $((tprev<0?tprev:i-tprev)) ${nparam:-none} $((ilook-i))"
}


## 関数 ble-syntax/parse/set-lookahead count
##
##   @param[in] count
##     現在位置の何文字先まで参照して動作を決定したかを指定します。
##   @var[out] i
##   @var[out] ilook
##
##   例えば "a@bcdx" の @ の位置に i があって、
##   x の文字を見て c 直後までしか読み取らない事を決定したとき、
##   set-lookahead 4 を実行して i を 2 進めるか、
##   i を 2 進めてから set-lookahead 2 を実行します。
##
##   最終的に i の次の 1 文字までしか参照しない時、
##   set-lookahead を呼び出す必要はありません。
##
function ble-syntax/parse/set-lookahead {
  ((i+$1>ilook&&(ilook=i+$1)))
}

# 構文木の管理 (_ble_syntax_tree)

## 関数 ble-syntax/parse/tree-append
## 要件 解析位置を進めてから呼び出す必要があります (要件: i>=p1+1)。
function ble-syntax/parse/tree-append {
#%if !release
  [[ $debug_p1 ]] && { ((i-1>=debug_p1)) || ble-stackdump "Wrong call of tree-append: Condition violation (p1=$debug_p1 i=$i iN=$iN)."; }
#%end
  local type=$1
  local beg=$2 end=$i
  local len=$((end-beg))
  ((len==0)) && return

  local tchild=$3 tprev=$4

  # 子情報・兄情報
  local ochild=-1 oprev=-1
  ((tchild>=0&&(ochild=i-tchild)))
  ((tprev>=0&&(oprev=i-tprev)))

  [[ $type =~ ^[0-9]+$ ]] && ble-syntax/parse/touch-updated-word "$i"

  # 追加する要素の数は BLE_SYNTAX_TREE_WIDTH と一致している必要がある。
  _ble_syntax_tree[i-1]="$type $len $ochild $oprev - ${_ble_syntax_tree[i-1]}"
}

function ble-syntax/parse/word-push {
  wtype=$1 wbegin=$2 tprev=$tchild tchild=-1
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
  ble/string#split-words word "${_ble_syntax_tree[i-1]}"
  local wlen=${word[1]} tplen=${word[3]}
  local wbegin=$((i-wlen))
  tchild=$((tplen<0?tplen:i-tplen))
  ble/dense-array#fill-range _ble_syntax_tree "$wbegin" "$i" ''
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
  ble/string#split-words parentNest "${_ble_syntax_nest[inest]}"

  local ntype=${parentNest[7]} nbeg=$inest
  ble-syntax/parse/tree-append "n$ntype" "$nbeg" "$tchild" "$tprev"

  local wlen=${parentNest[1]} nlen=${parentNest[3]} tplen=${parentNest[5]}
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
## 関数 ble-syntax/parse/nest-ctx
##   @var[out] nctx
function ble-syntax/parse/nest-ctx {
  nctx=
  ((inest>=0)) || return 1
  nctx=${_ble_syntax_nest[inest]%% *}
}
function ble-syntax/parse/nest-reset-tprev {
  if ((inest<0)); then
    tprev=-1
  else
    local -a nest
    ble/string#split-words nest "${_ble_syntax_nest[inest]}"
    local tclen=${nest[4]}
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
  local parent_inest=$1
  while :; do
    ((parent_inest<i1)) && return 0 # 変更していない範囲 または -1
    ((parent_inest<i2)) && return 1 # 変更によって消えた範囲

    local _onest=${_tail_syntax_nest[parent_inest-i2]}
    local _nnest=${_ble_syntax_nest[parent_inest]}
    [[ $_onest != "$_nnest" ]] && return 1

    local -a onest; ble/string#split-words onest "$_onest"
#%if !release
    ((onest[3]!=0&&onest[3]<=parent_inest)) || { ble-stackdump "invalid nest onest[3]=${onest[3]} parent_inest=$parent_inest text=$text" && return 0; }
#%end
    ((parent_inest=onest[3]<0?onest[3]:(parent_inest-onest[3])))
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

## 関数 ble-syntax/ctx#get_name [-v varname]
##   @var[in] varname
##     既定値 ret
##   @var[out] !varname
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
_ble_syntax_bash_RexSpaces=$'[ \t]+'
_ble_syntax_bash_RexIFSs="[$_ble_syntax_bash_IFS]+"
_ble_syntax_bash_RexDelimiter="[$_ble_syntax_bash_IFS;|&<>()]"
_ble_syntax_bash_RexRedirect='((\{[a-zA-Z_][a-zA-Z_0-9]*\}|[0-9]+)?(&?>>?|>[|&]|<[>&]?|<<[-<]?))[ 	]*'

## @var _ble_syntax_bash_chars[]
##   特定の役割を持つ文字の集合。Bracket expression [～] に入れて使う為の物。
##   histchars に依存しているので変化があった時に更新する。
_ble_syntax_bash_chars=()
_ble_syntax_bashc_seed=

function ble-syntax:bash/cclass/update/reorder {
  eval "local a=\"\${$1}\""

  # Bracket expression として安全な順に並び替える
  [[ $a == *']'* ]] && a="]${a//]}"
  [[ $a == *'-'* ]] && a="${a//-}-"

  eval "$1=\$a"
}

## 関数 ble-syntax:bash/cclass/update
##
##   @var[in] _ble_syntax_bash_histc12
##   @var[in,out] _ble_syntax_bashc_seed
##   @var[in,out] _ble_syntax_bash_chars[]
##
##   @exit 更新があった時に正常終了します。
##     更新の必要がなかった時に 1 を返します。
##
function ble-syntax:bash/cclass/update {
  local seed=$_ble_syntax_bash_histc12
  shopt -q extglob && seed=${seed}x
  [[ $seed == "$_ble_syntax_bashc_seed" ]] && return 1
  _ble_syntax_bashc_seed=$seed

  local key modified=
  if [[ $_ble_syntax_bash_histc12 == '!^' ]]; then
    for key in "${!_ble_syntax_bash_charsDef[@]}"; do
      _ble_syntax_bash_chars[key]=${_ble_syntax_bash_charsDef[key]}
    done
    _ble_syntax_bashc_simple=$_ble_syntax_bash_chars_simpleDef
  else
    modified=1

    local histc1=${_ble_syntax_bash_histc12:0:1}
    local histc2=${_ble_syntax_bash_histc12:1:1}
    for key in "${!_ble_syntax_bash_charsFmt[@]}"; do
      local a=${_ble_syntax_bash_charsFmt[key]}
      a=${a//@h/$histc1}
      a=${a//@q/$histc2}
      _ble_syntax_bash_chars[key]=$a
    done

    local a=$_ble_syntax_bash_chars_simpleFmt
    a=${a//@h/$histc1}
    a=${a//@q/$histc2}
    _ble_syntax_bashc_simple=$a
  fi


  if [[ $seed == *x ]]; then
    # extglob: ?() *() +() @() !()
    local extglob='@+!' # *? は既に登録されている筈
    _ble_syntax_bash_chars[CTX_ARGI]=${_ble_syntax_bash_chars[CTX_ARGI]}$extglob
    _ble_syntax_bash_chars[CTX_PATN]=${_ble_syntax_bash_chars[CTX_PATN]}$extglob
  fi

  if [[ $modified ]]; then
    for key in "${!_ble_syntax_bash_chars[@]}"; do
      ble-syntax:bash/cclass/update/reorder _ble_syntax_bash_chars[key]
    done
    ble-syntax:bash/cclass/update/reorder _ble_syntax_bashc_simple
  fi
  return 0
}

_ble_syntax_bash_charsDef=()
_ble_syntax_bash_charsFmt=()
_ble_syntax_bash_chars_simpleDef=
_ble_syntax_bash_chars_simpleFmt=
function ble-syntax:bash/cclass/initialize {
  local delimiters="$_ble_syntax_bash_IFS;|&()<>"
  local expansions="\$\"\`\\'"
  local glob='[*?'
  local tilde='~:'

  # _ble_syntax_bash_chars[CTX_ARGI] は以下で使われている
  #   ctx-command (色々)
  #   ctx-redirect (CTX_RDRF, CTX_RDRD, CTX_RDRS)
  #   ctx-values (CTX_VALI, CTX_VALR, CTX_VALQ)
  #   ctx-conditions (CTX_CONDI, CTX_CONDQ)
  # 更に以下でも使われている
  #   ctx-bracket-expression
  #   ctx-brace-expansion
  #   check-tilde-expansion

  # default values
  _ble_syntax_bash_charsDef[CTX_ARGI]="$delimiters$expansions$glob{$tilde^!"
  _ble_syntax_bash_charsDef[CTX_PATN]="$expansions$glob(|)<>{!" # <> はプロセス置換のため。
  _ble_syntax_bash_charsDef[CTX_QUOT]="\$\"\`\\!"         # 文字列 "～" で特別な意味を持つのは $ ` \ " のみ。+履歴展開の ! も。
  _ble_syntax_bash_charsDef[CTX_EXPR]="][}()$expansions!" # ()[] は入れ子を数える為。} は ${var:ofs:len} の為。
  _ble_syntax_bash_charsDef[CTX_PWORD]="}$expansions!"    # パラメータ展開 ${～}
  _ble_syntax_bash_charsDef[CTX_RDRH]="$delimiters$expansions"

  # templates
  _ble_syntax_bash_charsFmt[CTX_ARGI]="$delimiters$expansions$glob{$tilde@q@h"
  _ble_syntax_bash_charsFmt[CTX_PATN]="$expansions$glob(|)<>{@h"
  _ble_syntax_bash_charsFmt[CTX_QUOT]="\$\"\`\\@h"
  _ble_syntax_bash_charsFmt[CTX_EXPR]="][}()$expansions@h"
  _ble_syntax_bash_charsFmt[CTX_PWORD]="}$expansions@h"
  _ble_syntax_bash_charsFmt[CTX_RDRH]=${_ble_syntax_bash_charsDef[CTX_RDRH]}

  _ble_syntax_bash_chars_simpleDef="$delimiters$expansions^!"
  _ble_syntax_bash_chars_simpleFmt="$delimiters$expansions@q@h"

  _ble_syntax_bash_histc12='!^'
  ble-syntax:bash/cclass/update
}

ble-syntax:bash/cclass/initialize

## @var _ble_syntax_bash_simple_rex_word
## @var _ble_syntax_bash_simple_rex_element
##   単純な単語のパターンとその構成要素を表す正規表現
##   histchars に依存しているので変化があった時に更新する。
_ble_syntax_bash_simple_rex_word=
_ble_syntax_bash_simple_rex_element=
_ble_syntax_bash_simple_rex_letter=
_ble_syntax_bash_simple_rex_quote=
_ble_syntax_bash_simple_rex_param=
function ble-syntax:bash/simple-word/update {
  local q="'"
  local letter='\[[!^]|[^'${_ble_syntax_bashc_simple}']'
  local param1='\$([-*@#?$!0_]|[1-9][0-9]*|[a-zA-Z_][a-zA-Z_0-9]*)'
  local param2='\$\{(#?[-*@#?$!0]|[#!]?([1-9][0-9]*|[a-zA-Z_][a-zA-Z_0-9]*))\}' # ${!!} ${!$} はエラーになる。履歴展開の所為?
  local squot='"[^"]*"|\$"([^"\]|\\.)*"'; squot="${squot//\"/$q}"
  local dquot='\$?"([^'${_ble_syntax_bash_chars[CTX_QUOT]}']|\\.)*"'
  _ble_syntax_bash_simple_rex_element='(\\.|'$squot'|'$dquot'|'$param1'|'$param2'|'$letter')'
  _ble_syntax_bash_simple_rex_word='^'$_ble_syntax_bash_simple_rex_element'+$'
  _ble_syntax_bash_simple_rex_letter=$letter
  _ble_syntax_bash_simple_rex_quote='\\.|'$squot'|'$dquot
  _ble_syntax_bash_simple_rex_param=$param1'|'$param2
}
ble-syntax:bash/simple-word/update

function ble-syntax:bash/simple-word/is-simple {
  [[ $1 =~ $_ble_syntax_bash_simple_rex_word ]]
}
function ble-syntax:bash/simple-word/extract-parameter-names {
  ret=()
  local word=$1
  local rex1='^('$_ble_syntax_bash_simple_rex_quote'|'$_ble_syntax_bash_simple_rex_letter')+'
  local rex2='^'$_ble_syntax_bash_simple_rex_param
  while [[ $word ]]; do
    [[ $word =~ $rex1 ]] && word=${word:${#BASH_REMATCH}}
    [[ $word =~ $rex2 ]] || break
    word=${word:${#BASH_REMATCH}}
    local var=${BASH_REMATCH[1]}${BASH_REMATCH[2]}
    [[ $var == [_a-zA-Z]* ]] && ble/array#push ret "$var"
  done
}
function ble-syntax:bash/simple-word/eval-noglob.impl {
  # グローバル変数の復元
  local -a ret
  ble-syntax:bash/simple-word/extract-parameter-names "$1"
  if ((${#ret[@]})); then
    local __ble_defs
    ble/util/assign __ble_defs 'ble/util/print-global-definitions --hidden-only "${ret[@]}"'
    builtin eval -- "$__ble_defs" &>/dev/null # 読み取り専用の変数のこともある
  fi

  builtin eval -- "__ble_ret=$1"; local ext=$?
  builtin eval : # Note: bash 3.1/3.2 eval バグ対策 (#D1132)
  return "$ext"
}
function ble-syntax:bash/simple-word/eval-noglob {
  local __ble_ret
  ble-syntax:bash/simple-word/eval-noglob.impl "$1"
  ret=$__ble_ret
}
function ble-syntax:bash/simple-word/eval.impl {
  # グローバル変数の復元
  local -a ret=()
  ble-syntax:bash/simple-word/extract-parameter-names "$1"
  if ((${#ret[@]})); then
    local __ble_defs
    ble/util/assign __ble_defs 'ble/util/print-global-definitions --hidden-only "${ret[@]}"'
    builtin eval -- "$__ble_defs" &>/dev/null # 読み取り専用の変数のこともある
  fi

  if [[ $1 == ['[#']* ]]; then
    # 先頭に [ があると配列添字と解釈されて失敗するので '' を前置する。
    builtin eval "__ble_ret=(''$1)"; local ext=$?
  else
    # 先頭が [ 以外の時は tilde expansion 等が有効になる様に '' は前置しない。
    builtin eval "__ble_ret=($1)"; local ext=$?
  fi &>/dev/null # Note: failglob 時に一致がないとエラーが生じる
  builtin eval : # Note: bash 3.1/3.2 eval バグ対策 (#D1132)
  return "$ext"
}
## 関数 ble-syntax:bash/simple-word/eval
##
##   @exit
##     shopt -q failglob の時、パス名展開に失敗すると
##     0 以外の終了ステータスを返します。
##
function ble-syntax:bash/simple-word/eval {
  local __ble_ret
  ble-syntax:bash/simple-word/eval.impl "$1"; local ext=$?
  ret=$__ble_ret
  return "$ext"
}

function ble-syntax:bash/initialize-ctx {
  ctx=$CTX_CMDX # CTX_CMDX が ble-syntax:bash の最初の文脈
}

## 関数 ble-syntax:bash/initialize-vars
##   @var[in,out] _ble_syntax_bash_histc12
##   @var[in,out] _ble_syntax_bash_histstop
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
  local histc12
  if [[ ${histchars+set} ]]; then
    histc12=${histchars::2}
  else
    histc12='!^'
  fi
  _ble_syntax_bash_histc12=$histc12

  if ble-syntax:bash/cclass/update; then
    ble-syntax:bash/simple-word/update
  fi

  local histstop=$' \t\n='
  shopt -q extglob && histstop="$histstop("
  _ble_syntax_bash_histstop=$histstop
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
      local rematch1=${BASH_REMATCH[1]}
      local rematch2=${BASH_REMATCH[2]}
      local rematch3=${BASH_REMATCH[3]}

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
    if rex='^(\$?")([^'"${_ble_syntax_bash_chars[CTX_QUOT]}"']|\\.)*("?)' && [[ $tail =~ $rex ]]; then
      local rematch1=${BASH_REMATCH[1]} # for bash-3.1 ${#arr[n]} bug
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
  [[ $tail == ['[?*@+!()|']* ]] || return 1

  local ntype= force_attr=
  if ((ctx==CTX_VRHS||ctx==CTX_ARGVR||ctx==CTX_VALR||ctx==CTX_RDRS)); then
    force_attr=$ctx
    ntype="glob_attr=$force_attr"
  elif ((ctx==CTX_PATN||ctx==CTX_BRAX)); then
    ble-syntax/parse/nest-type -v ntype
    local exit_attr=
    if [[ $ntype == glob_attr=* ]]; then
      force_attr=${ntype#*=}
      exit_attr=$force_attr
    elif ((ctx==CTX_BRAX)); then
      force_attr=$ctx
      ntype="glob_attr=$force_attr"
    elif ((ctx==CTX_PATN)); then
      if [[ $ntype == glob_nest ]]; then
        exit_attr=$CTX_PATN
      else
        exit_attr=$ATTR_GLOB
      fi
      ntype=
    else
      ntype=
    fi
  elif [[ $1 == assign ]]; then
    # $1 == assign の時、arr[... の "[" の位置で呼び出されたことを意味する。
    ntype='a['
  fi

  if [[ $tail == ['?*@+!']'('* ]] && shopt -q extglob; then
    ble-syntax/parse/nest-push "$CTX_PATN" "$ntype"
    ((_ble_syntax_attr[i]=${force_attr:-ATTR_GLOB},i+=2))
    return 0
  fi

  # 履歴展開の解釈の方が強い
  local histc1=${_ble_syntax_bash_histc12::1}
  [[ $histc1 && $tail == "$histc1"* ]] && return 1

  if [[ $tail == '['* ]]; then
    if ((ctx==CTX_BRAX)); then
      # 角括弧式の中の [ or [! はそのまま読み飛ばす。
      ((_ble_syntax_attr[i++]=force_attr))
      [[ $tail == '[!'* ]] && ((i++))
      return 0
    fi

    ble-syntax/parse/nest-push "$CTX_BRAX" "$ntype"
    ((_ble_syntax_attr[i++]=${force_attr:-ATTR_GLOB}))
    [[ $tail == '[!'* ]] && ((i++))
    if [[ ${text:i:1} == ']' ]]; then
      ((_ble_syntax_attr[i++]=${force_attr:-CTX_BRAX}))
    elif [[ ${text:i:1} == '[' ]]; then
      # Note: 条件コマンド [[ に変換する為に [[ の連なりは一度に読み取る。
      if [[ ${text:i+1:1} == [:=.] ]]; then
        # Note: glob bracket expression が POSIX 括弧で始まっている時は
        # [[ が一まとまりになっていると困るので除外。
        ble/syntax/parse/set-lookahead 2
      else
        ((_ble_syntax_attr[i++]=${force_attr:-CTX_BRAX}))
        [[ ${text:i:1} == '!'* ]] && ((i++))
      fi
    fi

    return 0
  elif [[ $tail == ['?*']* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-ATTR_GLOB}))
    return 0
  elif [[ $tail == ['@+!']* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
    return 0
  elif ((ctx==CTX_PATN||ctx==CTX_BRAX)); then
    if [[ $tail == '('* ]]; then
      ble-syntax/parse/nest-push "$CTX_PATN" "${ntype:-glob_nest}"
      ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
      return 0
    elif [[ $tail == ')'* ]]; then
      if ((ctx==CTX_PATN)); then
        ((_ble_syntax_attr[i++]=exit_attr))
        ble-syntax/parse/nest-pop
      else
        ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
      fi
      return 0
    elif [[ $tail == '|'* ]]; then
      ((_ble_syntax_attr[i++]=${force_attr:-ATTR_GLOB}))
      return 0
    fi
  fi

  return 1
}

_ble_syntax_bash_histexpand_RexWord=
_ble_syntax_bash_histexpand_RexMods=
_ble_syntax_bash_histexpand_RexEventDef=
_ble_syntax_bash_histexpand_RexQuicksubDef=
_ble_syntax_bash_histexpand_RexEventFmt=
_ble_syntax_bash_histexpand_RexQuicksubFmt=
function ble-syntax:bash/check-history-expansion/.initialize {
  local spaces=$' \t\n' nl=$'\n'
  local rex_event='-?[0-9]+|[!#]|[^-$^*%:'$spaces'=?!#;&|<>()]+|\?[^?'$nl']*\??'
  _ble_syntax_bash_histexpand_RexEventDef='^!('$rex_event')'

  local rex_word1='([0-9]+|[$%^])'
  local rex_wordsA=':('$rex_word1'?-'$rex_word1'?|\*|'$rex_word1'\*?)'
  local rex_wordsB='([$%^]?-'$rex_word1'?|\*|[$^%][*-]?)'
  _ble_syntax_bash_histexpand_RexWord='('$rex_wordsA'|'$rex_wordsB')?'

  # ※本当は /s(.)([^\]|\\.)*?\1([^\]|\\.)*?\1/ 等としたいが *? は ERE にない。
  #   仕方がないので ble-syntax:bash/check-history-expansion/.check-modifiers
  #   にて繰り返し正規表現を適用して s?..?..? を読み取る。
  local rex_modifier=':[htrepqx]|:[gGa]?&|:[gGa]?s(/([^\/]|\\.)*){0,2}(/|$)'
  _ble_syntax_bash_histexpand_RexMods='('$rex_modifier')*'

  _ble_syntax_bash_histexpand_RexQuicksubDef='\^([^^\]|\\.)*\^([^^\]|\\.)*\^'

  # for histchars
  _ble_syntax_bash_histexpand_RexQuicksubFmt='@A([^@C\]|\\.)*@A([^@C\]|\\.)*@A'
  _ble_syntax_bash_histexpand_RexEventFmt='^@A('$rex_event'|@A)'
}
ble-syntax:bash/check-history-expansion/.initialize

## 関数 ble-syntax:bash/check-history-expansion/.initialize-event
##   @var[out] rex_event
function ble-syntax:bash/check-history-expansion/.initialize-event {
  local histc1=${_ble_syntax_bash_histc12::1}
  if [[ $histc1 == '!' ]]; then
    rex_event=$_ble_syntax_bash_histexpand_RexEventDef
  else
    local A="[$histc1]"
    [[ $histc1 == '^' ]] && A='\^'
    rex_event=$_ble_syntax_bash_histexpand_RexEventFmt
    rex_event=${rex_event//@A/$A}
  fi
}
## 関数 ble-syntax:bash/check-history-expansion/.initialize-quicksub
##   @var[out] rex_quicksub
function ble-syntax:bash/check-history-expansion/.initialize-quicksub {
  local histc2=${_ble_syntax_bash_histc12:1:1}
  if [[ $histc2 == '^' ]]; then
    rex_quicksub=$_ble_syntax_bash_histexpand_RexQuicksubDef
  else
    rex_quicksub=$_ble_syntax_bash_histexpand_RexQuicksubFmt
    rex_quicksub=${rex_quicksub//@A/[$histc2]}
    rex_quicksub=${rex_quicksub//@C/$histc2}
  fi
}
function ble-syntax:bash/check-history-expansion/.check-modifiers {
  # check simple modifiers
  [[ ${text:i} =~ $_ble_syntax_bash_histexpand_RexMods ]] &&
    ((i+=${#BASH_REMATCH}))

  # check :s?..?..? form modifier
  if local rex='^:[gGa]?s(.)'; [[ ${text:i} =~ $rex ]]; then
    local del=${BASH_REMATCH[1]}
    local A="[$del]" B="[^$del]"
    [[ $del == '^' || $del == ']' ]] && A='\'$del
    [[ $del != '\' ]] && B=$B'|\\.'

    local rex_substitute='^:[gGa]?s('$A'('$B')*){0,2}('$A'|$)'
    if [[ ${text:i} =~ $rex_substitute ]]; then
      ((i+=${#BASH_REMATCH}))
      ble-syntax:bash/check-history-expansion/.check-modifiers
      return
    fi
  fi

  # ErrMsg 'unrecognized modifier'
  if [[ ${text:i} == ':'[gGa]* ]]; then
    ((_ble_syntax_attr[i+1]=ATTR_ERR,i+=2))
  elif [[ ${text:i} == ':'* ]]; then
    ((_ble_syntax_attr[i]=ATTR_ERR,i++))
  fi
}
## 関数 ble-syntax:bash/check-history-expansion
##   @var[in] i tail
function ble-syntax:bash/check-history-expansion {
  [[ -o histexpand ]] || return 1

  local histc1=${_ble_syntax_bash_histc12:0:1}
  local histc2=${_ble_syntax_bash_histc12:1:1}
  if [[ $histc1 && $tail == "$histc1"[^"$_ble_syntax_bash_histstop"]* ]]; then

    # "～" 文字列中では一致可能範囲を制限する。
    if ((ctx==CTX_QUOT)); then
      local tail=${tail%%'"'*}
      [[ $tail == '!' ]] && return 1
    fi

    ((_ble_syntax_attr[i]=ATTR_HISTX))
    local rex_event
    ble-syntax:bash/check-history-expansion/.initialize-event
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
    [[ ${text:i} =~ $_ble_syntax_bash_histexpand_RexWord ]] &&
      ((i+=${#BASH_REMATCH}))

    ble-syntax:bash/check-history-expansion/.check-modifiers
    return 0
  elif ((i==0)) && [[ $histc2 && $tail == "$histc2"* ]]; then
    ((_ble_syntax_attr[i]=ATTR_HISTX))
    local rex_quicksub
    ble-syntax:bash/check-history-expansion/.initialize-quicksub
    if [[ $tail =~ $rex_quicksub ]]; then
      ((i+=${#BASH_REMATCH}))

      ble-syntax:bash/check-history-expansion/.check-modifiers
      return 0
    else
      # 末端まで
      ((i+=${#tail}))
      return 0
    fi
  fi

  return 1
}
## 関数 ble-syntax:bash/starts-with-histchars
##   @var[in] tail
function ble-syntax:bash/starts-with-histchars {
  [[ $_ble_syntax_bash_histc12 && $tail == ["$_ble_syntax_bash_histc12"]* ]]
}

#------------------------------------------------------------------------------
# 文脈: 各種文脈

_BLE_SYNTAX_FCTX[CTX_QUOT]=ble-syntax:bash/ctx-quot
function ble-syntax:bash/ctx-quot {
  # 文字列の中身
  local rex
  if rex='^([^'"${_ble_syntax_bash_chars[CTX_QUOT]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
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
  elif ble-syntax:bash/starts-with-histchars; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

_BLE_SYNTAX_FCTX[CTX_CASE]=ble-syntax:bash/ctx-case
function ble-syntax:bash/ctx-case {
  if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif [[ $tail == '('* ]]; then
    ((ctx=CTX_CMDX))
    ble-syntax/parse/nest-push "$CTX_PATN"
    ((_ble_syntax_attr[i++]=ATTR_GLOB))
    return 0
  elif [[ $tail == 'esac'$_ble_syntax_bash_RexDelimiter* || $tail == 'esac' ]]; then
    ((ctx=CTX_CMDX1))
    ble-syntax:bash/ctx-command
  else
    ((ctx=CTX_CMDX))
    ble-syntax/parse/nest-push "$CTX_PATN"
    ble-syntax:bash/ctx-globpat
  fi
}

# 文脈 CTX_PATN (extglob/case-pattern)
_BLE_SYNTAX_FCTX[CTX_PATN]=ble-syntax:bash/ctx-globpat
function ble-syntax:bash/ctx-globpat {
  # glob () の中身 (extglob @(...) や case in (...) の中)
  local rex
  if rex='^([^'${_ble_syntax_bash_chars[CTX_PATN]}']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif ble-syntax:bash/check-process-subst; then
    return 0
  elif [[ $tail == ['<>']* ]]; then
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  elif ble-syntax:bash/check-quotes; then
    return 0
  elif ble-syntax:bash/check-dollar; then
    return 0
  elif ble-syntax:bash/check-glob; then
    return 0
  elif ble-syntax:bash/check-brace-expansion; then
    return 0
  elif ble-syntax:bash/starts-with-histchars; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

# 文脈 CTX_BRAX (bracket expression)
_BLE_SYNTAX_FCTX[CTX_BRAX]=ble-syntax:bash/ctx-bracket-expression
_BLE_SYNTAX_FEND[CTX_BRAX]=ble-syntax:bash/ctx-bracket-expression.end
function ble-syntax:bash/ctx-bracket-expression {
  local nctx; ble-syntax/parse/nest-ctx
  if ((nctx==CTX_PATN)); then
    local chars=${_ble_syntax_bash_chars[CTX_PATN]}
  else
    # 以下の文脈では ctx-command と同様の処理で問題ない。
    #
    #   ctx-command (色々)
    #   ctx-redirect (CTX_RDRF CTX_RDRD CTX_RDRS)
    #   ctx-values (CTX_VALI, CTX_VALR, CTX_VALQ)
    #   ctx-conditions (CTX_CONDI, CTX_CONDQ)
    #     この文脈では例外として && || < > など一部の演算子で delimiters
    #     が単語中に許されるが、この例外は [...] を含む単語には当てはまらない。
    #
    # is-delimiters の時に [... は其処で不完全終端する。
    local chars=${_ble_syntax_bash_chars[CTX_ARGI]//'~'}
  fi
  chars="][${chars#']'}"

  local ntype; ble-syntax/parse/nest-type -v ntype
  local force_attr=; [[ $ntype == glob_attr=* ]] && force_attr=${ntype#*=}

  local rex
  if [[ $tail == ']'* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-ATTR_GLOB}))
    ble-syntax/parse/nest-pop

    # 通常引数が配列代入の形式を持つとき、以降でチルダ展開が有効
    # 例: echo arr[i]=... arr[i]+=...
    if [[ $ntype == 'a[' ]]; then
      local is_assign=
      if [[ $tail == ']='* ]]; then
        ((_ble_syntax_attr[i++]=ctx,is_assign=1))
      elif [[ $tail == ']+'* ]]; then
        ble-syntax/parse/set-lookahead 2
        [[ $tail == ']+=' ]] && ((_ble_syntax_attr[i]=ctx,i+=2,is_assign=1))
      fi

      if [[ $is_assign ]]; then
        ble-assert '[[ ${_ble_syntax_bash_command_CtxAssign[ctx]} ]]'
        ((ctx=_ble_syntax_bash_command_CtxAssign[ctx]))
        if local tail=${text:i}; [[ $tail == '~'* ]]; then
          ble-syntax:bash/check-tilde-expansion rhs
        fi
      fi
    fi
    return 0
  elif [[ $tail == '['* ]]; then
    rex='^\[@([^'$chars']+(@\]?)?)?'
    rex=${rex//@/:}'|'${rex//@/'\.'}'|'${rex//@/=}'|^\['
    [[ $tail =~ $rex ]]
    ((_ble_syntax_attr[i]=${force_attr:-ctx},
      i+=${#BASH_REMATCH}))
    return 0
  elif rex='^([^'$chars']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=${force_attr:-ctx},
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
  elif ble-syntax:bash/check-brace-expansion; then
    return 0
  elif ble-syntax:bash/check-tilde-expansion; then
    return 0
  elif ble-syntax:bash/starts-with-histchars; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
    return 0
  elif ((nctx==CTX_PATN)) && [[ $tail == ['<>']* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
    return 0
  fi

  return 1
}
function ble-syntax:bash/ctx-bracket-expression.end {
  local is_end=

  local nctx; ble-syntax/parse/nest-ctx
  if ((nctx==CTX_PATN)); then
    # 外側は ctx-globpat
    local tail=${text:i}
    [[ ! $tail || $tail == ')'* ]] && is_end=1
  else
    # 外側は ctx-command など。
    ble-syntax:bash/check-word-end/is-delimiter && is_end=1
    [[ $tail == ':'* && ${_ble_syntax_bash_command_IsAssign[ctx]} ]] && is_end=1
  fi

  if [[ $is_end ]]; then
    ble-syntax/parse/nest-pop
    ble-syntax/parse/check-end
    return
  fi

  return 0
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
  if rex='^([^'"${_ble_syntax_bash_chars[ctx]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
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
  elif ble-syntax:bash/starts-with-histchars; then
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
##   'a['  @ check-variable-assignment    o  a[...]= の中身
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
        tail=${text:i} ble-syntax:bash/check-tilde-expansion rhs
      elif ((_ble_bash>=30100)) && [[ $tail == ']+'* ]]; then
        ble-syntax/parse/set-lookahead 2
        if [[ $tail == ']+='* ]]; then
          # a[...]+=, a+=([...]+=) の場合
          ((i+=2))
          tail=${text:i} ble-syntax:bash/check-tilde-expansion rhs
        fi
      else
        if [[ $ntype == 'a[' ]]; then
          # a[...]... という唯のコマンドの場合。
          if ((ctx==CTX_VRHS)); then
            # 例: arr[123]aaa
            ((ctx=CTX_CMDI,wtype=CTX_CMDI))
          elif ((ctx==CTX_ARGVR)); then
            # 例: declare arr[123]aaa
            ((ctx=CTX_ARGVI,wtype=CTX_ARGVI))
          fi
        else # ntype == 'd['
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
  if rex='^([^'"${_ble_syntax_bash_chars[ctx]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
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
  elif ble-syntax:bash/starts-with-histchars; then
    # 恐ろしい事に数式中でも履歴展開が有効…。
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

#------------------------------------------------------------------------------
# ブレース展開

## CTX_CONDI 及び CTX_RDRS の時は不活性化したブレース展開として振る舞う
## CTX_RDRF 及び CTX_RDRD の時は複数語に展開されるブレース展開はエラーなので、
## nest-push して解析だけ行いブレース展開であるということが確定した時点でエラーを設定する。

function ble-syntax:bash/check-brace-expansion {
  [[ $tail == '{'* ]] || return 1

  local rex='^\{[0-9a-zA-Z.]*(\}?)'
  [[ $tail =~ $rex ]]
  local str=$BASH_REMATCH

  local force_attr= inactive=

  # 特定の文脈では完全に不活性
  # Note: {fd}> リダイレクトの先読みに合わせて、
  #   不活性であっても一気に読み取る必要がある。
  #   cf ble-syntax:bash/starts-with-delimiter-or-redirect
  if ((ctx==CTX_CONDI||ctx==CTX_CONDQ||ctx==CTX_RDRS||ctx==CTX_VRHS||ctx==CTX_ARGVR||ctx==CTX_VALR)); then
    inactive=1
  elif ((ctx==CTX_PATN||ctx==CTX_BRAX)); then
    local ntype; ble-syntax/parse/nest-type -v ntype
    if [[ $ntype == glob_attr=* ]]; then
      force_attr=${ntype#*=}
      (((force_attr==CTX_RDRS||force_attr==CTX_VRHS||force_attr==CTX_ARGVR||force_attr==CTX_VALR)&&(inactive=1)))
    elif ((ctx==CTX_BRAX)); then
      local nctx; ble-syntax/parse/nest-ctx
      (((nctx==CTX_CONDI||octx==CTX_CONDQ)&&(inactive=1)))
    fi
  elif ((ctx==CTX_BRACE1||ctx==CTX_BRACE2)); then
    local ntype; ble-syntax/parse/nest-type -v ntype
    if [[ $ntype == glob_attr=* ]]; then
      force_attr=${ntype#*=}
    fi
  fi

  if [[ $inactive ]]; then
    ((_ble_syntax_attr[i]=${force_attr:-ctx},i+=${#str}))
    return 0
  fi

  # ブレース展開がある時チルダ展開は無効化される
  # Note: CTX_VRHS 等のときは inactive なので此処には来ないので OK
  [[ ${_ble_syntax_bash_command_IsAssign[ctx]} ]] &&
    ctx=${_ble_syntax_bash_command_IsAssign[ctx]}

  # {a..b..c} の形式のブレース展開
  if rex='^\{(([0-9]+)\.\.[0-9]+|[a-zA-Z]\.\.[a-zA-Z])(\.\.[0-9]+)?\}$'; [[ $str =~ $rex ]]; then
    if [[ $force_attr ]]; then
      ((_ble_syntax_attr[i]=force_attr,i+=${#str}))
    else
      local rematch1=${BASH_REMATCH[1]}
      local rematch2=${BASH_REMATCH[2]}
      local rematch3=${BASH_REMATCH[3]}
      local len2=${#rematch2}; ((len2||(len2=1)))
      local attr=$ATTR_BRACE
      if ((ctx==CTX_RDRF||ctx==CTX_RDRD)); then
        if [[ ${rematch1::len2} != "${rematch1:len2+2}" ]]; then
          ((attr=ATTR_ERR))
        fi
      fi

      ((_ble_syntax_attr[i++]=attr))
      ((_ble_syntax_attr[i]=ctx,i+=len2,
        _ble_syntax_attr[i]=ATTR_BRACE,i+=2,
        _ble_syntax_attr[i]=ctx,i+=${#rematch1}-len2-2))
      if [[ $rematch3 ]]; then
        ((_ble_syntax_attr[i]=ATTR_BRACE,i+=2,
          _ble_syntax_attr[i]=ctx,i+=${#rematch3}-2))
      fi
      ((_ble_syntax_attr[i++]=attr))
    fi

    return 0
  fi

  # それ以外
  # Note: {aa},bb} は {"aa}","bb"} と解釈されるので、
  #   ここでは終端の "}" の有無に拘らず nest-push する。
  local ntype=
  ((ctx==CTX_RDRF||ctx==CTX_RDRD)) && force_attr=$ctx
  [[ $force_attr ]] && ntype="glob_attr=$force_attr"
  ble-syntax/parse/nest-push "$CTX_BRACE1" "$ntype"
  local len=$((${#str}-1))
  ((_ble_syntax_attr[i++]=${force_attr:-ATTR_BRACE},
    len&&(_ble_syntax_attr[i]=${force_attr:-ctx},i+=len)))

  return 0
}

# 文脈 CTX_BRAX (brace expansion)
_BLE_SYNTAX_FCTX[CTX_BRACE1]=ble-syntax:bash/ctx-brace-expansion
_BLE_SYNTAX_FCTX[CTX_BRACE2]=ble-syntax:bash/ctx-brace-expansion
_BLE_SYNTAX_FEND[CTX_BRACE1]=ble-syntax:bash/ctx-brace-expansion.end
_BLE_SYNTAX_FEND[CTX_BRACE2]=ble-syntax:bash/ctx-brace-expansion.end
function ble-syntax:bash/ctx-brace-expansion {
  if [[ $tail == '}'* ]] && ((ctx==CTX_BRACE2)); then
    local force_attr=
    local ntype; ble-syntax/parse/nest-type -v ntype
    [[ $ntype == glob_attr=* ]] && force_attr=$ATTR_ERR # ※${ntype#*=} ではなくエラー

    ((_ble_syntax_attr[i++]=${force_attr:-ATTR_BRACE}))
    ble-syntax/parse/nest-pop
    return 0
  elif [[ $tail == ','* ]]; then
    local force_attr=
    local ntype; ble-syntax/parse/nest-type -v ntype
    [[ $ntype == glob_attr=* ]] && force_attr=${ntype#*=}

    ((_ble_syntax_attr[i++]=${force_attr:-ATTR_BRACE}))
    ((ctx=CTX_BRACE2))
    return 0
  fi

  local chars=",${_ble_syntax_bash_chars[CTX_ARGI]//'~:'}"
  ((ctx==CTX_BRACE2)) && chars="}$chars"
  ble-syntax:bash/cclass/update/reorder chars
  if local rex='^([^'$chars']|\\.)+'; [[ $tail =~ $rex ]]; then
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
  elif ble-syntax:bash/check-brace-expansion; then
    return 0
  elif ble-syntax:bash/starts-with-histchars; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}
function ble-syntax:bash/ctx-brace-expansion.end {
  if ((i==${#text})) || ble-syntax:bash/check-word-end/is-delimiter; then
    ble-syntax/parse/nest-pop
    ble-syntax/parse/check-end
    return
  fi

  return 0
}

#------------------------------------------------------------------------------
# チルダ展開

# ${_ble_syntax_bash_chars[CTX_ARGI]} により読み取りを行っている
# ctx-command ctx-values ctx-conditions ctx-redirect から呼び出される事を想定している。

function ble-syntax:bash/check-tilde-expansion {
  [[ $tail == ['~:']* ]] || return 1

  local tilde_enabled=$((i==wbegin))
  [[ $1 == rhs ]] && tilde_enabled=1

  if [[ $tail == ':'* ]]; then
    _ble_syntax_attr[i++]=$ctx

    # 変数代入の右辺、または、その一つ下の角括弧式のときチルダ展開が有効。
    if ! ((tilde_enabled=_ble_syntax_bash_command_IsAssign[ctx])); then
      if ((ctx==CTX_BRAX)); then
        local nctx; ble-syntax/parse/nest-ctx
        ((tilde_enabled=_ble_syntax_bash_command_IsAssign[nctx]))
      fi
    fi

    local tail=${text:i}
    [[ $tail == '~'* ]] || return 0
  fi

  if ((tilde_enabled)); then
    local chars="${_ble_syntax_bash_chars[CTX_ARGI]}/:"
    ble-syntax:bash/cclass/update/reorder chars
    local delimiters="$_ble_syntax_bash_IFS;|&()<>"
    local rex='^(~\+|~[^'$chars']*)([^'$delimiters'/:]?)'; [[ $tail =~ $rex ]]
    local str=${BASH_REMATCH[1]}

    local path attr=$ctx
    eval "path=$str"
    if [[ ! ${BASH_REMATCH[2]} && $path != "$str" ]]; then
      ((attr=ATTR_TILDE))

      if ((ctx==CTX_BRAX)); then
        # CTX_BRAX は単語先頭には来ないので、
        # ここに来るのは [[ $tail == ':~'* ]] だった時のみのはず。
        # このとき、各括弧式は : の直後でキャンセルする。
        ble-assert 'ble/util/unlocal tail; [[ $tail == ":~"* ]]'
        ble-syntax/parse/nest-pop
      fi
    else
      # ~+ で始まってかつ有効なチルダ展開ではない時 ~ まで後退 (#D1424)
      if [[ $str == '~+' ]]; then
        ble/syntax/parse/set-lookahead 3
        str='~'
      fi
    fi
    ((_ble_syntax_attr[i]=attr,i+=${#str}))
  else
    local chars=${_ble_syntax_bash_chars[CTX_ARGI]}
    local rex='^~([^'$chars']|\\.)*'; [[ $tail =~ $rex ]]
    ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
  fi

  return 0
}

#------------------------------------------------------------------------------
# 変数代入の形式の単語
#
#   実は通常の引数であっても変数代入の形式をしているものは微妙に扱いが異なる。
#   変数代入の形式の引数の右辺ではチルダ展開が有効である。
#

_ble_syntax_bash_command_CtxAssign[CTX_CMDI]=$CTX_VRHS
_ble_syntax_bash_command_CtxAssign[CTX_ARGVI]=$CTX_ARGVR
_ble_syntax_bash_command_CtxAssign[CTX_ARGI]=$CTX_ARGQ
_ble_syntax_bash_command_CtxAssign[CTX_FARGI3]=$CTX_FARGQ3
_ble_syntax_bash_command_CtxAssign[CTX_CARGI1]=$CTX_CARGQ1
_ble_syntax_bash_command_CtxAssign[CTX_VALI]=$CTX_VALQ
_ble_syntax_bash_command_CtxAssign[CTX_CONDI]=$CTX_CONDQ

_ble_syntax_bash_command_IsAssign[CTX_VRHS]=$CTX_CMDI
_ble_syntax_bash_command_IsAssign[CTX_ARGVR]=$CTX_ARGVI
_ble_syntax_bash_command_IsAssign[CTX_ARGQ]=$CTX_ARGI
_ble_syntax_bash_command_IsAssign[CTX_FARGQ3]=$CTX_FARGI3
_ble_syntax_bash_command_IsAssign[CTX_CARGQ1]=$CTX_CARGI1
_ble_syntax_bash_command_IsAssign[CTX_VALR]=$CTX_VALI
_ble_syntax_bash_command_IsAssign[CTX_VALQ]=$CTX_VALI
_ble_syntax_bash_command_IsAssign[CTX_CONDQ]=$CTX_CONDI

## 関数 ble-syntax:bash/check-variable-assignment
## @var[in] tail
function ble-syntax:bash/check-variable-assignment {
  ((wbegin==i)) || return 1

  # 値リストにおける [0]=value の形式の単語は特別に扱う。
  if ((ctx==CTX_VALI)) && [[ $tail == '['* ]]; then
    ((ctx=CTX_VALR))
    ble-syntax/parse/nest-push "$CTX_EXPR" 'd['
    # → ble-syntax:bash/ctx-expr/.count-bracket で抜ける
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  [[ ${_ble_syntax_bash_command_CtxAssign[ctx]} ]] || return 1

  # パターン一致 (var= var+= arr[ のどれか)
  local suffix='=|\+=?'
  ((_ble_bash<30100)) && suffix='='
  if ((ctx==CTX_ARGVI)); then
    suffix="$suffix|\[?"
  else
    suffix="$suffix|\["
  fi
  local rex_assign="^[a-zA-Z_][a-zA-Z_0-9]*($suffix)"
  [[ $tail =~ $rex_assign ]] || return 1
  local rematch1=${BASH_REMATCH[1]} # for bash-3.1 ${#arr[n]} bug
  if [[ $rematch1 == '+' ]]; then
    # var+... 曖昧状態

    # Note: + の次の文字が = でない時に此処に来るので、
    # + の次の文字まで先読みしたことになる。
    ble-syntax/parse/set-lookahead $((${#BASH_REMATCH}+1))

    return 1
  fi

  local variable_assign=
  if ((ctx==CTX_CMDI||ctx==CTX_ARGVI)); then
    # 変数代入のときは ctx は先に CTX_VRHS, CTX_ARGVR に変換する
    ((wtype=ATTR_VAR,
      _ble_syntax_attr[i]=ATTR_VAR,
      i+=${#BASH_REMATCH},
      ${#rematch1}&&(_ble_syntax_attr[i-${#rematch1}]=CTX_EXPR),
      variable_assign=1,
      ctx=_ble_syntax_bash_command_CtxAssign[ctx]))
  else
    # 変数代入以外のときは = が現れて初めて CTX_ARGQ などに変換する
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
  fi

  if [[ $rematch1 == '[' ]]; then
    # arr[
    if [[ $variable_assign ]]; then
      i=$((i-1)) ble-syntax/parse/nest-push "$CTX_EXPR" 'a['
      # → ble-syntax:bash/ctx-expr/.count-bracket で抜ける
    else
      ((i--))
      tail=${text:i} ble-syntax:bash/check-glob assign
      # → ble-syntax:bash/check-glob 内で nest-push "$CTX_BRAX" 'a[' し、
      # → ble-syntax:bash/ctx-bracket-expression で抜けた後で = があれば文脈値設定
    fi
  elif [[ $rematch1 == *'=' ]]; then
    if [[ $variable_assign && ${text:i} == '('* ]]; then
      # var=( var+=(
      # * nest-pop した直後は未だ CTX_VRHS, CTX_ARGVR の続きになっている。
      #   例: a=(1 2)b=1 は a='(1 2)b=1' と解釈される。
      #   従って ctx (nest-pop 時の文脈) はそのまま (CTX_VRHS, CTX_ARGVR) にする。

      ble-syntax:bash/ctx-values/enter
      ((_ble_syntax_attr[i++]=ATTR_DEL))
    else
      # var=... var+=...
      [[ $variable_assign ]] || ((ctx=_ble_syntax_bash_command_CtxAssign[ctx]))
      if local tail=${text:i}; [[ $tail == '~'* ]]; then
        ble-syntax:bash/check-tilde-expansion rhs
      fi
    fi
  fi

  return 0
}

#------------------------------------------------------------------------------
# 文脈: コマンドライン

_BLE_SYNTAX_FCTX[CTX_ARGX]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGX0]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDX]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDX1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXT]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXC]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXE]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXD]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXD0]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXV]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGI]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGQ]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDI]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_VRHS]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGVR]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FEND[CTX_CMDI]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_ARGI]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_ARGQ]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_VRHS]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_ARGVR]=ble-syntax:bash/ctx-command/check-word-end

# declare var=value
_BLE_SYNTAX_FCTX[CTX_ARGVX]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGVI]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FEND[CTX_ARGVI]=ble-syntax:bash/ctx-command/check-word-end

# for var in ... / case arg in
_BLE_SYNTAX_FCTX[CTX_SARGX1]=ble-syntax:bash/ctx-command-compound-expect
_BLE_SYNTAX_FCTX[CTX_FARGX1]=ble-syntax:bash/ctx-command-compound-expect
_BLE_SYNTAX_FCTX[CTX_FARGX2]=ble-syntax:bash/ctx-command-compound-expect
_BLE_SYNTAX_FCTX[CTX_FARGX3]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_FARGI1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_FARGI2]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_FARGI3]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_FARGQ3]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FEND[CTX_FARGI1]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_FARGI2]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_FARGI3]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_FARGQ3]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FCTX[CTX_CARGX1]=ble-syntax:bash/ctx-command-compound-expect
_BLE_SYNTAX_FCTX[CTX_CARGX2]=ble-syntax:bash/ctx-command-compound-expect
_BLE_SYNTAX_FCTX[CTX_CARGI1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CARGQ1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CARGI2]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FEND[CTX_CARGI1]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_CARGQ1]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_CARGI2]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FCTX[CTX_TARGX1]=ble-syntax:bash/ctx-command-time-expect
_BLE_SYNTAX_FCTX[CTX_TARGX2]=ble-syntax:bash/ctx-command-time-expect
_BLE_SYNTAX_FCTX[CTX_TARGI1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_TARGI2]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FEND[CTX_TARGI1]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_TARGI2]=ble-syntax:bash/ctx-command/check-word-end

## 関数 ble-syntax:bash/starts-with-delimiter-or-redirect
##
##   空白類、コマンド区切り文字、またはリダイレクトかどうかを判定する。
##   単語開始における 1>2 や {fd}>2 もリダイレクトと判定する。
##
##   Note: ここで "1>2" や "{fd}>" に一致しなかったとしても、通常の文脈で
##   "{fd}" や "1" 等の列が一気に読み取られる限り先読みの問題は発生しないはず。
##   ブレース展開の解析は "{fd}" が一気に読み取られる様に注意深く実装する。
##
function ble-syntax:bash/starts-with-delimiter-or-redirect {
  local delimiters=$_ble_syntax_bash_RexDelimiter
  local redirect=$_ble_syntax_bash_RexRedirect
  [[ ( $tail =~ ^$delimiters || $wbegin -lt 0 && $tail =~ ^$redirect || $wbegin -lt 0 && $tail == $'\\\n'* ) && $tail != ['<>']'('* ]]
}
function ble-syntax:bash/starts-with-delimiter {
  [[ $tail == ["$_ble_syntax_bash_IFS;|&<>()"]* && $tail != ['<>']'('* ]]
}
function ble-syntax:bash/check-word-end/is-delimiter {
  local tail=${text:i}
  if [[ $tail == [!"$_ble_syntax_bash_IFS;|&<>()"]* ]]; then
    return 1
  elif [[ $tail == ['<>']* ]]; then
    ble-syntax/parse/set-lookahead 2
    [[ $tail == ['<>']'('* ]] && return 1
  fi
  return 0
}

## 関数 ble-syntax:bash/check-here-document-from spaces
##   @param[in] spaces
function ble-syntax:bash/check-here-document-from {
  local spaces=$1
  [[ $nparam && $spaces == *$'\n'* ]] || return 1
  local rex="$_ble_term_FS@([RI][QH][^$_ble_term_FS]*)(.*$)" && [[ $nparam =~ $rex ]] || return 1

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

## 配列 _ble_syntax_bash_command_EndCtx
##   単語が終了した後の次の文脈値を設定する。
##   check-word-end で用いる。
##
##   Note #1: time -p -- cmd は bash-4.2 以降
##     bash-4.2 未満では -p の直後にすぐコマンドが来なければならない。
##
_ble_syntax_bash_command_EndCtx=()
_ble_syntax_bash_command_EndCtx[CTX_ARGI]=$CTX_ARGX
_ble_syntax_bash_command_EndCtx[CTX_ARGQ]=$CTX_ARGX
_ble_syntax_bash_command_EndCtx[CTX_ARGVI]=$CTX_ARGVX
_ble_syntax_bash_command_EndCtx[CTX_ARGVR]=$CTX_ARGVX
_ble_syntax_bash_command_EndCtx[CTX_VRHS]=$CTX_CMDXV
_ble_syntax_bash_command_EndCtx[CTX_FARGI1]=$CTX_FARGX2
_ble_syntax_bash_command_EndCtx[CTX_FARGI2]=$CTX_FARGX3
_ble_syntax_bash_command_EndCtx[CTX_FARGI3]=$CTX_FARGX3
_ble_syntax_bash_command_EndCtx[CTX_FARGQ3]=$CTX_FARGX3
_ble_syntax_bash_command_EndCtx[CTX_CARGI1]=$CTX_CARGX2
_ble_syntax_bash_command_EndCtx[CTX_CARGQ1]=$CTX_CARGX2
_ble_syntax_bash_command_EndCtx[CTX_CARGI2]=$CTX_CASE
_ble_syntax_bash_command_EndCtx[CTX_TARGI1]=$((_ble_bash>=40200?CTX_TARGX2:CTX_CMDXT)) #1
_ble_syntax_bash_command_EndCtx[CTX_TARGI2]=$CTX_CMDXT

## 配列 _ble_syntax_bash_command_EndWtype[wtype]
##   実際に tree 登録する wtype を指定します。
##   ※解析中の wtype には解析開始時の wtype が入っていることに注意する。
_ble_syntax_bash_command_EndWtype[CTX_ARGX]=$CTX_ARGI
_ble_syntax_bash_command_EndWtype[CTX_ARGX0]=$CTX_ARGI
_ble_syntax_bash_command_EndWtype[CTX_ARGVX]=$CTX_ARGVI
_ble_syntax_bash_command_EndWtype[CTX_CMDX]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDX1]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXT]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXC]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXE]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXD]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXD0]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXV]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_FARGX1]=$CTX_ARGI
_ble_syntax_bash_command_EndWtype[CTX_SARGX1]=$CTX_ARGI
_ble_syntax_bash_command_EndWtype[CTX_FARGX2]=$CTX_FARGI2 # in
_ble_syntax_bash_command_EndWtype[CTX_FARGX3]=$CTX_ARGI # in
_ble_syntax_bash_command_EndWtype[CTX_CARGX1]=$CTX_ARGI
_ble_syntax_bash_command_EndWtype[CTX_CARGX2]=$CTX_CARGI2 # in
_ble_syntax_bash_command_EndWtype[CTX_TARGX1]=$CTX_ARGI # -p
_ble_syntax_bash_command_EndWtype[CTX_TARGX2]=$CTX_ARGI # --

## 配列 _ble_syntax_bash_command_Expect
##
##   許容するコマンドの種類を表す正規表現を設定する。
##   check-word-end で用いる。
##   配列 _ble_syntax_bash_command_bwtype の設定と対応している必要がある。
##
##   * 前提: 予約語のみに一致する
##     この配列が設定されている文脈値については、
##     既定でコマンドの属性は ATTR_ERR にする。
##     許容するコマンドは何れも予約語なので、
##     許容された暁には自動的に ATTR_KEYWORD で上書きされるのでOK
##
##     予約語以外に一致する時には、
##     明示的に属性値 ATTR_ERR をキャンセルする必要がある。
##
_ble_syntax_bash_command_Expect=()
_ble_syntax_bash_command_Expect[CTX_CMDXC]='^(\(|\{|\(\(|\[\[|for|select|case|if|while|until)$'
_ble_syntax_bash_command_Expect[CTX_CMDXE]='^(\}|fi|done|esac|then|elif|else|do)$'
_ble_syntax_bash_command_Expect[CTX_CMDXD]='^(\{|do)$'
_ble_syntax_bash_command_Expect[CTX_CMDXD0]='^(\{|do)$'

## 関数 ble-syntax:bash/ctx-command/check-word-end
##   @var[in,out] ctx
##   @var[in,out] wbegin
##   @var[in,out] 他
function ble-syntax:bash/ctx-command/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  ble-syntax:bash/check-word-end/is-delimiter || return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}
  local wt=$wtype

  [[ ${_ble_syntax_bash_command_EndWtype[wt]} ]] &&
    wtype=${_ble_syntax_bash_command_EndWtype[wt]}
  local rex_expect_command=${_ble_syntax_bash_command_Expect[wt]}
  if [[ $rex_expect_command ]]; then
    # 特定のコマンドのみを受け付ける文脈
    [[ $word =~ $rex_expect_command ]] || ((wtype=ATTR_ERR))
  fi
  ble-syntax/parse/word-pop

  if ((ctx==CTX_CMDI)); then
    if ((wt==CTX_CMDXV)); then
      ((ctx=CTX_ARGX))
      return 0
    fi

    local processed=
    case "$word" in
    ('[[')
      # 条件コマンド開始
      ble-syntax/parse/touch-updated-attr "$wbeg"
      ((_ble_syntax_attr[wbeg]=ATTR_DEL,
        ctx=CTX_ARGX0))

      ble-syntax/parse/word-cancel # 単語 "[[" (とその内部のノード全て) を削除
      if [[ $word == '[[' ]]; then
        # "[[" は一度角括弧式として読み取られるので、その情報を削除する。
        _ble_syntax_attr[wbeg+1]= # 角括弧式として着色されているのを消去
      fi

      i=$wbeg ble-syntax/parse/nest-push "$CTX_CONDX"

      # workaround: word "[[" を nest 内部に設置し直す
      i=$wbeg ble-syntax/parse/word-push "$CTX_CMDI" "$wbeg"
      ble-syntax/parse/word-pop
      return 0 ;;
    ('time')               ((ctx=CTX_TARGX1)); processed=keyword ;;
    ('!')                  ((ctx=CTX_CMDXT)) ; processed=keyword ;;
    ('if'|'while'|'until') ((ctx=CTX_CMDX1)) ; processed=begin ;;
    ('for')                ((ctx=CTX_FARGX1)); processed=begin ;;
    ('select')             ((ctx=CTX_SARGX1)); processed=begin ;;
    ('case')               ((ctx=CTX_CARGX1)); processed=begin ;;
    ('{')              
      ((ctx=CTX_CMDX1))
      if ((wt==CTX_CMDXD||wt==CTX_CMDXD0)); then
        processed=middle # "for ...; {" などの時
      else
        processed=begin
      fi ;;
    ('then'|'elif'|'else'|'do') ((ctx=CTX_CMDX1)) ; processed=middle ;;
    ('}'|'done'|'fi'|'esac')    ((ctx=CTX_CMDXE)) ; processed=end ;;
    ('function')
      ((ctx=CTX_ARGX))
      local isfuncsymx=$'\t\n'' "$&'\''();<>\`|' rex_space=$'[ \t]' rex
      if rex="^$rex_space+" && [[ ${text:i} =~ $rex ]]; then
        ((_ble_syntax_attr[i]=CTX_ARGX,i+=${#BASH_REMATCH},ctx=CTX_ARGX))
        if rex="^([^#$isfuncsymx][^$isfuncsymx]*)($rex_space*)(\(\(|\($rex_space*\)?)?" && [[ ${text:i} =~ $rex ]]; then
          local rematch1=${BASH_REMATCH[1]}
          local rematch2=${BASH_REMATCH[2]}
          local rematch3=${BASH_REMATCH[3]}
          ((_ble_syntax_attr[i]=ATTR_FUNCDEF,i+=${#rematch1},
            ${#rematch2}&&(_ble_syntax_attr[i]=CTX_CMDX1,i+=${#rematch2})))

          if [[ $rematch3 == '('*')' ]]; then
            ((_ble_syntax_attr[i]=ATTR_DEL,i+=${#rematch3},ctx=CTX_CMDXC))
          elif ((_ble_bash>=40200)) && [[ $rematch3 == '((' ]]; then
            ble-syntax/parse/set-lookahead 2
            ((ctx=CTX_CMDXC))
          elif [[ $rematch3 == '('* ]]; then
            ((_ble_syntax_attr[i]=ATTR_ERR,ctx=CTX_ARGX0))
            ble-syntax/parse/nest-push "$CTX_CMDX1" '('
            ((${#rematch3}>=2&&(_ble_syntax_attr[i+1]=CTX_CMDX1),i+=${#rematch3}))
          else
            ((ctx=CTX_CMDXC))
          fi
          processed=keyword
        fi
      fi
      [[ $processed ]] || ((_ble_syntax_attr[i-1]=ATTR_ERR)) ;;
    esac

    if [[ $processed ]]; then
      local attr=
      case $processed in
      (keyword) attr=$ATTR_KEYWORD ;;
      (begin)   attr=$ATTR_KEYWORD_BEGIN ;;
      (end)     attr=$ATTR_KEYWORD_END ;;
      (middle)  attr=$ATTR_KEYWORD_MID ;;
      esac
      if [[ $attr ]]; then
        ble-syntax/parse/touch-updated-attr "$wbeg"
        ((_ble_syntax_attr[wbeg]=attr))
      fi

      return 0
    fi

    # 関数定義である可能性を考え stat を置かず読み取る
    ((ctx=CTX_ARGX))
    if local rex='^([ 	]*)(\([ 	]*\)?)?'; [[ ${text:i} =~ $rex && $BASH_REMATCH ]]; then

      # for bash-3.1 ${#arr[n]} bug
      local rematch1=${BASH_REMATCH[1]}
      local rematch2=${BASH_REMATCH[2]}

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
      else
        # case: /hoge */ 恐らくコマンド
        ((_ble_syntax_attr[i]=CTX_ARGX,i+=${#rematch1}))
      fi
    fi

    # 引数の取り扱いが特別な builtin
    case $word in
    ('declare'|'readonly'|'typeset'|'local'|'export'|'alias')
      ((ctx=CTX_ARGVX)) ;;
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
    # for name in ... / case value in
    if [[ $word != in ]];  then
      ble-syntax/parse/touch-updated-attr "$wbeg"
      ((_ble_syntax_attr[wbeg]=ATTR_ERR))
    fi
  fi

  if ((_ble_syntax_bash_command_EndCtx[ctx])); then
    ((ctx=_ble_syntax_bash_command_EndCtx[ctx]))
  fi

  return 0
}

## 配列 _ble_syntax_bash_command_Opt
##   その場でコマンドが終わっても良いかどうかを設定する。
##   .check-delimiter-or-redirect で用いる。
_ble_syntax_bash_command_Opt=()
_ble_syntax_bash_command_Opt[CTX_ARGX]=1
_ble_syntax_bash_command_Opt[CTX_ARGX0]=1
_ble_syntax_bash_command_Opt[CTX_ARGVX]=1
_ble_syntax_bash_command_Opt[CTX_CMDXV]=1
_ble_syntax_bash_command_Opt[CTX_CMDXE]=1
_ble_syntax_bash_command_Opt[CTX_CMDXD0]=1

_ble_syntax_bash_is_command_form_for=

function ble-syntax:bash/ctx-command/.check-delimiter-or-redirect {
  if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs || $wbegin -lt 0 && $tail == $'\\\n'* ]]; then
    # 空白 or \ + 改行

    local spaces=$BASH_REMATCH
    if [[ $tail == $'\\\n'* ]]; then
      # \ + 改行は単純に無視
      spaces=$'\\\n'
    elif [[ $spaces == *$'\n'* ]]; then
      # 改行がある場合: ヒアドキュメントの確認 / 改行による文脈更新
      ble-syntax:bash/check-here-document-from "$spaces" && return 0
      if ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||ctx==CTX_CMDXV||ctx==CTX_CMDXT||ctx==CTX_CMDXE)); then
        ((ctx=CTX_CMDX))
      elif ((ctx==CTX_FARGX2||ctx==CTX_FARGX3||ctx==CTX_CMDXD0)); then
        ((ctx=CTX_CMDXD))
      fi
    fi

    # ctx はそのままで素通り
    ((_ble_syntax_attr[i]=ctx,i+=${#spaces}))
    return 0

  elif [[ $tail =~ ^$_ble_syntax_bash_RexRedirect ]]; then
    # リダイレクト (& 単体の解釈より優先する)

    # for bash-3.1 ${#arr[n]} bug ... 一旦 rematch1 に入れてから ${#rematch1} で文字数を得る。
    local len=${#BASH_REMATCH}
    local rematch1=${BASH_REMATCH[1]}
    local rematch3=${BASH_REMATCH[3]}
    ((_ble_syntax_attr[i]=ATTR_DEL,
      ${#rematch1}<len&&(_ble_syntax_attr[i+${#rematch1}]=CTX_ARGX)))
    if ((ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXT)); then
      ((ctx=CTX_CMDXV))
    elif ((ctx==CTX_CMDXC||ctx==CTX_CMDXD||ctx==CTX_CMDXD0)); then
      ((ctx=CTX_CMDXV,
        _ble_syntax_attr[i]=ATTR_ERR))
    elif ((ctx==CTX_CMDXE)); then
      ((ctx=CTX_ARGX0))
    elif ((ctx==CTX_FARGX3)); then
      ((_ble_syntax_attr[i]=ATTR_ERR))
    fi

    if [[ ${text:i+len} != [!$'\n|&()']* ]]; then
      # リダイレクトがその場で終わるときはそもそも nest-push せずエラー。
      # Note: 上の判定の文字集合は _ble_syntax_bash_RexDelimiter の部分集合。
      #   但し、空白類および <> はリダイレクトに含まれ得るので許容する。
      ((_ble_syntax_attr[i+len-1]=ATTR_ERR))
    else
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
    fi
    ((i+=len))
    return 0
  elif local rex='^(&&|\|[|&]?)|^;(;&?|&)|^[;&]'
       ((_ble_bash<40000)) && rex='^(&&|\|\|?)|^;(;)|^[;&]'
       [[ $tail =~ $rex ]]
  then
    # 制御演算子 && || | & ; |& ;; ;;& ;&

    if [[ $BASH_REMATCH == ';' ]]; then
      if ((ctx==CTX_FARGX2||ctx==CTX_FARGX3||ctx==CTX_CMDXD0)); then
        ((_ble_syntax_attr[i++]=ATTR_DEL,ctx=CTX_CMDXD))
        return 0
      elif ((ctx==CTX_CMDXT)); then
        # Note #D0592: time ; 及び ! ; に限っては、エラーにならずに直後に CTX_CMDXE になる
        # Note #D1477: Bash 4.4 で振る舞いが変わる。
        ((_ble_syntax_attr[i++]=ATTR_DEL,ctx=_ble_bash>=40400?CTX_CMDX:CTX_CMDXE))
        return 0
      fi
    fi

    # for bash-3.1 ${#arr[n]} bug
    local rematch1=${BASH_REMATCH[1]} rematch2=${BASH_REMATCH[2]}
    ((_ble_syntax_attr[i]=ATTR_DEL,
      (_ble_syntax_bash_command_Opt[ctx]||ctx==CTX_CMDX&&${#rematch2})||
        (_ble_syntax_attr[i]=ATTR_ERR)))

    ((ctx=${#rematch1}?CTX_CMDX1:(
         ${#rematch2}?CTX_CASE:
         CTX_CMDX)))
    ((i+=${#BASH_REMATCH}))
    return 0
  elif local rex='^\(\(?' && [[ $tail =~ $rex ]]; then
    # サブシェル (, 算術コマンド ((
    local m=${BASH_REMATCH[0]}
    if ((ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXT||ctx==CTX_CMDXC)); then
      ((_ble_syntax_attr[i]=ATTR_DEL))
      ((ctx=CTX_ARGX0))
      [[ $_ble_syntax_bash_is_command_form_for && $tail == '(('* ]] && ((ctx=CTX_CMDXD0))
      ble-syntax/parse/nest-push $((${#m}==1?CTX_CMDX1:CTX_EXPR)) "$m"
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
      ((_ble_syntax_attr[i]=(ctx==CTX_CMDX||ctx==CTX_CMDXV||ctx==CTX_CMDXE||ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX)?attr:ATTR_ERR,
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
_ble_syntax_bash_command_BeginCtx=()
_ble_syntax_bash_command_BeginCtx[CTX_ARGX]=$CTX_ARGI
_ble_syntax_bash_command_BeginCtx[CTX_ARGX0]=$CTX_ARGI
_ble_syntax_bash_command_BeginCtx[CTX_ARGVX]=$CTX_ARGVI
_ble_syntax_bash_command_BeginCtx[CTX_CMDX]=$CTX_CMDI
_ble_syntax_bash_command_BeginCtx[CTX_CMDX1]=$CTX_CMDI
_ble_syntax_bash_command_BeginCtx[CTX_CMDXT]=$CTX_CMDI
_ble_syntax_bash_command_BeginCtx[CTX_CMDXC]=$CTX_CMDI
_ble_syntax_bash_command_BeginCtx[CTX_CMDXE]=$CTX_CMDI
_ble_syntax_bash_command_BeginCtx[CTX_CMDXD]=$CTX_CMDI
_ble_syntax_bash_command_BeginCtx[CTX_CMDXD0]=$CTX_CMDI
_ble_syntax_bash_command_BeginCtx[CTX_CMDXV]=$CTX_CMDI
_ble_syntax_bash_command_BeginCtx[CTX_FARGX1]=$CTX_FARGI1
_ble_syntax_bash_command_BeginCtx[CTX_SARGX1]=$CTX_FARGI1
_ble_syntax_bash_command_BeginCtx[CTX_FARGX2]=$CTX_FARGI2
_ble_syntax_bash_command_BeginCtx[CTX_FARGX3]=$CTX_FARGI3
_ble_syntax_bash_command_BeginCtx[CTX_CARGX1]=$CTX_CARGI1
_ble_syntax_bash_command_BeginCtx[CTX_CARGX2]=$CTX_CARGI2
_ble_syntax_bash_command_BeginCtx[CTX_TARGX1]=$CTX_TARGI1
_ble_syntax_bash_command_BeginCtx[CTX_TARGX2]=$CTX_TARGI2

#%if !release
## 配列 _ble_syntax_bash_command_isARGI[ctx]
##
##   この配列要素が非空文字列のとき、
##   その文脈はシェル単語を解析中に用いられることを表す。
##
_ble_syntax_bash_command_isARGI[CTX_CMDI]=1
_ble_syntax_bash_command_isARGI[CTX_VRHS]=1
_ble_syntax_bash_command_isARGI[CTX_ARGI]=1
_ble_syntax_bash_command_isARGI[CTX_ARGQ]=1
_ble_syntax_bash_command_isARGI[CTX_ARGVI]=1
_ble_syntax_bash_command_isARGI[CTX_ARGVR]=1
_ble_syntax_bash_command_isARGI[CTX_FARGI1]=1 # var
_ble_syntax_bash_command_isARGI[CTX_FARGI2]=1 # in
_ble_syntax_bash_command_isARGI[CTX_FARGI3]=1 # args...
_ble_syntax_bash_command_isARGI[CTX_FARGQ3]=1 # args... (= の後)
_ble_syntax_bash_command_isARGI[CTX_CARGI1]=1 # value
_ble_syntax_bash_command_isARGI[CTX_CARGQ1]=1 # value (= の後)
_ble_syntax_bash_command_isARGI[CTX_CARGI2]=1 # in
_ble_syntax_bash_command_isARGI[CTX_TARGI1]=1 # -p
_ble_syntax_bash_command_isARGI[CTX_TARGI2]=1 # --
#%end
function ble-syntax:bash/ctx-command/.check-word-begin {
  if ((wbegin<0)); then
    local octx
    ((octx=ctx,
      wtype=octx,
      ctx=_ble_syntax_bash_command_BeginCtx[ctx]))
#%if !release
    if ((ctx==0)); then
      ((ctx=wtype=CTX_ARGI))
      ble-stackdump "invalid ctx=$octx at the beginning of words"
    fi
#%end

    # Note: ここで設定される wtype は最終的に ctx-command/check-word-end で
    #   配列 _ble_syntax_bash_command_EndWtype により変換されてから tree に登録される。
    ble-syntax/parse/word-push "$wtype" "$i"

    ((octx!=CTX_ARGX0)); return # return unexpectedWbegin
  fi

#%if !release
  ((_ble_syntax_bash_command_isARGI[ctx])) || ble-stackdump "invalid ctx=$ctx in words"
#%end
  return 0
}

# コマンド・引数部分
function ble-syntax:bash/ctx-command {
#%if !release
  if ble-syntax:bash/starts-with-delimiter-or-redirect; then
    ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||ctx==CTX_FARGX2||ctx==CTX_FARGX3||
        ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXT||ctx==CTX_CMDXC||
        ctx==CTX_CMDXE||ctx==CTX_CMDXD||ctx==CTX_CMDXD0||ctx==CTX_CMDXV)) || ble-stackdump "invalid ctx=$ctx @ i=$i"
    ((wbegin<0&&wtype<0)) || ble-stackdump "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
    ble-syntax:bash/ctx-command/.check-delimiter-or-redirect; return
  fi
#%else
  ble-syntax:bash/ctx-command/.check-delimiter-or-redirect && return 0
#%end

  ble-syntax:bash/check-comment && return 0

  local unexpectedWbegin=-1
  ble-syntax:bash/ctx-command/.check-word-begin || ((unexpectedWbegin=i))

  local wtype0=$wtype i0=$i

  local flagConsume=0
  if ble-syntax:bash/check-variable-assignment; then
    flagConsume=1
  elif local rex='^([^'${_ble_syntax_bash_chars[CTX_ARGI]}']|\\.)+'; [[ $tail =~ $rex ]]; then
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
  elif ble-syntax:bash/check-brace-expansion; then
    flagConsume=1
  elif ble-syntax:bash/check-tilde-expansion; then
    flagConsume=1
  elif ble-syntax:bash/starts-with-histchars; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    flagConsume=1
  fi

  if ((flagConsume)); then
    ble-assert '((wtype0>=0))'
    [[ ${_ble_syntax_bash_command_Expect[wtype0]} ]] &&
      ((_ble_syntax_attr[i0]=ATTR_ERR))
    if ((unexpectedWbegin>=0)); then
      ble-syntax/parse/touch-updated-attr "$unexpectedWbegin"
      ((_ble_syntax_attr[unexpectedWbegin]=ATTR_ERR))
    fi
    return 0
  else
    return 1
  fi
}

function ble-syntax:bash/ctx-command-compound-expect {
  ble-assert '((ctx==CTX_FARGX1||ctx==CTX_SARGX1||ctx==CTX_CARGX1||ctx==CTX_FARGX2||ctx==CTX_CARGX2))'
  local _ble_syntax_bash_is_command_form_for=
  if ble-syntax:bash/starts-with-delimiter-or-redirect; then
    # "for var in ... / case arg in" を処理している途中で delimiter が来た場合。
    if ((ctx==CTX_FARGX2)) && [[ $tail == [$';\n']* ]]; then
      # for var in ... の in 以降が省略された形である。
      # ble-syntax:bash/ctx-command で FARGX3 と同様に処理する。
      ble-syntax:bash/ctx-command
      return
    elif ((ctx==CTX_FARGX1)) && [[ $tail == '(('* ]]; then
      # for ((...)) の場合
      # ここで return せずに以降の CTX_CMDX1 用の処理に任せる
      ((ctx=CTX_CMDX1,_ble_syntax_bash_is_command_form_for=1))
    elif [[ $tail == $'\n'* ]]; then
      if ((ctx==CTX_CARGX2)); then
        ((_ble_syntax_attr[i++]=CTX_ARGX))
      else
        ((_ble_syntax_attr[i++]=ATTR_ERR,ctx=CTX_ARGX))
      fi
      return 0
    elif [[ $tail =~ ^$_ble_syntax_bash_RexSpaces ]]; then
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

  # コメント禁止
  local i0=$i
  if ble-syntax:bash/check-comment; then
    if ((ctx==CTX_FARGX1||ctx==CTX_SARGX1||ctx==CTX_CARGX1)); then
      # "for var / select var / case arg" を処理している途中でコメントが来た場合
      ((_ble_syntax_attr[i0]=ATTR_ERR))
    fi
    return 0
  fi

  # 他は同じ
  ble-syntax:bash/ctx-command
}

function ble-syntax:bash/ctx-command-time-expect {
  ble-assert '((ctx==CTX_TARGX1||ctx==CTX_TARGX2))'

  if ble-syntax:bash/starts-with-delimiter-or-redirect; then
    ble-assert '((wbegin<0&&wtype<0))'
    if [[ $tail =~ ^$_ble_syntax_bash_RexSpaces ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      return 0
    else
      ((ctx=CTX_CMDXT))
      ble-syntax:bash/ctx-command/.check-delimiter-or-redirect; return
    fi
  fi

  # 期待する単語でない時は CTX_CMDXT に decay
  local is_time_option=
  local head=-p; ((ctx==CTX_TARGX2)) && head=--
  if [[ $tail == "$head"* ]]; then
    ble-syntax/parse/set-lookahead 3
    if [[ $tail == "$head" ]] || i=$((i+2)) ble-syntax:bash/check-word-end/is-delimiter; then
      is_time_option=1
    fi
  fi
  ((is_time_option||(ctx=CTX_CMDXT)))

  # 他は同じ
  ble-syntax:bash/ctx-command
}

#------------------------------------------------------------------------------
# 文脈: 配列値リスト
#

_BLE_SYNTAX_FCTX[CTX_VALX]=ble-syntax:bash/ctx-values
_BLE_SYNTAX_FCTX[CTX_VALI]=ble-syntax:bash/ctx-values
_BLE_SYNTAX_FEND[CTX_VALI]=ble-syntax:bash/ctx-values/check-word-end
_BLE_SYNTAX_FCTX[CTX_VALR]=ble-syntax:bash/ctx-values
_BLE_SYNTAX_FEND[CTX_VALR]=ble-syntax:bash/ctx-values/check-word-end
_BLE_SYNTAX_FCTX[CTX_VALQ]=ble-syntax:bash/ctx-values
_BLE_SYNTAX_FEND[CTX_VALQ]=ble-syntax:bash/ctx-values/check-word-end

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
##   @remarks この関数は ble-syntax:bash/check-variable-assignment から呼ばれる。
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
  [[ ${text:i:1} == [!"$_ble_syntax_bash_IFS;|&<>()"] ]] && return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}

  ble-syntax/parse/word-pop

  ble-assert '((ctx==CTX_VALI||ctx==CTX_VALR||ctx==CTX_VALQ))' 'invalid context'
  ((ctx=CTX_VALX))

  return 0
}

function ble-syntax:bash/ctx-values {
  # コマンド・引数部分
  if ble-syntax:bash/starts-with-delimiter; then
#%if !release
    ((ctx==CTX_VALX)) || ble-stackdump "invalid ctx=$ctx @ i=$i"
    ((wbegin<0&&wtype<0)) || ble-stackdump "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
#%end

    if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs ]]; then
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
  ble-assert '((ctx==CTX_VALI||ctx==CTX_VALR||ctx==CTX_VALQ))' "invalid context ctx=$ctx"
#%end

  if ble-syntax:bash/check-variable-assignment; then
    return 0
  elif local rex='^([^'${_ble_syntax_bash_chars[CTX_ARGI]}']|\\.)+' && [[ $tail =~ $rex ]]; then
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
  elif ble-syntax:bash/check-brace-expansion; then
    return 0
  elif ble-syntax:bash/check-tilde-expansion; then
    return 0
  elif ble-syntax:bash/starts-with-histchars; then
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
_BLE_SYNTAX_FCTX[CTX_CONDQ]=ble-syntax:bash/ctx-conditions
_BLE_SYNTAX_FEND[CTX_CONDQ]=ble-syntax:bash/ctx-conditions/check-word-end

## 関数 ble-syntax:bash/ctx-conditions/check-word-end
function ble-syntax:bash/ctx-conditions/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  [[ ${text:i:1} == [!"$_ble_syntax_bash_IFS;|&<>()"] ]] && return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}

  ble-syntax/parse/word-pop

  ble-assert '((ctx==CTX_CONDI||ctx==CTX_CONDQ))' 'invalid context'
  if [[ $word == ']]' ]]; then
    ble-syntax/parse/touch-updated-attr "$wbeg"
    ((_ble_syntax_attr[wbeg]=ATTR_DEL))
    ble-syntax/parse/nest-pop
  else
    ((ctx=CTX_CONDX))
  fi
  return 0
}

function ble-syntax:bash/ctx-conditions {
  # コマンド・引数部分
  if ble-syntax:bash/starts-with-delimiter; then
#%if !release
    ((ctx==CTX_CONDX)) || ble-stackdump "invalid ctx=$ctx @ i=$i"
    ((wbegin<0&&wtype<0)) || ble-stackdump "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
#%end

    if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      return 0
    else
      # [(<>;|&] など
      ((_ble_syntax_attr[i++]=CTX_CONDI))
      return 0
    fi
  fi

  ble-syntax:bash/check-comment && return 0

  if ((wbegin<0)); then
    ((ctx=CTX_CONDI))
    ble-syntax/parse/word-push "$ctx" "$i"
  fi

#%if !release
  ble-assert '((ctx==CTX_CONDI||ctx==CTX_CONDQ))' "invalid context ctx=$ctx"
#%end

  if ble-syntax:bash/check-variable-assignment; then
    return 0
  elif local rex='^([^'${_ble_syntax_bash_chars[CTX_ARGI]}']|\\.)+' && [[ $tail =~ $rex ]]; then
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
  elif ble-syntax:bash/check-brace-expansion; then
    return 0
  elif ble-syntax:bash/check-tilde-expansion; then
    return 0
  elif ble-syntax:bash/starts-with-histchars; then
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
  ble-syntax:bash/check-word-end/is-delimiter || return 1

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
    [[ ${tail:1} =~ ^$_ble_syntax_bash_RexSpaces ]] &&
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
  if rex='^([^'${_ble_syntax_bash_chars[CTX_ARGI]}']|\\.)+' && [[ $tail =~ $rex ]]; then
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
  elif ble-syntax:bash/check-brace-expansion; then
    return 0
  elif ble-syntax:bash/check-tilde-expansion; then
    return 0
  elif ble-syntax:bash/starts-with-histchars; then
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

_ble_syntax_bash_heredoc_EscSP='\040'
_ble_syntax_bash_heredoc_EscHT='\011'
_ble_syntax_bash_heredoc_EscLF='\012'
_ble_syntax_bash_heredoc_EscFS='\034'
function ble-syntax:bash/ctx-heredoc-word/initialize {
  local ret
  ble/util/s2c ' '
  ble/util/sprintf _ble_syntax_bash_heredoc_EscSP '\\%03o' "$ret"
  ble/util/s2c $'\t'
  ble/util/sprintf _ble_syntax_bash_heredoc_EscHT '\\%03o' "$ret"
  ble/util/s2c $'\n'
  ble/util/sprintf _ble_syntax_bash_heredoc_EscLF '\\%03o' "$ret"
  ble/util/s2c "$_ble_term_FS"
  ble/util/sprintf _ble_syntax_bash_heredoc_EscFS '\\%03o' "$ret"
}
ble-syntax:bash/ctx-heredoc-word/initialize

## 関数 ble-syntax:bash/ctx-heredoc-word/remove-quotes word
##   @var[out] delimiter
function ble-syntax:bash/ctx-heredoc-word/remove-quotes {
  local text=$1 result=

  local rex='^[^\$"'\'']+|^\$?["'\'']|^\\.?|^.'
  while [[ $text && $text =~ $rex ]]; do
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
  if [[ $ret == *[\\\'$_ble_syntax_bash_IFS$_ble_term_FS]* ]]; then
    local a b fs=$_ble_term_FS
    a=\\   ; b="\\$a"; ret="${ret//"$a"/$b}"
    a=\'   ; b="\\$a"; ret="${ret//"$a"/$b}"
    a=' '  ; b="$_ble_syntax_bash_heredoc_EscSP"; ret="${ret//"$a"/$b}"
    a=$'\t'; b="$_ble_syntax_bash_heredoc_EscHT"; ret="${ret//"$a"/$b}"
    a=$'\n'; b="$_ble_syntax_bash_heredoc_EscLF"; ret="${ret//"$a"/$b}"
    a=$fs  ; b="$_ble_syntax_bash_heredoc_EscFS"; ret="${ret//"$a"/$b}"
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
  ble-syntax:bash/check-word-end/is-delimiter || return 1

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
  nparam=$nparam$_ble_term_FS@$I$Q$escaped
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
  local tree_array=$1 tofs=$2
  local -i beg=$3 end=$4 lbeg=$5 lend=$6
  (((beg<=0)&&(beg=1)))

  local node i nofs
  for ((i=end;i>=beg;i--)); do
    builtin eval "node=(\${$tree_array[tofs+i-1]})"
    ((${#node[@]})) || continue
    for ((nofs=0;nofs<${#node[@]};nofs+=BLE_SYNTAX_TREE_WIDTH)); do
      local wtype=${node[nofs]} wlen=${node[nofs+1]}
      local wbeg=$((wlen<0?wlen:i-wlen)) wend=$i

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
    local -a stat; ble/string#split-words stat "${_ble_syntax_stat[j]}"

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
  ble/string#split-words node "${_ble_syntax_tree[j-1]}"

  local nofs
  if [[ $1 ]]; then
    nofs=$1 ble-syntax/parse/shift.tree/1
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
    ble/string#split-words nest "${_ble_syntax_nest[j]}"

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
  local limit=$1
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
  local j=$_shift2_j
  if ((i<j2)); then
    ((tprev=-1)) # 中断
    return
  fi

  ble-syntax/parse/shift.impl2/.shift-until "$((i+1))"
  ble-syntax/parse/shift.tree "$nofs"
  ((_shift2_j=j))

  if ((tprev>end0&&wbegin>end0)) && [[ ${wtype//[0-9]} ]]; then
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

  local iN=${#_ble_syntax_text} # tree-enumerate 起点は (古い text の長さ) である
  local _shift2_j=$iN # proc1 に渡す変数
  ble-syntax/tree-enumerate ble-syntax/parse/shift.impl2/.proc1
  local j=$_shift2_j
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

## 関数 ble-syntax/parse/determine-parse-range
##
##   @var[out] i1 i2 j2
##
##   @var[in] beg end end0
##   @var[in] _ble_syntax_dbeg
##   @var[in] _ble_syntax_dend
##     文字列の変更範囲と、前回の解析でやり残した範囲を指定します。
##
function ble-syntax/parse/determine-parse-range {
  local flagSeekStat=0
  ((i1=_ble_syntax_dbeg,i1>=end0&&(i1+=shift),
    i2=_ble_syntax_dend,i2>=end0&&(i2+=shift),
    (i1<0||beg<i1)&&(i1=beg,flagSeekStat=1),
    (i2<0||i2<end)&&(i2=end),
    (i2>iN)&&(i2=iN),
    j2=i2-shift))

  if ((flagSeekStat)); then
    # beg より前の最後の stat の位置まで戻る
    local lookahead='stat[7]'
    local -a stat
    while ((i1>0)); do
      if [[ ${_ble_syntax_stat[--i1]} ]]; then
        ble/string#split-words stat "${_ble_syntax_stat[i1]}"
        ((i1+lookahead<=beg)) && break
      fi
    done
  fi

#%if !release
  ((0<=i1&&i1<=beg&&end<=i2&&i2<=iN)) || ble-stackdump "X2 0 <= $i1 <= $beg <= $end <= $i2 <= $iN"
#%end
}

function ble-syntax/parse/check-end {
  [[ ${_BLE_SYNTAX_FEND[ctx]} ]] && "${_BLE_SYNTAX_FEND[ctx]}"
}

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
  local text=$1
  local beg=${2:-0} end=${3:-${#text}}
  local end0=${4:-$end}
  ((end==beg&&end0==beg&&_ble_syntax_dbeg<0)) && return

  local IFS=$_ble_term_IFS

  local -ir iN=${#text} shift=$((end-end0))
#%if !release
  if ! ((0<=beg&&beg<=end&&end<=iN&&beg<=end0)); then
    ble-stackdump "X1 0 <= beg:$beg <= end:$end <= iN:$iN, beg:$beg <= end0:$end0 (shift=$shift text=$text)"
    ((beg=0,end=iN))
  fi
#%else
  ((0<=beg&&beg<=end&&end<=iN&&beg<=end0)) || ((beg=0,end=iN))
#%end

  # 解析予定範囲の更新
  #   @var i1 解析範囲開始
  #   @var i2 解析必要範囲終端 (此処以降で文脈が一致した時に解析終了)
  #   @var j2 シフト前の解析終端
  local i1 i2 j2
  ble-syntax/parse/determine-parse-range

  ble-syntax/vanishing-word/register _ble_syntax_tree 0 "$i1" "$j2" 0 "$i2"

  ble-syntax/parse/shift

  # 解析途中状態の復元
  local ctx wbegin wtype inest tchild tprev nparam ilook
  if ((i1>0)) && [[ ${_ble_syntax_stat[i1]} ]]; then
    local -a stat
    ble/string#split-words stat "${_ble_syntax_stat[i1]}"
    local wlen=${stat[1]} nlen=${stat[3]} tclen=${stat[4]} tplen=${stat[5]}
    ctx=${stat[0]}
    wbegin=$((wlen<0?wlen:i1-wlen))
    wtype=${stat[2]}
    inest=$((nlen<0?nlen:i1-nlen))
    tchild=$((tclen<0?tclen:i1-tclen))
    tprev=$((tplen<0?tplen:i1-tplen))
    nparam=${stat[6]}; [[ $nparam == none ]] && nparam=
    ilook=$((i1+${stat[7]:-1}))
  else
    # 初期値
    ctx=$CTX_UNSPECIFIED ##!< 現在の解析の文脈
    ble-syntax:"$_ble_syntax_lang"/initialize-ctx # ctx 初期化
    wbegin=-1       ##!< シェル単語内にいる時、シェル単語の開始位置
    wtype=-1        ##!< シェル単語内にいる時、シェル単語の種類
    inest=-1        ##!< 入れ子の時、親の開始位置
    tchild=-1
    tprev=-1
    nparam=
    ilook=1
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

  ble-syntax:"$_ble_syntax_lang"/initialize-vars

  # 解析
  _ble_syntax_text=$text
  local i _stat tail
#%if !release
  local debug_p1
#%end
  for ((i=i1;i<iN;)); do
    ble-syntax/parse/generate-stat
    if ((i>=i2)) && [[ ${_tail_syntax_stat[i-i2]} == "$_stat" ]]; then
      if ble-syntax/parse/nest-equals "$inest"; then
        # 前回の解析と同じ状態になった時 → 残りは前回の結果と同じ
        _ble_syntax_stat=("${_ble_syntax_stat[@]::i}" "${_tail_syntax_stat[@]:i-i2}")
        _ble_syntax_tree=("${_ble_syntax_tree[@]::i}" "${_tail_syntax_tree[@]:i-i2}")
        _ble_syntax_nest=("${_ble_syntax_nest[@]::i}" "${_tail_syntax_nest[@]:i-i2}")
        _ble_syntax_attr=("${_ble_syntax_attr[@]::i}" "${_tail_syntax_attr[@]:i-i2}")
        break
      fi
    fi
    _ble_syntax_stat[i]=$_stat

    tail=${text:i}
#%if !release
    debug_p1=$i
#%end
    # 処理
    "${_BLE_SYNTAX_FCTX[ctx]}" || ((_ble_syntax_attr[i]=ATTR_ERR,i++))

    # nest-pop で CMDI/ARGI になる事もあるし、
    # また単語終端な文字でも FCTX が失敗する事もある (unrecognized な場合) ので、
    # (FCTX の中や直後ではなく) ここで単語終端をチェック
    ble-syntax/parse/check-end
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
    _ble_syntax_stat[i]=$_stat

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
# Check

function ble-syntax:bash/is-complete {
  local iN=${#_ble_syntax_text}

  # (1) 最後の点にエラーが設定されていた時
  # - 閉じていない single quotation などは此処。
  # - 入れ子が閉じていない時もここで引っかかる。
  # - 実はヒアドキュメントが閉じていない時もここでかかる。
  ((iN>0)) && ((_ble_syntax_attr[iN-1]==ATTR_ERR)) && return 1

  local stat=${_ble_syntax_stat[iN]}
  if [[ $stat ]]; then
    ble/string#split-words stat "$stat"

    # (2) 入れ子が閉じていない時
    local nlen=${stat[3]}; ((nlen>=0)) && return 1

    # (3) ヒアドキュメントの待ちがある時
    local nparam=${stat[6]}; [[ $nparam == none ]] && nparam=
    local rex="$_ble_term_FS@([RI][QH][^$_ble_term_FS]*)(.*$)"
    [[ $nparam =~ $rex ]] && return 1

    # (4) 完結している文脈値の時以外
    local ctx=${stat[0]}
    ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||
        ctx==CTX_CMDX||ctx==CTX_CMDXT||ctx==CTX_CMDXE||ctx==CTX_CMDXV||
        ctx==CTX_TARGX1||ctx==CTX_TARGX2)) || return 1
  fi

  # 構文 if..fi, etc が閉じているか?
  local attrs ret
  IFS= eval 'attrs="::${_ble_syntax_attr[*]/%/::}"'
  ble/string#count-string "$attrs" ":$ATTR_KEYWORD_BEGIN:"; local nbeg=$ret
  ble/string#count-string "$attrs" ":$ATTR_KEYWORD_END:"; local nend=$ret
  ((nbeg>nend)) && return 1

  return 0
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
#       ble/string#split-words stat "${_ble_syntax_stat[i]}"
#       return
#     fi
#   done
# }

function ble-syntax/completion-context/add {
  local source=$1
  local comp1=$2
  context[${#context[*]}]="$source $comp1"
}

function ble-syntax/completion-context/check/parameter-expansion {
  local rex_paramx='^(\$(\{[!#]?)?)([a-zA-Z_][a-zA-Z_0-9]*)?$'
  if [[ ${text:i:index-i} =~ $rex_paramx ]]; then
    local rematch1=${BASH_REMATCH[1]}
    ble-syntax/completion-context/add variable $((i+${#rematch1}))
  fi
}

_ble_syntax_bash_complete_Arg[CTX_ARGI]=argument
_ble_syntax_bash_complete_Arg[CTX_ARGQ]=argument
_ble_syntax_bash_complete_Arg[CTX_FARGI1]=variable
_ble_syntax_bash_complete_Arg[CTX_FARGI3]=argument
_ble_syntax_bash_complete_Arg[CTX_FARGQ3]=argument
_ble_syntax_bash_complete_Arg[CTX_CARGI1]=argument
_ble_syntax_bash_complete_Arg[CTX_CARGQ1]=argument
_ble_syntax_bash_complete_Arg[CTX_VALI]=file
_ble_syntax_bash_complete_Arg[CTX_VALQ]=file
_ble_syntax_bash_complete_Arg[CTX_CONDI]=file
_ble_syntax_bash_complete_Arg[CTX_CONDQ]=file
_ble_syntax_bash_complete_Arg[CTX_ARGVI]=variable:=

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
      ble/string#split-words stat "${_ble_syntax_stat[i]}"
      break
    fi
  done
  [[ ! ${stat[0]} ]] && return

  local ctx=${stat[0]} wlen=${stat[1]}
  local wbeg=$((wlen<0?wlen:i-wlen))
  if ((ctx==CTX_CMDI)); then
    if ((wlen>=0)); then
      # CTX_CMDI  → コマンドの続き
      ble-syntax/completion-context/add command "$wbeg"
      if [[ ${text:wbeg:index-wbeg} =~ $rex_param ]]; then
        ble-syntax/completion-context/add variable:= "$wbeg"
      fi
    fi
    ble-syntax/completion-context/check/parameter-expansion
  elif [[ ${_ble_syntax_bash_complete_Arg[ctx]} ]]; then
    # CTX_ARGI  → 引数の続き
    if ((wlen>=0)); then
      local source=${_ble_syntax_bash_complete_Arg[ctx]}
      ble-syntax/completion-context/add "$source" "$wbeg"

      local sub=${text:wbeg:index-wbeg}
      if [[ $sub == *[=:]* ]]; then
        sub=${sub##*[=:]}
        ble-syntax/completion-context/add file "$((index-${#sub}))"
      fi
    fi
    ble-syntax/completion-context/check/parameter-expansion
  elif ((ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXT||ctx==CTX_CMDXV)); then
    # 直前の再開点が CMDX だった場合、
    # 現在地との間にコマンド名があればそれはコマンドである。
    # スペースや ;&| 等のコマンド以外の物がある可能性もある事に注意する。
    local word=${text:i:index-i}

    # コマンドのチェック
    if ble-syntax:bash/simple-word/is-simple "$word"; then
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
    elif [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
      # 単語が未だ開始していない時 (空白)
      shopt -q no_empty_cmd_completion ||
        ble-syntax/completion-context/add command "$index"
    fi

    ble-syntax/completion-context/check/parameter-expansion
  elif ((ctx==CTX_CMDXC)); then
    local rex word=${text:i:index-i}
    if [[ ${text:i:index-i} =~ $rex_param ]]; then
      ble-syntax/completion-context/add wordlist:'for:select:case:if:while:until' "$i"
    elif rex='^[[({]+$'; [[ $word =~ $rex ]]; then
      ble-syntax/completion-context/add wordlist:'(:{:((:[[' "$i"
    fi
  elif ((ctx==CTX_CMDXE)); then
    if [[ ${text:i:index-i} =~ $rex_param ]]; then
      ble-syntax/completion-context/add wordlist:fi:done:esac:then:elif:else:do "$i"
    fi
  elif ((ctx==CTX_CMDXD0)); then
    if [[ ${text:i:index-i} =~ $rex_param ]]; then
      ble-syntax/completion-context/add wordlist:';:{:do' "$i"
    fi
  elif ((ctx==CTX_CMDXD)); then
    if [[ ${text:i:index-i} =~ $rex_param ]]; then
      ble-syntax/completion-context/add wordlist:'{:do' "$i"
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
  elif ((ctx==CTX_TARGX1||ctx==CTX_TARGI1||ctx==CTX_TARGX2||ctx==CTX_TARGI2)); then
    ble-syntax/completion-context/add command "$i"
    if ((ctx==CTX_TARGX1)); then
      local rex='^-p?$'
      [[ ${text:i:index-i} =~ $rex ]] &&
        ble-syntax/completion-context/add wordlist:-p "$i"
    elif ((ctx==CTX_TARGX2)); then
      local rex='^--?$'
      [[ ${text:i:index-i} =~ $rex ]] &&
        ble-syntax/completion-context/add wordlist:-- "$i"
    fi
  elif ((ctx==CTX_ARGX||ctx==CTX_CARGX1||ctx==CTX_FARGX3||ctx==CTX_ARGVX||ctx==CTX_VALX||ctx==CTX_CONDX||ctx==CTX_RDRS)); then
    local source=file
    if ((ctx==CTX_ARGX||ctx==CTX_CARGX1||ctx==CTX_FARGX3)); then
      source=argument
    elif ((ctx==CTX_ARGVX)); then
      source=variable:=
    fi

    local word=${text:i:index-i}
    if ble-syntax:bash/simple-word/is-simple "$word"; then
      # 単語が i から開始している場合
      ble-syntax/completion-context/add "$source" "$i"
      local rex="^([^'\"\$\\]|\\.)*="
      if [[ $word =~ $rex ]]; then
        word=${word:${#BASH_REMATCH}}
        ble-syntax/completion-context/add "$source" "$((index-${#word}))"
      fi
    elif [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
      # 単語が未だ開始していない時 (空白)
      ble-syntax/completion-context/add "$source" "$index"
    fi
    ble-syntax/completion-context/check/parameter-expansion
  elif ((ctx==CTX_RDRF||ctx==CTX_VRHS||ctx==CTX_ARGVR||ctx==CTX_VALR)); then
    if ((ctx==CTX_VRHS||ctx==CTX_ARGVR||ctx==CTX_VALR)); then
      # CTX_VRHS: VAR=value の value 部分
      if ((wlen>=0)); then
        # CTX_VRHS における単語は var= または var+= の形式をしている筈
        # ■ToDo arr[...]= arr[]+=... の時は?
        local p=$wbeg
        local rex='^[a-zA-Z0-9]+\+?='
        [[ ${text:p:index-p} =~ $rex ]] && ((p+=${#BASH_REMATCH}))
      else
        local p=$i
      fi
    else
      # CTX_RDRF: redirect の filename 部分
      local p=$((wlen>=0?wbeg:i))
    fi

    if ble-syntax:bash/simple-word/is-simple "${text:p:index-p}"; then
      ble-syntax/completion-context/add file "$p"
    fi
  elif ((ctx==CTX_QUOT)); then
    ble-syntax/completion-context/check/parameter-expansion
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
  ble/string#split-words stat "${_ble_syntax_stat[index]}"
  if [[ ${stat[0]} ]]; then
    # ここで CTX_CMDI や CTX_ARGI は処理しない。
    # 既に check-prefix で引っかかっている筈だから。
    local ctx=${stat[0]}

    if ((ctx==CTX_CMDX||ctx==CTX_CMDXV||ctx==CTX_CMDX1||ctx==CTX_CMDXT)); then
      if ! shopt -q no_empty_cmd_completion; then
        ble-syntax/completion-context/add command "$index"
        ble-syntax/completion-context/add variable:= "$index"
      fi
    elif ((ctx==CTX_CMDXC)); then
      ble-syntax/completion-context/add wordlist:'(:{:((:[[:for:select:case:if:while:until' "$index"
    elif ((ctx==CTX_CMDXE)); then
      ble-syntax/completion-context/add wordlist:'}:fi:done:esac:then:elif:else:do' "$index"
    elif ((ctx==CTX_CMDXD0)); then
      ble-syntax/completion-context/add wordlist:';:{:do' "$index"
    elif ((ctx==CTX_CMDXD)); then
      ble-syntax/completion-context/add wordlist:'{:do' "$index"
    elif ((ctx==CTX_ARGX||ctx==CTX_CARGX1||ctx==FARGX3)); then
      ble-syntax/completion-context/add argument "$index"
    elif ((ctx==CTX_FARGX1||ctx==CTX_SARGX1)); then
      ble-syntax/completion-context/add variable "$index"
    elif ((ctx==CTX_CARGX2)); then
      ble-syntax/completion-context/add wordlist:in "$index"
    elif ((ctx==CTX_FARGX2)); then
      ble-syntax/completion-context/add wordlist:in:do "$index"
    elif ((ctx==CTX_TARGX1)); then
      ble-syntax/completion-context/add command "$index"
      ble-syntax/completion-context/add wordlist:-p "$index"
    elif ((ctx==CTX_TARGX2)); then
      ble-syntax/completion-context/add command "$index"
      ble-syntax/completion-context/add wordlist:-- "$index"
    elif ((ctx==CTX_RDRF||ctx==CTX_RDRS||ctx==CTX_VRHS||ctx==CTX_ARGVR||ctx==CTX_VALR)); then
      ble-syntax/completion-context/add file "$index"
    fi
  fi
}

## 関数 ble-syntax/completion-context
##   @var[out] context[]
function ble-syntax/completion-context {
  local text=$1 index=$2
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
  local wtxt=${_ble_syntax_text:wbegin:wlen}
  if [[ ! $comp_cword ]] && ((wbegin<=pos)); then
    if ((pos<=wbegin+wlen)); then
      comp_cword=${#comp_words[@]}
      comp_point=$((${#comp_line}+wbegin+wlen-pos))
      comp_line="$wtxt$comp_line"
      ble/array#push comp_words "$wtxt"
    else
      comp_cword=${#comp_words[@]}
      comp_point=${#comp_line}
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
        extract_command_found=1
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
  ((comp_cword=${#comp_words[@]}-1-comp_cword,
    comp_point=${#comp_line}-comp_point))
}

## (tree-enumerate-proc) ble-syntax:bash/extract-command/.scan
function ble-syntax:bash/extract-command/.scan {
  ((pos<wbegin)) && return

  if ((wbegin+wlen<pos)); then
    ble-syntax/tree-enumerate-break
  else
    local extract_has_word=
    ble-syntax/tree-enumerate-children \
      ble-syntax:bash/extract-command/.scan
    local has_word=$extract_has_word
    ble/util/unlocal extract_has_word

    if [[ $has_word && ! $extract_command_found ]]; then
      ble-syntax:bash/extract-command/.construct nested
      ble-syntax/tree-enumerate-break
    fi
  fi

  if [[ $wtype =~ ^[0-9]+$ && ! $extract_has_word ]]; then
    extract_has_word=$wtype
    return
  fi
}

## 関数 ble-syntax:bash/extract-command index
## @var[out] comp_cword comp_words comp_line comp_point
function ble-syntax:bash/extract-command {
  local pos=$1
  local extract_command_found=

  local extract_has_word=
  ble-syntax/tree-enumerate \
    ble-syntax:bash/extract-command/.scan
  [[ ! $extract_has_word ]] && return 1

  if [[ ! $extract_command_found ]]; then
    ble-syntax:bash/extract-command/.construct
  fi

  # {
  #   echo "pos=$pos w=$extract_has_word c=$extract_command_found"
  #   declare -p comp_words comp_cword comp_line comp_point
  # } >> ~/a.txt

  [[ $extract_command_found ]]
}

#==============================================================================
#
# syntax-highlight
#
#==============================================================================

# 遅延初期化対象
_ble_syntax_attr2iface=()
function ble-syntax/attr2g { ble-color/faces/initialize && ble-syntax/attr2g "$@"; }

# 遅延初期化子
function ble-syntax/faces-onload-hook {
  function _ble_syntax_attr2iface.define {
    ((_ble_syntax_attr2iface[$1]=_ble_faces__$2))
  }

  function ble-syntax/attr2g {
    local iface=${_ble_syntax_attr2iface[$1]:-_ble_faces__syntax_default}
    g=${_ble_faces[iface]}
  }

  # Note: navy was replaced by 26 for dark background
  # Note: gray was replaced by 242 for dark background

  ble-color-defface syntax_default           none
  ble-color-defface syntax_command           fg=brown
  ble-color-defface syntax_quoted            fg=green
  ble-color-defface syntax_quotation         fg=green,bold
  ble-color-defface syntax_expr              fg=26
  ble-color-defface syntax_error             bg=203,fg=231 # bg=224
  ble-color-defface syntax_varname           fg=202
  ble-color-defface syntax_delimiter         bold
  ble-color-defface syntax_param_expansion   fg=purple
  ble-color-defface syntax_history_expansion bg=94,fg=231
  ble-color-defface syntax_function_name     fg=92,bold # fg=purple
  ble-color-defface syntax_comment           fg=242
  ble-color-defface syntax_glob              fg=198,bold
  ble-color-defface syntax_brace             fg=37,bold
  ble-color-defface syntax_tilde             fg=navy,bold
  ble-color-defface syntax_document          fg=94
  ble-color-defface syntax_document_begin    fg=94,bold

  ble-color-defface command_builtin_dot fg=red,bold
  ble-color-defface command_builtin     fg=red
  ble-color-defface command_alias       fg=teal
  ble-color-defface command_function    fg=92 # fg=purple
  ble-color-defface command_file        fg=green
  ble-color-defface command_keyword     fg=blue
  ble-color-defface command_jobs        fg=red
  ble-color-defface command_directory   fg=26,underline
  ble-color-defface filename_directory  fg=26,underline
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
  _ble_syntax_attr2iface.define CTX_ARGQ     syntax_default
  _ble_syntax_attr2iface.define CTX_ARGVX    syntax_default
  _ble_syntax_attr2iface.define CTX_ARGVI    syntax_default
  _ble_syntax_attr2iface.define CTX_ARGVR    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDX     syntax_default
  _ble_syntax_attr2iface.define CTX_CMDX1    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDXT    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDXC    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDXE    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDXD    syntax_default
  _ble_syntax_attr2iface.define CTX_CMDXD0   syntax_default
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
  _ble_syntax_attr2iface.define CTX_VALR     syntax_default
  _ble_syntax_attr2iface.define CTX_VALQ     syntax_default
  _ble_syntax_attr2iface.define CTX_CONDX    syntax_default
  _ble_syntax_attr2iface.define CTX_CONDI    syntax_default
  _ble_syntax_attr2iface.define CTX_CONDQ    syntax_default
  _ble_syntax_attr2iface.define ATTR_COMMENT syntax_comment
  _ble_syntax_attr2iface.define CTX_CASE     syntax_default
  _ble_syntax_attr2iface.define CTX_PATN     syntax_default
  _ble_syntax_attr2iface.define ATTR_GLOB    syntax_glob
  _ble_syntax_attr2iface.define CTX_BRAX     syntax_default
  _ble_syntax_attr2iface.define ATTR_BRACE   syntax_brace
  _ble_syntax_attr2iface.define CTX_BRACE1   syntax_default
  _ble_syntax_attr2iface.define CTX_BRACE2   syntax_default
  _ble_syntax_attr2iface.define ATTR_TILDE   syntax_tilde

  # for var in ... / case arg in / time -p --
  _ble_syntax_attr2iface.define CTX_SARGX1   syntax_default
  _ble_syntax_attr2iface.define CTX_FARGX1   syntax_default
  _ble_syntax_attr2iface.define CTX_FARGX2   syntax_default
  _ble_syntax_attr2iface.define CTX_FARGX3   syntax_default
  _ble_syntax_attr2iface.define CTX_FARGI1   syntax_varname
  _ble_syntax_attr2iface.define CTX_FARGI2   command_keyword
  _ble_syntax_attr2iface.define CTX_FARGI3   syntax_default
  _ble_syntax_attr2iface.define CTX_FARGQ3   syntax_default

  _ble_syntax_attr2iface.define CTX_CARGX1   syntax_default
  _ble_syntax_attr2iface.define CTX_CARGX2   syntax_default
  _ble_syntax_attr2iface.define CTX_CARGI1   syntax_default
  _ble_syntax_attr2iface.define CTX_CARGQ1   syntax_default
  _ble_syntax_attr2iface.define CTX_CARGI2   command_keyword

  _ble_syntax_attr2iface.define CTX_TARGX1   syntax_default
  _ble_syntax_attr2iface.define CTX_TARGX2   syntax_default
  _ble_syntax_attr2iface.define CTX_TARGI1   syntax_default
  _ble_syntax_attr2iface.define CTX_TARGI2   syntax_default

  # here documents
  _ble_syntax_attr2iface.define CTX_RDRH    syntax_document_begin
  _ble_syntax_attr2iface.define CTX_RDRI    syntax_document_begin
  _ble_syntax_attr2iface.define CTX_HERE0   syntax_document
  _ble_syntax_attr2iface.define CTX_HERE1   syntax_document

  _ble_syntax_attr2iface.define ATTR_CMD_BOLD      command_builtin_dot
  _ble_syntax_attr2iface.define ATTR_CMD_BUILTIN   command_builtin
  _ble_syntax_attr2iface.define ATTR_CMD_ALIAS     command_alias
  _ble_syntax_attr2iface.define ATTR_CMD_FUNCTION  command_function
  _ble_syntax_attr2iface.define ATTR_CMD_FILE      command_file
  _ble_syntax_attr2iface.define ATTR_CMD_JOBS      command_jobs
  _ble_syntax_attr2iface.define ATTR_CMD_DIR       command_directory
  _ble_syntax_attr2iface.define ATTR_KEYWORD       command_keyword
  _ble_syntax_attr2iface.define ATTR_KEYWORD_BEGIN command_keyword
  _ble_syntax_attr2iface.define ATTR_KEYWORD_END   command_keyword
  _ble_syntax_attr2iface.define ATTR_KEYWORD_MID   command_keyword
  _ble_syntax_attr2iface.define ATTR_FILE_DIR      filename_directory
  _ble_syntax_attr2iface.define ATTR_FILE_LINK     filename_link
  _ble_syntax_attr2iface.define ATTR_FILE_EXEC     filename_executable
  _ble_syntax_attr2iface.define ATTR_FILE_FILE     filename_other
  _ble_syntax_attr2iface.define ATTR_FILE_WARN     filename_warning
  _ble_syntax_attr2iface.define ATTR_FILE_FIFO     filename_pipe
  _ble_syntax_attr2iface.define ATTR_FILE_SOCK     filename_socket
  _ble_syntax_attr2iface.define ATTR_FILE_BLK      filename_block
  _ble_syntax_attr2iface.define ATTR_FILE_CHR      filename_character
}

ble-color/faces/addhook-onload ble-syntax/faces-onload-hook

function ble-syntax/highlight/cmdtype1 {
  type=$1
  local cmd=$2
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
    ((type=ATTR_KEYWORD)) ;;
  (*:%*)
    # jobs
    ble/util/joblist.check
    if jobs -- "$cmd" &>/dev/null; then
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
  local cmd=$1 _0=$2
  local btype; ble/util/type btype "$cmd"
  ble-syntax/highlight/cmdtype1 "$btype" "$cmd"

  if [[ $type == "$ATTR_CMD_ALIAS" && $cmd != "$_0" ]]; then
    # alias を \ で無効化している場合は
    # unalias して再度 check (2fork)
    type=$(
      unalias "$cmd"
      ble/util/type btype "$cmd"
      ble-syntax/highlight/cmdtype1 "$btype" "$cmd"
      builtin echo -n "$type")
  elif [[ $type == "$ATTR_KEYWORD" ]]; then
    # Note: 予約語 (keyword) の時は構文解析の時点で着色しているのでコマンドとしての着色は行わない。
    #   関数 ble-syntax/highlight/cmdtype が呼び出されたとすれば、コマンドとしての文脈である。
    #   予約語がコマンドとして取り扱われるのは、クォートされていたか変数代入やリダイレクトの後だった時。
    #   この時 file, function, builtin, jobs のどれかになる。以下、最悪で 3fork+2exec
    ble/util/joblist.check
    if [[ ! ${cmd##%*} ]] && jobs -- "$cmd" &>/dev/null; then
      # %() { :; } として 関数を定義できるが jobs の方が優先される。
      # (% という名の関数を呼び出す方法はない?)
      # でも % で始まる物が keyword になる事はそもそも無いような。
      ((type=ATTR_CMD_JOBS))
    elif ble/util/isfunction "$cmd"; then
      ((type=ATTR_CMD_FUNCTION))
    elif enable -p | ble/bin/grep -q -F -x "enable $cmd" &>/dev/null; then
      ((type=ATTR_CMD_BUILTIN))
    elif type -P -- "$cmd" &>/dev/null; then
      ((type=ATTR_CMD_FILE))
    else
      ((type=ATTR_ERR))
    fi
  fi
}

## 関数 ble-syntax/highlight/cmdtype cmd word
##   @param[in] cmd
##     シェル展開・クォート除去を実行した後の文字列を指定します。
##   @param[in] word
##     シェル展開・クォート除去を実行する前の文字列を指定します。
##   @var[out] type
if ((_ble_bash>=40200||_ble_bash>=40000&&!_ble_bash_loaded_in_function)); then
  # Note: 連想配列 _ble_syntax_highlight_filetype は ble-syntax-lazy.sh で先に定義される。

  _ble_syntax_highlight_filetype_version=-1
  function ble-syntax/highlight/cmdtype {
    local cmd=$1 _0=$2

    # check cache
    if ((_ble_syntax_highlight_filetype_version!=_ble_edit_LINENO)); then
      _ble_syntax_highlight_filetype=()
      ((_ble_syntax_highlight_filetype_version=_ble_edit_LINENO))
    fi

    type=${_ble_syntax_highlight_filetype[x$_0]}
    [[ $type ]] && return

    ble-syntax/highlight/cmdtype2 "$cmd" "$_0"
    _ble_syntax_highlight_filetype["x$_0"]=$type
  }
else
  _ble_syntax_highlight_filetype=()
  _ble_syntax_highlight_filetype_version=-1
  function ble-syntax/highlight/cmdtype {
    local cmd=$1 _0=$2

    # check cache
    if ((_ble_syntax_highlight_filetype_version!=_ble_edit_LINENO)); then
      _ble_syntax_highlight_filetype=()
      ((_ble_syntax_highlight_filetype_version=_ble_edit_LINENO))
    fi

    local i iN
    for ((i=0,iN=${#_ble_syntax_highlight_filetype[@]}/2;i<iN;i++)); do
      if [[ ${_ble_syntax_highlight_filetype[2*i]} == x"$_0" ]]; then
        type=${_ble_syntax_highlight_filetype[2*i+1]}
        return
      fi
    done

    ble-syntax/highlight/cmdtype2 "$cmd" "$_0"
    _ble_syntax_highlight_filetype[2*iN]=x$_0
    _ble_syntax_highlight_filetype[2*iN+1]=$type
  }
fi

function ble-syntax/highlight/filetype {
  local file=$1 _0=$2
  type=
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
  local _i _arr=$1 _i1=$2 _i2=$3 _v=$4
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
      _ble_highlight_layer_syntax1_table[i]=$g
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
  elif local wtxt=${text:wbeg:wlen}; ble-syntax:bash/simple-word/is-simple "$wtxt"; then
    local ret
    if ((wtype==CTX_RDRS)); then
      ble-syntax:bash/simple-word/eval-noglob "$wtxt"; local ext=$? value=$ret
    else
      ble-syntax:bash/simple-word/eval "$wtxt"; local ext=$?
      local -a value; value=("${ret[@]}")
    fi

    if ((ext&&(wtype==CTX_CMDI||wtype==CTX_ARGI||wtype==CTX_RDRF||wtype==CTX_RDRS))); then
      # failglob 等の理由で展開に失敗した場合
      type=$ATTR_ERR
    elif (((wtype==CTX_RDRF||wtype==CTX_RDRD)&&${#value[@]}>=2)); then
      # 複数語に展開されたら駄目
      type=$ATTR_ERR
    elif ((wtype==CTX_CMDI)); then
      local attr=${_ble_syntax_attr[wbeg]}
      if ((attr!=ATTR_KEYWORD&&attr!=ATTR_KEYWORD_BEGIN&&attr!=ATTR_KEYWORD_END&&attr!=ATTR_KEYWORD_MID&&attr!=ATTR_DEL)); then
        ble-syntax/highlight/cmdtype "$value" "$wtxt"
      fi
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
    node[nofs+4]=$g
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
  local wbeg=$1 wend=$2 attr=$3
  ((wbeg<color_umin&&(wbeg=color_umin),
    wend>color_umax&&(wend=color_umax),
    wbeg<wend)) || return

  if [[ $attr =~ ^[0-9]+$ ]]; then
    ble/dense-array#fill-range _ble_highlight_layer_syntax2_table "$wbeg" "$wend" "$attr"
  else
    ble/dense-array#fill-range _ble_highlight_layer_syntax2_table "$wbeg" "$wend" ''
  fi
}

function ble-highlight-layer:syntax/word/.proc-childnode {
  if [[ $wtype =~ ^[0-9]+$ ]]; then
    local wbeg=$wbegin wend=$i
    ble-highlight-layer:syntax/word/.apply-attribute "$wbeg" "$wend" "$attr"
  fi

  ((tchild>=0)) && ble-syntax/tree-enumerate-children "$proc_children"
}

## @var[in,out] _ble_syntax_word_umin,_ble_syntax_word_umax
function ble-highlight-layer:syntax/update-word-table {
  # update table2 (単語の削除に関しては後で考える)
  # (1) 単語色の計算
  local color_umin=-1 color_umax=-1 iN=${#_ble_syntax_text}
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
      ble/string#split-words node "${_ble_syntax_tree[i-1]}"

      local wlen=${node[1]}
      local wbeg=$((i-wlen)) wend=$i

      if [[ ${node[0]} =~ ^[0-9]+$ ]]; then
        local attr=${node[4]}
        ble-highlight-layer:syntax/word/.apply-attribute "$wbeg" "$wend" "$attr"
      fi

      local tclen=${node[2]}
      if ((tclen>=0)); then
        local tchild=$((i-tclen))
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
  local i1=$1 i2=$2 g=$3
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
  local j=0 jN=${#_ble_highlight_layer_syntax3_list[*]}
  if ((jN)); then
    for ((j=0;j<jN;j++)); do
      local -a range
      ble/string#split-words range "${_ble_highlight_layer_syntax3_list[j]}"

      local a=${range[0]} b=${range[1]}
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
    ble/string#split-words stat "${_ble_syntax_stat[iN]}"
    local ctx=${stat[0]} nlen=${stat[3]} nparam=${stat[6]}
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
  ((DMIN>=0)) && umin=$DMIN umax=$DMAX

#%if !release
  if [[ $ble_debug ]]; then
    local debug_attr_umin=$_ble_syntax_attr_umin
    local debug_attr_uend=$_ble_syntax_attr_umax
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
      ch=${_ble_highlight_layer_plain_buff[DMAX]}
      _ble_highlight_layer_syntax_buff[DMAX]=$sgr$ch
    fi
  fi

  local i j g gprev=0
  if ((umin>0)); then
    ble-highlight-layer:syntax/getg "$((umin-1))"
    gprev=$g
  fi

  if ((umin>=0)); then
    local sgr
    for ((i=umin;i<=umax;i++)); do
      local ch=${_ble_highlight_layer_plain_buff[i]}
      ble-highlight-layer:syntax/getg "$i"
      [[ $g ]] || ble-highlight-layer/update/getg "$i"
      if ((gprev!=g)); then
        ble-color-g2sgr -v sgr "$g"
        ch=$sgr$ch
        ((gprev=g))
      fi
      _ble_highlight_layer_syntax_buff[i]=$ch
    done
  fi

  PREV_UMIN=$umin PREV_UMAX=$umax
  PREV_BUFF=_ble_highlight_layer_syntax_buff

#%if !release
  if [[ $ble_debug ]]; then
    local status buff= nl=$'\n'
    _ble_syntax_attr_umin=$debug_attr_umin _ble_syntax_attr_umax=$debug_attr_uend ble-syntax/print-status -v status
    ble/util/assign buff 'declare -p _ble_highlight_layer_plain_buff _ble_highlight_layer_syntax_buff | ble/bin/cat -A'; status="$status${buff%$nl}$nl"
    ble/util/assign buff 'declare -p _ble_highlight_layer_disabled_buff _ble_highlight_layer_region_buff _ble_highlight_layer_overwrite_mode_buff | ble/bin/cat -A'; status="$status${buff%$nl}$nl"
    #ble/util/assign buff 'declare -p _ble_textarea_bufferName $_ble_textarea_bufferName | cat -A'; status="$status$buff"
    ble-edit/info/show raw "$status"
  fi
#%end

  # # 以下は単語の分割のデバグ用
  # local -a words=() word
  # for ((i=1;i<=iN;i++)); do
  #   if [[ ${_ble_syntax_tree[i-1]} ]]; then
  #     ble/string#split-words word "${_ble_syntax_tree[i-1]}"
  #     local wtxt="${text:i-word[1]:word[1]}" value
  #     if ble-syntax:bash/simple-word/is-simple "$wtxt"; then
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
  local i=$1
  if [[ ${_ble_highlight_layer_syntax3_table[i]} ]]; then
    g=${_ble_highlight_layer_syntax3_table[i]}
  elif [[ ${_ble_highlight_layer_syntax2_table[i]} ]]; then
    g=${_ble_highlight_layer_syntax2_table[i]}
  elif [[ ${_ble_highlight_layer_syntax1_table[i]} ]]; then
    g=${_ble_highlight_layer_syntax1_table[i]}
  else
    g=
  fi
}

#%#----------------------------------------------------------------------------
#%# old test samples
#%#----------------------------------------------------------------------------
#%begin
# mytest 'echo hello world'
# mytest 'echo "hello world"'
# mytest 'echo a"hed"a "aa"b b"aa" aa'
# mytest 'echo a"$"a a"\$\",$*,$var,$12"a $*,$var,$12'
# mytest 'echo a"---$((1+a[12]*3))---$(echo hello)---"a'
# mytest 'a=1 b[x[y]]=1234 echo <( world ) >> hello; ( sub shell); ((1+2*3));'
# mytest 'a=${#hello} b=${world[10]:1:(5+2)*3} c=${arr[*]%%"test"$(cmd).cpp} d+=12'
# mytest 'for ((i=0;i<10;i++)); do echo hello; done; { : '"'worlds'\\'' record'"'; }'
# mytest '[[ echo == echo ]]; echo hello'

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
#%end
#%#----------------------------------------------------------------------------
#%)
#%m main main.r/\<ATTR_/BLE_ATTR_/
#%m main main.r/\<CTX_/BLE_CTX_/
#%x main

function ble-syntax/import { :; }

ble/util/isfunction ble/textarea#invalidate &&
  ble/textarea#invalidate
