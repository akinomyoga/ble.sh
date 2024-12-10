#!/bin/bash
#%[release = 0]
#%m main (

function ble/syntax/util/is-directory {
  local path=$1
  # Note: #D1168 Cygwin では // で始まるパスの判定は遅い
  if [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && $path == //* ]]; then
    [[ $path == // ]]
  else
    [[ -d $path ]]
  fi
}

## @fn ble/syntax/urange#update prefix p1 p2
## @fn ble/syntax/wrange#update prefix p1 [p2]
##   @param[in]   prefix
##   @param[in]   p1 p2
##   @var[in,out] {prefix}umin {prefix}umax
##
##   ble/syntax/urange#update に関しては、
##   ble/urange#update --prefix=prefix p1 p2 に等価である。
##   ble/syntax/wrange#update に対応するものはない。
##
function ble/syntax/urange#update {
  local prefix=$1
  local p1=$2 p2=${3:-$2}
  ((0<=p1&&p1<p2)) || return 1
  (((${prefix}umin<0||${prefix}umin>p1)&&(${prefix}umin=p1),
    (${prefix}umax<0||${prefix}umax<p2)&&(${prefix}umax=p2)))
}
function ble/syntax/wrange#update {
  local prefix=$1
  local p1=$2 p2=${3:-$2}
  ((0<=p1&&p1<=p2)) || return 1
  (((${prefix}umin<0||${prefix}umin>p1)&&(${prefix}umin=p1),
    (${prefix}umax<0||${prefix}umax<p2)&&(${prefix}umax=p2)))
}

## @fn ble/syntax/urange#shift prefix
## @fn ble/syntax/wrange#shift prefix
##   @param[in]   prefix
##   @var[in]     beg end end0 shift
##   @var[in,out] {prefix}umin {prefix}umax
##
##   ble/syntax/urange#shift に関しては、
##   ble/urange#shift --prefix=prefix "$beg" "$end" "$end0" "$shift" に等価である。
##   ble/syntax/wrange#shift に対応するものはない。
##
function ble/syntax/urange#shift {
  local prefix=$1
  ((${prefix}umin>=end0?(${prefix}umin+=shift):(
      ${prefix}umin>=beg&&(${prefix}umin=end)),
    ${prefix}umax>end0?(${prefix}umax+=shift):(
      ${prefix}umax>beg&&(${prefix}umax=beg)),
    ${prefix}umin>=${prefix}umax&&
      (${prefix}umin=${prefix}umax=-1)))
}
function ble/syntax/wrange#shift {
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
##   各要素は "( wtype wlen tclen tplen wattr )*" の形式をしている。
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
##   attr (wattr) または - or --
##     単語の着色に関する情報を保持する。
##     以下の何れかの形式を持つ。
##
##     "-"
##       単語の着色が未だ計算されていない事を表す。
##     g
##       描画属性値を保持する。
##     'm' len ':' attr (',' len ':' attr)*
##       長さ len の部分列と属性の組。
##       長さ len として '$' を指定した場合は単語終端までを意味する。
##     'd'
##       描画属性を削除することを意味する。
##
## @var _ble_syntax_TREE_WIDTH
##   _ble_syntax_tree に格納される一つの範囲情報のフィールドの数。
##
## @var _ble_syntax_attr[i]
##   文脈・属性の情報
_ble_syntax_text=
_ble_syntax_stat=()
_ble_syntax_nest=()
_ble_syntax_tree=()
_ble_syntax_attr=()

# Note: "_ble_syntax_lang=bash" is set in core-syntax-def.sh since other
# modules want to overwrite the variable even before module core-syntax is
# loaded.

_ble_syntax_TREE_WIDTH=5

#--------------------------------------
# ble/syntax/tree-enumerate proc
# ble/syntax/tree-enumerate-children proc
# ble/syntax/tree-enumerate-in-range beg end proc

function ble/syntax/tree-enumerate/.add-root-element {
  local wtype=$1 wlen=$2 tclen=$3 tplen=$4

  # Note: wtype は単語に格納される時に EndWtype テーブルで変換される。
  #  ble/syntax:bash/ctx-command/check-word-end の実装を参照の事。
  [[ ! ${wtype//[0-9]} && ${_ble_syntax_bash_command_EndWtype[wtype]} ]] &&
    wtype=${_ble_syntax_bash_command_EndWtype[wtype]}

  TE_root="$wtype $wlen $tclen $tplen -- $TE_root"
}

## @fn ble/syntax/tree-enumerate/.initialize
##
##   @var[in]  iN
##     文字列の長さ、つまり現在の解析終端位置を指定します。
##
##   @var[out] TE_root
##     ${_ble_syntax_tree[iN-1]} を調整して返します。
##     閉じていない範囲 (word, nest) を終端位置で閉じたときの値を計算します。
##
##   @var[out] TE_i
##     一番最後の範囲の終端位置を返します。
##     解析情報がない場合は -1 を返します。
##
##   @var[out] TE_nofs
##     0 に初期化します。
##
function ble/syntax/tree-enumerate/.initialize {
  if [[ ! ${_ble_syntax_stat[iN]} ]]; then
    TE_root= TE_i=-1 TE_nofs=0
    return 0
  fi

  local -a stat nest
  ble/string#split-words stat "${_ble_syntax_stat[iN]}"
  local wtype=${stat[2]}
  local wlen=${stat[1]}
  local nlen=${stat[3]} inest
  ((inest=nlen<0?nlen:iN-nlen))
  local tclen=${stat[4]}
  local tplen=${stat[5]}

  TE_root=
  ((iN>0)) && TE_root=${_ble_syntax_tree[iN-1]}

  while
    if ((wlen>=0)); then
      # TE_root に単語ノードを追加
      ble/syntax/tree-enumerate/.add-root-element "$wtype" "$wlen" "$tclen" "$tplen"
      tclen=0
    fi
    ((inest>=0))
  do
    ble/util/assert '[[ ${_ble_syntax_nest[inest]} ]]' "$FUNCNAME/FATAL1" || break

    ble/string#split-words nest "${_ble_syntax_nest[inest]}"

    local olen=$((iN-inest))
    tplen=${nest[4]}
    ((tplen>=0&&(tplen+=olen)))

    # TE_root にネストノードを追加
    ble/syntax/tree-enumerate/.add-root-element "${nest[7]}" "$olen" "$tclen" "$tplen"

    wtype=${nest[2]} wlen=${nest[1]} nlen=${nest[3]} tclen=0 tplen=${nest[5]}
    ((wlen>=0&&(wlen+=olen),
      tplen>=0&&(tplen+=olen),
      nlen>=0&&(nlen+=olen),
      inest=nlen<0?nlen:iN-nlen))

    ble/util/assert '((nlen<0||nlen>olen))' "$FUNCNAME/FATAL2" || break
  done

  if [[ $TE_root ]]; then
    ((TE_i=iN))
  else
    ((TE_i=tclen>=0?iN-tclen:tclen))
  fi
  ((TE_nofs=0))
}

## @fn ble/syntax/tree-enumerate/.impl command...
##   @param[in] command...
##     各ノードについて呼び出すコマンドを指定します。
##   @var[in] iN
##   @var[in] TE_root,TE_i,TE_nofs
function ble/syntax/tree-enumerate/.impl {
  local islast=1
  while ((TE_i>0)); do
    local -a node
    if ((TE_i<iN)); then
      ble/string#split-words node "${_ble_syntax_tree[TE_i-1]}"
    else
      ble/string#split-words node "${TE_root:-${_ble_syntax_tree[iN-1]}}"
    fi

    ble/util/assert '((TE_nofs<${#node[@]}))' "$FUNCNAME(i=$TE_i,iN=$iN,TE_nofs=$TE_nofs,node=${node[*]},command=$@)/FATAL1" || break

    local wtype=${node[TE_nofs]} wlen=${node[TE_nofs+1]} tclen=${node[TE_nofs+2]} tplen=${node[TE_nofs+3]} attr=${node[TE_nofs+4]}
    local wbegin=$((wlen<0?wlen:TE_i-wlen))
    local tchild=$((tclen<0?tclen:TE_i-tclen))
    local tprev=$((tplen<0?tplen:TE_i-tplen))
    "$@"

    ble/util/assert '((tprev<TE_i))' "$FUNCNAME/FATAL2" || break

    ((TE_i=tprev,TE_nofs=0,islast=0))
  done
}

## @var[in] iN
## @var[in] TE_root,TE_i,TE_nofs
## @var[in] tchild
function ble/syntax/tree-enumerate-children {
  ((0<tchild&&tchild<=TE_i)) || return 1
  local TE_nofs=$((TE_i==tchild?TE_nofs+_ble_syntax_TREE_WIDTH:0))
  local TE_i=$tchild
  ble/syntax/tree-enumerate/.impl "$@"
}
function ble/syntax/tree-enumerate-break { ((tprev=-1)); }

## @fn ble/syntax/tree-enumerate command...
##   現在の解析状態 _ble_syntax_tree に基いて、
##   指定したコマンド command... を
##   トップレベルの各ノードに対して末尾にあるノードから順に呼び出します。
##
##   @param[in] command...
##     呼び出すコマンドを指定します。
##
##     コマンドは以下のシェル変数を入力・出力とします。
##     @var[in]     TE_i TE_nofs
##     @var[in]     wtype wbegin wlen attr tchild
##     @var[in,out] tprev
##       列挙を中断する時は ble/syntax/tree-enumerate-break
##       を呼び出す事によって、tprev=-1 を設定します。
##
##     内部で ble/syntax/tree-enumerate-children を呼び出すと、
##     更に入れ子になった単語について処理を実行する事ができます。
##
##   @var[in] iN
##     解析の起点を指定します。_ble_syntax_stat が設定されている必要があります。
##     指定を省略した場合は _ble_syntax_stat の末尾が使用されます。
function ble/syntax/tree-enumerate {
  local TE_root TE_i TE_nofs
  [[ ${iN:+set} ]] || local iN=${#_ble_syntax_text}
  ble/syntax/tree-enumerate/.initialize
  ble/syntax/tree-enumerate/.impl "$@"
}

## @fn ble/syntax/tree-enumerate-in-range beg end proc
##   入れ子構造に従わず或る範囲内に登録されている節を列挙します。
##   @param[in] beg,end
##   @param[in] proc
##     以下の変数を使用する関数を指定します。
##     @var[in] wtype wlen wbeg wend wattr
##     @var[in] node
##     @var[in] TE_i TE_nofs
function ble/syntax/tree-enumerate-in-range {
  local beg=$1 end=$2
  local proc=$3
  local -a node
  local TE_i TE_nofs
  for ((TE_i=end;TE_i>=beg;TE_i--)); do
    ((TE_i>0)) && [[ ${_ble_syntax_tree[TE_i-1]} ]] || continue
    ble/string#split-words node "${_ble_syntax_tree[TE_i-1]}"
    local flagUpdateNode=
    for ((TE_nofs=0;TE_nofs<${#node[@]};TE_nofs+=_ble_syntax_TREE_WIDTH)); do
      local wtype=${node[TE_nofs]} wlen=${node[TE_nofs+1]} wattr=${node[TE_nofs+4]}
      local wbeg=$((wlen<0?wlen:TE_i-wlen)) wend=$TE_i
      "${@:3}"
    done
  done
}

#--------------------------------------
# ble/syntax/print-status

function ble/syntax/print-status/.graph {
  local char=$1
  if ble/util/isprint+ "$char"; then
    graph="'$char'"
    return 0
  else
    local ret
    ble/util/s2c "$char"
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
function ble/syntax/print-status/.tree-prepend {
  local j=$1
  local value=$2${tree[j]}
  tree[j]=$value
  ((max_tree_width<${#value}&&(max_tree_width=${#value})))
}

function ble/syntax/print-status/.dump-arrays/.append-attr-char {
  if (($?==0)); then
    attr="${attr}$1"
  else
    attr="${attr} "
  fi
}

## @fn ble/syntax/print-status/ctx#get-text ctx
##   @var[out] ret
function ble/syntax/print-status/ctx#get-text {
  local sgr
  ble/syntax/ctx#get-name "$1"
  ret=${ret#BLE_}
  if [[ ! $ret ]]; then
    ble/color/face2sgr syntax_error
    ret="${ret}CTX$1$_ble_term_sgr0"
  fi
}
## @fn ble/syntax/print-status/word.get-text index
##   _ble_syntax_tree[index] の内容を文字列にします。
##   @param[in] index
##   @var[out]  word
function ble/syntax/print-status/word.get-text {
  local index=$1
  ble/string#split-words word "${_ble_syntax_tree[index]}"
  local out= ret
  if [[ $word ]]; then
    local nofs=$((${#word[@]}/_ble_syntax_TREE_WIDTH*_ble_syntax_TREE_WIDTH))
    while (((nofs-=_ble_syntax_TREE_WIDTH)>=0)); do
      local axis=$((index+1))

      local wtype=${word[nofs]}
      if [[ $wtype =~ ^[0-9]+$ ]]; then
        ble/syntax/print-status/ctx#get-text "$wtype"; wtype=$ret
      elif [[ $wtype =~ ^n* ]]; then
        # Note: nest-pop 時の tree-append では prefix n を付けている。
        wtype=$sgr_quoted\"${wtype:1}\"$_ble_term_sgr0
      else
        wtype=$sgr_error${wtype}$_ble_term_sgr0
      fi

      local b=$((axis-word[nofs+1])) e=$axis
      local sprev=${word[nofs+3]} schild=${word[nofs+2]}
      if ((sprev>=0)); then
        sprev="@$((axis-sprev-1))>"
      else
        sprev=
      fi
      if ((schild>=0)); then
        schild=">@$((axis-schild-1))"
      else
        schild=
      fi

      local wattr=${word[nofs+4]}
      if [[ $wattr != - ]]; then
        wattr="/(wattr=$wattr)"
      else
        wattr=
      fi

      out=" word=$wtype:$sprev$b-$e$schild$wattr$out"
      for ((;b<index;b++)); do
        ble/syntax/print-status/.tree-prepend "$b" '|'
      done
      ble/syntax/print-status/.tree-prepend "$index" '+'
    done
    word=$out
  fi
}
## @fn ble/syntax/print-status/nest.get-text index
##   _ble_syntax_nest[index] の内容を文字列にします。
##   @param[in] index
##   @var[out]  nest
function ble/syntax/print-status/nest.get-text {
  local index=$1
  ble/string#split-words nest "${_ble_syntax_nest[index]}"
  if [[ $nest ]]; then
    local ret
    ble/syntax/print-status/ctx#get-text "${nest[0]}"; local nctx=$ret

    local nword=-
    if ((nest[1]>=0)); then
      ble/syntax/print-status/ctx#get-text "${nest[2]}"; local swtype=$ret
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
      # Note #D1774: bash-3.0 bug "${var//../$'...'}" とすると $'' の引用符が残
      #   る問題の回避の為に行を分けて代入する。
      nparam=${nparam//$_ble_term_FS/$'\e[7m^\\\e[m'}
      nparam=" nparam=$nparam"
    fi

    nest=" nest=($nctx w=$nword n=$nnest t=$nchild:$nprev$nparam)"
  fi
}
## @fn ble/syntax/print-status/stat.get-text index
##   _ble_syntax_stat[index] の内容を文字列にします。
##   @param[in] index
##   @var[out]  stat
function ble/syntax/print-status/stat.get-text {
  local index=$1
  ble/string#split-words stat "${_ble_syntax_stat[index]}"
  if [[ $stat ]]; then
    local ret
    ble/syntax/print-status/ctx#get-text "${stat[0]}"; local stat_ctx=$ret

    local stat_word=-
    if ((stat[1]>=0)); then
      ble/syntax/print-status/ctx#get-text "${stat[2]}"; local stat_wtype=$ret
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
      # Note #D1774: bash-3.0 bug "${var//$'...'}" とすると余分な引用符が残る問
      #   題を回避する為に行を分けて代入している。
      snparam=${snparam//"$_ble_term_FS"/$'\e[7m^\\\e[m'}
      snparam=" nparam=$snparam"
    fi

    local stat_lookahead=
    ((stat[7]!=1)) && stat_lookahead=" >>${stat[7]}"
    stat=" stat=($stat_ctx w=$stat_word n=$stat_inest t=$stat_child:$stat_prev$snparam$stat_lookahead)"
  fi
}

## @var[out] resultA
## @var[in]  iN
function ble/syntax/print-status/.dump-arrays {
  local -a tree char line
  tree=()
  char=()
  line=()

  local ret
  ble/color/face2sgr syntax_error; local sgr_error=$ret
  ble/color/face2sgr syntax_quoted; local sgr_quoted=$ret

  local i max_tree_width=0
  for ((i=0;i<=iN;i++)); do
    local attr="  ${_ble_syntax_attr[i]:-|}"
    if ((_ble_syntax_attr_umin<=i&&i<_ble_syntax_attr_umax)); then
      attr="${attr:${#attr}-2:2}*"
    else
      attr="${attr:${#attr}-2:2} "
    fi

    [[ ${_ble_highlight_layer_syntax1_table[i]} ]] && ble/color/g2sgr "${_ble_highlight_layer_syntax1_table[i]}"
    ble/syntax/print-status/.dump-arrays/.append-attr-char "${ret}a${_ble_term_sgr0}"
    [[ ${_ble_highlight_layer_syntax2_table[i]} ]] && ble/color/g2sgr "${_ble_highlight_layer_syntax2_table[i]}"
    ble/syntax/print-status/.dump-arrays/.append-attr-char "${ret}w${_ble_term_sgr0}"
    [[ ${_ble_highlight_layer_syntax3_table[i]} ]] && ble/color/g2sgr "${_ble_highlight_layer_syntax3_table[i]}"
    ble/syntax/print-status/.dump-arrays/.append-attr-char "${ret}e${_ble_term_sgr0}"

    [[ ${_ble_syntax_stat_shift[i]} ]]
    ble/syntax/print-status/.dump-arrays/.append-attr-char s

    local index=000$i
    index=${index:${#index}-3:3}

    local word nest stat
    ble/syntax/print-status/word.get-text "$i"
    ble/syntax/print-status/nest.get-text "$i"
    ble/syntax/print-status/stat.get-text "$i"

    local graph=
    ble/syntax/print-status/.graph "${_ble_syntax_text:i:1}"
    char[i]="$attr $index $graph"
    line[i]=$word$nest$stat
  done

  resultA='_ble_syntax_attr/tree/nest/stat?'$'\n'
  ble/string#reserve-prototype "$max_tree_width"
  for ((i=0;i<=iN;i++)); do
    local t=${tree[i]}${_ble_string_prototype::max_tree_width}
    resultA="$resultA${char[i]} ${t::max_tree_width}${line[i]}"$'\n'
  done
}

## @fn ble/syntax/print-status/.dump-tree/proc1
## @var[out] resultB
## @var[in]  prefix
## @var[in]  nl
function ble/syntax/print-status/.dump-tree/proc1 {
  local tip="| "; tip=${tip:islast:1}
  prefix="$prefix$tip   " ble/syntax/tree-enumerate-children ble/syntax/print-status/.dump-tree/proc1
  resultB="$prefix\_ '${_ble_syntax_text:wbegin:wlen}'$nl$resultB"
}

## @fn ble/syntax/print-status/.dump-tree
## @var[out] resultB
## @var[in]  iN
function ble/syntax/print-status/.dump-tree {
  resultB=

  local nl=$_ble_term_nl
  local prefix=
  ble/syntax/tree-enumerate ble/syntax/print-status/.dump-tree/proc1
}

function ble/syntax/print-status {
  local iN=${#_ble_syntax_text}

  local resultA
  ble/syntax/print-status/.dump-arrays

  local resultB
  ble/syntax/print-status/.dump-tree

  local result=$resultA$resultB
  if [[ $1 == -v && $2 ]]; then
    local "${2%%\[*\]}" && ble/util/upvar "$2" "$result"
  else
    ble/util/print "$result"
  fi
}

function ble/syntax/print-layer-buffer.draw {
  local layer_name=$1
  local -a keys vals
  builtin eval "keys=(\"\${!_ble_highlight_layer_${layer_name}_buff[@]}\")"
  builtin eval "vals=(\"\${_ble_highlight_layer_${layer_name}_buff[@]}\")"

  local ret sgr0=$_ble_term_sgr0
  ble/color/face2sgr command_builtin; local sgr1=$ret
  ble/color/face2sgr syntax_varname; local sgr2=$ret
  ble/color/face2sgr syntax_quoted; local sgr3=$ret

  ble/canvas/put.draw "${sgr1}buffer${sgr0} ${sgr2}$layer_name${sgr0}=("
  local i count=0
  for ((i=0;i<${#keys[@]};i++)); do
    local key=${keys[i]} val=${vals[i]}
    while ((count++<key)); do
      ((count==1)) || ble/canvas/put.draw ' '
      ble/canvas/put.draw $'\e[91munset\e[m'
    done

    ((count==1)) || ble/canvas/put.draw ' '
    ble/string#quote-word "$val" quote-empty:sgrq="$sgr3"
    ble/canvas/put.draw "$ret"
  done
  ble/canvas/put.draw ")$_ble_term_nl"
}

#--------------------------------------

function ble/syntax/parse/serialize-stat {
  ((ilook<=i&&(ilook=i+1)))
  sstat="$ctx $((wbegin<0?wbegin:i-wbegin)) $wtype $((inest<0?inest:i-inest)) $((tchild<0?tchild:i-tchild)) $((tprev<0?tprev:i-tprev)) ${nparam:-none} $((ilook-i))"
}


## @fn ble/syntax/parse/set-lookahead count
##
##   @param[in] count
##     現在位置の何文字先まで参照して動作を決定したかを指定します。文字列が終端
##     している事を確認した時、そこに可能性として存在し得た1文字を参照した事に
##     なるので、その文字列終端も1文字に数える必要があります。
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
function ble/syntax/parse/set-lookahead {
  ((i+$1>ilook&&(ilook=i+$1)))
}

# 構文木の管理 (_ble_syntax_tree)

## @fn ble/syntax/parse/tree-append
## 要件 解析位置を進めてから呼び出す必要があります (要件: i>=p1+1)。
function ble/syntax/parse/tree-append {
#%if !release
  [[ $debug_p1 ]] && ble/util/assert '((i-1>=debug_p1))' "Wrong call of tree-append: Condition violation (p1=$debug_p1 i=$i iN=$iN)."
#%end
  local type=$1
  local beg=$2 end=$i
  local len=$((end-beg))
  ((len==0)) && return 0

  local tchild=$3 tprev=$4

  # 子情報・兄情報
  local ochild=-1 oprev=-1
  ((tchild>=0&&(ochild=i-tchild)))
  ((tprev>=0&&(oprev=i-tprev)))

  [[ $type =~ ^[0-9]+$ ]] && ble/syntax/parse/touch-updated-word "$i"

  # 追加する要素の数は _ble_syntax_TREE_WIDTH と一致している必要がある。
  _ble_syntax_tree[i-1]="$type $len $ochild $oprev - ${_ble_syntax_tree[i-1]}"
}

function ble/syntax/parse/word-push {
  wtype=$1 wbegin=$2 tprev=$tchild tchild=-1
}
## @fn ble/syntax/parse/word-pop
## 要件 解析位置を進めてから呼び出す必要があります (要件: i>=p1+1)。
# 仮定: 1つ上の level は nest-push による level か top level のどちらかである。
#   この場合に限って ble/syntax/parse/nest-reset-tprev を用いて、tprev
#   を適切な値に復元することができる。
function ble/syntax/parse/word-pop {
  ble/syntax/parse/tree-append "$wtype" "$wbegin" "$tchild" "$tprev"
  ((wbegin=-1,wtype=-1,tchild=i))
  ble/syntax/parse/nest-reset-tprev
}
## '[[' 専用の関数:
##   word-push/word-pop と nest-push の順序を反転させる為に。
##   具体的にどう使われているかは使っている箇所を参照すると良い。
##   ※本当は [[ が見付かった時点でコマンドとして読み取るのではなく、
##     特別扱いするべきな気もするが、面倒なので今の実装になっている。
## 仮定: 一番最後に設置されたのが単語である事。
##   かつ、キャンセルされる単語は今回の解析ステップで設置された物である事。
function ble/syntax/parse/word-cancel {
  local -a word
  ble/string#split-words word "${_ble_syntax_tree[i-1]}"
  local wlen=${word[1]} tplen=${word[3]}
  local wbegin=$((i-wlen))
  tchild=$((tplen<0?tplen:i-tplen))
  ble/array#fill-range _ble_syntax_tree "$wbegin" "$i" ''
}

# 入れ子構造の管理

## @fn ble/syntax/parse/nest-push newctx ntype
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
function ble/syntax/parse/nest-push {
  local wlen=$((wbegin<0?wbegin:i-wbegin))
  local nlen=$((inest<0?inest:i-inest))
  local tclen=$((tchild<0?tchild:i-tchild))
  local tplen=$((tprev<0?tprev:i-tprev))
  _ble_syntax_nest[i]="$ctx $wlen $wtype $nlen $tclen $tplen ${nparam:-none} ${2:-none}"
  ((ctx=$1,inest=i,wbegin=-1,wtype=-1,tprev=tchild,tchild=-1))
  nparam=
}
## @fn ble/syntax/parse/nest-pop
## 要件 解析位置を進めてから呼び出す必要があります (要件: i>=p1+1)。
##   現在の入れ子を閉じます。現在の入れ子情報を記録して、一つ上の入れ子情報を復元します。
##   @var[   out] ctx      上の入れ子階層の ctx を復元します。
##   @var[   out] wbegin   上の入れ子階層の wbegin を復元します。
##   @var[   out] wtype    上の入れ子階層の wtype を復元します。
##   @var[in,out] inest    記録する入れ子情報を指定します。上の入れ子階層の inest を復元します。
##   @var[in,out] tchild   記録する入れ子情報を指定します。上の入れ子階層の tchild を復元します。
##   @var[in,out] tprev    記録する入れ子情報を指定します。上の入れ子階層の tprev を復元します。
##   @var[   out] nparam   上の入れ子階層の nparam を復元します。
function ble/syntax/parse/nest-pop {
  ((inest<0)) && return 1

  local -a parentNest
  ble/string#split-words parentNest "${_ble_syntax_nest[inest]}"

  local ntype=${parentNest[7]} nbeg=$inest
  ble/syntax/parse/tree-append "n$ntype" "$nbeg" "$tchild" "$tprev"

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
function ble/syntax/parse/nest-type {
  local _ble_local_var=ntype
  [[ $1 == -v ]] && _ble_local_var=$2
  if ((inest<0)); then
    builtin eval "$_ble_local_var="
    return 1
  else
    builtin eval "$_ble_local_var=\"\${_ble_syntax_nest[inest]##* }\""
  fi
}
## @fn ble/syntax/parse/nest-ctx
##   @var[out] nctx
function ble/syntax/parse/nest-ctx {
  nctx=
  ((inest>=0)) || return 1
  nctx=${_ble_syntax_nest[inest]%% *}
}
function ble/syntax/parse/nest-reset-tprev {
  if ((inest<0)); then
    tprev=-1
  else
    local -a nest
    ble/string#split-words nest "${_ble_syntax_nest[inest]}"
    local tclen=${nest[4]}
    ((tprev=tclen<0?tclen:inest-tclen))
  fi
}
## @fn ble/syntax/parse/nest-equals
##   現在のネスト状態と前回のネスト状態が一致するか判定します。
## @var i1                     更新開始点
## @var i2                     更新終了点
## @var tail_syntax_stat[i-i2] i2 以降の更新前状態
## @var _ble_syntax_stat[i]    新しい状態
function ble/syntax/parse/nest-equals {
  local parent_inest=$1
  while :; do
    ((parent_inest<i1)) && return 0 # 変更していない範囲 または -1
    ((parent_inest<i2)) && return 1 # 変更によって消えた範囲

    local onest=${tail_syntax_nest[parent_inest-i2]}
    local nnest=${_ble_syntax_nest[parent_inest]}
    [[ $onest != "$nnest" ]] && return 1

    ble/string#split-words onest "$onest"
#%if !release
    ble/util/assert \
      '((onest[3]!=0&&onest[3]<=parent_inest))' \
      "invalid nest onest[3]=${onest[3]} parent_inest=$parent_inest text=$text" || return 0
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
_ble_syntax_word_defer_umin=-1 _ble_syntax_word_defer_umax=-1
function ble/syntax/parse/touch-updated-attr {
  ble/syntax/urange#update _ble_syntax_attr_ "$1" "$(($1+1))"
}
function ble/syntax/parse/touch-updated-word {
#%if !release
  ble/util/assert "(($1>0))" "invalid word position $1"
#%end
  ble/syntax/wrange#update _ble_syntax_word_ "$1"
}

#==============================================================================
#
# 文脈値
#

# 文脈値達 from lib/core-syntax-ctx.def
#%$ sed 's/[[:space:]]*#.*//;/^$/d' lib/core-syntax-ctx.def | awk '$2 ~ /^[0-9]+$/ {print $1 "=" $2;}'

# for debug
_ble_syntax_bash_ctx_names=(
#%$ sed 's/[[:space:]]*#.*//;/^$/d' lib/core-syntax-ctx.def | awk '$2 ~ /^[0-9]+$/ {print "  [" $2 "]=" $1;}'
)

## @fn ble/syntax/ctx#get-name ctx
##   @param[in] ctx
##   @var[out] ret
function ble/syntax/ctx#get-name {
  ret=${_ble_syntax_bash_ctx_names[$1]#_ble_ctx_}
}

# @var _ble_syntax_context_proc[]
# @var _ble_syntax_context_end[]
#   以上の二つの配列を通して文法要素は最終的に登録される。
#   (逆に言えば上の二つの配列を弄れば別の文法の解析を実行する事もできる)
_ble_syntax_context_proc=()
_ble_syntax_context_end=()

#==============================================================================
#
# 空文法
#
#------------------------------------------------------------------------------

function ble/syntax:text/ctx-unspecified {
  ((_ble_syntax_attr[i]=ctx,i+=${#tail}))
  return 0
}
_ble_syntax_context_proc[CTX_UNSPECIFIED]=ble/syntax:text/ctx-unspecified

function ble/syntax:text/initialize-ctx { ctx=$CTX_UNSPECIFIED; }
function ble/syntax:text/initialize-vars { return 0; }

#==============================================================================
#
# Bash Script 文法
#
#------------------------------------------------------------------------------

_ble_syntax_bash_RexSpaces=$'[ \t]+'
_ble_syntax_bash_RexIFSs="[$_ble_term_IFS]+"
_ble_syntax_bash_RexDelimiter="[$_ble_term_IFS;|&<>()]"
_ble_syntax_bash_RexRedirect='((\{[_a-zA-Z][_a-zA-Z0-9]*\}|[0-9]+)?(&?>>?|>[|&]|<[>&]?|<<[-<]?))[ 	]*'

## @var _ble_syntax_bash_chars[]
##   特定の役割を持つ文字の集合。Bracket expression [～] に入れて使う為の物。
##   histchars に依存しているので変化があった時に更新する。
_ble_syntax_bash_chars=()
_ble_syntax_bashc_seed=

function ble/syntax:bash/cclass/update/reorder {
  builtin eval "local a=\"\${$1}\""

  # Bracket expression として安全な順に並び替える
  [[ $a == *']'* ]] && a="]${a//]}"
  [[ $a == *'-'* ]] && a="${a//-}-"

  builtin eval "$1=\$a"
}

## @fn ble/syntax:bash/cclass/update
##
##   @var[in] _ble_syntax_bash_histc12
##   @var[in,out] _ble_syntax_bashc_seed
##   @var[in,out] _ble_syntax_bash_chars[]
##
##   @exit 更新があった時に正常終了します。
##     更新の必要がなかった時に 1 を返します。
##
function ble/syntax:bash/cclass/update {
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
      a=${a//@h/"$histc1"}
      a=${a//@q/"$histc2"}
      _ble_syntax_bash_chars[key]=$a
    done

    local a=$_ble_syntax_bash_chars_simpleFmt
    a=${a//@h/"$histc1"}
    a=${a//@q/"$histc2"}
    _ble_syntax_bashc_simple=$a
  fi

  if [[ $seed == *x ]]; then
    # extglob: ?() *() +() @() !()
    local extglob='@+!' # *? は既に登録されている筈
    _ble_syntax_bash_chars[CTX_ARGI]=${_ble_syntax_bash_chars[CTX_ARGI]}$extglob
    _ble_syntax_bash_chars[CTX_PATN]=${_ble_syntax_bash_chars[CTX_PATN]}$extglob
    _ble_syntax_bash_chars[CTX_PWORD]=${_ble_syntax_bash_chars[CTX_PWORD]}$extglob
    _ble_syntax_bash_chars[CTX_PWORDE]=${_ble_syntax_bash_chars[CTX_PWORDE]}$extglob
    _ble_syntax_bash_chars[CTX_PWORDR]=${_ble_syntax_bash_chars[CTX_PWORDR]}$extglob
  fi

  if [[ $modified ]]; then
    for key in "${!_ble_syntax_bash_chars[@]}"; do
      ble/syntax:bash/cclass/update/reorder _ble_syntax_bash_chars[key]
    done
    ble/syntax:bash/cclass/update/reorder _ble_syntax_bashc_simple
  fi
  return 0
}

_ble_syntax_bash_charsDef=()
_ble_syntax_bash_charsFmt=()
_ble_syntax_bash_chars_simpleDef=
_ble_syntax_bash_chars_simpleFmt=
function ble/syntax:bash/cclass/initialize {
  local delimiters="$_ble_term_IFS;|&()<>"
  local expansions="\$\"\`\\'"
  local glob='[*?'
  local tilde='~:'

  # _ble_syntax_bash_chars[CTX_ARGI] は以下で使われている
  #   ctx-command (色々)
  #   ctx-redirect (CTX_RDRF, CTX_RDRD, CTX_RDRD2, CTX_RDRS)
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
  _ble_syntax_bash_charsDef[CTX_PWORD]="}$expansions$glob!" # パラメータ展開 ${～}
  _ble_syntax_bash_charsDef[CTX_PWORDE]="}$expansions$glob!" # パラメータ展開 ${～} エラー
  _ble_syntax_bash_charsDef[CTX_PWORDR]="}/$expansions$glob!" # パラメータ展開 ${～} 置換前
  _ble_syntax_bash_charsDef[CTX_RDRH]="$delimiters$expansions"
  _ble_syntax_bash_charsDef[CTX_HERE1]="\\\$\`$_ble_term_nl!"

  # templates
  _ble_syntax_bash_charsFmt[CTX_ARGI]="$delimiters$expansions$glob{$tilde@q@h"
  _ble_syntax_bash_charsFmt[CTX_PATN]="$expansions$glob(|)<>{@h"
  _ble_syntax_bash_charsFmt[CTX_QUOT]="\$\"\`\\@h"
  _ble_syntax_bash_charsFmt[CTX_EXPR]="][}()$expansions@h"
  _ble_syntax_bash_charsFmt[CTX_PWORD]="}$expansions$glob@h"
  _ble_syntax_bash_charsFmt[CTX_PWORDE]="}$expansions$glob@h"
  _ble_syntax_bash_charsFmt[CTX_PWORDR]="}/$expansions$glob@h"
  _ble_syntax_bash_charsFmt[CTX_RDRH]=${_ble_syntax_bash_charsDef[CTX_RDRH]}
  _ble_syntax_bash_charsFmt[CTX_HERE1]="\\\$\`$_ble_term_nl@h"

  _ble_syntax_bash_chars_simpleDef="$delimiters$expansions^!"
  _ble_syntax_bash_chars_simpleFmt="$delimiters$expansions@q@h"

  _ble_syntax_bash_histc12='!^'
  ble/syntax:bash/cclass/update
}

ble/syntax:bash/cclass/initialize

#------------------------------------------------------------------------------
# ble/syntax:bash/simple-word

## @var _ble_syntax_bash_simple_rex_word
## @var _ble_syntax_bash_simple_rex_element
##   単純な単語のパターンとその構成要素を表す正規表現
##   histchars に依存しているので変化があった時に更新する。
_ble_syntax_bash_simple_rex_letter=
_ble_syntax_bash_simple_rex_param=
_ble_syntax_bash_simple_rex_bquot=
_ble_syntax_bash_simple_rex_squot=
_ble_syntax_bash_simple_rex_dquot=
_ble_syntax_bash_simple_rex_literal=
_ble_syntax_bash_simple_rex_element=
_ble_syntax_bash_simple_rex_word=
_ble_syntax_bash_simple_rex_open_word=
_ble_syntax_bash_simple_rex_open_dquot=
_ble_syntax_bash_simple_rex_open_squot=
_ble_syntax_bash_simple_rex_incomplete_word1=
_ble_syntax_bash_simple_rex_incomplete_word2=

_ble_syntax_bash_simple_rex_noglob_word1=
_ble_syntax_bash_simple_rex_noglob_word2=

function ble/syntax:bash/simple-word/update {
  local q="'"

  local letter='\[[!^]|[^'${_ble_syntax_bashc_simple}']'
  local param1='\$([-*@#?$!0_]|[1-9][0-9]*|[_a-zA-Z][_a-zA-Z0-9]*)'
  local param2='\$\{(#?[-*@#?$!0]|[#!]?([1-9][0-9]*|[_a-zA-Z][_a-zA-Z0-9]*))\}' # ${!!} ${!$} はエラーになる。履歴展開の所為?
  local param=$param1'|'$param2
  local bquot='\\.'
  local squot=$q'[^'$q']*'$q'|\$'$q'([^'$q'\]|\\.)*'$q
  local dquot='\$?"([^'${_ble_syntax_bash_chars[CTX_QUOT]}']|\\.|'$param')*"'
  _ble_syntax_bash_simple_rex_letter=$letter # 0 groups
  _ble_syntax_bash_simple_rex_param=$param   # 3 groups
  _ble_syntax_bash_simple_rex_bquot=$bquot   # 0 groups
  _ble_syntax_bash_simple_rex_squot=$squot   # 1 groups
  _ble_syntax_bash_simple_rex_dquot=$dquot   # 4 groups

  # @var _ble_syntax_bash_simple_rex_element
  # @var _ble_syntax_bash_simple_rex_word
  _ble_syntax_bash_simple_rex_literal='^('$letter')+$'
  _ble_syntax_bash_simple_rex_element='('$bquot'|'$squot'|'$dquot'|'$param'|'$letter')'
  _ble_syntax_bash_simple_rex_word='^'$_ble_syntax_bash_simple_rex_element'+$'

  # @var _ble_syntax_bash_simple_rex_open_word
  local open_squot=$q'[^'$q']*|\$'$q'([^'$q'\]|\\.)*'
  local open_dquot='\$?"([^'${_ble_syntax_bash_chars[CTX_QUOT]}']|\\.|'$param')*'
  _ble_syntax_bash_simple_rex_open_word='^('$_ble_syntax_bash_simple_rex_element'*)(\\|'$open_squot'|'$open_dquot')$'
  _ble_syntax_bash_simple_rex_open_squot=$open_squot
  _ble_syntax_bash_simple_rex_open_dquot=$open_dquot

  # @var _ble_syntax_bash_simple_rex_incomplete_word1
  # @var _ble_syntax_bash_simple_rex_incomplete_word2
  local letter1='\[[!^]|[^{'${_ble_syntax_bashc_simple}']'
  local letter2='\[[!^]|[^'${_ble_syntax_bashc_simple}']'
  _ble_syntax_bash_simple_rex_incomplete_word1='^('$bquot'|'$squot'|'$dquot'|'$param'|'$letter1')+'
  _ble_syntax_bash_simple_rex_incomplete_word2='^(('$bquot'|'$squot'|'$dquot'|'$param'|'$letter2')*)(\\|'$open_squot'|'$open_dquot')?$'

  # @var _ble_syntax_bash_simple_rex_noglob_word{1,2}
  local noglob_letter='[^[?*'${_ble_syntax_bashc_simple}']'
  _ble_syntax_bash_simple_rex_noglob_word1='^('$bquot'|'$squot'|'$dquot'|'$noglob_letter')+$'
  _ble_syntax_bash_simple_rex_noglob_word2='^('$bquot'|'$squot'|'$dquot'|'$param'|'$noglob_letter')+$'
}
ble/syntax:bash/simple-word/update

function ble/syntax:bash/simple-word/is-literal {
  [[ $1 =~ $_ble_syntax_bash_simple_rex_literal ]]
}
function ble/syntax:bash/simple-word/is-simple {
  [[ $1 =~ $_ble_syntax_bash_simple_rex_word ]]
}
function ble/syntax:bash/simple-word/is-simple-or-open-simple {
  [[ $1 =~ $_ble_syntax_bash_simple_rex_word || $1 =~ $_ble_syntax_bash_simple_rex_open_word ]]
}
function ble/syntax:bash/simple-word/is-never-word {
  ble/syntax:bash/simple-word/is-simple-or-open-simple && return 1
  local rex=${_ble_syntax_bash_simple_rex_word%'$'}'[ |&;<>()]|^[ |&;<>()]'
  [[ $1 =~ $rex ]]
}
function ble/syntax:bash/simple-word/is-simple-noglob {
  [[ $1 =~ $_ble_syntax_bash_simple_rex_noglob_word1 ]] && return 0
  if [[ $1 =~ $_ble_syntax_bash_simple_rex_noglob_word2 ]]; then
    builtin eval -- "local expanded=$1" 2>/dev/null
    local rex='[*?]|\[.+\]|[*?@+!]\(.*\)'
    [[ $expanded =~ $rex ]] || return 0
  fi
  return 1
}

## @fn ble/syntax:bash/simple-word/evaluate-last-brace-expansion simple_word
##   @param[in] simple_word
##   @var[out] ret simple_ibrace
function ble/syntax:bash/simple-word/evaluate-last-brace-expansion {
  local value=$1
  local bquot=$_ble_syntax_bash_simple_rex_bquot
  local squot=$_ble_syntax_bash_simple_rex_squot
  local dquot=$_ble_syntax_bash_simple_rex_dquot
  local param=$_ble_syntax_bash_simple_rex_param
  local letter='\[[!^]|[^{,}'${_ble_syntax_bashc_simple}']'
  local symbol='[{,}]'

  local rex_range_expansion='^(([-+]?[0-9]+)\.\.\.[-+]?[0-9]+|([a-zA-Z])\.\.[a-zA-Z])(\.\.[-+]?[0-9]+)?$'

  local rex0='^('$bquot'|'$squot'|'$dquot'|'$param'|'$letter')+'
  local stack; stack=()
  local out= comma= index=0 iopen=0 no_brace_length=0
  while [[ $value ]]; do
    if [[ $value =~ $rex0 ]]; then
      local len=${#BASH_REMATCH}
      ((index+=len,no_brace_length+=len))
      out=$out${value::len}
      value=${value:len}
    elif [[ $value == '{'* ]]; then
      ((iopen=++index,no_brace_length=0))
      value=${value:1}
      ble/array#push stack "$comma:$out"
      out= comma=
    elif ((${#stack[@]})) && [[ $value == '}'* ]]; then
      ((++index))
      value=${value:1}
      ble/array#pop stack
      local out0=${ret#*:} comma0=${ret%%:*}
      if [[ $comma ]]; then
        ((iopen=index,no_brace_length=0))
        out=$out0$out
        comma=$comma0
      elif [[ $out =~ $rex_range_expansion ]]; then
        ((iopen=index,no_brace_length=0))
        out=$out0${2#+}$3
        comma=$comma0
      else
        ((++no_brace_length))
        ble/array#push stack "$comma0:$out0" # cancel pop
        out=$out'}'
      fi
    elif ((${#stack[@]})) && [[ $value == ','* ]]; then
      ((iopen=++index,no_brace_length=0))
      value=${value:1}
      out= comma=1
    else
      ((++index,++no_brace_length))
      out=$out${value::1}
      value=${value:1}
    fi
  done

  while ((${#stack[@]})); do
    ble/array#pop stack
    local out0=${ret#*:} comma0=${ret%%:*}
    out=$out0$out
  done

  ret=$out simple_ibrace=$iopen:$((${#out}-no_brace_length))
}

## @fn ble/syntax:bash/simple-word/reconstruct-incomplete-word word
##   word について不完全なブレース展開と不完全な引用符を閉じ、
##   更にブレース展開を実行して最後の単語を取得します。
##
##   @param[in] word
##     不完全な単語を指定します。
##
##   @var[out] ret
##     word に対して不完全なブレース展開と引用符を閉じ、ブレース展開した結果を返します。
##
##   @var[out] simple_flags
##     引用符 $"..." を閉じた時に simple_flags=I を設定します。
##     引用符 "..." を閉じた時に simple_flags=D を設定します。
##     引用符 $'...' を閉じた時に simple_flags=E を設定します。
##     引用符 '...' を閉じた時に simple_flags=S を設定します。
##     不完全な末端 \ があった時に simple_flags=B を設定します。
##
##   @var[out] simple_ibrace=ibrace:jbrace
##     ブレース展開の構造を破壊せずに変更できる最初の位置を返します。
##     ibrace には word 内の位置を返し、jbrace には ret 内の位置を返します。
##
##   @exit
##     ブレース展開及び引用符を閉じることによってシェルの完全な単語になる時に成功します。
##     それ以外の場合に失敗します。
##
function ble/syntax:bash/simple-word/reconstruct-incomplete-word {
  local word=$1
  ret= simple_flags= simple_ibrace=0:0

  [[ $word ]] || return 0

  if [[ $word =~ $_ble_syntax_bash_simple_rex_incomplete_word1 ]]; then
    ret=${word::${#BASH_REMATCH}}
    word=${word:${#BASH_REMATCH}}
    [[ $word ]] || return 0
  fi

  if [[ $word =~ $_ble_syntax_bash_simple_rex_incomplete_word2 ]]; then
    local out=$ret

    local m_brace=${BASH_REMATCH[1]}
    local m_quote=${word:${#m_brace}}

    if [[ $m_brace ]]; then
      ble/syntax:bash/simple-word/evaluate-last-brace-expansion "$m_brace"
      simple_ibrace=$((${#out}+${simple_ibrace%:*})):$((${#out}+${simple_ibrace#*:}))
      out=$out$ret
    fi

    if [[ $m_quote ]]; then
      case $m_quote in
      ('$"'*) out=$out$m_quote\" simple_flags=I ;;
      ('"'*)  out=$out$m_quote\" simple_flags=D ;;
      ("$'"*) out=$out$m_quote\' simple_flags=E ;;
      ("'"*)  out=$out$m_quote\' simple_flags=S ;;
      ('\')   simple_flags=B ;;
      (*) return 1 ;;
      esac
    fi

    ret=$out
    return 0
  fi

  return 1
}

## @fn ble/syntax:bash/simple-word/extract-parameter-names word
##   単純単語に含まれるパラメータ展開のパラメータ名を抽出します。
##   @var[in] word
##   @var[out] ret
function ble/syntax:bash/simple-word/extract-parameter-names {
  ret=()
  local letter=$_ble_syntax_bash_simple_rex_letter
  local bquot=$_ble_syntax_bash_simple_rex_bquot
  local squot=$_ble_syntax_bash_simple_rex_squot
  local dquot=$_ble_syntax_bash_simple_rex_dquot
  local param=$_ble_syntax_bash_simple_rex_param

  local value=$1
  local rex0='^('$letter'|'$bquot'|'$squot')+'
  local rex1='^('$dquot')'
  local rex2='^('$param')'
  while [[ $value ]]; do
    [[ $value =~ $rex0 ]] && value=${value:${#BASH_REMATCH}}
    if [[ $value =~ $rex1 ]]; then
      value=${value:${#BASH_REMATCH}}
      ble/syntax:bash/simple-word/extract-parameter-names/.process-dquot "$BASH_REMATCH"
    fi
    [[ $value =~ $rex2 ]] || break
    value=${value:${#BASH_REMATCH}}
    local var=${BASH_REMATCH[2]}${BASH_REMATCH[3]}
    [[ $var == [_a-zA-Z]* ]] && ble/array#push ret "$var"
  done
}
## @fn ble/syntax:bash/simple-word/extract-parameter-names/.process-dquot match
##   @var[in,out] ret
function ble/syntax:bash/simple-word/extract-parameter-names/.process-dquot {
  local value=$1
  if [[ $value == '$"'*'"' ]]; then
    value=${value:2:${#value}-3}
  elif [[ $value == '"'*'"' ]]; then
    value=${value:1:${#value}-2}
  else
    return 0
  fi

  local rex0='^([^'${_ble_syntax_bash_chars[CTX_QUOT]}']|\\.)+'
  local rex2='^('$param')'
  while [[ $value ]]; do
    [[ $value =~ $rex0 ]] && value=${value:${#BASH_REMATCH}}
    [[ $value =~ $rex2 ]] || break
    value=${value:${#BASH_REMATCH}}
    local var=${BASH_REMATCH[2]}${BASH_REMATCH[3]}
    [[ $var == [_a-zA-Z]* ]] && ble/array#push ret "$var"
  done
}

function ble/syntax:bash/simple-word/eval/.set-result {
  if [[ $__ble_word_limit ]] && (($#>__ble_word_limit)); then
    set -- "${@::__ble_word_limit}"
  fi
  __ble_ret=("$@")
}
function ble/syntax:bash/simple-word/eval/.print-result {
  if [[ $__ble_word_limit ]] && (($#>__ble_word_limit)); then
    set -- "${@::__ble_word_limit}"
  fi
  if (($#>=1000)) && [[ $OSTYPE != cygwin ]]; then
    # ファイル数が少ない場合は fork コストを避ける為に多少遅くても quote&eval
    # でデータを親シェルに転送する。Cygwin では mapfile/read が unbuffered で遅
    # いので、ファイル数が遅くても quote&eval を使う。

    if ((_ble_bash>=50200)); then
      printf '%s\0' "$@" >| "$__ble_simple_word_tmpfile"
      ble/util/print 'ble/util/readarray -d "" __ble_ret < "$__ble_simple_word_tmpfile"'
      return 0
    elif ((_ble_bash>=40000)); then
      ret=("$@")
      ble/util/writearray --nlfix ret >| "$__ble_simple_word_tmpfile"
      ble/util/print 'ble/util/readarray --nlfix __ble_ret < "$__ble_simple_word_tmpfile"'
      return 0
    fi
  fi

  local ret; ble/string#quote-words "$@"
  ble/util/print "__ble_ret=($ret)"
}
## @fn ble/syntax:bash/simple-word/eval/.eval-set
## @fn ble/syntax:bash/simple-word/eval/.eval-print
##   Evaluate the specified word and set or print the results.
##   @var[in] __ble_simple_word
##     This variable specifies the target word to evalaute.
##   @remarks #D2246: These functions are needed to evaluate the word in a
##     context with the proper positional parameters.  The evaluation of the
##     positional parameter expansions in $__ble_simple_word may cause
##     unexpected "failglob" if the positional parameters of the current
##     context is naively used.  We try to restore the positional parameters of
##     the top-level context and evaluate the word with these positional
##     parameters.
function ble/syntax:bash/simple-word/eval/.eval-set {
  if [[ ${_ble_edit_exec_lastparams[0]+set} ]]; then
    set -- "${_ble_edit_exec_lastparams[@]}"
  else
    set --
  fi
  local ext=0
  builtin eval -- "ble/syntax:bash/simple-word/eval/.set-result $__ble_simple_word" &>/dev/null; ext=$?
  builtin eval : # Note: bash 3.1/3.2 eval バグ対策 (#D1132)
  return "$ext"
}
function ble/syntax:bash/simple-word/eval/.eval-print {
  if [[ ${_ble_edit_exec_lastparams[0]+set} ]]; then
    set -- "${_ble_edit_exec_lastparams[@]}"
  else
    set --
  fi
  builtin eval -- "ble/syntax:bash/simple-word/eval/.print-result $__ble_simple_word"
}
## @fn ble/syntax:bash/simple-word/eval/.impl word opts
##   @param[in] word
##   @param[in,opt] opts
##   @var[out] __ble_ret
function ble/syntax:bash/simple-word/eval/.impl {
  local __ble_word=$1 __ble_opts=$2 __ble_flags=

  # グローバル変数の復元
  local -a ret=()
  ble/syntax:bash/simple-word/extract-parameter-names "$__ble_word"
  if ((${#ret[@]})); then
    local __ble_defs
    ble/util/assign __ble_defs 'ble/util/print-global-definitions --hidden-only "${ret[@]}"'
    builtin eval -- "$__ble_defs" &>/dev/null # 読み取り専用の変数のこともある
  fi

  local __ble_word_limit=
  ble/string#match ":$__ble_opts:" ':limit=([^:]*):' &&
    ((__ble_word_limit=BASH_REMATCH[1]))

  # glob パターンを含む可能性がある時の処理 (Note: is-simple-noglob の
  # 判定で変数を参照するので、グローバル変数の復元よりも後で処理する必
  # 要がある)
  if [[ $- != *f* ]] && ! ble/syntax:bash/simple-word/is-simple-noglob "$1"; then
    if [[ :$__ble_opts: == *:noglob:* ]]; then
      set -f
      __ble_flags=f
    elif ble/util/is-cygwin-slow-glob "$1"; then # Note: #D1168
      if shopt -q failglob &>/dev/null; then
        __ble_ret=()
        return 1
      elif shopt -q nullglob &>/dev/null; then
        __ble_ret=()
        return 0
      else
        # noglob で処理する
        set -f
        __ble_flags=f
      fi
    elif [[ :$__ble_opts: == *:stopcheck:* ]]; then
      ble/decode/has-input && return 148
      if ((_ble_bash>=40000)); then
        __ble_flags=s
      elif shopt -q globstar &>/dev/null; then
        # conditional-sync が使えない場合はせめて globstar だけでも撥ねる
        if builtin eval "[[ $__ble_word == *'**'* ]]"; then
          [[ :$__ble_opts: == *:timeout=*:* ]] && return 142
          return 148
        fi
      fi
    fi
  fi

  # Note: failglob 時に一致がないと実行されないので予め __ble_ret=() をする。
  #   また、エラーメッセージが生じるので /dev/null に繋ぐ。
  __ble_ret=()
  local __ble_simple_word=$__ble_word
  if [[ $__ble_flags == *s* ]]; then
    local __ble_sync_command=ble/syntax:bash/simple-word/eval/.eval-print
    local __ble_sync_opts=progressive-weight
    local __ble_sync_weight=$bleopt_syntax_eval_polling_interval

    # determine timeout
    local __ble_sync_timeout=$_ble_syntax_bash_simple_eval_timeout
    if [[ $_ble_syntax_bash_simple_eval_timeout_carry ]]; then
      __ble_sync_timeout=0
    elif local __ble_rex=':timeout=([^:]*):'; [[ :$__ble_opts: =~ $__ble_rex ]]; then
      __ble_sync_timeout=${BASH_REMATCH[1]}
    fi
    [[ $__ble_sync_timeout ]] &&
      __ble_sync_opts=$__ble_sync_opts:timeout=$((__ble_sync_timeout))

    local _ble_local_tmpfile; ble/util/assign/mktmp
    local __ble_simple_word_tmpfile=$_ble_local_tmpfile
    local __ble_script
    ble/util/assign __ble_script 'ble/util/conditional-sync "$__ble_sync_command" "" "$__ble_sync_weight" "$__ble_sync_opts"' &>/dev/null; local ext=$?
    builtin eval -- "$__ble_script"
    ble/util/assign/rmtmp
  else
    ble/syntax:bash/simple-word/eval/.eval-set; local ext=$?
  fi

  [[ $__ble_flags == *f* ]] && set +f
  return "$ext"
}

_ble_syntax_bash_simple_eval_hash=
## @fn ble/syntax:bash/simple-word/eval/.cache-clear
##   @var[in,out] _ble_syntax_bash_simple_eval
function ble/syntax:bash/simple-word/eval/.cache-clear {
  ble/gdict#clear _ble_syntax_bash_simple_eval
  ble/gdict#clear _ble_syntax_bash_simple_eval_full
}
## @fn ble/syntax:bash/simple-word/eval/.cache-update
##   @var[in,out] _ble_syntax_bash_simple_eval
##   @var[in,out] _ble_syntax_bash_simple_eval_hash
function ble/syntax:bash/simple-word/eval/.cache-update {
  local hash=$-:${BASHOPTS-}:$_ble_edit_lineno:$_ble_textarea_version:$PWD
  if [[ $hash != "$_ble_syntax_bash_simple_eval_hash" ]]; then
    _ble_syntax_bash_simple_eval_hash=$hash
    ble/syntax:bash/simple-word/eval/.cache-clear
  fi
}
## @fn ble/syntax:bash/simple-word/eval/.save word ext ret...
##   @var[in] ext
##   @var[in,out] _ble_syntax_bash_simple_eval
function ble/syntax:bash/simple-word/eval/.cache-save {
  ((ext==148||ext==142)) && return 0
  local ret; ble/string#quote-words "$3"
  ble/gdict#set _ble_syntax_bash_simple_eval "$1" "ext=$2 count=$(($#-2)) ret=$ret"
  local ret; ble/string#quote-words "${@:3}"
  ble/gdict#set _ble_syntax_bash_simple_eval_full "$1" "ext=$2 count=$(($#-2)) ret=($ret)"
}
## @fn ble/syntax:bash/simple-word/eval/.cache-load word opts
function ble/syntax:bash/simple-word/eval/.cache-load {
  ext= ret=
  if [[ :$2: == *:single:* ]]; then
    ble/gdict#get _ble_syntax_bash_simple_eval "$1" || return 1
  else
    ble/gdict#get _ble_syntax_bash_simple_eval_full "$1" || return 1
  fi
  builtin eval -- "$ret"
  return 0
}

## @fn ble/syntax:bash/simple-word/eval word opts
##   @param[in] word
##   @param[in,opt] opts
##     コロン区切りのオプション指定です。
##
##       noglob
##         パス名展開を抑制します。
##
##     以下は (成功時の) 評価結果に影響を与えないオプションです。
##
##       single
##         最初の展開結果のみを ret に設定します。
##       limit=COUNT
##         評価後の単語数を COUNT 以下に制限します。これは count によって設定さ
##         れる展開結果の単語数にも影響を与えます。
##       count
##         変数 count に展開結果の単語数を返します。
##       cached
##         展開結果をキャッシュします。
##
##     以下はパス名展開の起こる可能性にある単語に対して有効です。
##
##       stopcheck
##         ユーザー入力があった場合に中断します。
##       timeout=NUM
##         stopcheck を指定している時に有効です。timeout を指定します。
##       retry-noglob-on-timeout
##         timeout した時に noglob で改めて展開を試行します。
##       timeout-carry
##         timeout が発生した場合に後続の eval にタイムアウトを伝播します。
##
##   @var[in] _ble_syntax_bash_simple_eval_timeout
##     パス名展開のタイムアウトの既定値を指定します。空文字列が指定さ
##     れている時、既定でタイムアウトは起こりません。
##   @var[in,out] _ble_syntax_bash_simple_eval_timeout_carry
##     この値が設定されている時、パス名展開に対して強制的にタイムアウトが起こり
##     ます。opts に timeout-carry が指定されている時に値が設定されます。
##
##   @arr[out] ret
##     展開結果を返します。複数の単語に評価される場合にはそれを全て返します。
##     opts に single が指定されている時、最初の展開結果のみを返します。
##   @var[out] count
##     opts に count が指定されている時に展開結果の数を返します。
##
##   @exit
##     ユーザー入力により中断した場合は 148 を返します。timeout を起こ
##     した場合 142 を返します。例えば failglob など、その他の理由でパ
##     ス名展開に失敗した時 0 以外の終了ステータスを返します。
##
_ble_syntax_bash_simple_eval_timeout=
_ble_syntax_bash_simple_eval_timeout_carry=
function ble/syntax:bash/simple-word/eval {
  [[ :$2: != *:count:* ]] && local count
  if [[ :$2: == *:cached:* && :$2: != *:noglob:* ]]; then
    ble/syntax:bash/simple-word/eval/.cache-update
    local ext; ble/syntax:bash/simple-word/eval/.cache-load "$1" "$2" && return "$ext"
  fi

  local __ble_ret
  ble/syntax:bash/simple-word/eval/.impl "$1" "$2"; local ext=$?
  ret=("${__ble_ret[@]}")
  count=${#ret[@]}

  if [[ :$2: == *:cached:* && :$2: != *:noglob:* ]]; then
    ble/syntax:bash/simple-word/eval/.cache-save "$1" "$ext" "${ret[@]}"
  fi
  if ((ext==142)); then
    [[ :$2: == *:timeout-carry:* ]] &&
      _ble_syntax_bash_simple_eval_timeout_carry=1
    if [[ :$2: == *:retry-noglob-on-timeout:* ]]; then
      ble/syntax:bash/simple-word/eval "$1" "$2:noglob"
      return "$?"
    fi
  fi
  return "$ext"
}

## @fn ble/syntax:bash/simple-word/eval word [opts]
##   Evaluate the specified word only when the word is safe and take the first
##   word when the word is expanded to multiple words.
##
##   @param[in,opt] opts
##     A colon-separated list of options.  In addition to the values supported
##     by ble/syntax:bash/simple-word/eval, the following values are available:
##
##     @opt reconstruct
##       Try to reconstruct the full word using
##       ble/syntax:bash/simple-word/reconstruct-incomplete-word when there is
##       no closing quote corresponding to an opening one in the word.
##
##     @opt nonull
##       Fails when no word is generated.  This may happen with e.g. an
##       expansion an empty array "${arr[@]}" or unmatching glob pattern with
##       nullglob.
##
##     The other options are processed by "ble/syntax:bash/simple-word/eval",
##     but if "limit=COUNT" is not specified, the option "limit=1" is added to
##     suppress the number of generated words.
##
##   @arr[out] ret
##
function ble/syntax:bash/simple-word/safe-eval {
  local __ble_opts=$2
  if [[ :$__ble_opts: == *:reconstruct:* ]]; then
    local simple_flags simple_ibrace
    ble/syntax:bash/simple-word/reconstruct-incomplete-word "$1" || return 1
    ble/util/unlocal simple_flags simple_ibrace
  else
    ble/syntax:bash/simple-word/is-simple "$1" || return 1
  fi
  [[ :$__ble_opts: == *:limit=*:* ]] ||
    __ble_opts=$__ble_opts:limit=1

  ble/syntax:bash/simple-word/eval "$1" "$__ble_opts" &&
    { [[ :$__ble_opts: != *:nonull:* ]] || ((${#ret[@]})); }
}

## @fn ble/syntax:bash/simple-word/get-rex_element sep
##   指定した分割文字 (sep) で区切られた単純単語片に一致する正規表現を構築します。
##   @var[out] rex_element
function ble/syntax:bash/simple-word/get-rex_element {
  local sep=$1
  local param=$_ble_syntax_bash_simple_rex_param
  local bquot=$_ble_syntax_bash_simple_rex_bquot
  local squot=$_ble_syntax_bash_simple_rex_squot
  local dquot=$_ble_syntax_bash_simple_rex_dquot
  local letter1='\[[!^]|[^'$sep$_ble_syntax_bashc_simple']'
  rex_element='('$bquot'|'$squot'|'$dquot'|'$param'|'$letter1')+'
}
## @fn ble/syntax:bash/simple-word/evaluate-path-spec path_spec [sep] [opts]
##   @param[in] path_spec
##   @param[in,opt] sep (default: '/:=')
##   @param[in,opt] opts
##     noglob
##     stopcheck
##     timeout=*
##     timeout-carry
##     cached
##       これらは simple-word/eval に対するオプションです。
##
##     notilde
##       評価時にチルダ展開を抑制します。
##     after-sep
##       分割位置を分割子の前ではなく後に変更します。
##     fixlen=LEN
##       分割の対象とならない固定接頭辞の長さを指定します。
##
##   @arr[out] spec
##   @arr[out] path
##   @arr[out] ret
##     path_spec 全体を評価した時の結果を返します。
##     パス名展開によって複数のパスに展開された場合に、
##     全ての展開結果を含む配列になります。
##
##   指定した path_spec を sep に含まれる文字で区切ってルートから末端まで順に評価します。
##   各階層までの評価の対象を spec に評価の結果を path に追加します。
##   例えば path_spec='~/a/b' の時、
##     spec=(~ ~/a ~/a/b)
##     path=(/home/user /home/user/a /home/user/a/b)
##   という結果が得られます。
##
function ble/syntax:bash/simple-word/evaluate-path-spec {
  local word=$1 sep=${2:-'/:='} opts=$3
  ret=() spec=() path=()
  [[ $word ]] || return 0

  # read options
  local eval_opts=$opts notilde=
  [[ :$opts: == *:notilde:* ]] && notilde=\'\' # チルダ展開の抑制
  local fixlen
  ble/opts#extract-last-optarg "$opts" fixlen 0

  # compose regular expressions
  local rex_element; ble/syntax:bash/simple-word/get-rex_element "$sep"
  local rex='^['$sep']?'$rex_element'|^['$sep']'
  [[ :$opts: == *:after-sep:* ]] &&
    local rex='^'$rex_element'['$sep']?|^['$sep']'

  local tail=${word:fixlen} s=${word::fixlen} p= ext=0
  while [[ $tail =~ $rex ]]; do
    local rematch=$BASH_REMATCH
    s=$s$rematch
    ble/syntax:bash/simple-word/eval "$notilde$s" "$eval_opts"; ext=$?
    ((ext==148||ext==142)) && return "$ext"
    p=$ret
    tail=${tail:${#rematch}}
    ble/array#push spec "$s"
    ble/array#push path "$p"
  done
  [[ $tail ]] && return 1
  ((ext)) && return "$ext"
  return 0
}

## @fn ble/syntax:bash/simple-word/detect-separated-path word [sep] [opts]
##   指定した単語が単一のパス名か sep 区切りのパス名刺低下の判定を行います。
##   @param[in] word
##   @param[in,opt] sep
##   @param[in] opts
##     noglob
##     stopcheck
##     timeout=*
##     timeout-carry
##     cached
##     url
##     notilde
##   @var[out] ret
##     有効な区切り文字の集合を返します。
function ble/syntax:bash/simple-word/detect-separated-path {
  local word=$1 sep=${2:-':'} opts=$3
  [[ $word ]] || return 1

  local rex_url='^[a-z]+://'
  [[ :$opts: == *:url:* ]] && ble/string#match-safe "$word" "$rex_url" && return 1

  # read eval options
  local eval_opts=$opts notilde=
  [[ :$opts: == *:notilde:* ]] && notilde=\'\' # チルダ展開の抑制

  # compose regular expressions
  local rex_element
  ble/syntax:bash/simple-word/get-rex_element /
  local rex='^'$rex_element'/?|^/'

  local tail=$word head=
  while [[ $tail =~ $rex ]]; do
    local rematch=$BASH_REMATCH
    ble/syntax:bash/simple-word/locate-filename/.exists "$notilde$head$rematch"; local ext=$?
    ((ext==148)) && return 148
    ((ext==0)) || break
    head=$head$rematch
    tail=${tail:${#rematch}}
  done

  ret=
  local i
  for ((i=0;i<${#sep};i++)); do
    local sep1=${sep:i:1}
    ble/syntax:bash/simple-word/get-rex_element "$sep1"
    local rex_nocolon='^('$rex_element')?$'
    local rex_hascolon='^('$rex_element')?['$sep1']'
    [[ $head =~ $rex_nocolon && $tail =~ $rex_hascolon ]] && ret=$ret$sep1
  done
  [[ $ret ]]
}

## @fn ble/syntax:bash/simple-word/locate-filename/.exists word opts
##   @param[in] word
##   @param[in] opts
##   @var[in] eval_opts
##   @var[in] rex_url
function ble/syntax:bash/simple-word/locate-filename/.exists {
  local word=$1 ret
  ble/syntax:bash/simple-word/eval "$word" "$eval_opts" || return "$?"
  local path=$ret
  # Note: #D1168 Cygwin では // で始まるパスの判定は遅いので直接文字列で判定する
  if [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && $path == //* ]]; then
    [[ $path == // ]]
  else
    [[ -e $path || -h $path ]]
  fi || [[ :$opts: == *:url:* ]] && ble/string#match-safe "$path" "$rex_url"
}
## @fn ble/syntax:bash/simple-word/locate-filename word [sep] [opts]
##   @param[in] word
##   @param[in] sep
##   @param[in] opts
##     exists
##       存在する有効なファイル名のみを抽出します。
##     greedy
##       : を区切りと見做さずに結合したパスが有効であれば、その結合パスを採用します。
##     url
##       [a-z]+:// で始まるパスを無条件に有効なパスと判定します。
##     stopcheck
##       時間のかかる可能性のあるパス名展開をユーザ入力により中断します。
##     timeout=*
##       stopcheck に際して timeout を指定します。
##     timeout-carry
##       タイムアウトを後続のパス名展開に伝播させます。
##     cached
##       展開内容をキャッシュします。
##
##   @arr[out] ret
##     偶数個の要素を含みます。偶数 index (0, 2, 4, ...) が範囲の開始で、
##     奇数 index (1, 3, 5, ...) が範囲の終了です。
##
function ble/syntax:bash/simple-word/locate-filename {
  local word=$1 sep=${2:-':='} opts=$3
  ret=0
  [[ $word ]] || return 0

  # prepare evaluator
  local eval_opts=$opts

  # compose regular expressions
  local rex_element; ble/syntax:bash/simple-word/get-rex_element "$sep"
  local rex='^'$rex_element'['$sep']|^['$sep']'
  local rex_url='^[a-z]+://'

  local -a seppos=()
  local tail=$word p=0
  while [[ $tail =~ $rex ]]; do
    ((p+=${#BASH_REMATCH}))
    tail=${tail:${#BASH_REMATCH}}
    ble/array#push seppos "$((p-1))"
  done
  ble/syntax:bash/simple-word/is-simple "$tail" &&
    ble/array#push seppos "$((p+${#tail}))"

  local -a out=()
  for ((i=0;i<${#seppos[@]};i++)); do
    local j0=$i
    [[ :$opts: == *:greedy:* ]] && j0=${#seppos[@]}-1
    local j
    for ((j=j0;j>=i;j--)); do
      local f1=0 f2=${seppos[j]}
      ((i)) && ((f1=seppos[i-1]+1))

      if ((j>i)); then
        # もし繋げて存在するファイル名になるのであればそれを採用
        ble/syntax:bash/simple-word/locate-filename/.exists "${word:f1:f2-f1}" "$opts"; local ext=$?
        ((ext==148)) && return 148
        if ((ext==0)); then
          ble/array#push out "$f1" "$f2"
          ((i=j))
        fi
      else
        # ファイルが見つからなかった場合は単一区間を登録
        if [[ :$opts: != *:exists:* ]] ||
             { ble/syntax:bash/simple-word/locate-filename/.exists "${word:f1:f2-f1}" "$opts"
               local ext=$?; ((ext==148)) && return 148; ((ext==0)); }; then
          ble/array#push out "$f1" "$f2"
        fi
      fi
    done
  done

  ret=("${out[@]}")
  return 0
}

## @fn ble/syntax:bash/simple-word#break-word word sep
##   単語を指定した分割子で分割します。評価は行いません。
##   progcomp で単語を COMP_WORDBREAKS で分割するのに使います。
##   例えば a==b:c\=d に対して ret=(a == b : c=d) という結果を生成します。
##
##   @param[in] word
##     前提: simple-word/is-simple である必要があります。
##
##   @arr[out] ret
##     単語片を含む配列を返します。
##     偶数番目の要素は分割子以外の文字列です。
##     奇数番目の要素は分割子からなる文字列です。
##
function ble/syntax:bash/simple-word#break-word {
  local word=$1 sep=${2:-':='}
  if [[ ! $word ]]; then
    ret=('')
    return 0
  fi

  sep=${sep//[\"\'\$\`]}

  # compose regular expressions
  local rex_element; ble/syntax:bash/simple-word/get-rex_element "$sep"
  local rex='^('$rex_element')?['$sep']+'

  local -a out=()
  local tail=$word p=0
  while [[ $tail =~ $rex ]]; do
    local rematch1=${BASH_REMATCH[1]}
    ble/array#push out "$rematch1"
    ble/array#push out "${BASH_REMATCH:${#rematch1}}"
    tail=${tail:${#BASH_REMATCH}}
  done
  ble/array#push out "$tail"
  ret=("${out[@]}")
  return 0
}

#------------------------------------------------------------------------------

function ble/syntax:bash/initialize-ctx {
  ctx=$CTX_CMDX # CTX_CMDX が ble/syntax:bash の最初の文脈
}

## @fn ble/syntax:bash/initialize-vars
##   @var[in,out] _ble_syntax_bash_histc12
##   @var[in,out] _ble_syntax_bash_histstop
function ble/syntax:bash/initialize-vars {
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

  if ble/syntax:bash/cclass/update; then
    ble/syntax:bash/simple-word/update
  fi

  local histstop=$' \t\n='
  shopt -q extglob && histstop="$histstop("
  _ble_syntax_bash_histstop=$histstop
}


#------------------------------------------------------------------------------
# 共通の字句の一致判定

function ble/variable#load-user-state/.print-global-state {
  # This function is a callback for "ble/util/for-global-variables"
  local __ble_set= __ble_val= __ble_att=
  if [[ :$2: == *:unset:* ]]; then
    # This branch is selected when the global variable is hidden by a local
    # readonly variable and its state cannot be accesed.  In this case, so that
    # the default variable highlighting is chosen, we pretend that a scalar
    # variable is set to be a non-empty value.
    __ble_set=unknown
    __ble_val=unknown
    __ble_att=
  else
    __ble_set=${!1+set}
    __ble_val=${!1-}
    ble/variable#get-attr -v __ble_att "$1"

    # Note: We remove the readonly attribute "r" because
    # "ble/util/for-global-variables" uses the readonly attribute to access the
    # global variable so we cannot correctly test the readonly attribute.
    # Anyway, since we know that the global variable is hidden by a local
    # variable, it is natural to consider the global variable is not readonly
    # because a global readonly variable cannot be hidden by a local variable.
    # An exceptional case is the case where the global variable is made
    # readonly using "declare -gr" after it is hidden by a local variable.
    __ble_att=${__ble_att//r}
  fi
  declare -p __ble_set __ble_val __ble_att
}

## @fn ble/variable#load-user-state
##   @var[out] __ble_var_set __ble_var_val __ble_var_att
function ble/variable#load-user-state {
  __ble_var_set= __ble_var_val= __ble_var_att=
  [[ $1 == __ble_* || $1 == _ble_local_* ]] && return 0
  ble/function#try ble/variable#load-user-state/variable:"$1" && return 0

  # special parameters
  if [[ $1 == '?' ]]; then
    __ble_var_set=set
    __ble_var_val=$_ble_edit_exec_lastexit
    __ble_var_att=
    return 0
  elif ble/string#match "$1" '^[1-9][0-9]*$'; then
    # positional parameters
    local __ble_name=$1
    if [[ ${_ble_edit_exec_lastparams[0]+set} ]]; then
      set -- "${_ble_edit_exec_lastparams[@]}"
    else
      set --
    fi
    __ble_var_set=${!__ble_name+set}
    __ble_var_val=${!__ble_name-}
    __ble_var_att=
    return 0
  fi

  # Extract global state. When we support this, we should also consider it in
  # the custom loader ble/variable#load-user-state/variable:"$1".
  if [[ :$2: == *:global:* ]] && ! ble/variable#is-global "$1"; then
    local _ble_highlight_vartype_name=$1
    local __ble_var_state
    ble/util/assign __ble_var_state 'ble/util/for-global-variables ble/variable#load-user-state/.print-global-state "" "$_ble_highlight_vartype_name"'
    if [[ $__ble_var_state ]]; then
      local __ble_set __ble_val __ble_att
      builtin eval -- "$__ble_var_state"
      __ble_var_set=$__ble_set
      __ble_var_val=$__ble_val
      __ble_var_att=$__ble_att
      return 0
    fi
  fi

  __ble_var_set=${!1+set}
  __ble_var_val=${!1-}
  ble/variable#get-attr -v __ble_var_att "$1"
}

## @fn ble/syntax/highlight/vartype varname [opts [tail]]
##   変数の種類・状態に応じた属性値を決定します。
##
##   @param[in] varname
##     判定対象の変数名を指定します。
##   @param[in,opt] opts
##     コロン区切りのオプションを指定します。
##
##     readvar ... ユーザー文脈で "set -u" が指定されていてかつ存在しない変数に
##         対してエラー着色を適用します。
##
##     global ... グローバル変数の状態を参照します。
##
##     no-readonly ... readonly 状態を無視します。
##
##   @param[in,opt] tail
##     ${var...} 形式の内部を解析している時に変数名に続く文字列を指定します。
##
##   @var[out] ret
##     属性値を返します。
##
##   @var[out,opt] lookahead
##     tail が指定された時にのみ設定されます。属性値を決定する際に参照した tail
##     内の先読み文字数を返します。
##
function ble/syntax/highlight/vartype {
  ret=$ATTR_VAR
  [[ $bleopt_highlight_variable ]] || return 0

  local __ble_name=$1 __ble_opts=${2-} __ble_tail=${3-}

  local __ble_var_set __ble_var_val __ble_var_att
  ble/variable#load-user-state "$__ble_name" "$__ble_opts"

  if [[ $__ble_var_set || $__ble_var_att == *[aA]* ]]; then
    if [[ $__ble_var_val && :$__ble_opts: == *:expr:* ]] && ! ble/string#match "$__ble_var_val" '^-?[0-9]+(#[_a-zA-Z0-9@]*)?$'; then
      ret=$ATTR_VAR_EXPR
    elif [[ $__ble_var_set && $__ble_var_att == *x* ]]; then
      # Note: 配列の場合には第0要素が設定されている時のみ。
      ret=$ATTR_VAR_EXPORT
    elif [[ $__ble_var_att == *a* ]]; then
      ret=$ATTR_VAR_ARRAY
    elif [[ $__ble_var_att == *A* ]]; then
      ret=$ATTR_VAR_HASH
    elif [[ $__ble_var_att == *r* ]]; then
      ret=$ATTR_VAR_READONLY
    elif [[ $__ble_var_att == *i* ]]; then
      ret=$ATTR_VAR_NUMBER
    elif [[ $__ble_var_att == *[luc]* ]]; then
      ret=$ATTR_VAR_TRANSFORM
    elif [[ ! $__ble_var_val ]]; then
      [[ $__ble_tail == :* ]] && lookahead=2
      if [[ $__ble_tail == ':?'* ]]; then
        ret=$ATTR_ERR
      else
        ret=$ATTR_VAR_EMPTY
      fi
    else
      ret=$ATTR_VAR
    fi
  else
    if [[ :$__ble_opts: == *:newvar:* ]]; then
      # assignments var=, var+=
      ret=$ATTR_VAR_NEW
      return 0
    elif
      [[ $__ble_tail == :* ]] && lookahead=2
      [[ $__ble_tail == ':?'* || $__ble_tail == '?'* ]]
    then
      ret=$ATTR_ERR
      return 0
    fi

    # set -u のチェック
    if [[ :$__ble_opts: == *:readvar:* && $_ble_bash_set == *u* ]]; then
      if [[ ! $__ble_tail ]] || {
           [[ $__ble_tail == :* ]] && lookahead=2
           ! ble/string#match "$__ble_tail" '^:?[-+?=]'; }
      then
        ret=$ATTR_ERR
        return 0
      fi
    fi

    ret=$ATTR_VAR_UNSET
  fi
  return 0
}

function ble/syntax:bash/check-plain-with-escape {
  local rex='^('$1'|\\.)' is_quote=$2
  [[ $tail =~ $rex ]] || return 1
  if [[ $BASH_REMATCH == '\'? &&
          ( ! $is_quote || $BASH_REMATCH == '\'[$'\\`$\n"'] ) ]]; then
    ((_ble_syntax_attr[i]=ATTR_QESC))
  else
    ((_ble_syntax_attr[i]=ctx))
  fi
  ((i+=${#BASH_REMATCH}))
  return 0
}

function ble/syntax:bash/check-dollar {
  [[ $tail == '$'* ]] || return 1

  local rex
  if [[ $tail == '${'* ]]; then
    # Note: パラメータ展開の中で許される物:
    #   決まったパターン + 数式や文字列に途中で切り替わる事も。
    # Note: 初めに文字数 ${#param} の形式を試す (失敗するとしても lookahead は設定する)。
    #   その次に ${param...} 及び ${!param...} の形式を試す。
    #   これにより ${#...} の # が文字数か或いは $# か判定する。
    local rex1='^(\$\{#)([-*@#?$!0]\}?|[1-9][0-9]*\}?|[_a-zA-Z][_a-zA-Z0-9]*[[}]?)'
    local rex2='^(\$\{!?)([-*@#?$!0]|[1-9][0-9]*|[_a-zA-Z][_a-zA-Z0-9]*\[?)'
    if
      [[ $tail =~ $rex1 ]] && {
        [[ ${BASH_REMATCH[2]} == *['[}'] || $BASH_REMATCH == "$tail" ]] ||
          { ble/syntax/parse/set-lookahead "$((${#BASH_REMATCH}+1))"; false; } } ||
        [[ $tail =~ $rex2 ]]
    then
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
      local varname=${rematch2%['[}']}

      local ntype='${'
      if ((ctx==CTX_QUOT)); then
        ntype='"${'
      elif ((ctx==CTX_PWORD||ctx==CTX_PWORDE||ctx==CTX_PWORDR||ctx==CTX_EXPR)); then
        local ntype2; ble/syntax/parse/nest-type -v ntype2
        [[ $ntype2 == '"${' ]] && ntype='"${'
      fi

      local ret lookahead= tail2=${tail:${#rematch1}+${#varname}}
      ble/syntax/highlight/vartype "$varname" readvar:global "$tail2"; local attr=$ret

      ble/syntax/parse/nest-push "$CTX_PARAM" "$ntype"
      ((_ble_syntax_attr[i]=ctx,
        i+=${#rematch1},
        _ble_syntax_attr[i]=attr,
        i+=${#varname}))
      [[ $lookahead ]] && ble/syntax/parse/set-lookahead "$lookahead"

      if rex='^\$\{![_a-zA-Z][_a-zA-Z0-9]*[*@]\}?'; [[ $tail =~ $rex ]]; then
        ble/syntax/parse/set-lookahead 2
        if [[ $BASH_REMATCH == *'}' ]]; then
          # ${!head<@>} の時は末尾の @* を個別に読み取る。
          ((i++,ctx=CTX_PWORDE))
        fi
      elif [[ $rematch2 == *'[' ]]; then
        ble/syntax/parse/nest-push "$CTX_EXPR" 'v['
        ((_ble_syntax_attr[i++]=CTX_EXPR))
      fi
      return 0
    elif ((_ble_bash>=50300)) && [[ $tail == '${'[$' \t\n|']* ]]; then
      ((_ble_syntax_attr[i]=CTX_PARAM))
      ble/syntax/parse/nest-push "$CTX_CMDX" 'cmdsub_nofork'
      ((i+=2))
      [[ $tail == '${|'* ]] && ((i++))
      return 0
    else
      ((_ble_syntax_attr[i]=ATTR_ERR,i+=2))
      return 0
    fi
  elif [[ $tail == '$(('* ]]; then
    ((_ble_syntax_attr[i]=CTX_PARAM))
    ble/syntax/parse/nest-push "$CTX_EXPR" '$(('
    ((i+=3))
    return 0
  elif [[ $tail == '$['* ]]; then
    ((_ble_syntax_attr[i]=CTX_PARAM))
    ble/syntax/parse/nest-push "$CTX_EXPR" '$['
    ((i+=2))
    return 0
  elif [[ $tail == '$('* ]]; then
    ((_ble_syntax_attr[i]=CTX_PARAM))
    ble/syntax/parse/nest-push "$CTX_CMDX" '$('
    ((i+=2))
    return 0
  elif rex='^\$([-*@#?$!0_]|[1-9]|[_a-zA-Z][_a-zA-Z0-9]*)' && [[ $tail =~ $rex ]]; then
    local rematch=$BASH_REMATCH rematch1=${BASH_REMATCH[1]}
    ((_ble_syntax_attr[i++]=CTX_PARAM))

    if ((_ble_bash<40200)) && local tail=${tail:1} &&
         ble/syntax:bash/starts-with-histchars && ble/syntax:bash/check-history-expansion; then
      # bash-4.1 以下では $!" や $!a 等が履歴展開の対象になる。
      return 0
    else
      local ret; ble/syntax/highlight/vartype "$rematch1" readvar:global
      ((_ble_syntax_attr[i]=ret,i+=${#rematch}-1))
      return 0
    fi
  else
    # if dollar doesn't match any patterns it is treated as a normal character
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi
}

function ble/syntax:bash/check-quotes {
  local rex aqdel=$ATTR_QDEL aquot=$CTX_QUOT

  # 字句的に解釈されるが除去はされない場合
  if ((ctx==CTX_EXPR)) && [[ $tail != \`* ]]; then
    local ntype
    ble/syntax/parse/nest-type
    case $ntype in
    ('${')
      # ${var:...} の中では如何なる quote も除去されない (字句的には解釈される)。
      # 除去されない quote は算術式エラーである。Note: bash >= 5.2 では "..."
      # と $"..." は許される。
      if ((_ble_bash<50200)) || [[ $tail == \'* || $tail == \$\'* ]]; then
        ((aqdel=ATTR_ERR,aquot=CTX_EXPR))
      fi ;;
    ('$['|'$(('|expr-paren-ax)
      if [[ $tail == \'* ]] || ((_ble_bash<40400)); then
        ((aqdel=ATTR_ERR,aquot=CTX_EXPR))
      fi ;;
    ('(('|expr-paren|expr-brack)
      if [[ $tail == \'* ]] && ((_ble_bash>=50100)); then
        ((aqdel=ATTR_ERR,aquot=CTX_EXPR))
      fi ;;
    ('a['|'v['|expr-paren-ai|expr-brack-ai)
      if [[ $tail == \'* ]] && ((_ble_bash>=40400)); then
        ((aqdel=ATTR_ERR,aquot=CTX_EXPR))
      fi ;;
    ('"${')
      if ! { [[ $tail == '$'[\'\"]* ]] && shopt -q extquote; }; then
        # "${var:...}" の中では 〈extquote が設定されている時の $'' $""〉 を例
        # 外としてquote は除去されない (字句的には解釈される)。
        ((aqdel=ATTR_ERR,aquot=CTX_EXPR))
      fi ;;
    # ('d['|expr-paren-di|expr-brack-di) ;; # nop
    esac
  elif ((ctx==CTX_PWORD||ctx==CTX_PWORDE||ctx==CTX_PWORDR)); then
    # "${var ～}" の中では $'' $"" は ! shopt -q extquote の時除去されない。
    if [[ $tail == '$'[\'\"]* ]] && ! shopt -q extquote; then
      local ntype
      ble/syntax/parse/nest-type
      if [[ $ntype == '"${' ]]; then
        ((aqdel=ctx,aquot=ctx))
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
    if rex='^(\$?")([^'"${_ble_syntax_bash_chars[CTX_QUOT]}"']*)("?)' && [[ $tail =~ $rex ]]; then
      local rematch1=${BASH_REMATCH[1]} # for bash-3.1 ${#arr[n]} bug
      if [[ ${BASH_REMATCH[3]} ]]; then
        # 終端まで行った場合
        ((_ble_syntax_attr[i]=aqdel,
          _ble_syntax_attr[i+${#rematch1}]=aquot,
          i+=${#BASH_REMATCH},
          _ble_syntax_attr[i-1]=aqdel))
      else
        # 中に構造がある場合
        ble/syntax/parse/nest-push "$CTX_QUOT"
        if (((ctx==CTX_PWORD||ctx==CTX_PWORDE||ctx==CTX_PWORDR)&&aqdel!=ATTR_QDEL)); then
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
    elif rex='^\$'\''(([^'\''\]|\\(.|$))*)('\''?)' && [[ $tail =~ $rex ]]; then
      ((_ble_syntax_attr[i]=aqdel,i+=2))
      local t=${BASH_REMATCH[1]} rematch4=${BASH_REMATCH[4]}

      local rex='\\[abefnrtvE"'\''\?]|\\[0-7]{1,3}|\\c.|\\x[0-9a-fA-F]{1,2}'
      ((_ble_bash>=40200)) && rex=$rex'|\\u[0-9a-fA-F]{1,4}|\\U[0-9a-fA-F]{1,8}'
      local rex='^([^'\''\]*)('$rex'|(\\.))'
      while [[ $t =~ $rex ]]; do
        local m1=${BASH_REMATCH[1]} m2=${BASH_REMATCH[2]}
        [[ $m1 ]] && ((_ble_syntax_attr[i]=aquot,i+=${#m1}))
        if [[ ${BASH_REMATCH[3]} ]]; then
          ((_ble_syntax_attr[i]=aquot))
        else
          ((_ble_syntax_attr[i]=ATTR_QESC))
        fi
        ((i+=${#m2}))
        t=${t:${#BASH_REMATCH}}
      done
      [[ $t ]] && ((_ble_syntax_attr[i]=aquot,i+=${#t}))
      if [[ $rematch4 ]]; then
        ((_ble_syntax_attr[i++]=aqdel))
      else
        ((_ble_syntax_attr[i-1]=ATTR_ERR))
      fi
      return 0
    fi
  fi

  return 1
}

function ble/syntax:bash/check-process-subst {
  # プロセス置換
  if [[ $tail == ['<>']'('* ]]; then
    ble/syntax/parse/nest-push "$CTX_CMDX" '('
    ((_ble_syntax_attr[i]=ATTR_DEL,i+=2))
    return 0
  fi

  return 1
}

function ble/syntax:bash/check-comment {
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

function ble/syntax:bash/check-glob {
  [[ $tail == ['[?*@+!()|']* ]] || return 1

  local ntype= force_attr=
  if ((ctx==CTX_VRHS||ctx==CTX_ARGVR||ctx==CTX_ARGER||ctx==CTX_VALR||ctx==CTX_RDRS)); then
    force_attr=$ctx
    ntype="glob_attr=$force_attr"
  elif ((ctx==CTX_FARGX1||ctx==CTX_FARGI1)); then
    # for [xxx] / for a[xxx] の場合
    force_attr=$ATTR_ERR
    ntype="glob_attr=$force_attr"
  elif ((ctx==CTX_PWORD||ctx==CTX_PWORDE||ctx==CTX_PWORDR)); then
    ntype="glob_ctx=$ctx"
  elif ((ctx==CTX_PATN||ctx==CTX_BRAX)); then
    ble/syntax/parse/nest-type
    local exit_attr=
    if [[ $ntype == glob_attr=* ]]; then
      force_attr=${ntype#*=}
      exit_attr=$force_attr
    elif ((ctx==CTX_BRAX)); then
      force_attr=$ctx
      ntype="glob_attr=$force_attr"
    elif ((ctx==CTX_PATN)); then
      ((exit_attr=_ble_syntax_attr[inest]))

      # glob_ctx=* の時は ntype は子に継承する
      [[ $ntype != glob_ctx=* ]] && ntype=
    else
      ntype=
    fi
  elif [[ $1 == assign ]]; then
    # $1 == assign の時、arr[... の "[" の位置で呼び出されたことを意味する。
    ntype='a['
  fi

  if [[ $tail == ['?*@+!']'('* ]] && shopt -q extglob; then
    ble/syntax/parse/nest-push "$CTX_PATN" "$ntype"
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

    ble/syntax/parse/nest-push "$CTX_BRAX" "$ntype"
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
      ble/syntax/parse/nest-push "$CTX_PATN" "$ntype"
      ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
      return 0
    elif [[ $tail == ')'* ]]; then
      if ((ctx==CTX_PATN)); then
        ((_ble_syntax_attr[i++]=exit_attr))
        ble/syntax/parse/nest-pop
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
function ble/syntax:bash/check-history-expansion/.initialize {
  local spaces=$_ble_term_IFS nl=$'\n'
  local rex_event='-?[0-9]+|[!#]|[^-$^*%:'$spaces'=?!#;&|<>()]+|\?[^?'$nl']*\??'
  _ble_syntax_bash_histexpand_RexEventDef='^!('$rex_event')'

  local rex_word1='([0-9]+|[$%^])'
  local rex_wordsA=':('$rex_word1'?-'$rex_word1'?|\*|'$rex_word1'\*?)'
  local rex_wordsB='([$%^]?-'$rex_word1'?|\*|[$^%][*-]?)'
  _ble_syntax_bash_histexpand_RexWord='('$rex_wordsA'|'$rex_wordsB')?'

  # ※本当は /s(.)([^\]|\\.)*?\1([^\]|\\.)*?\1/ 等としたいが *? は ERE にない。
  #   仕方がないので ble/syntax:bash/check-history-expansion/.check-modifiers
  #   にて繰り返し正規表現を適用して s?..?..? を読み取る。
  local rex_modifier=':[htrepqx]|:[gGa]?&|:[gGa]?s(/([^\/]|\\.)*){0,2}(/|$)'
  _ble_syntax_bash_histexpand_RexMods='('$rex_modifier')*'

  _ble_syntax_bash_histexpand_RexQuicksubDef='\^([^^\]|\\.)*\^([^^\]|\\.)*\^'

  # for histchars
  _ble_syntax_bash_histexpand_RexQuicksubFmt='@A([^@C\]|\\.)*@A([^@C\]|\\.)*@A'
  _ble_syntax_bash_histexpand_RexEventFmt='^@A('$rex_event'|@A)'
}
ble/syntax:bash/check-history-expansion/.initialize

## @fn ble/syntax:bash/check-history-expansion/.initialize-event
##   @var[out] rex_event
function ble/syntax:bash/check-history-expansion/.initialize-event {
  local histc1=${_ble_syntax_bash_histc12::1}
  if [[ $histc1 == '!' ]]; then
    rex_event=$_ble_syntax_bash_histexpand_RexEventDef
  else
    local A="[$histc1]"
    [[ $histc1 == '^' ]] && A='\^'
    rex_event=$_ble_syntax_bash_histexpand_RexEventFmt
    rex_event=${rex_event//@A/"$A"}
  fi
}
## @fn ble/syntax:bash/check-history-expansion/.initialize-quicksub
##   @var[out] rex_quicksub
function ble/syntax:bash/check-history-expansion/.initialize-quicksub {
  local histc2=${_ble_syntax_bash_histc12:1:1}
  if [[ $histc2 == '^' ]]; then
    rex_quicksub=$_ble_syntax_bash_histexpand_RexQuicksubDef
  else
    rex_quicksub=$_ble_syntax_bash_histexpand_RexQuicksubFmt
    rex_quicksub=${rex_quicksub//@A/"[$histc2]"}
    rex_quicksub=${rex_quicksub//@C/"$histc2"}
  fi
}
function ble/syntax:bash/check-history-expansion/.check-modifiers {
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
      ble/syntax:bash/check-history-expansion/.check-modifiers
      return 0
    fi
  fi

  # ErrMsg 'unrecognized modifier'
  if [[ ${text:i} == ':'[gGa]* ]]; then
    ((_ble_syntax_attr[i+1]=ATTR_ERR,i+=2))
  elif [[ ${text:i} == ':'* ]]; then
    ((_ble_syntax_attr[i]=ATTR_ERR,i++))
  fi
}
## @fn ble/syntax:bash/check-history-expansion
##   @var[in] i tail
function ble/syntax:bash/check-history-expansion {
  [[ -o histexpand ]] || return 1

  local histc1=${_ble_syntax_bash_histc12:0:1}
  local histc2=${_ble_syntax_bash_histc12:1:1}
  if [[ $histc1 && $tail == "$histc1"[^"$_ble_syntax_bash_histstop"]* ]]; then

    # "～" 文字列中では一致可能範囲を制限する。
    if ((_ble_bash>=40300&&ctx==CTX_QUOT)); then
      local tail=${tail%%'"'*}
      [[ $tail == '!' ]] && return 1
    fi

    ((_ble_syntax_attr[i]=ATTR_HISTX))
    local rex_event
    ble/syntax:bash/check-history-expansion/.initialize-event
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

    ble/syntax:bash/check-history-expansion/.check-modifiers
    return 0
  elif ((i==0)) && [[ $histc2 && $tail == "$histc2"* ]]; then
    ((_ble_syntax_attr[i]=ATTR_HISTX))
    local rex_quicksub
    ble/syntax:bash/check-history-expansion/.initialize-quicksub
    if [[ $tail =~ $rex_quicksub ]]; then
      ((i+=${#BASH_REMATCH}))

      ble/syntax:bash/check-history-expansion/.check-modifiers
      return 0
    else
      # 末端まで
      ((i+=${#tail}))
      return 0
    fi
  fi

  return 1
}
## @fn ble/syntax:bash/starts-with-histchars
##   @var[in] tail
function ble/syntax:bash/starts-with-histchars {
  [[ $_ble_syntax_bash_histc12 && $tail == ["$_ble_syntax_bash_histc12"]* ]]
}

#------------------------------------------------------------------------------
# 文脈: 各種文脈

_ble_syntax_context_proc[CTX_QUOT]=ble/syntax:bash/ctx-quot
function ble/syntax:bash/ctx-quot {
  # 文字列の中身
  if ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[CTX_QUOT]}]+" 1; then
    return 0
  elif [[ $tail == '"'* ]]; then
    ((_ble_syntax_attr[i]=ATTR_QDEL,
      i+=1))
    ble/syntax/parse/nest-pop
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

_ble_syntax_context_proc[CTX_CASE]=ble/syntax:bash/ctx-case
function ble/syntax:bash/ctx-case {
  if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs ]]; then
    ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
    return 0
  elif [[ $tail == '('* ]]; then
    ((_ble_syntax_attr[i++]=ATTR_GLOB,ctx=CTX_CPATX))
    return 0
  elif [[ $tail == 'esac'$_ble_syntax_bash_RexDelimiter* || $tail == 'esac' ]]; then
    ((ctx=CTX_CMDX))
    ble/syntax:bash/ctx-command
  else
    ((ctx=CTX_CPATX))
    ble/syntax:bash/ctx-command-case-pattern-expect
  fi
}

# 文脈 CTX_PATN (extglob/case-pattern)
_ble_syntax_context_proc[CTX_PATN]=ble/syntax:bash/ctx-globpat
_ble_syntax_context_end[CTX_PATN]=ble/syntax:bash/ctx-globpat.end

## @fn ble/syntax:bash/ctx-globpat/get-stop-chars
##   @var[out] chars
function ble/syntax:bash/ctx-globpat/get-stop-chars {
  chars=${_ble_syntax_bash_chars[CTX_PATN]}
  local ntype; ble/syntax/parse/nest-type
  if [[ $ntype == glob_ctx=* ]]; then
    local gctx=${ntype#glob_ctx=}
    if ((gctx==CTX_PWORD||gctx==CTX_PWORDE)); then
      chars=}$chars
    elif ((gctx==CTX_PWORDR)); then
      chars=}/$chars
    fi
  fi
}
function ble/syntax:bash/ctx-globpat {
  # glob () の中身 (extglob @(...) や case in (...) の中)
  local chars; ble/syntax:bash/ctx-globpat/get-stop-chars
  if ble/syntax:bash/check-plain-with-escape "[^$chars]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif [[ $tail == ['<>']* ]]; then
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}
function ble/syntax:bash/ctx-globpat.end {
  local is_end= tail=${text:i}
  local ntype; ble/syntax/parse/nest-type
  if [[ $ntype == glob_ctx=* ]]; then
    local gctx=${ntype#glob_ctx=}
    if ((gctx==CTX_PWORD||gctx==CTX_PWORDE)); then
      [[ ! $tail || $tail == '}'* ]] && is_end=1
    elif ((gctx==CTX_PWORDR)); then
      [[ ! $tail || $tail == ['/}']* ]] && is_end=1
    fi
  fi

  if [[ $is_end ]]; then
    ble/syntax/parse/nest-pop
    ble/syntax/parse/check-end
    return 0
  fi

  return 0
}

# 文脈 CTX_BRAX (bracket expression)
_ble_syntax_context_proc[CTX_BRAX]=ble/syntax:bash/ctx-bracket-expression
_ble_syntax_context_end[CTX_BRAX]=ble/syntax:bash/ctx-bracket-expression.end
function ble/syntax:bash/ctx-bracket-expression {
  local nctx; ble/syntax/parse/nest-ctx
  if ((nctx==CTX_PATN)); then
    local chars; ble/syntax:bash/ctx-globpat/get-stop-chars
  elif ((nctx==CTX_PWORD||nctx==CTX_PWORDE||nctx==CTX_PWORDR)); then
    local chars=${_ble_syntax_bash_chars[nctx]}
  else
    # 以下の文脈では ctx-command と同様の処理で問題ない。
    #
    #   ctx-command (色々)
    #   ctx-redirect (CTX_RDRF CTX_RDRD CTX_RDRD2 CTX_RDRS)
    #   ctx-values (CTX_VALI, CTX_VALR, CTX_VALQ)
    #   ctx-conditions (CTX_CONDI, CTX_CONDQ)
    #     この文脈では例外として && || < > など一部の演算子で delimiters
    #     が単語中に許されるが、この例外は [...] を含む単語には当てはまらない。
    #
    # is-delimiters の時に [... は其処で不完全終端する。
    local chars=${_ble_syntax_bash_chars[CTX_ARGI]//'~'}
  fi
  chars="][${chars#']'}"

  local ntype; ble/syntax/parse/nest-type
  local force_attr=; [[ $ntype == glob_attr=* ]] && force_attr=${ntype#*=}

  local rex
  if [[ $tail == ']'* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-ATTR_GLOB}))
    ble/syntax/parse/nest-pop

    # 通常引数が配列代入の形式を持つとき、以降でチルダ展開が有効
    # 例: echo arr[i]=... arr[i]+=...
    if [[ $ntype == 'a[' ]]; then
      local is_assign=
      if [[ $tail == ']='* ]]; then
        ((_ble_syntax_attr[i++]=ctx,is_assign=1))
      elif [[ $tail == ']+'* ]]; then
        ble/syntax/parse/set-lookahead 2
        [[ $tail == ']+='* ]] && ((_ble_syntax_attr[i]=ctx,i+=2,is_assign=1))
      fi

      if [[ $is_assign ]]; then
        ble/util/assert '[[ ${_ble_syntax_bash_command_CtxAssign[ctx]} ]]'
        ((ctx=_ble_syntax_bash_command_CtxAssign[ctx]))
        if local tail=${text:i}; [[ $tail == '~'* ]]; then
          ble/syntax:bash/check-tilde-expansion rhs
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
  elif ctx=${force_attr:-$ctx} ble/syntax:bash/check-plain-with-escape "[^$chars]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/check-tilde-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
    return 0
  elif ((nctx==CTX_PATN)) && [[ $tail == ['<>']* ]]; then
    ((_ble_syntax_attr[i++]=${force_attr:-ctx}))
    return 0
  fi

  return 1
}
function ble/syntax:bash/ctx-bracket-expression.end {
  local is_end=

  local tail=${text:i}
  if [[ ! $tail ]]; then
    is_end=1
  else
    local nctx; ble/syntax/parse/nest-ctx
    local external_ctx=$nctx
    if ((nctx==CTX_PATN)); then
      local ntype; ble/syntax/parse/nest-type
      [[ $ntype == glob_ctx=* ]] &&
        external_ctx=${ntype#glob_ctx=}
    fi

    if ((external_ctx==CTX_PATN)); then
      [[ $tail == ')'* ]] && is_end=1
    elif ((external_ctx==CTX_PWORD||external_ctx==CTX_PWORDE)); then
      [[ $tail == '}'* ]] && is_end=1
    elif ((external_ctx==CTX_PWORDR)); then
      [[ $tail == ['}/']* ]] && is_end=1
    else
      # 外側は ctx-command など。
      if ble/syntax:bash/check-word-end/is-delimiter; then
        is_end=1
      elif [[ $tail == ':'* && ${_ble_syntax_bash_command_IsAssign[ctx]} ]]; then
        is_end=1
      fi
    fi
  fi

  if [[ $is_end ]]; then
    ble/syntax/parse/nest-pop
    ble/syntax/parse/check-end
    return "$?"
  fi

  return 0
}

_ble_syntax_context_proc[CTX_PARAM]=ble/syntax:bash/ctx-param
_ble_syntax_context_proc[CTX_PWORD]=ble/syntax:bash/ctx-pword
_ble_syntax_context_proc[CTX_PWORDR]=ble/syntax:bash/ctx-pword
_ble_syntax_context_proc[CTX_PWORDE]=ble/syntax:bash/ctx-pword-error
function ble/syntax:bash/ctx-param {
  # パラメータ展開 - パラメータの直後
  if [[ $tail == '}'* ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
    ((i+=1))
    ble/syntax/parse/nest-pop
    return 0
  fi

  local rex='##?|%%?|:?[-?=+]|:|/[/#%]?'
  ((_ble_bash>=40000)) && rex=$rex'|,,?|\^\^?|~~?'
  if ((_ble_bash>=50200)); then
    rex=$rex'|@[QEPAaUuLKk]?'
  elif ((_ble_bash>=50100)); then
    rex=$rex'|@[QEPAaUuLK]?'
  elif ((_ble_bash>=40400)); then
    rex=$rex'|@[QEPAa]?'
  fi
  rex='^('$rex')'
  if [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=CTX_PARAM,
      i+=${#BASH_REMATCH}))
    if [[ $BASH_REMATCH == '/'* ]]; then
      ((ctx=CTX_PWORDR))
    elif [[ $BASH_REMATCH == : ]]; then
      ((ctx=CTX_EXPR,_ble_syntax_attr[i-1]=CTX_EXPR))
    elif [[ $BASH_REMATCH == @* ]]; then
      ((ctx=CTX_PWORDE))
    else
      ((ctx=CTX_PWORD))
      [[ $BASH_REMATCH == [':-+=?#%']* ]] &&
        tail=${text:i} ble/syntax:bash/check-tilde-expansion pword
    fi
    return 0
  else
    local i0=$i
    ((ctx=CTX_PWORD))
    ble/syntax:bash/ctx-pword || return 1

    # 一文字だけエラー着色
    if ((i0+2<=i)); then
      ((_ble_syntax_attr[i0+1])) ||
        ((_ble_syntax_attr[i0+1]=_ble_syntax_attr[i0]))
    fi
    ((_ble_syntax_attr[i0]=ATTR_ERR))
    return 0
  fi
}
function ble/syntax:bash/ctx-pword {
  # パラメータ展開 - word 部
  if ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[ctx]}]+"; then
    return 0
  elif ((ctx==CTX_PWORDR)) && [[ $tail == '/'* ]]; then
    ((_ble_syntax_attr[i++]=CTX_PARAM,ctx=CTX_PWORD))
    return 0
  elif [[ $tail == '}'* ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
    ((i+=1))
    ble/syntax/parse/nest-pop
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}
function ble/syntax:bash/ctx-pword-error {
  local i0=$i
  if ble/syntax:bash/ctx-pword; then
    [[ $tail == '}'* ]] ||
      ((_ble_syntax_attr[i0]=ATTR_ERR))
    return 0
  else
    return 1
  fi
}

## @const CTX_EXPR
##   算術式の文脈値
##
##   対応する nest types (ntype) の一覧
##
##   NTYPE             NEST-PUSH LOCATION       QUOTE  DESC
##   ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
##   '$(('           @ check-dollar                 x  算術式展開 $(()) の中身
##   '$['            @ check-dollar                 x  算術式展開 $[] の中身
##   '(('            @ .check-delimiter-or-redirect o  算術式評価コマンド (()) の中身
##   'a['            @ check-variable-assignment    o  a[...]= の中身
##   'd['            @ ctx-values                   o  a=([...]=) の中身
##   'v['            @ check-dollar                 o  ${a[...]} の中身
##   '${'            @ check-dollar                 o  ${v:...} の中身
##   '"${'           @ check-dollar                 x  "${v:...}" の中身
##   'expr-paren'    @ .count-paren                 o  () によるネスト (quote 除去有効)
##   'expr-paren-ax' @ .count-paren                 +  () によるネスト / $(( $[ の内部
##   'expr-paren-ai' @ .count-paren                 +  () によるネスト / a[ v[ の内部          (unused)
##   'expr-paren-di' @ .count-paren                 o  () によるネスト / d[ の内部             (unused)
##   'expr-brack'    @ .count-bracket               o  [] によるネスト (quote 除去常時有効)    (unused)
##   'expr-brack-ai' @ .count-bracket               +  [] によるネスト / $(( $[ a[ v[ [ の内部
##   'expr-brack-di' @ .count-bracket               o  [] によるネスト / d[ の内部
##
##   '$('            @ check-dollar                 o  $(command)
##   'cmdsub_nofork' @ check-dollar                 o  ${ command; }
##   'cmd_brace'     @ ctx-command/check-word-end   o  { command; }
##
##   QUOTE = o ... 内部で quote 除去が有効
##   QUOTE = x ... 内部で quote 除去は無効
##
_ble_syntax_context_proc[CTX_EXPR]=ble/syntax:bash/ctx-expr
## @fn ble/syntax:bash/ctx-expr/.count-paren
##   算術式中の括弧の数 () を数えます。
##   @var ntype 現在の算術式の入れ子の種類を指定します。
##   @var char  括弧文字を指定します。
function ble/syntax:bash/ctx-expr/.count-paren {
  if [[ $char == ')' ]]; then
    if [[ $ntype == '((' || $ntype == '$((' ]]; then
      if [[ $tail == '))'* ]]; then
        ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
        ((i+=2))
        ble/syntax/parse/nest-pop
      else
        # ((echo) > /dev/null) や $((echo) > /dev/null) などの
        # 紛らわしいサブシェル・コマンド置換だったとみなす。
        # それまでに算術式と思っていた部分については仕方がないのでそのまま。
        ((ctx=CTX_ARGX0,
          _ble_syntax_attr[i++]=_ble_syntax_attr[inest]))
      fi
      return 0
    elif [[ $ntype == expr-paren* ]]; then
      ((_ble_syntax_attr[i++]=ctx))
      ble/syntax/parse/nest-pop
      return 0
    fi
  elif [[ $char == '(' ]]; then
    # determine nested ntype
    local ntype2=
    case $ntype in
    ('((')
      ntype2=expr-paren ;;
    ('$((')
      ntype2=expr-paren-ax ;;
    (expr-paren|expr-paren-ax|expr-paren-ai|expr-paren-di)
      ntype2=$ntype ;;
    ('$['|'a['|'v['|'d['|expr-brack|expr-brack-ai|expr-brack-di|'${'|'"${'|*)
      ble/util/assert 'false' "unexpected ntype='$ntype' here" ;;
    esac

    ble/syntax/parse/nest-push "$CTX_EXPR" "$ntype2"
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}
## @fn ble/syntax:bash/ctx-expr/.count-bracket
##   算術式中の括弧の数 [] を数えます。
##   @var ntype 現在の算術式の入れ子の種類を指定します。
##   @var char  括弧文字を指定します。
function ble/syntax:bash/ctx-expr/.count-bracket {
  if [[ $char == ']' ]]; then
    if [[ $ntype == expr-brack* || $ntype == '$[' ]]; then
      # 算術式展開 $[...] や入れ子 ((a[...]=123)) などの場合。
      ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
      ((i++))
      ble/syntax/parse/nest-pop
      return 0
    elif [[ $ntype == [ad]'[' ]]; then
      ((_ble_syntax_attr[i++]=CTX_EXPR))
      ble/syntax/parse/nest-pop
      if [[ $tail == ']='* ]]; then
        # a[...]=, a=([...]=) の場合
        ((i++))
        tail=${text:i} ble/syntax:bash/check-tilde-expansion rhs
      elif ((_ble_bash>=30100)) && [[ $tail == ']+'* ]]; then
        ble/syntax/parse/set-lookahead 2
        if [[ $tail == ']+='* ]]; then
          # a[...]+=, a+=([...]+=) の場合
          ((i+=2))
          tail=${text:i} ble/syntax:bash/check-tilde-expansion rhs
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
          elif ((ctx==CTX_ARGER)); then
            # 例: eval arr[123]aaa
            ((ctx=CTX_ARGEI,wtype=CTX_ARGEI))
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
      ble/syntax/parse/nest-pop
      return 0
    fi
  elif [[ $char == '[' ]]; then
    local ntype2=
    case $ntype in
    ('$['|'a['|'v[')
      ntype2=expr-brack-ai ;;
    ('d[')
      ntype2=expr-brack-di ;;
    (expr-brack|expr-brack-ai|expr-brack-di)
      ntype2=$ntype ;;
    ('(('|'$(('|expr-paren|expr-paren-ax|expr-paren-ai|expr-paren-di|'${'|'"${'|*)
      ble/util/assert 'false' "unexpected ntype='$ntype' here" ;;
    esac
    ble/syntax/parse/nest-push "$CTX_EXPR" "$ntype2"
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}
## @fn ble/syntax:bash/ctx-expr/.count-brace
##   算術式中に閉じ波括弧 '}' が来たら算術式を抜けます。
##   @var ntype 現在の算術式の入れ子の種類を指定します。
##   @var char  括弧文字を指定します。
function ble/syntax:bash/ctx-expr/.count-brace {
  if [[ $char == '}' ]]; then
    ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
    ((i++))
    ble/syntax/parse/nest-pop
    return 0
  fi

  return 1
}
## @fn ble/syntax:bash/ctx-expr/.check-plain-with-escape rex is_quote
##   @var[in] ntype
function ble/syntax:bash/ctx-expr/.check-plain-with-escape {
  local i0=$i
  ble/syntax:bash/check-plain-with-escape "$@" || return 1

  if [[ $tail == '\'* ]]; then
    case $ntype in
    ('$(('|'$['|expr-paren-ax|'${'|'"${')
      _ble_syntax_attr[i0]=$ATTR_ERR ;;
    ('(('|expr-paren|expr-brack)
      if ((_ble_bash>=50100)); then
        _ble_syntax_attr[i0]=$ATTR_ERR
      fi ;;
    ('a['|'v['|expr-paren-ai|expr-brack-ai)
      if ((_ble_bash>=40400)); then
        _ble_syntax_attr[i0]=$ATTR_ERR
      fi ;;
    # ('d['|expr-paren-di|expr-brack-di) ;; # d[ (designated init) 内部では常に \ は OK
    esac
  fi

  return 0
}

function ble/syntax:bash/ctx-expr {
  # 式の中身
  local rex
  if rex='^[_a-zA-Z][_a-zA-Z0-9]*'; [[ $tail =~ $rex ]]; then
    local rematch=$BASH_REMATCH
    local ret; ble/syntax/highlight/vartype "$BASH_REMATCH" readvar:expr:global
    ((_ble_syntax_attr[i]=ret,i+=${#rematch}))
    return 0
  elif rex='^0[xX][0-9a-fA-F]*|^[0-9]+(#[_a-zA-Z0-9@]*)?'; [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ATTR_VAR_NUMBER,i+=${#BASH_REMATCH}))
    return 0
  fi

  local ntype
  ble/syntax/parse/nest-type
  if ble/syntax:bash/ctx-expr/.check-plain-with-escape "[^${_ble_syntax_bash_chars[ctx]}_a-zA-Z0-9]+" 1; then
    return 0
  elif [[ $tail == ['][()}']* ]]; then
    local char=${tail::1}
    if [[ $ntype == *'(' || $ntype == expr-paren* ]]; then
      # ntype = '(('            # ((...))
      #       = '$(('           # $((...))
      #       = 'expr-paren'    # 式中の (..)
      #       = 'expr-paren-ax' # $(( $[ 中の (..)
      #       = 'expr-paren-ai' # a[ v[  中の (..)
      #       = 'expr-paren-di' # d[     中の (..)
      ble/syntax:bash/ctx-expr/.count-paren && return 0
    elif [[ $ntype == *'[' || $ntype == expr-brack* ]]; then
      # ntype = 'a['             # a[...]=
      #       = 'v['             # ${a[...]}
      #       = 'd['             # a=([...]=)
      #       = '$['             # $[...]
      #       = 'expr-brack'     # 式中の [...]
      #       = 'expr-brack-ai'  # $(( $[ a[ v[ 中の [...]
      #       = 'expr-brack-di'  # d[           中の [...]
      ble/syntax:bash/ctx-expr/.count-bracket && return 0
    elif [[ $ntype == '${' || $ntype == '"${' ]]; then
      # ntype = '${'  # ${var:offset:length}
      #       = '"${' # "${var:offset:length}"
      ble/syntax:bash/ctx-expr/.count-brace && return 0
    else
      ble/util/assert 'false' "unexpected ntype=$ntype for arithmetic expression"
    fi

    # 入れ子処理されなかった文字は通常文字として処理
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    # 恐ろしい事に数式中でも履歴展開が有効…。
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

#------------------------------------------------------------------------------
# ブレース展開

## CTX_CONDI 及び CTX_RDRS の時は不活性化したブレース展開として振る舞う。
## CTX_RDRF 及び CTX_RDRD, CTX_RDRD2 の時は複数語に展開されるブレース展開はエラーなので、
## nest-push して解析だけ行いブレース展開であるということが確定した時点でエラーを設定する。

function ble/syntax:bash/check-brace-expansion {
  [[ $tail == '{'* ]] || return 1

  local rex='^\{[-+a-zA-Z0-9.]*(\}?)'
  [[ $tail =~ $rex ]]
  local str=$BASH_REMATCH

  local force_attr= inactive=

  # 特定の文脈では完全に不活性
  # Note: {fd}> リダイレクトの先読みに合わせて、
  #   不活性であっても一気に読み取る必要がある。
  #   cf ble/syntax:bash/starts-with-delimiter-or-redirect
  if [[ $- != *B* ]]; then
    inactive=1
  elif ((ctx==CTX_CONDI||ctx==CTX_CONDQ||ctx==CTX_RDRS||ctx==CTX_VRHS)); then
    inactive=1
  elif ((_ble_bash>=50300&&ctx==CTX_VALR)); then
    # bash-5.3 以降では arr=([9]={1..10}) 等のブレース展開は不活性
    inactive=1
  elif ((ctx==CTX_PATN||ctx==CTX_BRAX)); then
    local ntype; ble/syntax/parse/nest-type
    if [[ $ntype == glob_attr=* ]]; then
      force_attr=${ntype#*=}
      (((force_attr==CTX_RDRS||force_attr==CTX_VRHS||force_attr==CTX_ARGVR||force_attr==CTX_ARGER||force_attr==CTX_VALR)&&(inactive=1)))
    elif ((ctx==CTX_BRAX)); then
      local nctx; ble/syntax/parse/nest-ctx
      (((nctx==CTX_CONDI||octx==CTX_CONDQ)&&(inactive=1)))
    fi
  elif ((ctx==CTX_BRACE1||ctx==CTX_BRACE2)); then
    local ntype; ble/syntax/parse/nest-type
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
  if rex='^\{(([-+]?[0-9]+)\.\.[-+]?[0-9]+|[a-zA-Z]\.\.[a-zA-Z])(\.\.[-+]?[0-9]+)?\}$'; [[ $str =~ $rex ]]; then
    if [[ $force_attr ]]; then
      ((_ble_syntax_attr[i]=force_attr,i+=${#str}))
    else
      local rematch1=${BASH_REMATCH[1]}
      local rematch2=${BASH_REMATCH[2]}
      local rematch3=${BASH_REMATCH[3]}
      local len2=${#rematch2}; ((len2||(len2=1)))
      local attr=$ATTR_BRACE
      if ((ctx==CTX_RDRF||ctx==CTX_RDRD||ctx==CTX_RDRD2)); then
        # リダイレクトで複数語に展開される時はエラー
        local lhs=${rematch1::len2} rhs=${rematch1:len2+2}
        if [[ $rematch2 ]]; then
          local lhs1=$((10#0${lhs#[-+]})); [[ $lhs == -* ]] && ((lhs1=-lhs1))
          local rhs1=$((10#0${rhs#[-+]})); [[ $rhs == -* ]] && ((rhs1=-rhs1))
          lhs=$lhs1 rhs=$rhs1
        fi
        [[ $lhs != "$rhs" ]] && ((attr=ATTR_ERR))
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
  ((ctx==CTX_RDRF||ctx==CTX_RDRD||ctx==CTX_RDRD2)) && force_attr=$ctx
  [[ $force_attr ]] && ntype="glob_attr=$force_attr"
  ble/syntax/parse/nest-push "$CTX_BRACE1" "$ntype"
  local len=$((${#str}-1))
  ((_ble_syntax_attr[i++]=${force_attr:-ATTR_BRACE},
    len&&(_ble_syntax_attr[i]=${force_attr:-ctx},i+=len)))

  return 0
}

# 文脈 CTX_BRAX (brace expansion)
_ble_syntax_context_proc[CTX_BRACE1]=ble/syntax:bash/ctx-brace-expansion
_ble_syntax_context_proc[CTX_BRACE2]=ble/syntax:bash/ctx-brace-expansion
_ble_syntax_context_end[CTX_BRACE1]=ble/syntax:bash/ctx-brace-expansion.end
_ble_syntax_context_end[CTX_BRACE2]=ble/syntax:bash/ctx-brace-expansion.end
function ble/syntax:bash/ctx-brace-expansion {
  if [[ $tail == '}'* ]] && ((ctx==CTX_BRACE2)); then
    local force_attr=
    local ntype; ble/syntax/parse/nest-type
    [[ $ntype == glob_attr=* ]] && force_attr=$ATTR_ERR # ※${ntype#*=} ではなくエラー

    ((_ble_syntax_attr[i++]=${force_attr:-ATTR_BRACE}))
    ble/syntax/parse/nest-pop
    return 0
  elif [[ $tail == ','* ]]; then
    local force_attr=
    local ntype; ble/syntax/parse/nest-type
    [[ $ntype == glob_attr=* ]] && force_attr=${ntype#*=}

    ((_ble_syntax_attr[i++]=${force_attr:-ATTR_BRACE}))
    ((ctx=CTX_BRACE2))
    return 0
  fi

  local chars=",${_ble_syntax_bash_chars[CTX_ARGI]//'~:'}"
  ((ctx==CTX_BRACE2)) && chars="}$chars"
  ble/syntax:bash/cclass/update/reorder chars
  if ble/syntax:bash/check-plain-with-escape "[^$chars]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  return 1
}
function ble/syntax:bash/ctx-brace-expansion.end {
  if ((i==${#text})) || ble/syntax:bash/check-word-end/is-delimiter; then
    ble/syntax/parse/nest-pop
    ble/syntax/parse/check-end
    return "$?"
  fi

  return 0
}

#------------------------------------------------------------------------------
# チルダ展開

# ${_ble_syntax_bash_chars[CTX_ARGI]} により読み取りを行っている
# ctx-command ctx-values ctx-conditions ctx-redirect から呼び出される事を想定している。

## @fn ble/syntax:bash/check-tilde-expansion
##   チルダ展開を検出して処理します。
##   単語の始めの ~、または変数代入形式の単語の途中の :~ または
##   パラメータ展開中の word の始めの ~ の処理を行います。
function ble/syntax:bash/check-tilde-expansion {
  [[ $tail == ['~:']* ]] || return 1

  # @var rhs_enabled
  #   変数代入形式の文脈の右辺でチルダ展開が有効かどうか。set -o posix では限ら
  #   れた文脈のみで有効になる。
  local rhs_enabled=
  { ((ctx==CTX_VRHS||ctx==CTX_ARGVR||ctx==CTX_VALR||ctx==CTX_ARGER)) ||
      ! ble/base/is-POSIXLY_CORRECT; } && rhs_enabled=1

  local tilde_enabled=$((i==wbegin||ctx==CTX_PWORD))
  [[ $1 == rhs && $rhs_enabled ]] && tilde_enabled=1 # = の直後

  if [[ $tail == ':'* ]]; then
    _ble_syntax_attr[i++]=$ctx

    # 変数代入の右辺、または、その一つ下の角括弧式のときチルダ展開が有効。
    if [[ $rhs_enabled ]]; then
      if ! ((tilde_enabled=_ble_syntax_bash_command_IsAssign[ctx])); then
        if ((ctx==CTX_BRAX)); then
          local nctx; ble/syntax/parse/nest-ctx
          ((tilde_enabled=_ble_syntax_bash_command_IsAssign[nctx]))
        fi
      fi
    fi

    local tail=${text:i}
    [[ $tail == '~'* ]] || return 0
  fi

  if ((tilde_enabled)); then
    local chars="${_ble_syntax_bash_chars[CTX_ARGI]}/:"
    # Note: pword の時は delimiters も除外したいので
    #   _ble_syntax_bash_chars[CTX_PWORD] ではなく
    #   _ble_syntax_bash_chars[CTX_ARGI] を修正して使う。
    ((ctx==CTX_PWORD)) && chars=${chars/'{'/'{}'}

    ble/syntax:bash/cclass/update/reorder chars
    local delimiters="$_ble_term_IFS;|&)<>"
    local rex='^(~\+|~[^'$chars']*)([^'$delimiters'/:]?)'; [[ $tail =~ $rex ]]
    local str=${BASH_REMATCH[1]}

    local path attr=$ctx
    builtin eval "path=$str"
    if [[ ! ${BASH_REMATCH[2]} && $path != "$str" ]]; then
      ((attr=ATTR_TILDE))

      if ((ctx==CTX_BRAX)); then
        # CTX_BRAX は単語先頭には来ないので、
        # ここに来るのは [[ $tail == ':~'* ]] だった時のみのはず。
        # このとき、各括弧式は : の直後でキャンセルする。
        ble/util/assert 'ble/util/unlocal tail; [[ $tail == ":~"* ]]'
        ble/syntax/parse/nest-pop
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
    ((_ble_syntax_attr[i]=ctx,i++)) # skip tilde
    local chars=${_ble_syntax_bash_chars[CTX_ARGI]}
    ble/syntax:bash/check-plain-with-escape "[^$chars]+" # 追加(失敗してもOK)
  fi

  return 0
}

#------------------------------------------------------------------------------
# 変数代入の形式の単語
#
#   実は通常の引数であっても変数代入の形式をしているものは微妙に扱いが異なる。
#   変数代入の形式の引数の右辺ではチルダ展開が有効である。
#

# 変数代入形式の時に文脈を切り替える文脈値。実際に変数代入でなくても変数代入形
# 式によるチルダ展開が有効である時には区別する必要がある。
_ble_syntax_bash_command_CtxAssign[CTX_CMDI]=$CTX_VRHS
_ble_syntax_bash_command_CtxAssign[CTX_COARGI]=$CTX_VRHS
_ble_syntax_bash_command_CtxAssign[CTX_ARGVI]=$CTX_ARGVR
_ble_syntax_bash_command_CtxAssign[CTX_ARGEI]=$CTX_ARGER
_ble_syntax_bash_command_CtxAssign[CTX_ARGI]=$CTX_ARGQ
_ble_syntax_bash_command_CtxAssign[CTX_FARGI3]=$CTX_FARGQ3
_ble_syntax_bash_command_CtxAssign[CTX_CARGI1]=$CTX_CARGQ1
_ble_syntax_bash_command_CtxAssign[CTX_CPATI]=$CTX_CPATQ
_ble_syntax_bash_command_CtxAssign[CTX_VALI]=$CTX_VALQ
_ble_syntax_bash_command_CtxAssign[CTX_CONDI]=$CTX_CONDQ

# 以下の配列はチルダ展開が有効な文脈を無効な文脈に切り替えるのに使っている。
_ble_syntax_bash_command_IsAssign[CTX_VRHS]=$CTX_CMDI
_ble_syntax_bash_command_IsAssign[CTX_ARGVR]=$CTX_ARGVI
_ble_syntax_bash_command_IsAssign[CTX_ARGER]=$CTX_ARGEI
_ble_syntax_bash_command_IsAssign[CTX_ARGQ]=$CTX_ARGI
_ble_syntax_bash_command_IsAssign[CTX_FARGQ3]=$CTX_FARGI3
_ble_syntax_bash_command_IsAssign[CTX_CARGQ1]=$CTX_CARGI1
_ble_syntax_bash_command_IsAssign[CTX_CPATQ]=$CTX_CPATI
_ble_syntax_bash_command_IsAssign[CTX_VALR]=$CTX_VALI
_ble_syntax_bash_command_IsAssign[CTX_VALQ]=$CTX_VALI
_ble_syntax_bash_command_IsAssign[CTX_CONDQ]=$CTX_CONDI

## @fn ble/syntax:bash/check-variable-assignment
## @var[in] tail
function ble/syntax:bash/check-variable-assignment {
  ((wbegin==i)) || return 1

  # 値リストにおける [0]=value の形式の単語は特別に扱う。
  if ((ctx==CTX_VALI)) && [[ $tail == '['* ]]; then
    ((ctx=CTX_VALR))
    ble/syntax/parse/nest-push "$CTX_EXPR" 'd['
    # → ble/syntax:bash/ctx-expr/.count-bracket で抜ける
    ((_ble_syntax_attr[i++]=ctx))
    return 0
  fi

  [[ ${_ble_syntax_bash_command_CtxAssign[ctx]} ]] || return 1

  # パターン一致 (var= var+= arr[ のどれか)
  local suffix='[=[]'
  ((_ble_bash>=30100)) && suffix=$suffix'|\+=?'
  local rex_assign="^([_a-zA-Z][_a-zA-Z0-9]*)($suffix)"
  [[ $tail =~ $rex_assign ]] || return 1
  local rematch=$BASH_REMATCH
  local rematch1=${BASH_REMATCH[1]} # for bash-3.1 ${#arr[n]} bug
  local rematch2=${BASH_REMATCH[2]} # for bash-3.1 ${#arr[n]} bug
  if [[ $rematch2 == '+' ]]; then
    # var+... 曖昧状態

    # Note: + の次の文字が = でない時に此処に来るので、
    # + の次の文字まで先読みしたことになる。
    ble/syntax/parse/set-lookahead "$((${#rematch}+1))"

    return 1
  fi

  local variable_assign=
  if ((ctx==CTX_CMDI||ctx==CTX_ARGVI||ctx==CTX_ARGEI&&${#rematch2})); then
    # 変数代入のときは ctx は先に CTX_VRHS, CTX_ARGVR に変換する
    local ret; ble/syntax/highlight/vartype "$rematch1" newvar:global
    ((wtype=ATTR_VAR,
      _ble_syntax_attr[i]=ret,
      i+=${#rematch},
      ${#rematch2}&&(_ble_syntax_attr[i-${#rematch2}]=CTX_EXPR),
      variable_assign=1,
      ctx=_ble_syntax_bash_command_CtxAssign[ctx]))
  else
    # 変数代入以外のときは = が現れて初めて CTX_ARGQ などに変換する
    ((_ble_syntax_attr[i]=ctx,
      i+=${#rematch}))
  fi

  if [[ $rematch2 == '[' ]]; then
    # arr[
    if [[ $variable_assign ]]; then
      i=$((i-1)) ble/syntax/parse/nest-push "$CTX_EXPR" 'a['
      # → ble/syntax:bash/ctx-expr/.count-bracket で抜ける
    else
      ((i--))
      tail=${text:i} ble/syntax:bash/check-glob assign
      # → ble/syntax:bash/check-glob 内で nest-push "$CTX_BRAX" 'a[' し、
      # → ble/syntax:bash/ctx-bracket-expression で抜けた後で = があれば文脈値設定
    fi
  elif [[ $rematch2 == *'=' ]]; then
    if [[ $variable_assign && ${text:i} == '('* ]]; then
      # var=( var+=(
      # * nest-pop した直後は未だ CTX_VRHS, CTX_ARGVR の続きになっている。
      #   例: a=(1 2)b=1 は a='(1 2)b=1' と解釈される。
      #   従って ctx (nest-pop 時の文脈) はそのまま (CTX_VRHS, CTX_ARGVR) にする。

      ble/syntax:bash/ctx-values/enter
      ((_ble_syntax_attr[i++]=ATTR_DEL))
    else
      # var=... var+=...
      [[ $variable_assign ]] || ((ctx=_ble_syntax_bash_command_CtxAssign[ctx]))
      if local tail=${text:i}; [[ $tail == '~'* ]]; then
        ble/syntax:bash/check-tilde-expansion rhs
      fi
    fi
  fi

  return 0
}

#------------------------------------------------------------------------------
# 文脈: コマンドライン

_ble_syntax_context_proc[CTX_ARGX]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_ARGX0]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDX]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDX0]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDX1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDXT]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDXC]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDXE]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDXD]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDXD0]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDXV]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_ARGI]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_ARGQ]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CMDI]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_VRHS]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_ARGVR]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_ARGER]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[CTX_CMDI]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_ARGI]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_ARGQ]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_VRHS]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_ARGVR]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_ARGER]=ble/syntax:bash/ctx-command/check-word-end

# declare var=value / eval var=value
_ble_syntax_context_proc[CTX_ARGVX]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_ARGVI]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[CTX_ARGVI]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_proc[CTX_ARGEX]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_ARGEI]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[CTX_ARGEI]=ble/syntax:bash/ctx-command/check-word-end

# for var in ... / case arg in
_ble_syntax_context_proc[CTX_SARGX1]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[CTX_FARGX1]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[CTX_FARGX2]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[CTX_FARGX3]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_FARGI1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_FARGI2]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_FARGI3]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_FARGQ3]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[CTX_FARGI1]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_FARGI2]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_FARGI3]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_FARGQ3]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_proc[CTX_CARGX1]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[CTX_CARGX2]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_proc[CTX_CPATX]=ble/syntax:bash/ctx-command-case-pattern-expect
_ble_syntax_context_proc[CTX_CPATX0]=ble/syntax:bash/ctx-command-case-pattern-expect
_ble_syntax_context_proc[CTX_CARGI1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CARGQ1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CARGI2]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CPATI]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_CPATQ]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[CTX_CARGI1]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_CARGQ1]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_CARGI2]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_CPATI]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_CPATQ]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_proc[CTX_TARGX1]=ble/syntax:bash/ctx-command-time-expect
_ble_syntax_context_proc[CTX_TARGX2]=ble/syntax:bash/ctx-command-time-expect
_ble_syntax_context_proc[CTX_TARGI1]=ble/syntax:bash/ctx-command
_ble_syntax_context_proc[CTX_TARGI2]=ble/syntax:bash/ctx-command
_ble_syntax_context_end[CTX_TARGI1]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_end[CTX_TARGI2]=ble/syntax:bash/ctx-command/check-word-end
_ble_syntax_context_proc[CTX_COARGX]=ble/syntax:bash/ctx-command-compound-expect
_ble_syntax_context_end[CTX_COARGI]=ble/syntax:bash/ctx-coproc/check-word-end

## @fn ble/syntax:bash/starts-with-delimiter-or-redirect
##
##   空白類、コマンド区切り文字、またはリダイレクトかどうかを判定する。
##   単語開始における 1>2 や {fd}>2 もリダイレクトと判定する。
##
##   Note: ここで "1>2" や "{fd}>" に一致しなかったとしても、通常の文脈で
##   "{fd}" や "1" 等の列が一気に読み取られる限り先読みの問題は発生しないはず。
##   ブレース展開の解析は "{fd}" が一気に読み取られる様に注意深く実装する。
##
function ble/syntax:bash/starts-with-delimiter-or-redirect {
  local delimiters=$_ble_syntax_bash_RexDelimiter
  local redirect=$_ble_syntax_bash_RexRedirect
  [[ ( $tail =~ ^$delimiters || $wbegin -lt 0 && $tail =~ ^$redirect || $wbegin -lt 0 && $tail == $'\\\n'* ) && $tail != ['<>']'('* ]]
}
function ble/syntax:bash/starts-with-delimiter {
  [[ $tail == ["$_ble_term_IFS;|&<>()"]* && $tail != ['<>']'('* ]]
}
function ble/syntax:bash/check-word-end/is-delimiter {
  local tail=${text:i}
  if [[ $tail == [!"$_ble_term_IFS;|&<>()"]* ]]; then
    return 1
  elif [[ $tail == ['<>']* ]]; then
    ble/syntax/parse/set-lookahead 2
    [[ $tail == ['<>']'('* ]] && return 1
  fi
  return 0
}

## @fn ble/syntax:bash/check-here-document-from spaces
##   @param[in] spaces
function ble/syntax:bash/check-here-document-from {
  local spaces=$1
  [[ $nparam && $spaces == *$'\n'* ]] || return 1
  local rex="$_ble_term_FS@([RI][QH][^$_ble_term_FS]*)(.*$)" && [[ $nparam =~ $rex ]] || return 1

  # ヒアドキュメントの開始
  local rematch1=${BASH_REMATCH[1]}
  local rematch2=${BASH_REMATCH[2]}
  local padding=${spaces%%$'\n'*}
  ((_ble_syntax_attr[i]=ctx,i+=${#padding}))
  nparam=${nparam::${#nparam}-${#BASH_REMATCH}}${nparam:${#nparam}-${#rematch2}}
  ble/syntax/parse/nest-push "$CTX_HERE0"
  ((i++))
  nparam=$rematch1
  return 0
}

function ble/syntax:bash/ctx-coproc/.is-next-compound {
  # @var ahead
  #   現在位置 p の次の文字を参照したかどうか
  local p=$i ahead=1 tail=${text:i}

  # 空白類は無視
  if local rex=$'^[ \t]+'; [[ $tail =~ $rex ]]; then
    ((p+=${#BASH_REMATCH}))
    ahead=1 tail=${text:p}
  fi

  local is_compound=
  if [[ $tail == '('* ]]; then
    is_compound=1
  elif rex='^[a-z]+|^\[\[?|^[{}!]'; [[ $tail =~ $rex ]]; then
    local rematch=$BASH_REMATCH

    ((p+=${#rematch}))
    [[ $rematch == ['{}!'] || $rematch == '[[' ]]; ahead=$?

    rex='^(\[\[|for|select|case|if|while|until|fi|done|esac|then|elif|else|do|[{}!]|coproc|function)$'
    if  [[ $rematch =~ $rex ]]; then
      if rex='^[;|&()'$_ble_term_IFS']|^$|^[<>]\(?' ahead=1; [[ ${text:p} =~ $rex ]]; then
        local rematch=$BASH_REMATCH
        ((p+=${#rematch}))
        [[ $rematch && $rematch != ['<>'] ]]; ahead=$?
        [[ $rematch != ['<>']'(' ]] && is_compound=1
      fi
    fi
  fi

  # 先読みの設定
  ble/syntax/parse/set-lookahead "$((p+ahead-i))"
  [[ $is_compound ]]
}
function ble/syntax:bash/ctx-coproc/check-word-end {
  ble/util/assert '((ctx==CTX_COARGI))'

  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  ble/syntax:bash/check-word-end/is-delimiter || return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}
  local wt=$wtype

  if local rex='^[_a-zA-Z][_a-zA-Z0-9]*$'; [[ $word =~ $rex ]]; then
    if ble/syntax:bash/ctx-coproc/.is-next-compound; then
      # 構文: 変数名 複合コマンド
      local attr=$ATTR_VAR

      # alias だった場合は解釈が変わり得る。alias が厳密に変数名に展開された時
      # にのみ変数名と判定する。複合コマンド開始に展開された場合は通常処理にフォー
      # ルバック。それ以外はエラー。
      if ble/alias#active "$word"; then
        attr=
        local ret; ble/alias#expand "$word"
        case $word in
        # 通常処理にフォールバックする
        ('if'|'while'|'until'|'for'|'select'|'case'|'{'|'[[') ;;
        # 通常処理(構文エラー)
        ('fi'|'done'|'esac'|'then'|'elif'|'else'|'do'|'}'|'!'|'coproc'|'function'|'in') ;;
        (*)
          if ble/string#match "$word" '^[_a-zA-Z][_a-zA-Z0-9]*$'; then
            # 変数名に展開される場合はOK
            attr=$ATTR_CMD_ALIAS
          else
            attr=$ATTR_ERR
          fi
        esac
      fi

      if [[ $attr ]]; then
        # Note: [_a-zA-Z0-9]+ は一回の読み取りの筈なので、
        #   此処で遡って代入しても問題ない筈。
        _ble_syntax_attr[wbegin]=$attr
        ((ctx=CTX_CMDXC,wtype=CTX_ARGVI))
        ble/syntax/parse/word-pop
        return 0
      fi
    fi
  fi

  ((ctx=CTX_CMDI,wtype=CTX_CMDX))
  ble/syntax:bash/ctx-command/check-word-end
}

## @arr _ble_syntax_bash_command_EndCtx
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
_ble_syntax_bash_command_EndCtx[CTX_ARGEI]=$CTX_ARGEX
_ble_syntax_bash_command_EndCtx[CTX_ARGER]=$CTX_ARGEX
_ble_syntax_bash_command_EndCtx[CTX_VRHS]=$CTX_CMDXV
_ble_syntax_bash_command_EndCtx[CTX_FARGI1]=$CTX_FARGX2
_ble_syntax_bash_command_EndCtx[CTX_FARGI2]=$CTX_FARGX3
_ble_syntax_bash_command_EndCtx[CTX_FARGI3]=$CTX_FARGX3
_ble_syntax_bash_command_EndCtx[CTX_FARGQ3]=$CTX_FARGX3
_ble_syntax_bash_command_EndCtx[CTX_CARGI1]=$CTX_CARGX2
_ble_syntax_bash_command_EndCtx[CTX_CARGQ1]=$CTX_CARGX2
_ble_syntax_bash_command_EndCtx[CTX_CARGI2]=$CTX_CASE
_ble_syntax_bash_command_EndCtx[CTX_CPATI]=$CTX_CPATX0
_ble_syntax_bash_command_EndCtx[CTX_CPATQ]=$CTX_CPATX0
_ble_syntax_bash_command_EndCtx[CTX_TARGI1]=$((_ble_bash>=40200?CTX_TARGX2:CTX_CMDXT)) #1
_ble_syntax_bash_command_EndCtx[CTX_TARGI2]=$CTX_CMDXT

## @arr _ble_syntax_bash_command_EndWtype[wtype]
##   実際に tree 登録する wtype を指定します。
##   ※解析中の wtype には解析開始時の wtype が入っていることに注意する。
_ble_syntax_bash_command_EndWtype[CTX_ARGX]=$CTX_ARGI
_ble_syntax_bash_command_EndWtype[CTX_ARGX0]=$CTX_ARGI
_ble_syntax_bash_command_EndWtype[CTX_ARGVX]=$CTX_ARGVI
_ble_syntax_bash_command_EndWtype[CTX_ARGEX]=$CTX_ARGEI
_ble_syntax_bash_command_EndWtype[CTX_CMDX]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDX0]=$CTX_CMDX0
_ble_syntax_bash_command_EndWtype[CTX_CMDX1]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXT]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXC]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXE]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXD]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXD0]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_CMDXV]=$CTX_CMDI
_ble_syntax_bash_command_EndWtype[CTX_FARGX1]=$CTX_FARGI1 # 変数名
_ble_syntax_bash_command_EndWtype[CTX_SARGX1]=$CTX_ARGI
_ble_syntax_bash_command_EndWtype[CTX_FARGX2]=$CTX_FARGI2 # in
_ble_syntax_bash_command_EndWtype[CTX_FARGX3]=$CTX_ARGI # in
_ble_syntax_bash_command_EndWtype[CTX_CARGX1]=$CTX_ARGI
_ble_syntax_bash_command_EndWtype[CTX_CARGX2]=$CTX_CARGI2 # in
_ble_syntax_bash_command_EndWtype[CTX_CPATX]=$CTX_CPATI
_ble_syntax_bash_command_EndWtype[CTX_CPATX0]=$CTX_CPATI
_ble_syntax_bash_command_EndWtype[CTX_TARGX1]=$CTX_ARGI # -p
_ble_syntax_bash_command_EndWtype[CTX_TARGX2]=$CTX_ARGI # --

## @arr _ble_syntax_bash_command_Expect
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

## @fn ble/syntax:bash/ctx-command/check-word-end
##   @var[in,out] ctx
##   @var[in,out] wbegin
##   @var[in,out] 他
function ble/syntax:bash/ctx-command/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  ble/syntax:bash/check-word-end/is-delimiter || return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}
  local stat_wt=$wtype # 単語解析中の wtype

  [[ ${_ble_syntax_bash_command_EndWtype[stat_wt]} ]] &&
    wtype=${_ble_syntax_bash_command_EndWtype[stat_wt]}
  local rex_expect_command=${_ble_syntax_bash_command_Expect[stat_wt]}
  if [[ $rex_expect_command ]]; then
    # 特定のコマンドのみを受け付ける文脈
    [[ $word =~ $rex_expect_command ]] || ((wtype=CTX_CMDX0))
  elif ((stat_wt==CTX_ARGX0||stat_wt==CTX_CPATX0)); then
    ((wtype=ATTR_ERR))
  elif ((stat_wt==CTX_CMDX1)); then
    local rex='^(then|elif|else|do|\}|done|fi|esac)$'
    [[ $word =~ $rex ]] && ((wtype=CTX_CMDX0))
  fi
  local tree_wt=$wtype # 実際に単語として登録された wtype
  ble/syntax/parse/word-pop

  if ((ctx==CTX_CMDI)); then
    local ret
    ble/alias#expand "$word"; local word_expanded=$ret

    # キーワードの処理
    if ((tree_wt==CTX_CMDX0)); then
      ((_ble_syntax_attr[wbeg]=ATTR_ERR,ctx=CTX_ARGX))
      return 0
    elif ((stat_wt!=CTX_CMDXV)); then # Note: 変数代入の直後はキーワードは処理しない
      local processed=
      case $word_expanded in
      ('[[')
        # 条件コマンド開始
        ble/syntax/parse/touch-updated-attr "$wbeg"
        ((_ble_syntax_attr[wbeg]=ATTR_DEL,
          ctx=_ble_bash>=50200?CTX_CMDXE:CTX_ARGX0))

        ble/syntax/parse/word-cancel # 単語 "[[" (とその内部のノード全て) を削除
        if [[ $word == '[[' ]]; then
          # "[[" は一度角括弧式として読み取られるので、その情報を削除する。
          _ble_syntax_attr[wbeg+1]= # 角括弧式として着色されているのを消去
        fi

        i=$wbeg ble/syntax/parse/nest-push "$CTX_CONDX"

        # workaround: word "[[" を nest 内部に設置し直す
        i=$wbeg ble/syntax/parse/word-push "$CTX_CMDI" "$wbeg"
        ble/syntax/parse/word-pop
        return 0 ;;
      ('time')               ((ctx=CTX_TARGX1)); processed=keyword ;;
      ('!')                  ((ctx=CTX_CMDXT)) ; processed=keyword ;;
      ('if'|'while'|'until') ((ctx=CTX_CMDX1)) ; processed=begin ;;
      ('for')                ((ctx=CTX_FARGX1)); processed=begin ;;
      ('select')             ((ctx=CTX_SARGX1)); processed=begin ;;
      ('case')               ((ctx=CTX_CARGX1)); processed=begin ;;
      ('{')
        # 単語属性の再設定
        ble/syntax/parse/touch-updated-attr "$wbeg"
        if ((stat_wt==CTX_CMDXD||stat_wt==CTX_CMDXD0)); then
          attr=$ATTR_KEYWORD_MID # "for ...; {" などの時
        else
          attr=$ATTR_KEYWORD_BEGIN
        fi
        ((_ble_syntax_attr[wbeg]=attr))

        # 単語削除&入れ子&単語再設置
        ble/syntax/parse/word-cancel
        ((ctx=CTX_CMDXE))
        i=$wbeg ble/syntax/parse/nest-push "$CTX_CMDX1" 'cmd_brace'
        i=$wbeg ble/syntax/parse/word-push "$CTX_CMDI" "$wbeg"
        ble/syntax/parse/word-pop
        return 0 ;;
      ('then'|'elif'|'else'|'do') ((ctx=CTX_CMDX1)); processed=middle ;;
      ('done'|'fi'|'esac')        ((ctx=CTX_CMDXE)); processed=end ;;
      ('}')
        if local ntype; ble/syntax/parse/nest-type; [[ $ntype == 'cmd_brace' ]]; then
          ble/syntax/parse/touch-updated-attr "$wbeg"
          ((_ble_syntax_attr[wbeg]=ATTR_KEYWORD_END))
          ble/syntax/parse/nest-pop
        else
          ble/syntax/parse/touch-updated-attr "$wbeg"
          ((_ble_syntax_attr[wbeg]=ATTR_ERR))
          ((ctx=CTX_CMDXE))
        fi
        return 0 ;;
      ('coproc')
        if ((_ble_bash>=40000)); then
          if ble/syntax:bash/ctx-coproc/.is-next-compound; then
            ((ctx=CTX_CMDXC))
          else
            ((ctx=CTX_COARGX))
          fi
          processed=keyword
        fi ;;
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
              ble/syntax/parse/set-lookahead 2
              ((ctx=CTX_CMDXC))
            elif [[ $rematch3 == '('* ]]; then
              ((_ble_syntax_attr[i]=ATTR_ERR,ctx=CTX_ARGX0))
              ble/syntax/parse/nest-push "$CTX_CMDX1" '('
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
          ble/syntax/parse/touch-updated-attr "$wbeg"
          ((_ble_syntax_attr[wbeg]=attr))
        fi

        return 0
      fi
    fi

    # 関数定義である可能性を考え stat を置かず読み取る
    ((ctx=CTX_ARGX))
    if local rex='^([ 	]*)(\([ 	]*\)?)?'; [[ ${text:i} =~ $rex && $BASH_REMATCH ]]; then

      # for bash-3.1 ${#arr[n]} bug
      local rematch1=${BASH_REMATCH[1]}
      local rematch2=${BASH_REMATCH[2]}

      if [[ $rematch2 == '('*')' ]]; then
        # case: /hoge ( *)/ 関数定義 (単語の種類 wtype を変更)
        #   上方の ble/syntax/parse/word-pop で設定した値を書き換え。
        # Note: 単語の種類が CTX_CMDX0 の時はそのままにする。
        ((tree_wt==CTX_CMDX0)) ||
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
        ble/syntax/parse/nest-push "$CTX_PATN"
        ((${#rematch2}>=2&&(_ble_syntax_attr[i+1]=CTX_CMDXC),
          i+=${#rematch2}))
      else
        # case: /hoge */ 恐らくコマンド

        # Note (#D2126): 実装当初 e1e87c2c (2015-02-26) から長らく解析中断点を
        # 置かずに一気に読み取っていたが、補完文脈生成で正しい文脈を再構築する
        # のが困難になるので、やはり解析中断点を単語末尾に置く事にする。正しく
        # lookahead を設定している限りは問題にならない筈。
        ble/syntax/parse/set-lookahead "$((${#rematch1}+1))"
      fi
    fi

    # 引数の取り扱いが特別な builtin
    case $word_expanded in
    ('declare'|'readonly'|'typeset'|'local'|'export'|'alias')
      ((ctx=CTX_ARGVX)) ;;
    ('eval')
      ((ctx=CTX_ARGEX)) ;;
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
      ble/syntax/parse/touch-updated-attr "$wbeg"
      ((_ble_syntax_attr[wbeg]=ATTR_ERR))
    fi
  fi

  if ((_ble_syntax_bash_command_EndCtx[ctx])); then
    ((ctx=_ble_syntax_bash_command_EndCtx[ctx]))
  fi

  return 0
}

## @arr _ble_syntax_bash_command_Opt
##   その場でコマンドが終わっても良いかどうかを設定する。
##   .check-delimiter-or-redirect で用いる。
_ble_syntax_bash_command_Opt=()
_ble_syntax_bash_command_Opt[CTX_ARGX]=1
_ble_syntax_bash_command_Opt[CTX_ARGX0]=1
_ble_syntax_bash_command_Opt[CTX_ARGVX]=1
_ble_syntax_bash_command_Opt[CTX_ARGEX]=1
_ble_syntax_bash_command_Opt[CTX_CMDX0]=1
_ble_syntax_bash_command_Opt[CTX_CMDXV]=1
_ble_syntax_bash_command_Opt[CTX_CMDXE]=1
_ble_syntax_bash_command_Opt[CTX_CMDXD0]=1

_ble_syntax_bash_is_command_form_for=

function ble/syntax:bash/ctx-command/.check-delimiter-or-redirect {
  if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs || $wbegin -lt 0 && $tail == $'\\\n'* ]]; then
    # 空白 or \ + 改行

    local spaces=$BASH_REMATCH
    if [[ $tail == $'\\\n'* ]]; then
      # \ + 改行は単純に無視
      spaces=$'\\\n'
    elif [[ $spaces == *$'\n'* ]]; then
      # 改行がある場合: ヒアドキュメントの確認 / 改行による文脈更新
      ble/syntax:bash/check-here-document-from "$spaces" && return 0
      if ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||ctx==CTX_ARGEX||ctx==CTX_CMDX0||ctx==CTX_CMDXV||ctx==CTX_CMDXT||ctx==CTX_CMDXE)); then
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
      ((ctx=CTX_CMDX0))
    elif ((ctx==CTX_FARGX3)); then
      ((_ble_syntax_attr[i]=ATTR_ERR))
    fi

    if [[ ${text:i+len} != [!$'\n|&()']* ]]; then
      # リダイレクトがその場で終わるときはそもそも nest-push せずエラー。
      # Note: 上の判定の文字集合は _ble_syntax_bash_RexDelimiter の部分集合。
      #   但し、空白類および <> はリダイレクトに含まれ得るので許容する。
      ((_ble_syntax_attr[i+len-1]=ATTR_ERR))
    else
      if [[ $rematch3 == '>&' ]]; then
        ble/syntax/parse/nest-push "$CTX_RDRD2" "$rematch3"
      elif [[ $rematch1 == *'&' ]]; then
        ble/syntax/parse/nest-push "$CTX_RDRD" "$rematch3"
      elif [[ $rematch1 == *'<<<' ]]; then
        ble/syntax/parse/nest-push "$CTX_RDRS" "$rematch3"
      elif [[ $rematch1 == *\<\< ]]; then
        # Note: emacs bug workaround
        #   '<<' と書くと何故か Emacs がヒアドキュメントと
        #   勘違いする様になったので仕方なく \<\< とする。
        ble/syntax/parse/nest-push "$CTX_RDRH" "$rematch3"
      elif [[ $rematch1 == *\<\<- ]]; then
        ble/syntax/parse/nest-push "$CTX_RDRI" "$rematch3"
      else
        ble/syntax/parse/nest-push "$CTX_RDRF" "$rematch3"
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
      ((ctx=_ble_bash>=50200||${#m}==1?CTX_CMDXE:CTX_ARGX0))
      [[ $_ble_syntax_bash_is_command_form_for && $tail == '(('* ]] && ((ctx=CTX_CMDXD0))
      ble/syntax/parse/nest-push "$((${#m}==1?CTX_CMDX1:CTX_EXPR))" "$m"
      ((i+=${#m}))
    else
      ble/syntax/parse/nest-push "$CTX_PATN"
      ((_ble_syntax_attr[i++]=ATTR_ERR))
    fi
    return 0
  elif [[ $tail == ')'* ]]; then
    local ntype
    ble/syntax/parse/nest-type
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
      ((_ble_syntax_attr[i]=(ctx==CTX_CMDX||ctx==CTX_CMDX0||ctx==CTX_CMDXV||ctx==CTX_CMDXE||ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||ctx==CTX_ARGEX)?attr:ATTR_ERR,
        i+=1))
      ble/syntax/parse/nest-pop
      return 0
    fi
  fi

  return 1
}

## @fn ble/syntax:bash/ctx-command/.check-word-begin
##   単語が未開始の場合に開始します。
##   @var[in,out] i,ctx,wtype,wbegin
##   @return 引数が来てはならない所に引数が来た時に 1 を返します。
_ble_syntax_bash_command_BeginCtx=()
_ble_syntax_bash_command_BeginCtx[CTX_ARGX]=$CTX_ARGI
_ble_syntax_bash_command_BeginCtx[CTX_ARGX0]=$CTX_ARGI
_ble_syntax_bash_command_BeginCtx[CTX_ARGVX]=$CTX_ARGVI
_ble_syntax_bash_command_BeginCtx[CTX_ARGEX]=$CTX_ARGEI
_ble_syntax_bash_command_BeginCtx[CTX_CMDX]=$CTX_CMDI
_ble_syntax_bash_command_BeginCtx[CTX_CMDX0]=$CTX_CMDI
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
_ble_syntax_bash_command_BeginCtx[CTX_CPATX]=$CTX_CPATI
_ble_syntax_bash_command_BeginCtx[CTX_CPATX0]=$CTX_CPATI
_ble_syntax_bash_command_BeginCtx[CTX_TARGX1]=$CTX_TARGI1
_ble_syntax_bash_command_BeginCtx[CTX_TARGX2]=$CTX_TARGI2
_ble_syntax_bash_command_BeginCtx[CTX_COARGX]=$CTX_COARGI

#%if !release
## @arr _ble_syntax_bash_command_isARGI[ctx]
##
##   assert 用の配列。シェル単語の解析中に現れても良い文脈値を管理する。この配
##   列要素が非空文字列のとき、その文脈はシェル単語の解析中に現れても良い。
##
_ble_syntax_bash_command_isARGI[CTX_CMDI]=1
_ble_syntax_bash_command_isARGI[CTX_VRHS]=1
_ble_syntax_bash_command_isARGI[CTX_ARGI]=1
_ble_syntax_bash_command_isARGI[CTX_ARGQ]=1
_ble_syntax_bash_command_isARGI[CTX_ARGVI]=1
_ble_syntax_bash_command_isARGI[CTX_ARGVR]=1
_ble_syntax_bash_command_isARGI[CTX_ARGEI]=1
_ble_syntax_bash_command_isARGI[CTX_ARGER]=1
_ble_syntax_bash_command_isARGI[CTX_FARGI1]=1 # var
_ble_syntax_bash_command_isARGI[CTX_FARGI2]=1 # in
_ble_syntax_bash_command_isARGI[CTX_FARGI3]=1 # args...
_ble_syntax_bash_command_isARGI[CTX_FARGQ3]=1 # args... (= の後)
_ble_syntax_bash_command_isARGI[CTX_CARGI1]=1 # value
_ble_syntax_bash_command_isARGI[CTX_CARGQ1]=1 # value (= の後)
_ble_syntax_bash_command_isARGI[CTX_CARGI2]=1 # in
_ble_syntax_bash_command_isARGI[CTX_CPATI]=1  # pattern
_ble_syntax_bash_command_isARGI[CTX_CPATQ]=1  # pattern
_ble_syntax_bash_command_isARGI[CTX_TARGI1]=1 # -p
_ble_syntax_bash_command_isARGI[CTX_TARGI2]=1 # --
_ble_syntax_bash_command_isARGI[CTX_COARGI]=1 # var (coproc の後)
#%end
# Detect the end of ${ list; }
function ble/syntax:bash/ctx-command/.check-funsub-end {
  ((_ble_bash>=50300)) || return 1

  # 新しいコマンド名が始まる文脈
  ((wbegin<0&&_ble_syntax_bash_command_BeginCtx[ctx]==CTX_CMDI)) || return 1

  [[ $tail == '}'* ]] || return 1

  local ntype
  ble/syntax/parse/nest-type
  [[ $ntype == 'cmdsub_nofork' ]] || return 1

  ((_ble_syntax_attr[i++]=_ble_syntax_attr[inest]))
  ble/syntax/parse/nest-pop
  return 0
}
function ble/syntax:bash/ctx-command/.check-word-begin {
  if ((wbegin<0)); then
    local octx
    ((octx=ctx,
      wtype=octx,
      ctx=_ble_syntax_bash_command_BeginCtx[ctx]))
#%if !release
    ble/util/assert '((ctx!=0))' "invalid ctx=$octx at the beginning of words" ||
      ((ctx=wtype=CTX_ARGI))
#%end

    # Note: ここで設定される wtype は最終的に ctx-command/check-word-end で
    #   配列 _ble_syntax_bash_command_EndWtype により変換されてから tree に登録される。
    ble/syntax/parse/word-push "$wtype" "$i"

    ((octx!=CTX_ARGX0&&octx!=CTX_CPATX0)); return "$?" # return unexpectedWbegin
  fi

#%if !release
  ble/util/assert '((_ble_syntax_bash_command_isARGI[ctx]))' "invalid ctx=$ctx in words"
#%end
  return 0
}

# コマンド・引数部分
function ble/syntax:bash/ctx-command {
#%if !release
  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    ble/util/assert '
      ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||ctx==CTX_ARGEX||
          ctx==CTX_FARGX2||ctx==CTX_FARGX3||ctx==CTX_COARGX||
          ctx==CTX_CMDX||ctx==CTX_CMDX0||ctx==CTX_CMDX1||ctx==CTX_CMDXT||ctx==CTX_CMDXC||
          ctx==CTX_CMDXE||ctx==CTX_CMDXD||ctx==CTX_CMDXD0||ctx==CTX_CMDXV))'  "invalid ctx=$ctx @ i=$i"
    ble/util/assert '((wbegin<0&&wtype<0))' "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
    ble/syntax:bash/ctx-command/.check-delimiter-or-redirect; return "$?"
  fi
#%else
  ble/syntax:bash/ctx-command/.check-delimiter-or-redirect && return 0
#%end

  ble/syntax:bash/check-comment && return 0

  ble/syntax:bash/ctx-command/.check-funsub-end && return 0

  local unexpectedWbegin=-1
  ble/syntax:bash/ctx-command/.check-word-begin || ((unexpectedWbegin=i))

  local wtype0=$wtype i0=$i

  local flagConsume=0
  if ble/syntax:bash/check-variable-assignment; then
    flagConsume=1
  elif local rex='^([^'${_ble_syntax_bash_chars[CTX_ARGI]}']+|\\.)'; [[ $tail =~ $rex ]]; then
    local rematch=$BASH_REMATCH
    local attr=$ctx
    [[ $BASH_REMATCH == '\'? ]] && attr=$ATTR_QESC
    ((_ble_syntax_attr[i]=attr,i+=${#rematch}))
    flagConsume=1
  elif ble/syntax:bash/check-process-subst; then
    flagConsume=1
  elif ble/syntax:bash/check-quotes; then
    flagConsume=1
  elif ble/syntax:bash/check-dollar; then
    flagConsume=1
  elif ble/syntax:bash/check-glob; then
    flagConsume=1
  elif ble/syntax:bash/check-brace-expansion; then
    flagConsume=1
  elif ble/syntax:bash/check-tilde-expansion; then
    flagConsume=1
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    flagConsume=1
  fi

  if ((flagConsume)); then
    ble/util/assert '((wtype0>=0))'

    if ((ctx==CTX_FARGI1)); then
      # for var in ... の var の部分は変数名をチェックして着色
      local rex='^[_a-zA-Z][_a-zA-Z0-9]*$' attr=$ATTR_ERR
      if ((i0==wbegin)) && [[ ${text:i0:i-i0} =~ $rex ]]; then
        local ret; ble/syntax/highlight/vartype "$BASH_REMATCH" global; attr=$ret
      fi
      ((_ble_syntax_attr[i0]=attr))
    fi

    [[ ${_ble_syntax_bash_command_Expect[wtype0]} ]] &&
      ((_ble_syntax_attr[i0]=ATTR_ERR))
    if ((unexpectedWbegin>=0)); then
      ble/syntax/parse/touch-updated-attr "$unexpectedWbegin"
      ((_ble_syntax_attr[unexpectedWbegin]=ATTR_ERR))
    fi
    return 0
  else
    return 1
  fi
}

function ble/syntax:bash/ctx-command-compound-expect {
  ble/util/assert '((ctx==CTX_FARGX1||ctx==CTX_SARGX1||ctx==CTX_CARGX1||ctx==CTX_FARGX2||ctx==CTX_CARGX2||ctx==CTX_COARGX))'
  local _ble_syntax_bash_is_command_form_for=
  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    # "for var in ... / case arg in" を処理している途中で delimiter が来た場合。
    if ((ctx==CTX_FARGX2)) && [[ $tail == [$';\n']* ]]; then
      # for var in ... の in 以降が省略された形である。
      # ble/syntax:bash/ctx-command で FARGX3 と同様に処理する。
      ble/syntax:bash/ctx-command
      return "$?"
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
    elif ((ctx!=CTX_COARGX)); then
      local i0=$i
      ((ctx=CTX_ARGX))
      ble/syntax:bash/ctx-command/.check-delimiter-or-redirect || ((i++))
      ((_ble_syntax_attr[i0]=ATTR_ERR))
      return 0
    fi
  fi

  # コメント禁止
  local i0=$i
  if ble/syntax:bash/check-comment; then
    if ((ctx==CTX_FARGX1||ctx==CTX_SARGX1||ctx==CTX_CARGX1||ctx==CTX_COARGX)); then
      # "for var / select var / case arg / coproc" を処理している途中でコメントが来た場合
      ((_ble_syntax_attr[i0]=ATTR_ERR))
    fi
    return 0
  fi

  # 他は同じ
  ble/syntax:bash/ctx-command
}

## @fn ble/syntax:bash/ctx-command-expect/.match-word word
##   現在位置から始まる単語が指定した単語に一致するかどうかを検査します。
##   @param[in] word
##   @var[in] tail i
function ble/syntax:bash/ctx-command-expect/.match-word {
  local word=$1 len=${#1}
  if [[ $tail == "$word"* ]]; then
    ble/syntax/parse/set-lookahead "$((len+1))"
    if ((${#tail}==len)) || i=$((i+len)) ble/syntax:bash/check-word-end/is-delimiter; then
      return 0
    fi
  fi
  return 1
}

function ble/syntax:bash/ctx-command-time-expect {
  ble/util/assert '((ctx==CTX_TARGX1||ctx==CTX_TARGX2))'

  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    ble/util/assert '((wbegin<0&&wtype<0))'
    if [[ $tail =~ ^$_ble_syntax_bash_RexSpaces ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      return 0
    else
      ((ctx=CTX_CMDXT))
      ble/syntax:bash/ctx-command/.check-delimiter-or-redirect; return "$?"
    fi
  fi

  # 期待する単語でない時は CTX_CMDXT に decay
  if ((ctx==CTX_TARGX1)); then
    # Note: bash-5.1 では "--" が来てもOKなので
    #   ctx=CTX_TARGX2 として次の if で処理させる。
    ble/syntax:bash/ctx-command-expect/.match-word '-p' ||
      ((ctx=_ble_bash>=50100?CTX_TARGX2:CTX_CMDXT))
  fi
  if ((ctx==CTX_TARGX2)); then
    ble/syntax:bash/ctx-command-expect/.match-word '--' ||
      ((ctx=CTX_CMDXT))
  fi

  # 他は同じ
  ble/syntax:bash/ctx-command
}

function ble/syntax:bash/ctx-command-case-pattern-expect {
  ble/util/assert '((ctx==CTX_CPATX||ctx==CTX_CPATX0))'

  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    local delimiter=$BASH_REMATCH
    if [[ $tail =~ ^$_ble_syntax_bash_RexSpaces ]]; then
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
    elif [[ $tail == '|'* ]]; then
      ((_ble_syntax_attr[i++]=ctx==CTX_CPATX?ATTR_ERR:ATTR_GLOB,ctx=CTX_CPATX))
    elif [[ $tail == ')'* ]]; then
      ((_ble_syntax_attr[i++]=ctx==CTX_CPATX?ATTR_ERR:ATTR_GLOB,ctx=CTX_CMDX))
    elif [[ $tail == '('* ]]; then
      # ctx-command と同様にエラーにして @() を始める。
      ble/syntax:bash/ctx-command/.check-delimiter-or-redirect
    else
      # 改行、リダイレクト、; & はエラー
      ((_ble_syntax_attr[i]=ATTR_ERR,i+=${#delimiter}))
    fi
    return "$?"
  fi

  # コメント禁止
  local i0=$i
  if ble/syntax:bash/check-comment; then
    ((_ble_syntax_attr[i0]=ATTR_ERR))
    return 0
  fi

  # 他は同じ
  ble/syntax:bash/ctx-command
}

#------------------------------------------------------------------------------
# 文脈: 配列値リスト
#

_ble_syntax_context_proc[CTX_VALX]=ble/syntax:bash/ctx-values
_ble_syntax_context_proc[CTX_VALI]=ble/syntax:bash/ctx-values
_ble_syntax_context_end[CTX_VALI]=ble/syntax:bash/ctx-values/check-word-end
_ble_syntax_context_proc[CTX_VALR]=ble/syntax:bash/ctx-values
_ble_syntax_context_end[CTX_VALR]=ble/syntax:bash/ctx-values/check-word-end
_ble_syntax_context_proc[CTX_VALQ]=ble/syntax:bash/ctx-values
_ble_syntax_context_end[CTX_VALQ]=ble/syntax:bash/ctx-values/check-word-end

## 文脈値 ctx-values
##
##   arr=() arr+=() から抜けた時にまた元の文脈値に復帰する必要があるので
##   nest-push, nest-pop で入れ子構造を一段作成する事にする。
##
##   但し、外側で設定されたヒアドキュメントを処理する為に工夫が必要である。
##   外側の nparam をそのまま利用しまた抜ける場合には外側の nparam に変更結果を適用する。
##   ble/syntax:bash/ctx-values/enter, leave はこの nparam の持ち越しに使用する。
##

## @fn ble/syntax:bash/ctx-values/enter
##   @remarks この関数は ble/syntax:bash/check-variable-assignment から呼ばれる。
function ble/syntax:bash/ctx-values/enter {
  local outer_nparam=$nparam
  ble/syntax/parse/nest-push "$CTX_VALX"
  nparam=$outer_nparam
}
## @fn ble/syntax:bash/ctx-values/leave
function ble/syntax:bash/ctx-values/leave {
  local inner_nparam=$nparam
  ble/syntax/parse/nest-pop
  nparam=$inner_nparam
}

## @fn ble/syntax:bash/ctx-values/check-word-end
function ble/syntax:bash/ctx-values/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  [[ ${text:i:1} == [!"$_ble_term_IFS;|&<>()"] ]] && return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}

  ble/syntax/parse/word-pop

  ble/util/assert '((ctx==CTX_VALI||ctx==CTX_VALR||ctx==CTX_VALQ))' 'invalid context'
  ((ctx=CTX_VALX))

  return 0
}

function ble/syntax:bash/ctx-values {
  # コマンド・引数部分
  if ble/syntax:bash/starts-with-delimiter; then
#%if !release
    ble/util/assert '((ctx==CTX_VALX))' "invalid ctx=$ctx @ i=$i"
    ble/util/assert '((wbegin<0&&wtype<0))' "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
#%end

    if [[ $tail =~ ^$_ble_syntax_bash_RexIFSs ]]; then
      local spaces=$BASH_REMATCH
      ble/syntax:bash/check-here-document-from "$spaces" && return 0

      # 空白 (ctx はそのままで素通り)
      ((_ble_syntax_attr[i]=ctx,i+=${#spaces}))
      return 0
    elif [[ $tail == ')'* ]]; then
      # 配列定義の終了
      ((_ble_syntax_attr[i++]=ATTR_DEL))
      ble/syntax:bash/ctx-values/leave
      return 0
    elif [[ $type == ';'* ]]; then
      ((_ble_syntax_attr[i++]=ATTR_ERR))
      return 0
    else
      ((_ble_syntax_attr[i++]=ATTR_ERR))
      return 0
    fi
  fi

  if ble/syntax:bash/check-comment; then
    return 0
  fi

  if ((wbegin<0)); then
    ((ctx=CTX_VALI))
    ble/syntax/parse/word-push "$ctx" "$i"
  fi

#%if !release
  ble/util/assert '((ctx==CTX_VALI||ctx==CTX_VALR||ctx==CTX_VALQ))' "invalid context ctx=$ctx"
#%end

  if ble/syntax:bash/check-variable-assignment; then
    return 0
  elif ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[CTX_ARGI]}]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/check-tilde-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  fi

  return 1
}

#------------------------------------------------------------------------------
# 文脈: [[ 条件式 ]]

_ble_syntax_context_proc[CTX_CONDX]=ble/syntax:bash/ctx-conditions
_ble_syntax_context_proc[CTX_CONDI]=ble/syntax:bash/ctx-conditions
_ble_syntax_context_end[CTX_CONDI]=ble/syntax:bash/ctx-conditions/check-word-end
_ble_syntax_context_proc[CTX_CONDQ]=ble/syntax:bash/ctx-conditions
_ble_syntax_context_end[CTX_CONDQ]=ble/syntax:bash/ctx-conditions/check-word-end

## @fn ble/syntax:bash/ctx-conditions/check-word-end
function ble/syntax:bash/ctx-conditions/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  [[ ${text:i:1} == [!"$_ble_term_IFS;|&<>()"] ]] && return 1

  local wbeg=$wbegin wlen=$((i-wbegin)) wend=$i
  local word=${text:wbegin:wlen}

  ble/syntax/parse/word-pop

  ble/util/assert '((ctx==CTX_CONDI||ctx==CTX_CONDQ))' 'invalid context'
  if [[ $word == ']]' ]]; then
    ble/syntax/parse/touch-updated-attr "$wbeg"
    ((_ble_syntax_attr[wbeg]=ATTR_DEL))
    ble/syntax/parse/nest-pop
  else
    ((ctx=CTX_CONDX))
  fi
  return 0
}

function ble/syntax:bash/ctx-conditions {
  # コマンド・引数部分
  if ble/syntax:bash/starts-with-delimiter; then
#%if !release
    ble/util/assert '((ctx==CTX_CONDX))' "invalid ctx=$ctx @ i=$i"
    ble/util/assert '((wbegin<0&&wtype<0))' "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
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

  ble/syntax:bash/check-comment && return 0

  if ((wbegin<0)); then
    ((ctx=CTX_CONDI))
    ble/syntax/parse/word-push "$ctx" "$i"
  fi

#%if !release
  ble/util/assert '((ctx==CTX_CONDI||ctx==CTX_CONDQ))' "invalid context ctx=$ctx"
#%end

  if ble/syntax:bash/check-variable-assignment; then
    return 0
  elif ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[CTX_ARGI]}]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/check-tilde-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
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

_ble_syntax_context_proc[CTX_RDRF]=ble/syntax:bash/ctx-redirect
_ble_syntax_context_proc[CTX_RDRD]=ble/syntax:bash/ctx-redirect
_ble_syntax_context_proc[CTX_RDRD2]=ble/syntax:bash/ctx-redirect
_ble_syntax_context_proc[CTX_RDRS]=ble/syntax:bash/ctx-redirect
_ble_syntax_context_end[CTX_RDRF]=ble/syntax:bash/ctx-redirect/check-word-end
_ble_syntax_context_end[CTX_RDRD]=ble/syntax:bash/ctx-redirect/check-word-end
_ble_syntax_context_end[CTX_RDRD2]=ble/syntax:bash/ctx-redirect/check-word-end
_ble_syntax_context_end[CTX_RDRS]=ble/syntax:bash/ctx-redirect/check-word-end
function ble/syntax:bash/ctx-redirect/check-word-begin {
  if ((wbegin<0)); then
    # ※解析の段階では CTX_RDRF/CTX_RDRD/CTX_RDRD2/CTX_RDRS の間に区別はない。
    #   但し、↓の行で解析に用いられた ctx が保存される。
    #   この情報は後で補完候補を生成するのに用いられる。
    ble/syntax/parse/word-push "$ctx" "$i"
    ble/syntax/parse/touch-updated-word "$i" #■これは不要では?
  fi
}
function ble/syntax:bash/ctx-redirect/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  ble/syntax:bash/check-word-end/is-delimiter || return 1

  # 単語の登録
  ble/syntax/parse/word-pop

  # pop
  ble/syntax/parse/nest-pop
#%if !release
  # ここで終端の必要のある ctx (CMDI や ARGI などの単語中の文脈) になる事は無い。
  # 何故なら push した時は CMDX か ARGX の文脈にいたはずだから。
  ble/util/assert '((!_ble_syntax_bash_command_isARGI[ctx]))' "invalid ctx=$ctx in words"
#%end
  return 0
}
function ble/syntax:bash/ctx-redirect {
  # redirect の直後にコマンド終了や別の redirect があってはならない
  if ble/syntax:bash/starts-with-delimiter-or-redirect; then
    ((_ble_syntax_attr[i++]=ATTR_ERR))
    [[ ${tail:1} =~ ^$_ble_syntax_bash_RexSpaces ]] &&
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
    return 0
  fi

  if local i0=$i; ble/syntax:bash/check-comment; then
    ((_ble_syntax_attr[i0]=ATTR_ERR))
    return 0
  fi

  # 単語開始の設置
  ble/syntax:bash/ctx-redirect/check-word-begin

  if ble/syntax:bash/check-plain-with-escape "[^${_ble_syntax_bash_chars[CTX_ARGI]}]+"; then
    return 0
  elif ble/syntax:bash/check-process-subst; then
    return 0
  elif ble/syntax:bash/check-quotes; then
    return 0
  elif ble/syntax:bash/check-dollar; then
    return 0
  elif ble/syntax:bash/check-glob; then
    return 0
  elif ble/syntax:bash/check-brace-expansion; then
    return 0
  elif ble/syntax:bash/check-tilde-expansion; then
    return 0
  elif ble/syntax:bash/starts-with-histchars; then
    ble/syntax:bash/check-history-expansion ||
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
function ble/syntax:bash/ctx-heredoc-word/initialize {
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
ble/syntax:bash/ctx-heredoc-word/initialize

## @fn ble/syntax:bash/ctx-heredoc-word/remove-quotes word
##   @var[out] delimiter
function ble/syntax:bash/ctx-heredoc-word/remove-quotes {
  local text=$1 result=

  local rex='^[^\$"'\'']+|^\$?["'\'']|^\\.?|^.'
  while [[ $text && $text =~ $rex ]]; do
    local rematch=$BASH_REMATCH
    if [[ $rematch == \" || $rematch == \$\" ]]; then
      if rex='^\$?"(([^\"]|\\.)*)(\\?$|")'; [[ $text =~ $rex ]]; then
        local str=${BASH_REMATCH[1]}
        local a b
        b='\`' a='`'; str=${str//"$b"/"$a"}
        b='\"' a='"'; str=${str//"$b"/"$a"} # WA #D1751 checked
        b='\$' a='$'; str=${str//"$b"/"$a"}
        b='\\' a='\'; str=${str//"$b"/"$a"}
        result=$result$str
        text=${text:${#BASH_REMATCH}}
        continue
      fi
    elif [[ $rematch == \' ]]; then
      if rex="^('[^']*)'?"; [[ $text =~ $rex ]]; then
        builtin eval "result=\$result${BASH_REMATCH[1]}'"
        text=${text:${#BASH_REMATCH}}
        continue
      fi
    elif [[ $rematch == \$\' ]]; then
      if rex='^(\$'\''([^\'\'']|\\.)*)('\''|\\?$)'; [[ $text =~ $rex ]]; then
        builtin eval "result=\$result${BASH_REMATCH[1]}'"
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

## @fn ble/syntax:bash/ctx-heredoc-word/remove-quotes delimiter
##   @var[out] escaped
function ble/syntax:bash/ctx-heredoc-word/escape-delimiter {
  local ret=$1
  if [[ $ret == *[\\\'$_ble_term_IFS$_ble_term_FS]* ]]; then
    local a b fs=$_ble_term_FS
    a=\\   ; b='\'$a; ret=${ret//"$a"/"$b"}
    a=\'   ; b='\'$a; ret=${ret//"$a"/"$b"}
    a=' '  ; b=$_ble_syntax_bash_heredoc_EscSP; ret=${ret//"$a"/"$b"}
    a=$'\t'; b=$_ble_syntax_bash_heredoc_EscHT; ret=${ret//"$a"/"$b"}
    a=$'\n'; b=$_ble_syntax_bash_heredoc_EscLF; ret=${ret//"$a"/"$b"}
    a=$fs  ; b=$_ble_syntax_bash_heredoc_EscFS; ret=${ret//"$a"/"$b"}
  fi
  escaped=$ret
}
function ble/syntax:bash/ctx-heredoc-word/unescape-delimiter {
  builtin eval "delimiter=\$'$1'"
}

## 文脈値 CTX_RDRH
##
##   @remarks
##     redirect と同様に nest-push と同時にこの文脈に入る事を想定する。
##
_ble_syntax_context_proc[CTX_RDRH]=ble/syntax:bash/ctx-heredoc-word
_ble_syntax_context_end[CTX_RDRH]=ble/syntax:bash/ctx-heredoc-word/check-word-end
_ble_syntax_context_proc[CTX_RDRI]=ble/syntax:bash/ctx-heredoc-word
_ble_syntax_context_end[CTX_RDRI]=ble/syntax:bash/ctx-heredoc-word/check-word-end
function ble/syntax:bash/ctx-heredoc-word/check-word-end {
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  ble/syntax:bash/check-word-end/is-delimiter || return 1

  # word = "EOF" 等の終端文字列
  local octx=$ctx word=${text:wbegin:i-wbegin}

  # 終了処理
  ble/syntax/parse/word-pop
  ble/syntax/parse/nest-pop

  local I
  if ((octx==CTX_RDRI)); then I=I; else I=R; fi

  local Q delimiter
  if [[ $word == *[\'\"\\]* ]]; then
    Q=Q; ble/syntax:bash/ctx-heredoc-word/remove-quotes "$word"
  else
    Q=H; delimiter=$word
  fi

  local escaped; ble/syntax:bash/ctx-heredoc-word/escape-delimiter "$delimiter"
  nparam=$nparam$_ble_term_FS@$I$Q$escaped
  return 0
}
function ble/syntax:bash/ctx-heredoc-word {
  ble/syntax:bash/ctx-redirect
}

## 文脈値 CTX_HERE0, CTX_HERE1
##
##   nest-push された環境で評価される。
##   nparam =~ [RI][QH]delimiter の形式を持つ。
##
_ble_syntax_context_proc[CTX_HERE0]=ble/syntax:bash/ctx-heredoc-content
_ble_syntax_context_proc[CTX_HERE1]=ble/syntax:bash/ctx-heredoc-content
function ble/syntax:bash/ctx-heredoc-content {
  local indented= quoted= delimiter=
  ble/syntax:bash/ctx-heredoc-word/unescape-delimiter "${nparam:2}"
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
      ble/syntax/parse/nest-pop
      return 0
    fi
  fi

  if [[ $quoted ]]; then
    ble/util/assert '((ctx==CTX_HERE0))'
    ((_ble_syntax_attr[i]=CTX_HERE0,i+=${#BASH_REMATCH}))
    return 0
  else
    ((ctx=CTX_HERE1))

    # \? 及び $? ${} $(()) $[] $() ``
    if rex='^(\\[\$`'$lf'])|^([^'${_ble_syntax_bash_chars[CTX_HERE1]}']|\\[^\$`'$lf'])+'$lf'?|^'$lf && [[ $tail =~ $rex ]]; then
      if [[ ${BASH_REMATCH[1]} ]]; then
        ((_ble_syntax_attr[i]=ATTR_QESC))
      else
        ((_ble_syntax_attr[i]=CTX_HERE0))
        [[ $BASH_REMATCH == *"$lf" ]] && ((ctx=CTX_HERE0))
      fi
      ((i+=${#BASH_REMATCH}))
      return 0
    fi

    if ble/syntax:bash/check-dollar; then
      return 0
    elif [[ $tail == '`'* ]] && ble/syntax:bash/check-quotes; then
      return 0
    elif ble/syntax:bash/starts-with-histchars; then
      ble/syntax:bash/check-history-expansion ||
        ((_ble_syntax_attr[i]=CTX_HERE0,i++))
      return 0
    else
      # 単独の $ や終端の \ など?
      ((_ble_syntax_attr[i]=CTX_HERE0,i++))
      return 0
    fi
  fi
}

#------------------------------------------------------------------------------
# Utilities based on syntactic structures

function ble/syntax:bash/is-complete {
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
    ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_ARGVX||ctx==CTX_ARGEX||
        ctx==CTX_CMDX||ctx==CTX_CMDX0||ctx==CTX_CMDXT||ctx==CTX_CMDXE||ctx==CTX_CMDXV||
        ctx==CTX_TARGX1||ctx==CTX_TARGX2)) || return 1
  fi

  # 構文 if..fi, etc が閉じているか?
  local attrs ret
  IFS= builtin eval 'attrs="::${_ble_syntax_attr[*]/%/::}"' # WA #D1570 checked
  ble/string#count-string "$attrs" ":$ATTR_KEYWORD_BEGIN:"; local nbeg=$ret
  ble/string#count-string "$attrs" ":$ATTR_KEYWORD_END:"; local nend=$ret
  ((nbeg>nend)) && return 1

  return 0
}

## @fn ble/syntax:bash/find-end-of-array-index beg end
##   "配列添字の綴じ括弧 ] の直前の位置" を求めます。
##   @param[in] beg
##     配列要素の添字指定の開始位置 ("[" の位置) を指定します。
##   @param[in] end
##     探索の終端位置を指定します。
##   @var[out] ret
##     beg に対応する "]" の位置を返します。
##     対応する終端がない場合は空文字列を返します。
function ble/syntax:bash/find-end-of-array-index {
  local beg=$1 end=$2
  ret=

  local inest0=$beg nest0
  [[ ${_ble_syntax_nest[inest0]} ]] || return 1

  local q stat1 nlen1 inest1 r=
  for ((q=inest0+1;q<end;q++)); do
    local stat1=${_ble_syntax_stat[q]}
    [[ $stat1 ]] || continue
    ble/string#split-words stat1 "$stat1"
    ((nlen1=stat1[3])) # (workaround Bash-4.2 segfault)
    ((inest1=nlen1<0?nlen1:q-nlen1))
    ((inest1<inest0)) && break
    ((r=q))
  done

  [[ ${_ble_syntax_text:r:end-r} == ']'* ]] && ret=$r
  [[ $ret ]]
}

## ble/syntax:bash/find-rhs wtype wbeg wlen opts
##   変数代入の形式の右辺の開始位置を取得します。
##   @param[in] wtype wbeg wlen
##   @param[in] opts
##     element-assignment
##       配列要素の場合にも変数代入の形式を許します。
##     long-option
##       --long-option= の形式にも強制的に対応します。
##   @var[out] ret
##     右辺の開始位置を返します。
##     変数代入の形式でない時には単語の開始位置を返します。
##   @exit
##     単語が変数代入の形式を持つ時に成功します。
##     それ以外の場合に失敗します。
function ble/syntax:bash/find-rhs {
  local wtype=$1 wbeg=$2 wlen=$3 opts=$4

  local text=$_ble_syntax_text
  local word=${text:wbeg:wlen} wend=$((wbeg+wlen))

  local rex=
  if ((wtype==ATTR_VAR)); then
    rex='^[_a-zA-Z0-9]+(\+?=|\[)'
  elif ((wtype==CTX_VALI)); then
    if [[ :$opts: == *:element-assignment:* ]]; then
      # 配列要素に対しても変数代入の形式を許す
      rex='^[_a-zA-Z0-9]+(\+?=|\[)|^(\[)'
    else
      rex='^(\[)'
    fi
  fi
  if [[ :$opts: == *:long-option:* ]]; then
    rex=${rex:+$rex'|'}'^--[-_a-zA-Z0-9]+='
  fi

  if [[ $rex && $word =~ $rex ]]; then
    local last_char=${BASH_REMATCH:${#BASH_REMATCH}-1}
    if [[ $last_char == '[' ]]; then
      # wtype==ATTR_VAR: arr[0]=x@ arr[1]+=x@
      # wtype==ATTR_VAR: declare arr[0]=x@ arr[1]+=x@
      # wtype==CTX_VALI: arr=([0]=x@ [1]+=x@)
      local p1=$((wbeg+${#BASH_REMATCH}-1))
      if ble/syntax:bash/find-end-of-array-index "$p1" "$wend"; then
        local p2=$ret
        case ${text:p2:wend-p2} in
        (']='*)  ((ret=p2+2)); return 0 ;;
        (']+='*) ((ret=p2+3)); return 0 ;;
        esac
      fi
    else
      # wtype==ATTR_VAR: var=x@ var+=x@
      # wtype==ATTR_VAR: declare var=x@ var+=x@
      ((ret=wbeg+${#BASH_REMATCH}))
      return 0
    fi
  fi

  ret=$wbeg
  return 1
}

#==============================================================================
# 解析部

_ble_syntax_vanishing_word_umin=-1
_ble_syntax_vanishing_word_umax=-1
function ble/syntax/vanishing-word/register {
  local tree_array=$1 tofs=$2
  local beg=$3 end=$4 lbeg=$5 lend=$6
  (((beg<=0)&&(beg=1)))

  local node i nofs
  for ((i=end;i>=beg;i--)); do
    builtin eval "node=(\${$tree_array[tofs+i-1]})"
    ((${#node[@]})) || continue
    for ((nofs=0;nofs<${#node[@]};nofs+=_ble_syntax_TREE_WIDTH)); do
      local wtype=${node[nofs]} wlen=${node[nofs+1]}
      local wbeg=$((wlen<0?wlen:i-wlen)) wend=$i

      ((wbeg<lbeg&&(wbeg=lbeg),
        wend>lend&&(wend=lend)))
      ble/syntax/urange#update _ble_syntax_vanishing_word_ "$wbeg" "$wend"
    done
  done
}

#----------------------------------------------------------
# shift

## @var[in] shift2_j
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift.stat {
  if [[ ${_ble_syntax_stat[shift2_j]} ]]; then
    local -a stat; ble/string#split-words stat "${_ble_syntax_stat[shift2_j]}"

    local k klen kbeg
    for k in 1 3 4 5; do # wlen nlen tclen tplen
      (((klen=stat[k])<0)) && continue
      ((kbeg=shift2_j-klen))
      if ((kbeg<beg)); then
        ((stat[k]+=shift))
      elif ((kbeg<end0)); then
        ((stat[k]-=end0-kbeg))
      fi
    done

    _ble_syntax_stat[shift2_j]="${stat[*]}"
  fi
}

## @var[in] node,shift2_j,nofs
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift.tree/1 {
  local k klen kbeg
  for k in 1 2 3; do # wlen/nlen tclen tplen
    ((klen=node[nofs+k]))
    ((klen<0||(kbeg=shift2_j-klen)>end0)) && continue
    # 長さが変化した時 (k==1)、または構文木の距離変化があった時 (k==2, k==3) にここへ来る。

    # (1) 単語の中身が変化した事を記録
    #   node の中身が書き換わった時 (wbegin < end0 の時):
    #   dirty 拡大の代わりに _ble_syntax_word_umax に登録するに留める。
    if [[ $k == 1 && ${node[nofs]} =~ ^[0-9]$ ]]; then
      ble/syntax/parse/touch-updated-word "$shift2_j"

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

## @var[in] shift2_j
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift.tree {
  [[ ${_ble_syntax_tree[shift2_j-1]} ]] || return 1
  local -a node
  ble/string#split-words node "${_ble_syntax_tree[shift2_j-1]}"

  local nofs
  if [[ $1 ]]; then
    nofs=$1 ble/syntax/parse/shift.tree/1
  else
    for ((nofs=0;nofs<${#node[@]};nofs+=_ble_syntax_TREE_WIDTH)); do
      ble/syntax/parse/shift.tree/1
    done
  fi

  _ble_syntax_tree[shift2_j-1]="${node[*]}"
}

## @var[in] shift2_j
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift.nest {
  # stat の先頭以外でも nest-push している
  #   @ ctx-command/check-word-begin の "関数名 ( " にて。
  if [[ ${_ble_syntax_nest[shift2_j]} ]]; then
    local -a nest
    ble/string#split-words nest "${_ble_syntax_nest[shift2_j]}"

    local k klen kbeg
    for k in 1 3 4 5; do
      (((klen=nest[k])))
      ((klen<0||(kbeg=shift2_j-klen)<0)) && continue
      if ((kbeg<beg)); then
        ((nest[k]+=shift))
      elif ((kbeg<end0)); then
        ((nest[k]-=end0-kbeg))
      fi
    done

    _ble_syntax_nest[shift2_j]="${nest[*]}"
  fi
}

function ble/syntax/parse/shift.impl2/.shift-until {
  local limit=$1
  while ((shift2_j>=limit)); do
#%if !release
    [[ $bleopt_syntax_debug ]] && _ble_syntax_stat_shift[shift2_j+shift]=1
#%end
    ble/syntax/parse/shift.stat
    ble/syntax/parse/shift.nest
    ((shift2_j--))
  done
}

## @fn ble/syntax/parse/shift.impl2/.proc1
##
## @var[in] TE_i
##   tree-enumerate によって設定される変数です。
##   現在処理している単語の終端境界を表します。
##   単語の情報は _ble_syntax_tree[TE_i-1] に格納されています。
##
## @var[in,out] shift2_j  何処まで処理したかを格納します。
##
## @var[in]     i1,i2,j2,iN
## @var[in]     beg,end,end0,shift
##   これらの変数は更に子関数で使用されます。
##
function ble/syntax/parse/shift.impl2/.proc1 {
  if ((TE_i<j2)); then
    ((tprev=-1)) # 中断
    return 0
  fi

  ble/syntax/parse/shift.impl2/.shift-until "$((TE_i+1))"
  ble/syntax/parse/shift.tree "$TE_nofs"

  if ((tprev>end0&&wbegin>end0)) && [[ ${wtype//[0-9]} ]]; then
    # skip 可能
    #   単語 (wtype=整数) の時は、nlen が外部に参照を持つ可能性がある。
    #   tprev<=end0 の場合、stat の中の tplen が shift 対象の可能性がある事に注意する。
#%if !release
    [[ $bleopt_syntax_debug ]] && _ble_syntax_stat_shift[shift2_j+shift]=1
#%end
    ble/syntax/parse/shift.stat
    ble/syntax/parse/shift.nest
    ((shift2_j=wbegin)) # skip
  elif ((tchild>=0)); then
    ble/syntax/tree-enumerate-children ble/syntax/parse/shift.impl2/.proc1
  fi
}

function ble/syntax/parse/shift.method1 {
  # shift (shift は毎回やり切る。途中状態で抜けたりはしない)
  local i j
  for ((i=i2,j=j2;i<=iN;i++,j++)); do
    # 注意: データの範囲
    #   stat[i]   は i in [0,iN]
    #   attr[i]   は i in [0,iN)
    #   tree[i-1] は i in (0,iN]
    local shift2_j=$j
    ble/syntax/parse/shift.stat
    ((j>0))  && ble/syntax/parse/shift.tree
    ((i<iN)) && ble/syntax/parse/shift.nest
  done
}

function ble/syntax/parse/shift.method2 {
#%if !release
  [[ $bleopt_syntax_debug ]] && _ble_syntax_stat_shift=()
#%end

  local iN=${#_ble_syntax_text} # tree-enumerate 起点は (古い text の長さ) である
  local shift2_j=$iN # proc1 に渡す変数
  ble/syntax/tree-enumerate ble/syntax/parse/shift.impl2/.proc1
  ble/syntax/parse/shift.impl2/.shift-until "$j2" # 未処理部分
}

## @var[in] i1,i2,j2,iN
## @var[in] beg,end,end0,shift
function ble/syntax/parse/shift {
  # ※shift==0 でも更新で消滅した部分を縮める必要があるので
  #   shift 実行する必要がある。

  # ble/syntax/parse/shift.method1 # 直接探索
  ble/syntax/parse/shift.method2 # tree-enumerate による skip

  if ((shift!=0)); then
    # 更新範囲の shift
    ble/syntax/urange#shift _ble_syntax_attr_
    ble/syntax/wrange#shift _ble_syntax_word_
    ble/syntax/wrange#shift _ble_syntax_word_defer_
    ble/syntax/urange#shift _ble_syntax_vanishing_word_
  fi
}

#----------------------------------------------------------
# parse

_ble_syntax_dbeg=-1 _ble_syntax_dend=-1

## @fn ble/syntax/parse/determine-parse-range
##
##   @var[out] i1 i2 j2
##
##   @var[in] beg end end0
##   @var[in] _ble_syntax_dbeg
##   @var[in] _ble_syntax_dend
##     文字列の変更範囲と、前回の解析でやり残した範囲を指定します。
##
function ble/syntax/parse/determine-parse-range {
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
  ble/util/assert '((0<=i1&&i1<=beg&&end<=i2&&i2<=iN))' "X2 0 <= $i1 <= $beg <= $end <= $i2 <= $iN"
#%end
}

function ble/syntax/parse/check-end {
  [[ ${_ble_syntax_context_end[ctx]} ]] && "${_ble_syntax_context_end[ctx]}"
}

## @fn ble/syntax/parse text opts [beg end end0]
##
##   @param[in]     text
##     解析対象の文字列を指定します。
##
##   @param[in]     opts
##     細かい動作を制御するオプションを指定します。
##
##   @param[in]     beg                text変更範囲 開始点 (既定値 = text先頭)
##   @param[in]     end                text変更範囲 終了点 (既定値 = text末端)
##   @param[in]     end0               長さが変わった時用 (既定値 = end)
##     これらの引数はtextに変更があった場合にその範囲を伝達するのに用います。
##
##   @var  [in,out] _ble_syntax_dbeg   解析予定範囲 開始点 (初期値 -1 = 解析予定無し)
##   @var  [in,out] _ble_syntax_dend   解析予定範囲 終了点 (初期値 -1 = 解析予定無し)
##     これらの変数はどの部分を解析する必要があるかを記録します。
##     beg end beg2 end2 を用いてtextの変更範囲を指定しても、
##     その変更範囲に対する解析を即座に完了させる訳ではなく逐次更新します。
##     ここには前回の parse 呼出でやり残した解析範囲の情報が格納されます。
##
##   @var  [in,out] _ble_syntax_stat[] (内部使用) 解析途中状態を記録
##   @var  [in,out] _ble_syntax_nest[] (内部使用) 入れ子の構造を記録
##   @var  [in,out] _ble_syntax_attr[] 各文字の属性
##   @var  [in,out] _ble_syntax_tree[] シェル単語の情報を記録
##     これらの変数には解析結果が格納されます。
##
##   @var  [in,out] _ble_syntax_attr_umin
##   @var  [in,out] _ble_syntax_attr_umax
##   @var  [in,out] _ble_syntax_word_umin
##   @var  [in,out] _ble_syntax_word_umax
##     今回の呼出によって文法的な解釈の変更が行われた範囲を更新します。
##
function ble/syntax/parse {
  local text=$1 iN=${#1}
  local opts=$2
  local beg=${3:-0} end=${4:-$iN} end0=${5:-0}
  ((end==beg&&end0==beg&&_ble_syntax_dbeg<0)) && return 0

  local IFS=$_ble_term_IFS

  local shift=$((end-end0))
#%if !release
  ble/util/assert \
    '((0<=beg&&beg<=end&&end<=iN&&beg<=end0))' \
    "X1 0 <= beg:$beg <= end:$end <= iN:$iN, beg:$beg <= end0:$end0 (shift=$shift text=$text)" ||
    ((beg=0,end=iN))
#%else
  ((0<=beg&&beg<=end&&end<=iN&&beg<=end0)) || ((beg=0,end=iN))
#%end

  # 解析予定範囲の更新
  #   @var i1 解析範囲開始
  #   @var i2 解析必要範囲終端 (此処以降で文脈が一致した時に解析終了)
  #   @var j2 シフト前の解析終端
  local i1 i2 j2
  ble/syntax/parse/determine-parse-range

  ble/syntax/vanishing-word/register _ble_syntax_tree 0 "$i1" "$j2" 0 "$i2"

  ble/syntax/parse/shift

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
    ble/syntax:"$_ble_syntax_lang"/initialize-ctx # ctx 初期化
    wbegin=-1       ##!< シェル単語内にいる時、シェル単語の開始位置
    wtype=-1        ##!< シェル単語内にいる時、シェル単語の種類
    inest=-1        ##!< 入れ子の時、親の開始位置
    tchild=-1
    tprev=-1
    nparam=
    ilook=1
  fi

  # 前回までに解析が終わっている部分 [0,i1), [i2,iN)
  local -a tail_syntax_stat tail_syntax_tree tail_syntax_nest tail_syntax_attr
  tail_syntax_stat=("${_ble_syntax_stat[@]:j2:iN-i2+1}")
  tail_syntax_tree=("${_ble_syntax_tree[@]:j2:iN-i2}")
  tail_syntax_nest=("${_ble_syntax_nest[@]:j2:iN-i2}")
  tail_syntax_attr=("${_ble_syntax_attr[@]:j2:iN-i2}")
  ble/array#reserve-prototype "$iN"
  _ble_syntax_stat=("${_ble_syntax_stat[@]::i1}" "${_ble_array_prototype[@]:i1:iN-i1}") # 再開用データ
  _ble_syntax_tree=("${_ble_syntax_tree[@]::i1}" "${_ble_array_prototype[@]:i1:iN-i1}") # 単語
  _ble_syntax_nest=("${_ble_syntax_nest[@]::i1}" "${_ble_array_prototype[@]:i1:iN-i1}") # 入れ子の親
  _ble_syntax_attr=("${_ble_syntax_attr[@]::i1}" "${_ble_array_prototype[@]:i1:iN-i1}") # 文脈・色とか

  ble/syntax:"$_ble_syntax_lang"/initialize-vars

  # 解析
  _ble_syntax_text=$text
  local i sstat tail
#%if !release
  local debug_p1
#%end
  for ((i=i1;i<iN;)); do
    ble/syntax/parse/serialize-stat
    if ((i>=i2)) && [[ ${tail_syntax_stat[i-i2]} == "$sstat" ]]; then
      if ble/syntax/parse/nest-equals "$inest"; then
        # 前回の解析と同じ状態になった時 → 残りは前回の結果と同じ
        _ble_syntax_stat=("${_ble_syntax_stat[@]::i}" "${tail_syntax_stat[@]:i-i2}")
        _ble_syntax_tree=("${_ble_syntax_tree[@]::i}" "${tail_syntax_tree[@]:i-i2}")
        _ble_syntax_nest=("${_ble_syntax_nest[@]::i}" "${tail_syntax_nest[@]:i-i2}")
        _ble_syntax_attr=("${_ble_syntax_attr[@]::i}" "${tail_syntax_attr[@]:i-i2}")
        break
      fi
    fi
    _ble_syntax_stat[i]=$sstat

    tail=${text:i}
#%if !release
    debug_p1=$i
#%end
    # 処理
    "${_ble_syntax_context_proc[ctx]}" || ((_ble_syntax_attr[i]=ATTR_ERR,i++))

    # nest-pop で CMDI/ARGI になる事もあるし、
    # また単語終端な文字でも FCTX が失敗する事もある (unrecognized な場合) ので、
    # (FCTX の中や直後ではなく) ここで単語終端をチェック
    ble/syntax/parse/check-end
  done
#%if !release
  builtin unset -v debug_p1
#%end

  ble/syntax/vanishing-word/register tail_syntax_tree "$((-i2))" "$((i2+1))" "$i" 0 "$i"

  ble/syntax/urange#update _ble_syntax_attr_ "$i1" "$i"

  (((i>=i2)?(
      _ble_syntax_dbeg=_ble_syntax_dend=-1
    ):(
      _ble_syntax_dbeg=i,_ble_syntax_dend=i2)))

  # 終端の状態の記録
  if ((i>=iN)); then
    ((i=iN))
    ble/syntax/parse/serialize-stat
    _ble_syntax_stat[i]=$sstat

    # ネスト開始点のエラー表示は +syntax 内で。
    # ここで設定すると部分更新の際に取り消しできないから。
    if ((inest>0)); then
      ((_ble_syntax_attr[iN-1]=ATTR_ERR))
      while ((inest>=0)); do
        ((i=inest))
        ble/syntax/parse/nest-pop
        ((inest>=i&&(inest=i-1)))
      done
    fi
  fi

#%if !release
  ble/util/assert \
    '((${#_ble_syntax_stat[@]}==iN+1))' \
    "unexpected array length #arr=${#_ble_syntax_stat[@]} (expected to be $iN), #proto=${#_ble_array_prototype[@]} should be >= $iN"
#%end
}

## @fn ble/syntax/highlight text [lang]
##   @param[in] text
##   @param[in] lang
##   @var[out] ret
function ble/syntax/highlight {
  local text=$1 lang=${2:-bash} cache_prefix=$3

  local -a _ble_highlight_layer_list=(plain syntax)
  local -a vars=()
  ble/array#push vars "${_ble_syntax_VARNAMES[@]}"
  ble/array#push vars "${_ble_highlight_layer_plain_VARNAMES[@]}"
  ble/array#push vars "${_ble_highlight_layer_syntax_VARNAMES[@]}"

  local "${vars[@]/%/=}" # WA #D1570 checked
  if [[ $cache_prefix ]] && ((${cache_prefix}_INITIALIZED++)); then
    ble/util/restore-vars "$cache_prefix" "${vars[@]}"

    ble/string#common-prefix "$_ble_syntax_text" "$text"
    local beg=${#ret}
    ble/string#common-suffix "${_ble_syntax_text:beg}" "${text:beg}"
    local end=$((${#text}-${#ret})) end0=$((${#_ble_syntax_text}-${#ret}))
  else
    ble/syntax/initialize-vars
    ble/highlight/layer:plain/initialize-vars
    ble/highlight/layer:syntax/initialize-vars
    _ble_syntax_lang=$lang
    local beg=0 end=${#text} end0=0
  fi

  ble/syntax/parse "$text" '' "$beg" "$end" "$end0"

  local HIGHLIGHT_BUFF HIGHLIGHT_UMIN HIGHLIGHT_UMAX
  ble/highlight/layer/update "$text" '' "$beg" "$end" "$end0"
  IFS= builtin eval "ret=\"\${$HIGHLIGHT_BUFF[*]}\""

  [[ $cache_prefix ]] &&
    ble/util/save-vars "$cache_prefix" "${vars[@]}"
  return 0
}

#==============================================================================
#
# syntax-complete
#
#==============================================================================

# ## @fn ble/syntax/getattr index
# function ble/syntax/getattr {
#   local i
#   attr=
#   for ((i=$1;i>=0;i--)); do
#     if [[ ${_ble_syntax_attr[i]} ]]; then
#       ((attr=_ble_syntax_attr[i]))
#       return 0
#     fi
#   done
#   return 1
# }

# ## @fn ble/syntax/getstat index
# function ble/syntax/getstat {
#   local i
#   for ((i=$1;i>=0;i--)); do
#     if [[ ${_ble_syntax_stat[i]} ]]; then
#       ble/string#split-words stat "${_ble_syntax_stat[i]}"
#       return 0
#     fi
#   done
#   return 1
# }

function ble/syntax/completion-context/add {
  local source=$1
  local comp1=$2
  ble/util/assert '[[ $source && comp1 -ge 0 ]]'
  sources[${#sources[*]}]="$source $comp1"
}

## @fn ble/syntax/completion-context/.check/parameter-expansion
##   @var[in] text istat index ctx
function ble/syntax/completion-context/.check/parameter-expansion {
  local rex_paramx='^(\$(\{[!#]?)?)([_a-zA-Z][_a-zA-Z0-9]*)?$'
  if [[ ${text:istat:index-istat} =~ $rex_paramx ]]; then
    local rematch1=${BASH_REMATCH[1]}
    local source=variable
    if [[ $rematch1 == '${'* ]]; then
      source=variable:b # suffix }
    elif ((ctx==CTX_BRACE1||ctx==CTX_BRACE2)); then
      source=variable:n # no suffix
    fi
    ble/syntax/completion-context/add "$source" "$((istat+${#rematch1}))"
  fi
}

## @fn ble/syntax/completion-context/prefix:*
##
##   @var[in] text index
##     補完対象のコマンドラインと現在のカーソルの位置を指定します。
##
##   @var[in] istat stat
##     直前の解析再開点の位置と記録されている情報を指定します。
##
##   @var[in] ctx wbeg wlen
##     直前の解析再開点の文脈・単語開始点・
##     直前の解析再開点に於ける単語の長さを指定します。
##
##   @var[in] rex_param
##

## @fn ble/syntax/completion-context/prefix:inside-command
##   CMDI 系統 (コマンドの続き) の文脈に対する補完文脈の生成
_ble_syntax_completion_context_check_prefix[CTX_CMDI]=inside-command
function ble/syntax/completion-context/prefix:inside-command {
  if ((wlen>=0)); then
    ble/syntax/completion-context/add command "$wbeg"
  fi
  ble/syntax/completion-context/.check/parameter-expansion
}
## @fn ble/syntax/completion-context/prefix:inside-argument source
##   ARGI 系統 (引数の続き) の文脈に対する補完文脈の生成
##   @param[in] source
_ble_syntax_completion_context_check_prefix[CTX_ARGI]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[CTX_ARGQ]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[CTX_FARGI1]='inside-argument variable:w'
_ble_syntax_completion_context_check_prefix[CTX_FARGI3]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[CTX_FARGQ3]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[CTX_CARGI1]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[CTX_CARGQ1]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[CTX_CPATI]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[CTX_CPATQ]='inside-argument argument'
_ble_syntax_completion_context_check_prefix[CTX_COARGI]='inside-argument variable command:V'
_ble_syntax_completion_context_check_prefix[CTX_VALI]='inside-argument sabbrev file'
_ble_syntax_completion_context_check_prefix[CTX_VALQ]='inside-argument sabbrev file'
_ble_syntax_completion_context_check_prefix[CTX_CONDI]='inside-argument sabbrev file option'
_ble_syntax_completion_context_check_prefix[CTX_CONDQ]='inside-argument sabbrev file'
_ble_syntax_completion_context_check_prefix[CTX_ARGVI]='inside-argument sabbrev variable:='
_ble_syntax_completion_context_check_prefix[CTX_ARGEI]='inside-argument command:D file'
function ble/syntax/completion-context/prefix:inside-argument {
  if ((wlen>=0)); then
    local source
    for source; do
      ble/syntax/completion-context/add "$source" "$wbeg"
      if [[ $source != argument ]]; then
        local sub=${text:wbeg:index-wbeg}
        if [[ $sub == *[=:]* ]]; then
          sub=${sub##*[=:]}
          ble/syntax/completion-context/add "$source" "$((index-${#sub}))"
        fi
      fi
    done
  fi
  ble/syntax/completion-context/.check/parameter-expansion
}

## @fn ble/syntax/completion-context/prefix:next-command
##   CMDX 系統の文脈に対する補完文脈の生成
_ble_syntax_completion_context_check_prefix[CTX_CMDX]=next-command
_ble_syntax_completion_context_check_prefix[CTX_CMDX1]=next-command
_ble_syntax_completion_context_check_prefix[CTX_CMDXT]=next-command
_ble_syntax_completion_context_check_prefix[CTX_CMDXV]=next-command
function ble/syntax/completion-context/.check-prefix/.test-redirection {
  ##   @var[in] index
  local word=$1
  [[ $word =~ ^$_ble_syntax_bash_RexRedirect$ ]] || return 1
  # 文法的に元々リダイレクトは許されない
  ((ctx==CTX_CMDXC||ctx==CTX_CMDXD||ctx==CTX_CMDXD0||ctx==CTX_FARGX3)) && return 0

  local rematch3=${BASH_REMATCH[3]}
  case $rematch3 in
  ('>&')
    ble/syntax/completion-context/add fd "$index"
    ble/syntax/completion-context/add file:no-fd "$index" ;;
  (*'&')
    ble/syntax/completion-context/add fd "$index" ;;
  ('<<'|'<<-')
    ble/syntax/completion-context/add wordlist:EOF:END:HERE "$index" ;;
  ('<<<'|*)
    ble/syntax/completion-context/add file "$index" ;;
  esac
  return 0
}
function ble/syntax/completion-context/prefix:next-command {
  # 直前の再開点が CMDX だった場合、
  # 現在地との間にコマンド名があればそれはコマンドである。
  # スペースや ;&| 等のコマンド以外の物がある可能性もある事に注意する。
  local word=${text:istat:index-istat}

  # コマンドのチェック
  if ble/syntax:bash/simple-word/is-simple-or-open-simple "$word"; then
    # 単語が istat から開始している場合
    ble/syntax/completion-context/add command "$istat"

    # 変数・代入のチェック
    if ble/string#match "$word" '^[_a-zA-Z][_a-zA-Z0-9]*\+?=$'; then
      if ((_ble_bash>=30100)) || [[ $word != *+= ]]; then
        # VAR=<argument>: 現在位置から argument 候補を生成する
        ble/syntax/completion-context/add argument "$index"
      fi
    fi
  elif ble/syntax/completion-context/.check-prefix/.test-redirection; then
    true
  elif [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
    # 単語が未だ開始していない時 (空白)
    shopt -q no_empty_cmd_completion ||
      ble/syntax/completion-context/add command "$index"
  fi

  ble/syntax/completion-context/.check/parameter-expansion
}
## @fn ble/syntax/completion-context/prefix:next-argument
##   ARGX 系統の文脈に対する補完文脈の生成
_ble_syntax_completion_context_check_prefix[CTX_ARGX]=next-argument
_ble_syntax_completion_context_check_prefix[CTX_CARGX1]=next-argument
_ble_syntax_completion_context_check_prefix[CTX_CPATX]=next-argument
_ble_syntax_completion_context_check_prefix[CTX_FARGX3]=next-argument
_ble_syntax_completion_context_check_prefix[CTX_COARGX]=next-argument
_ble_syntax_completion_context_check_prefix[CTX_ARGVX]=next-argument
_ble_syntax_completion_context_check_prefix[CTX_ARGEX]=next-argument
_ble_syntax_completion_context_check_prefix[CTX_VALX]=next-argument
_ble_syntax_completion_context_check_prefix[CTX_CONDX]=next-argument
_ble_syntax_completion_context_check_prefix[CTX_RDRS]=next-argument
function ble/syntax/completion-context/prefix:next-argument {
  local source
  if ((ctx==CTX_ARGX||ctx==CTX_CARGX1||ctx==CTX_FARGX3)); then
    source=(argument)
  elif ((ctx==CTX_COARGX)); then
    # Note: variable:w でも variable:= でもなく variable にしているのは、
    #   coproc の後は変数名が来ても "変数代入 " か "coproc 配列名"
    #   か分からないので、取り敢えず何も挿入しない様にする為。
    source=(command:V variable)
  elif ((ctx==CTX_ARGVX)); then
    source=(sabbrev variable:= option)
  elif ((ctx==CTX_ARGEX)); then
    source=(command:D file)
  elif ((ctx==CTX_CONDX)); then
    source=(sabbrev file option)
  else
    source=(sabbrev file)
  fi

  local word=${text:istat:index-istat}
  if ble/syntax:bash/simple-word/is-simple-or-open-simple "$word"; then
    # 単語が istat から開始している場合
    local src
    for src in "${source[@]}"; do
      ble/syntax/completion-context/add "$src" "$istat"
    done

    if [[ ${source[0]} != argument ]]; then
      # 引数の途中に unquoted '=' がある場合
      local rex="^([^='\"\$\\{}]|\\.)*="
      if [[ $word =~ $rex ]]; then
        word=${word:${#BASH_REMATCH}}
        ble/syntax/completion-context/add rhs "$((index-${#word}))"
      fi
    fi
  elif ble/syntax/completion-context/.check-prefix/.test-redirection "$word"; then
    true
  elif [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
    # 単語が未だ開始していない時 (空白)
    local src
    for src in "${source[@]}"; do
      ble/syntax/completion-context/add "$src" "$index"
    done
  fi
  ble/syntax/completion-context/.check/parameter-expansion
}
## @fn ble/syntax/completion-context/prefix:next-compound
##   複合コマンドを補完します。
_ble_syntax_completion_context_check_prefix[CTX_CMDXC]=next-compound
function ble/syntax/completion-context/prefix:next-compound {
  local rex word=${text:istat:index-istat}
  if [[ ${text:istat:index-istat} =~ $rex_param ]]; then
    ble/syntax/completion-context/add wordlist:-r:'for:select:case:if:while:until' "$istat"
  elif rex='^[[({]+$'; [[ $word =~ $rex ]]; then
    ble/syntax/completion-context/add wordlist:-r:'(:{:((:[[' "$istat"
  fi
}
## @fn ble/syntax/completion-context/prefix:next-identifier source
##   エスケープやクォートのない単純な単語に補完する文脈。
##   @param[in] source
_ble_syntax_completion_context_check_prefix[CTX_FARGX1]="next-identifier variable:w" # CTX_FARGX1 → (( でなければ 変数名
_ble_syntax_completion_context_check_prefix[CTX_SARGX1]="next-identifier variable:w"
function ble/syntax/completion-context/prefix:next-identifier {
  local source=$1 word=${text:istat:index-istat}
  if [[ $word =~ $rex_param ]]; then
    ble/syntax/completion-context/add "$source" "$istat"
  elif [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
    # 単語が未だ開始していない時は現在位置から補完開始
    ble/syntax/completion-context/add "$source" "$index"
  else
    ble/syntax/completion-context/add none "$istat"
  fi
}
_ble_syntax_completion_context_check_prefix[CTX_ARGX0]="next-word sabbrev"
_ble_syntax_completion_context_check_prefix[CTX_CMDX0]="next-word sabbrev"
_ble_syntax_completion_context_check_prefix[CTX_CPATX0]="next-word sabbrev"
_ble_syntax_completion_context_check_prefix[CTX_CMDXD0]="next-word wordlist:-rs:';:{:do'"
_ble_syntax_completion_context_check_prefix[CTX_CMDXD]="next-word wordlist:-rs:'{:do'"
_ble_syntax_completion_context_check_prefix[CTX_CMDXE]="next-word wordlist:-rs:'}:fi:done:esac:then:elif:else:do'"
_ble_syntax_completion_context_check_prefix[CTX_CARGX2]="next-word wordlist:-rs:'in'"
_ble_syntax_completion_context_check_prefix[CTX_CARGI2]="next-word wordlist:-rs:'in'"
_ble_syntax_completion_context_check_prefix[CTX_FARGX2]="next-word wordlist:-rs:'in:do'"
_ble_syntax_completion_context_check_prefix[CTX_FARGI2]="next-word wordlist:-rs:'in:do'"
function ble/syntax/completion-context/prefix:next-word {
  local source=$1 word=${text:istat:index-istat} rex=$'^[^ \t]*$'
  if [[ $word =~ ^$_ble_syntax_bash_RexSpaces$ ]]; then
    ble/syntax/completion-context/add "$source" "$index"
  else
    ble/syntax/completion-context/add "$source" "$istat"
  fi
}
## @fn ble/syntax/completion-context/prefix:time-argument {
_ble_syntax_completion_context_check_prefix[CTX_TARGX1]=time-argument
_ble_syntax_completion_context_check_prefix[CTX_TARGI1]=time-argument
_ble_syntax_completion_context_check_prefix[CTX_TARGX2]=time-argument
_ble_syntax_completion_context_check_prefix[CTX_TARGI2]=time-argument
function ble/syntax/completion-context/prefix:time-argument {
  ble/syntax/completion-context/.check/parameter-expansion
  ble/syntax/completion-context/add command "$istat"
  if ((ctx==CTX_TARGX1)); then
    local rex='^-p?$' words='-p'
    ((_ble_bash>=50100)) &&
      rex='^-[-p]?$' words='-p':'--'
    [[ ${text:istat:index-istat} =~ $rex ]] &&
      ble/syntax/completion-context/add wordlist:--:"$words" "$istat"
  elif ((ctx==CTX_TARGX2)); then
    local rex='^--?$'
    [[ ${text:istat:index-istat} =~ $rex ]] &&
      ble/syntax/completion-context/add wordlist:--:'--' "$istat"
  fi
}
## @fn ble/syntax/completion-context/prefix:quote
_ble_syntax_completion_context_check_prefix[CTX_QUOT]=quote
function ble/syntax/completion-context/prefix:quote {
  ble/syntax/completion-context/.check/parameter-expansion
  ble/syntax/completion-context/prefix:quote/.check-container-word
}
function ble/syntax/completion-context/prefix:quote/.check-container-word {
  # Note: CTX_QUOTE は nest の中にあるので、一旦外側に出て単語を探す。

  local nlen=${stat[3]}; ((nlen>=0)) || return 1
  local inest=$((nlen<0?nlen:istat-nlen))

  local nest; ble/string#split-words nest "${_ble_syntax_nest[inest]}"
  [[ ${nest[0]} ]] || return 1

  local wlen2=${nest[1]}; ((wlen2>=0)) || return 1
  local wbeg2=$((wlen2<0?wlen2:inest-wlen2))
  if ble/syntax:bash/simple-word/is-simple-or-open-simple "${text:wbeg2:index-wbeg2}"; then
    local wt=${nest[2]}
    [[ ${_ble_syntax_bash_command_EndWtype[wt]} ]] &&
      wt=${_ble_syntax_bash_command_EndWtype[wt]}
    if ((wt==CTX_CMDI)); then
      ble/syntax/completion-context/add command "$wbeg2"
    elif ((wt==CTX_ARGI||wt==CTX_ARGVI||wt==CTX_ARGEI||wt==CTX_FARGI2||wt==CTX_CARGI2)); then
      ble/syntax/completion-context/add argument "$wbeg2"
    elif ((wt==CTX_CPATI)); then # case pattern の内部
      #ble/syntax/completion-context/add file "$wbeg2"
      return 0
    fi
  fi
}

## @fn ble/syntax/completion-context/prefix:redirection
##   redirect の filename 部分を補完する文脈
_ble_syntax_completion_context_check_prefix[CTX_RDRF]=redirection
_ble_syntax_completion_context_check_prefix[CTX_RDRD2]=redirection
_ble_syntax_completion_context_check_prefix[CTX_RDRD]=redirection
function ble/syntax/completion-context/prefix:redirection {
  ble/syntax/completion-context/.check/parameter-expansion
  local p=$((wlen>=0?wbeg:istat))
  if ble/syntax:bash/simple-word/is-simple-or-open-simple "${text:p:index-p}"; then
    if ((ctx==CTX_RDRF)); then
      ble/syntax/completion-context/add file "$p"
    elif ((ctx==CTX_RDRD)); then
      ble/syntax/completion-context/add fd "$p"
    elif ((ctx==CTX_RDRD2)); then
      ble/syntax/completion-context/add fd "$p"
      ble/syntax/completion-context/add file:no-fd "$p"
    fi
  fi
}
_ble_syntax_completion_context_check_prefix[CTX_RDRH]=here
_ble_syntax_completion_context_check_prefix[CTX_RDRI]=here
function ble/syntax/completion-context/prefix:here {
  local p=$((wlen>=0?wbeg:istat))
  ble/syntax/completion-context/add wordlist:EOF:END:HERE "$p"
}


## @fn ble/syntax/completion-context/prefix:rhs
##   VAR=value の value 部分を補完する文脈
_ble_syntax_completion_context_check_prefix[CTX_VRHS]=rhs
_ble_syntax_completion_context_check_prefix[CTX_ARGVR]=rhs
_ble_syntax_completion_context_check_prefix[CTX_ARGER]=rhs
_ble_syntax_completion_context_check_prefix[CTX_VALR]=rhs
function ble/syntax/completion-context/prefix:rhs {
  ble/syntax/completion-context/.check/parameter-expansion
  if ((wlen>=0)); then
    local p=$wbeg
    local rex='^[_a-zA-Z0-9]+(\+?=|\[)'
    ((ctx==CTX_VALR)) && rex='^(\[)'
    if [[ ${text:p:index-p} =~ $rex ]]; then
      if [[ ${BASH_REMATCH[1]} == '[' ]]; then
        # CTX_VRHS:  arr[0]=x@ arr[1]+=x@
        # CTX_ARGVR: declare arr[0]=x@ arr[1]+=x@
        # CTX_VALR:  arr=([0]=x@ [1]+=x@)
        local p1=$((wbeg+${#BASH_REMATCH}-1))
        if local ret; ble/syntax:bash/find-end-of-array-index "$p1" "$index"; then
          local p2=$ret
          case ${_ble_syntax_text:p2:index-p2} in
          (']='*)  ((p=p2+2)) ;;
          (']+='*) ((p=p2+3)) ;;
          (']+')
            ble/syntax/completion-context/add wordlist:-rW:'+=' "$((p2+1))"
            p= ;;
          esac
        fi
      else
        # CTX_VRHS:  var=x@ var+=x@
        # CTX_ARGVR: declare var=x@ var+=x@
        ((p+=${#BASH_REMATCH}))
      fi
    fi
  else
    local p=$istat
  fi

  if [[ $p ]] && ble/syntax:bash/simple-word/is-simple-or-open-simple "${text:p:index-p}"; then
    ble/syntax/completion-context/add rhs "$p"
  fi
}

_ble_syntax_completion_context_check_prefix[CTX_PARAM]=param
function ble/syntax/completion-context/prefix:param {
  local tail=${text:istat:index-istat}
  if [[ $tail == : ]]; then
    return 0
  elif [[ $tail == '}'* ]]; then
    local nlen=${stat[3]}
    local inest=$((nlen<0?nlen:istat-nlen))
    ((0<=inest&&inest<istat)) &&
      ble/syntax/completion-context/.check-prefix "$inest"
    return "$?"
  else
    return 1
  fi
}

## @fn ble/syntax/completion-context/prefix:expr
##   数式中の変数名を補完する文脈
_ble_syntax_completion_context_check_prefix[CTX_EXPR]=expr
function ble/syntax/completion-context/prefix:expr {
  local tail=${text:istat:index-istat} rex='[_a-zA-Z]+$'
  if [[ $tail =~ $rex ]]; then
    local p=$((index-${#BASH_REMATCH}))
    ble/syntax/completion-context/add variable:a "$p"
    return 0
  elif [[ $tail == ']'* ]]; then
    local inest=... ntype
    local nlen=${stat[3]}; ((nlen>=0)) || return 1
    local inest=$((istat-nlen))
    ble/syntax/parse/nest-type # ([in] inest; [out] ntype)

    if [[ $ntype == [ad]'[' ]]; then
      # arr[...]=@ or arr=([...]=@)
      if [[ $tail == ']' ]]; then
        ble/syntax/completion-context/add wordlist:-rW:'=' "$((istat+1))"
      elif ((_ble_bash>=30100)) && [[ $tail == ']+' ]]; then
        ble/syntax/completion-context/add wordlist:-rW:'+=' "$((istat+1))"
      elif [[ $tail == ']=' || _ble_bash -ge 30100 && $tail == ']+=' ]]; then
        ble/syntax/completion-context/add rhs "$index"
      fi
    fi
  fi
}

## @fn ble/syntax/completion-context/prefix:expr
##   ブレース展開の中での補完
_ble_syntax_completion_context_check_prefix[CTX_BRACE1]=brace
_ble_syntax_completion_context_check_prefix[CTX_BRACE2]=brace
function ble/syntax/completion-context/prefix:brace {
  # (1) CTX_BRACE{1,2} 以外になるまで nest を出る
  local ctx1=$ctx istat1=$istat nlen1=${stat[3]}
  ((nlen1>=0)) || return 1
  local inest1=$((istat1-nlen1))
  while :; do
    local nest=${_ble_syntax_nest[inest1]}
    [[ $nest ]] || return 1
    ble/string#split-words nest "$nest"
    ctx1=${nest[0]}
    ((ctx1==CTX_BRACE1||ctx1==CTX_BRACE2)) || break
    inest1=${nest[3]}
    ((inest1>=0)) || return 1
  done

  # (2) 直前の stat
  for ((istat1=inest1;1;istat1--)); do
    ((istat1>=0)) || return 1
    [[ ${_ble_syntax_stat[istat1]} ]] && break
  done

  # (3) 単語の開始点
  local stat1
  ble/string#split-words stat1 "${_ble_syntax_stat[istat1]}"
  local wlen=${stat1[1]}
  local wbeg=$((wlen>=0?istat1-wlen:istat1))

  ble/syntax/completion-context/.check/parameter-expansion
  ble/syntax/completion-context/add argument "$wbeg"
}


## @fn ble/syntax/completion-context/.search-last-istat index
##   @param[in] index
##   @var[out] ret
function ble/syntax/completion-context/.search-last-istat {
  local index=$1 istat
  for ((istat=index;istat>=0;istat--)); do
    if [[ ${_ble_syntax_stat[istat]} ]]; then
      ret=$istat
      return 0
    fi
  done
  ret=
  return 1
}

## @fn ble/syntax/completion-context/.check-prefix from
##   @param[in,opt] from
##   @var[in] text
##   @var[in] index
##   @var[out] sources
function ble/syntax/completion-context/.check-prefix {
  local rex_param='^[_a-zA-Z][_a-zA-Z0-9]*$'
  local from=${1:-$((index-1))}

  local ret
  ble/syntax/completion-context/.search-last-istat "$from" || return 1
  local istat=$ret stat
  ble/string#split-words stat "${_ble_syntax_stat[istat]}"
  [[ ${stat[0]} ]] || return 1

  local ctx=${stat[0]} wlen=${stat[1]}
  local wbeg=$((wlen<0?wlen:istat-wlen))
  local name=${_ble_syntax_completion_context_check_prefix[ctx]}
  if [[ $name ]]; then
    builtin eval "ble/syntax/completion-context/prefix:$name"
  fi
}

## @fn ble/syntax/completion-context/here:*
##
##   @var[in] text index
##     補完対象のコマンドラインと現在のカーソルの位置を指定します。
##

function ble/syntax/completion-context/here:add {
  local source
  for source; do
    ble/syntax/completion-context/add "$source" "$index"
  done
}

_ble_syntax_completion_context_check_here[CTX_CMDX]='command'
_ble_syntax_completion_context_check_here[CTX_CMDXV]='command'
_ble_syntax_completion_context_check_here[CTX_CMDX1]='command'
_ble_syntax_completion_context_check_here[CTX_CMDXT]='command'
_ble_syntax_completion_context_check_here[CTX_CMDXC]='command compound'
_ble_syntax_completion_context_check_here[CTX_CMDXE]='command end'
_ble_syntax_completion_context_check_here[CTX_CMDXD0]='command for1'
_ble_syntax_completion_context_check_here[CTX_CMDXD]='command for2'
function ble/syntax/completion-context/here:command {
  case $1 in
  (compound)
    ble/syntax/completion-context/add wordlist:-rs:'(:{:((:[[:for:select:case:if:while:until' "$index" ;;
  (end)
    ble/syntax/completion-context/add wordlist:-rs:'}:fi:done:esac:then:elif:else:do' "$index" ;;
  (for1)
    ble/syntax/completion-context/add wordlist:-rs:';:{:do' "$index" ;;
  (for2)
    ble/syntax/completion-context/add wordlist:-rs:'{:do' "$index" ;;
  (*)
    if ! shopt -q no_empty_cmd_completion; then
      ble/syntax/completion-context/add command "$index"
    fi ;;
  esac
}

_ble_syntax_completion_context_check_here[CTX_ARGX]='argument'
_ble_syntax_completion_context_check_here[CTX_CARGX1]='argument'
_ble_syntax_completion_context_check_here[CTX_FARGX3]='argument'
_ble_syntax_completion_context_check_here[CTX_ARGX0]='argument none'
_ble_syntax_completion_context_check_here[CTX_CPATX0]='argument none'
_ble_syntax_completion_context_check_here[CTX_CMDX0]='argument none'
_ble_syntax_completion_context_check_here[CTX_FARGX1]='argument for1'
_ble_syntax_completion_context_check_here[CTX_SARGX1]='argument for1'
_ble_syntax_completion_context_check_here[CTX_ARGVX]='argument declare'
_ble_syntax_completion_context_check_here[CTX_ARGEX]='argument eval'
_ble_syntax_completion_context_check_here[CTX_CARGX2]='argument case'
_ble_syntax_completion_context_check_here[CTX_CPATI]='argument case-pattern'
_ble_syntax_completion_context_check_here[CTX_FARGX2]='argument for2'
_ble_syntax_completion_context_check_here[CTX_TARGX1]='argument time1'
_ble_syntax_completion_context_check_here[CTX_TARGX2]='argument time2'
_ble_syntax_completion_context_check_here[CTX_COARGX]='argument coproc'
_ble_syntax_completion_context_check_here[CTX_CONDX]='argument cond'
function ble/syntax/completion-context/here:argument {
  case $1 in
  (none)
    ble/syntax/completion-context/add sabbrev "$index" ;;
  (for1)
    # for @, select @
    ble/syntax/completion-context/add variable:w "$index"
    ble/syntax/completion-context/add sabbrev "$index" ;;
  (declare)
    # declare @
    ble/syntax/completion-context/add variable:= "$index"
    ble/syntax/completion-context/add option "$index"
    ble/syntax/completion-context/add sabbrev "$index" ;;
  (eval)
    # eval @, eval echo @
    ble/syntax/completion-context/add command:D "$index"
    ble/syntax/completion-context/add file "$index" ;;
  (case)
    # case a @
    ble/syntax/completion-context/add wordlist:-rs:'in' "$index" ;;
  (case-pattern)
    # case a in @
    ble/syntax/completion-context/add file "$index" ;;
  (for2)
    # for a @
    ble/syntax/completion-context/add wordlist:-rs:'in:do' "$index" ;;
  (time1)
    # time @
    local words='-p'
    ((_ble_bash>=50100)) && words='-p':'--'
    ble/syntax/completion-context/add command "$index"
    ble/syntax/completion-context/add wordlist:--:"$words" "$index" ;;
  (time2)
    # time -p @
    ble/syntax/completion-context/add command "$index"
    ble/syntax/completion-context/add wordlist:--:'--' "$index" ;;
  (coproc)
    # coproc @
    ble/syntax/completion-context/add variable:w "$index"
    ble/syntax/completion-context/add command:V "$index" ;;
  (cond)
    # [[ @
    ble/syntax/completion-context/add sabbrev "$index"
    ble/syntax/completion-context/add option "$index"
    ble/syntax/completion-context/add file "$index" ;;
  (*)
    ble/syntax/completion-context/add argument "$index" ;;
  esac
}

# redirections
_ble_syntax_completion_context_check_here[CTX_RDRF]='add file'
_ble_syntax_completion_context_check_here[CTX_RDRS]='add file'
_ble_syntax_completion_context_check_here[CTX_RDRD]='add fd'
_ble_syntax_completion_context_check_here[CTX_RDRD2]='add fd file:no-fd'
_ble_syntax_completion_context_check_here[CTX_RDRH]='add wordlist:EOF:END:HERE'
_ble_syntax_completion_context_check_here[CTX_RDRI]='add wordlist:EOF:END:HERE'

# rhs
_ble_syntax_completion_context_check_here[CTX_VRHS]='add rhs'
_ble_syntax_completion_context_check_here[CTX_ARGVR]='add rhs'
_ble_syntax_completion_context_check_here[CTX_ARGER]='add rhs'
_ble_syntax_completion_context_check_here[CTX_VALR]='add rhs'

## @fn ble/syntax/completion-context/.check-here
##   現在地点を開始点とする補完の可能性を列挙します
##   @var[in]  text
##   @var[in]  index
##   @var[out] sources
function ble/syntax/completion-context/.check-here {
  ((${#sources[*]})) && return 0
  local -a stat
  ble/string#split-words stat "${_ble_syntax_stat[index]}"
  if [[ ${stat[0]-} && ${_ble_syntax_completion_context_check_here[stat[0]]-} ]]; then
    # Note: ここで CTX_CMDI や CTX_ARGI は処理しない。既に check-prefix で引っ
    #   かかっている筈だから。
    #
    # Note (#D1690): 文句が出たので 当初引数類の補完はその場で開始しない事にし
    #   たが、すると空文字列から補完を開始できなくなってしまった。やはり、ここ
    #   で引数の補完を開始しなければならない。
    #
    #   そもそも .check-prefix で補完文脈を生成できる時は、入力済みの内容に拘ら
    #   ず補完文脈を生成するべきである。それにより、.check-here に到達するのは
    #   補完文脈が他に生成しようがない状況に限定される。この時、実は
    #   .check-here の側は修正は必要なかった。
    local proc=${_ble_syntax_completion_context_check_here[stat[0]]-}
    builtin eval "ble/syntax/completion-context/here:$proc"
  fi
}

## @fn ble/syntax/completion-context/generate
##   @var[out] sources[]
function ble/syntax/completion-context/generate {
  local text=$1 index=$2
  sources=()
  ((index<0&&(index=0)))

  ble/syntax/completion-context/.check-prefix
  ble/syntax/completion-context/.check-here
}

#------------------------------------------------------------------------------
# extract-command

## @fn ble/syntax:bash/extract-command/.register-word
## @var[in,out] comp_words, comp_line, comp_point, comp_cword
## @var[in]     TE_i TE_nofs wbegin wlen
function ble/syntax:bash/extract-command/.register-word {
  local wtxt=${_ble_syntax_text:wbegin:wlen}
  if [[ ! $comp_cword ]] && ((wbegin<=EC_pos)); then
    if ((EC_pos<=wbegin+wlen)); then
      comp_cword=${#comp_words[@]}
      comp_point=$((${#comp_line}+wbegin+wlen-EC_pos))
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
  [[ $EC_opts == *:treeinfo:* ]] &&
    ble/array#push tree_words "$TE_i:$TE_nofs"
}

function ble/syntax:bash/extract-command/.construct-proc {
  if [[ $wtype =~ ^[0-9]+$ ]]; then
    if ((wtype==CTX_CMDI||wtype==CTX_CMDX0)); then
      if ((EC_pos<wbegin)); then
        comp_line= comp_point= comp_cword= comp_words=()
        [[ $EC_opts == *:treeinfo:* ]] && tree_words=()
      else
        ble/syntax:bash/extract-command/.register-word
        ble/syntax/tree-enumerate-break
        EC_found=1
        return 0
      fi
    elif ((wtype==CTX_ARGI||wtype==CTX_ARGVI||wtype==CTX_ARGEI||wtype==ATTR_VAR)); then
      ble/syntax:bash/extract-command/.register-word
      comp_line=" $comp_line"
    fi
  fi
}

function ble/syntax:bash/extract-command/.construct {
  comp_line= comp_point= comp_cword= comp_words=()
  [[ $EC_opts == *:treeinfo:* ]] && tree_words=()

  if [[ $1 == nested ]]; then
    ble/syntax/tree-enumerate-children \
      ble/syntax:bash/extract-command/.construct-proc
  else
    ble/syntax/tree-enumerate \
      ble/syntax:bash/extract-command/.construct-proc
  fi

  ble/array#reverse comp_words
  ((comp_cword=${#comp_words[@]}-1-comp_cword,
    comp_point=${#comp_line}-comp_point))
  [[ $EC_opts == *:treeinfo:* ]] &&
    ble/array#reverse tree_words
}

## (tree-enumerate-proc) ble/syntax:bash/extract-command/.scan
function ble/syntax:bash/extract-command/.scan {
  ((EC_pos<wbegin)) && return 0

  if ((wbegin+wlen<EC_pos)); then
    ble/syntax/tree-enumerate-break
  else
    local EC_has_word=
    ble/syntax/tree-enumerate-children \
      ble/syntax:bash/extract-command/.scan
    local has_word=$EC_has_word
    ble/util/unlocal EC_has_word

    if [[ $has_word && ! $EC_found ]]; then
      ble/syntax:bash/extract-command/.construct nested
      ble/syntax/tree-enumerate-break
    fi
  fi

  if [[ $wtype =~ ^[0-9]+$ && ! $EC_has_word ]]; then
    EC_has_word=$wtype
    return 0
  fi
}

## @fn ble/syntax:bash/extract-command index [opts]
##   @param[in] index
##   @param[in] opts
##     treeinfo
##       コマンドを構成する各単語の構文木の情報を取得します。
##       以下の配列に結果を格納します。
##       @arr[out] tree_words
##
##   @var[out] comp_cword comp_words comp_line comp_point
function ble/syntax:bash/extract-command {
  local EC_pos=$1 EC_opts=:$2:
  local EC_found=

  local EC_has_word=
  ble/syntax/tree-enumerate \
    ble/syntax:bash/extract-command/.scan
  if [[ ! $EC_found && $EC_has_word ]]; then
    ble/syntax:bash/extract-command/.construct
  fi
  [[ $EC_found ]]
}

#------------------------------------------------------------------------------
# extract-command-by-noderef

## @fn ble/syntax/tree#previous-sibling i[:nofs] [opts]
## @fn ble/syntax/tree#next-sibling     i[:nofs] [opts]
##   指定した位置の単語について、前または次の兄弟ノードを取得します。
##
##   @param[in] i:nofs
##
##   @param[in] opts
##     コロン区切りのオプションです。
##
##     wvars が指定されている時、以下の変数に見つかった単語の情報を格納します。
##     @var[out] wtype wlen wbeg wend wattr
##
##   @var[out] ret=i:nofs
##
function ble/syntax/tree#previous-sibling {
  local i0=${1%%:*} nofs0=0 opts=:$2:
  [[ $1 == *:* ]] && nofs0=${1#*:}

  local node
  ble/string#split-words node "${_ble_syntax_tree[i0-1]}"
  ble/util/assert '((${#node[@]}>nofs0))' "Broken AST: tree-node info missing at $((i0-1))[$nofs0]" || return 1
  local tplen=${node[nofs0+3]}
  ((tplen>=0)) || return 1

  local i=$((i0-tplen)) nofs=0
  ret=$i:$nofs
  if [[ $opts == *:wvars:* ]]; then
    ble/string#split-words node "${_ble_syntax_tree[i-1]}"
    ble/util/assert '((${#node[@]}>nofs))' "Broken AST: tree-node info missing at $((i-1))[$nofs]" || return 1
    wtype=${node[nofs]}
    wlen=${node[nofs+1]}
    ((wbeg=i-wlen,wend=i))
    wattr=${node[nofs+4]}
  fi
  return 0
}
function ble/syntax/tree#next-sibling {
  local i0=${1%%:*} nofs0=0 opts=:$2:
  [[ $1 == *:* ]] && nofs0=${1#*:}

  # 自分が末尾にいるので弟はない
  ((nofs0)) && return 1

  local iN=${#_ble_syntax_text} i nofs node
  for ((i=i0+1;i<=iN;i++)); do
    [[ ${_ble_syntax_tree[i-1]} ]] || continue
    ble/string#split-words node "${_ble_syntax_tree[i-1]}"
    nofs=${#node[@]}
    while (((nofs-=_ble_syntax_TREE_WIDTH)>=0)); do
      # node = (wtype wlen tclen tplen wattr)+
      if ((i0==i-node[nofs+2])); then
        # 親が見つかったので弟はいない
        return 1
      elif ((i0==i-node[nofs+3])); then
        # これが弟
        ret=$i:$nofs
        if [[ $opts == *:wvars:* ]]; then
          wtype=${node[nofs]}
          wlen=${node[nofs+1]}
          ((wbeg=i-wlen,wend=i))
          wattr=${node[nofs+4]}
        fi
        return 0
      fi
    done
  done
  return 1
}

## @fn ble/syntax:bash/extract-command-by-noderef i[:nofs] [opts]
##   @param[in] i:nofs
##     単語を指定します。
##
##   @param[in] opts
##     コロン区切りのオプションです。
##
##     treeinfo が指定された時は以下の配列に各単語の位置を
##     "i:nofs" の形式で格納します。
##     @var[out] tree_words
##
##   @var[out] comp_words comp_line comp_cword comp_point
##     再構築したコマンド情報を格納します。
##     カーソル位置は指定した単語の末尾にあると仮定します。
##
function ble/syntax:bash/extract-command-by-noderef {
  local i=${1%%:*} nofs=0 opts=:$2:
  [[ $1 == *:* ]] && nofs=${1#*:}

  # initialize output
  comp_words=()
  tree_words=()
  comp_line=
  comp_cword=0
  comp_point=0

  local ExprIsArgument='wtype==CTX_ARGI||wtype==CTX_ARGVI||wtype==CTX_ARGEI||wtype==ATTR_VAR'

  # 自ノードの追加
  local ret node wtype wlen wbeg wend wattr
  ble/string#split-words node "${_ble_syntax_tree[i-1]}"
  wtype=${node[nofs]} wlen=${node[nofs+1]}
  [[ ! ${wtype//[0-9]} ]] && ((wtype==CTX_CMDI||ExprIsArgument)) || return 1
  ble/array#push comp_words "${_ble_syntax_text:i-wlen:wlen}"
  [[ $opts == *:treeinfo:* ]] &&
    ble/array#push tree_words "$i:$nofs"

  # 兄ノードの追加
  ret=$i:$nofs
  while
    { [[ ${wtype//[0-9]} ]] || ((wtype!=CTX_CMDI)); } &&
      ble/syntax/tree#previous-sibling "$ret" wvars
  do
    [[ ! ${wtype//[0-9]} ]] || continue
    if ((wtype==CTX_CMDI||ExprIsArgument)); then
      ble/array#push comp_words "${_ble_syntax_text:wbeg:wlen}"
      [[ $opts == *:treeinfo:* ]] &&
        ble/array#push tree_words "$ret"
    fi
  done
  ble/array#reverse comp_words
  [[ $opts == *:treeinfo:* ]] &&
    ble/array#reverse tree_words

  # 現在位置 (comp_cword, comp_point)
  ((comp_cword=${#comp_words[@]}-1))

  # 弟ノードの探索
  ret=$i:$nofs
  while ble/syntax/tree#next-sibling "$ret" wvars; do
    [[ ! ${wtype//[0-9]} ]] || continue
    ((wtype==CTX_CMDI)) && break
    if ((ExprIsArgument)); then
      ble/array#push comp_words "${_ble_syntax_text:wbeg:wlen}"
      [[ $opts == *:treeinfo:* ]] &&
        ble/array#push tree_words "$ret"
    fi
  done

  local IFS=$_ble_term_IFS
  comp_line="${comp_words[*]}"
  local tmp="${comp_words[*]::comp_cword+1}"
  comp_point=${#tmp}
}

#==============================================================================
#
# syntax-highlight
#
#==============================================================================

# 遅延初期化対象
_ble_syntax_attr2iface=()

# 遅延初期化子
function ble/syntax/attr2iface/color_defface.onload {
  function ble/syntax/attr2iface/.define {
    ((_ble_syntax_attr2iface[$1]=_ble_faces__$2))
  }

  ble/syntax/attr2iface/.define CTX_UNSPECIFIED syntax_default

  ble/syntax/attr2iface/.define CTX_ARGX     syntax_default
  ble/syntax/attr2iface/.define CTX_ARGX0    syntax_default
  ble/syntax/attr2iface/.define CTX_ARGI     syntax_default
  ble/syntax/attr2iface/.define CTX_ARGQ     syntax_default
  ble/syntax/attr2iface/.define CTX_ARGVX    syntax_default
  ble/syntax/attr2iface/.define CTX_ARGVI    syntax_default
  ble/syntax/attr2iface/.define CTX_ARGVR    syntax_default
  ble/syntax/attr2iface/.define CTX_ARGEX    syntax_default
  ble/syntax/attr2iface/.define CTX_ARGEI    syntax_default
  ble/syntax/attr2iface/.define CTX_ARGER    syntax_default
  ble/syntax/attr2iface/.define CTX_CMDX     syntax_default
  ble/syntax/attr2iface/.define CTX_CMDX0    syntax_default
  ble/syntax/attr2iface/.define CTX_CMDX1    syntax_default
  ble/syntax/attr2iface/.define CTX_CMDXT    syntax_default
  ble/syntax/attr2iface/.define CTX_CMDXC    syntax_default
  ble/syntax/attr2iface/.define CTX_CMDXE    syntax_default
  ble/syntax/attr2iface/.define CTX_CMDXD    syntax_default
  ble/syntax/attr2iface/.define CTX_CMDXD0   syntax_default
  ble/syntax/attr2iface/.define CTX_CMDXV    syntax_default
  ble/syntax/attr2iface/.define CTX_CMDI     syntax_command
  ble/syntax/attr2iface/.define CTX_VRHS     syntax_default
  ble/syntax/attr2iface/.define CTX_QUOT     syntax_quoted
  ble/syntax/attr2iface/.define CTX_EXPR     syntax_expr
  ble/syntax/attr2iface/.define ATTR_ERR     syntax_error
  ble/syntax/attr2iface/.define ATTR_VAR     syntax_varname
  ble/syntax/attr2iface/.define ATTR_QDEL    syntax_quotation
  ble/syntax/attr2iface/.define ATTR_QESC    syntax_escape
  ble/syntax/attr2iface/.define ATTR_DEF     syntax_default
  ble/syntax/attr2iface/.define ATTR_DEL     syntax_delimiter
  ble/syntax/attr2iface/.define CTX_PARAM    syntax_param_expansion
  ble/syntax/attr2iface/.define CTX_PWORD    syntax_default
  ble/syntax/attr2iface/.define CTX_PWORDE   syntax_error
  ble/syntax/attr2iface/.define CTX_PWORDR   syntax_default
  ble/syntax/attr2iface/.define ATTR_HISTX   syntax_history_expansion
  ble/syntax/attr2iface/.define ATTR_FUNCDEF syntax_function_name
  ble/syntax/attr2iface/.define CTX_VALX     syntax_default
  ble/syntax/attr2iface/.define CTX_VALI     syntax_default
  ble/syntax/attr2iface/.define CTX_VALR     syntax_default
  ble/syntax/attr2iface/.define CTX_VALQ     syntax_default
  ble/syntax/attr2iface/.define CTX_CONDX    syntax_default
  ble/syntax/attr2iface/.define CTX_CONDI    syntax_default
  ble/syntax/attr2iface/.define CTX_CONDQ    syntax_default
  ble/syntax/attr2iface/.define ATTR_COMMENT syntax_comment
  ble/syntax/attr2iface/.define CTX_CASE     syntax_default
  ble/syntax/attr2iface/.define CTX_PATN     syntax_default
  ble/syntax/attr2iface/.define ATTR_GLOB    syntax_glob
  ble/syntax/attr2iface/.define CTX_BRAX     syntax_default
  ble/syntax/attr2iface/.define ATTR_BRACE   syntax_brace
  ble/syntax/attr2iface/.define CTX_BRACE1   syntax_default
  ble/syntax/attr2iface/.define CTX_BRACE2   syntax_default
  ble/syntax/attr2iface/.define ATTR_TILDE   syntax_tilde

  # for var in ... / case arg in / time -p --
  ble/syntax/attr2iface/.define CTX_SARGX1   syntax_default
  ble/syntax/attr2iface/.define CTX_FARGX1   syntax_default
  ble/syntax/attr2iface/.define CTX_FARGX2   syntax_default
  ble/syntax/attr2iface/.define CTX_FARGX3   syntax_default
  ble/syntax/attr2iface/.define CTX_FARGI1   syntax_varname
  ble/syntax/attr2iface/.define CTX_FARGI2   command_keyword
  ble/syntax/attr2iface/.define CTX_FARGI3   syntax_default
  ble/syntax/attr2iface/.define CTX_FARGQ3   syntax_default

  ble/syntax/attr2iface/.define CTX_CARGX1   syntax_default
  ble/syntax/attr2iface/.define CTX_CARGX2   syntax_default
  ble/syntax/attr2iface/.define CTX_CARGI1   syntax_default
  ble/syntax/attr2iface/.define CTX_CARGQ1   syntax_default
  ble/syntax/attr2iface/.define CTX_CARGI2   command_keyword
  ble/syntax/attr2iface/.define CTX_CPATX    syntax_default
  ble/syntax/attr2iface/.define CTX_CPATI    syntax_default
  ble/syntax/attr2iface/.define CTX_CPATQ    syntax_default
  ble/syntax/attr2iface/.define CTX_CPATX0   syntax_default

  ble/syntax/attr2iface/.define CTX_TARGX1   syntax_default
  ble/syntax/attr2iface/.define CTX_TARGX2   syntax_default
  ble/syntax/attr2iface/.define CTX_TARGI1   syntax_default
  ble/syntax/attr2iface/.define CTX_TARGI2   syntax_default

  ble/syntax/attr2iface/.define CTX_COARGX   syntax_default
  ble/syntax/attr2iface/.define CTX_COARGI   syntax_command

  # redirection words
  ble/syntax/attr2iface/.define CTX_RDRF    syntax_default
  ble/syntax/attr2iface/.define CTX_RDRD    syntax_default
  ble/syntax/attr2iface/.define CTX_RDRD2   syntax_default
  ble/syntax/attr2iface/.define CTX_RDRS    syntax_default

  # here documents
  ble/syntax/attr2iface/.define CTX_RDRH    syntax_document_begin
  ble/syntax/attr2iface/.define CTX_RDRI    syntax_document_begin
  ble/syntax/attr2iface/.define CTX_HERE0   syntax_document
  ble/syntax/attr2iface/.define CTX_HERE1   syntax_document

  ble/syntax/attr2iface/.define ATTR_CMD_BOLD       command_builtin_dot
  ble/syntax/attr2iface/.define ATTR_CMD_BUILTIN    command_builtin
  ble/syntax/attr2iface/.define ATTR_CMD_ALIAS      command_alias
  ble/syntax/attr2iface/.define ATTR_CMD_FUNCTION   command_function
  ble/syntax/attr2iface/.define ATTR_CMD_FILE       command_file
  ble/syntax/attr2iface/.define ATTR_CMD_JOBS       command_jobs
  ble/syntax/attr2iface/.define ATTR_CMD_DIR        command_directory
  ble/syntax/attr2iface/.define ATTR_CMD_SUFFIX     command_suffix
  ble/syntax/attr2iface/.define ATTR_CMD_SUFFIX_NEW command_suffix_new

  ble/syntax/attr2iface/.define ATTR_KEYWORD       command_keyword
  ble/syntax/attr2iface/.define ATTR_KEYWORD_BEGIN command_keyword
  ble/syntax/attr2iface/.define ATTR_KEYWORD_END   command_keyword
  ble/syntax/attr2iface/.define ATTR_KEYWORD_MID   command_keyword
  ble/syntax/attr2iface/.define ATTR_FILE_DIR      filename_directory
  ble/syntax/attr2iface/.define ATTR_FILE_STICKY   filename_directory_sticky
  ble/syntax/attr2iface/.define ATTR_FILE_LINK     filename_link
  ble/syntax/attr2iface/.define ATTR_FILE_ORPHAN   filename_orphan
  ble/syntax/attr2iface/.define ATTR_FILE_FILE     filename_other
  ble/syntax/attr2iface/.define ATTR_FILE_SETUID   filename_setuid
  ble/syntax/attr2iface/.define ATTR_FILE_SETGID   filename_setgid
  ble/syntax/attr2iface/.define ATTR_FILE_EXEC     filename_executable
  ble/syntax/attr2iface/.define ATTR_FILE_WARN     filename_warning
  ble/syntax/attr2iface/.define ATTR_FILE_FIFO     filename_pipe
  ble/syntax/attr2iface/.define ATTR_FILE_SOCK     filename_socket
  ble/syntax/attr2iface/.define ATTR_FILE_BLK      filename_block
  ble/syntax/attr2iface/.define ATTR_FILE_CHR      filename_character
  ble/syntax/attr2iface/.define ATTR_FILE_URL      filename_url
  ble/syntax/attr2iface/.define ATTR_VAR_UNSET     varname_unset
  ble/syntax/attr2iface/.define ATTR_VAR_EMPTY     varname_empty
  ble/syntax/attr2iface/.define ATTR_VAR_NUMBER    varname_number
  ble/syntax/attr2iface/.define ATTR_VAR_EXPR      varname_expr
  ble/syntax/attr2iface/.define ATTR_VAR_ARRAY     varname_array
  ble/syntax/attr2iface/.define ATTR_VAR_HASH      varname_hash
  ble/syntax/attr2iface/.define ATTR_VAR_READONLY  varname_readonly
  ble/syntax/attr2iface/.define ATTR_VAR_TRANSFORM varname_transform
  ble/syntax/attr2iface/.define ATTR_VAR_EXPORT    varname_export
  ble/syntax/attr2iface/.define ATTR_VAR_NEW       varname_new
}
blehook/eval-after-load color_defface ble/syntax/attr2iface/color_defface.onload

#------------------------------------------------------------------------------
# ble/syntax/highlight/cmdtype


## @fn ble/syntax/highlight/cmdtype1 command_type command
##   指定したコマンドに対する属性を決定します。
##   @param[in] command_type
##     builtin type -t command の結果を指定します。
##   @param[in] command
##     コマンド名です。
##   @var[out] type
function ble/syntax/highlight/cmdtype1 {
  type=$1
  local cmd=$2
  case $type:$cmd in
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
    if [[ -d $cmd ]] && shopt -q autocd &>/dev/null; then
      ((type=ATTR_CMD_DIR))
    elif [[ $cmd == *.* ]] && ble/function#try ble/complete/sabbrev#match "$cmd" 's'; then
      if [[ -e $cmd || -h $cmd ]]; then
        ((type=ATTR_CMD_SUFFIX))
      else
        ((type=ATTR_CMD_SUFFIX_NEW))
      fi
    else
      ((type=ATTR_ERR))
    fi ;;
  esac
}

# #D1341 #D1355 #D1440 locale 対策
function ble/syntax/highlight/cmdtype/.jobs { local LC_ALL=C; jobs; }
ble/function#suppress-stderr ble/syntax/highlight/cmdtype/.jobs
function ble/syntax/highlight/cmdtype/.is-job-name {
  ble/util/joblist.check

  local value=$1 word=$2
  if [[ $value == '%'* ]] && jobs -- "$value" &>/dev/null; then
    return 0
  fi

  local quote=\'\"\\\`
  if [[ ${auto_resume+set} && $word != *["$quote"]* ]]; then
    if [[ $auto_resume == exact ]]; then
      local jobs job ret
      ble/util/assign-array jobs 'ble/syntax/highlight/cmdtype/.jobs'
      for job in "${jobs[@]}"; do
        ble/string#trim "${job#*' '}"
        ble/string#trim "${ret#*' '}"
        [[ $value == "$ret" ]] && return 0
      done
      return 1
    elif [[ $auto_resume == substring ]]; then
      jobs -- "%?$value" &>/dev/null; return "$?"
    else
      jobs -- "%$value" &>/dev/null; return "$?"
    fi
  fi

  return 1
}
function ble/syntax/highlight/cmdtype/.impl {
  local cmd=$1 word=$2
  local cmd_type; ble/util/type cmd_type "$cmd"
  ble/syntax/highlight/cmdtype1 "$cmd_type" "$cmd"

  if [[ $type == "$ATTR_CMD_ALIAS" && $cmd != "$word" ]]; then
    # alias を \ で無効化している場合は
    # unalias して再度 check (2fork)
    type=$(
      builtin unalias "$cmd"
      ble/util/type cmd_type "$cmd"
      ble/syntax/highlight/cmdtype1 "$cmd_type" "$cmd"
      printf %s "$type")
  elif ble/syntax/highlight/cmdtype/.is-job-name "$cmd" "$word"; then
    # %() { :; } として 関数を定義できるが jobs の方が優先される。
    # (% という名の関数を呼び出す方法はない?)
    # でも % で始まる物が keyword になる事はそもそも無いような。
    ((type=ATTR_CMD_JOBS))
  elif [[ $type == "$ATTR_KEYWORD" ]]; then
    # Note: 予約語 (keyword) の時は構文解析の時点で着色しているのでコマンドとしての着色は行わない。
    #   関数 ble/syntax/highlight/cmdtype が呼び出されたとすれば、コマンドとしての文脈である。
    #   予約語がコマンドとして取り扱われるのは、クォートされていたか変数代入やリダイレクトの後だった時。
    #   この時 type -a -t の二番目の候補を用いて種類を決定する #D1406
    ble/syntax/highlight/cmdtype1 "${cmd_type[1]}" "$cmd"
  fi
}

## @fn ble/syntax/highlight/cmdtype cmd word
##   @param[in] cmd
##     シェル展開・クォート除去を実行した後の文字列を指定します。
##   @param[in] word
##     シェル展開・クォート除去を実行する前の文字列を指定します。
##   @var[out] type

# Note: 連想配列 _ble_syntax_highlight_filetype は core-syntax-def.sh で先に定義される。
_ble_syntax_highlight_filetype_version=-1
function ble/syntax/highlight/cmdtype {
  local cmd=$1 word=$2

  # check cache
  if ((_ble_syntax_highlight_filetype_version!=_ble_edit_LINENO)); then
    ble/gdict#clear _ble_syntax_highlight_filetype
    ((_ble_syntax_highlight_filetype_version=_ble_edit_LINENO))
  fi

  if local ret; ble/gdict#get _ble_syntax_highlight_filetype "$word"; then
    type=$ret
    return 0
  fi

  ble/syntax/highlight/cmdtype/.impl "$cmd" "$word"
  ble/gdict#set _ble_syntax_highlight_filetype "$word" "$type"
}

#------------------------------------------------------------------------------
# ble/syntax/highlight/filetype

## @fn ble/syntax/highlight/filetype filename [opts]
##   @param[in] fielname
##   @param[in,opt] opts
##     @opt follow-symlink
##   @var[out] type
function ble/syntax/highlight/filetype {
  type=
  local file=$1

  # Note: #D1168 Cygwin では // で始まるパスはとても遅い
  if [[ ( $OSTYPE == cygwin || $OSTYPE == msys ) && $file == //* ]]; then
    [[ $file == // ]] && ((type=ATTR_FILE_DIR))
    [[ $type ]]; return "$?"
  fi

  if [[ :$2: != *:follow-symlink:* && -h $file ]]; then
    if [[ -e $file ]]; then
      ((type=ATTR_FILE_LINK))
    else
      ((type=ATTR_FILE_ORPHAN))
    fi
  elif [[ -e $file ]]; then
    if [[ -d $file ]]; then
      if [[ -k $file ]]; then
        ((type=ATTR_FILE_STICKY))
      elif [[ :$2: != *:follow-symlink:* && -h ${file%/} ]]; then
        ((type=ATTR_FILE_LINK))
      else
        ((type=ATTR_FILE_DIR))
      fi
    elif [[ -f $file ]]; then
      if [[ -u $file ]]; then
        ((type=ATTR_FILE_SETUID))
      elif [[ -g $file ]]; then
        ((type=ATTR_FILE_SETGID))
      elif [[ -x $file ]]; then
        ((type=ATTR_FILE_EXEC))
      else
        ((type=ATTR_FILE_FILE))
      fi
    elif [[ -c $file ]]; then
      ((type=ATTR_FILE_CHR))
    elif [[ -p $file ]]; then
      ((type=ATTR_FILE_FIFO))
    elif [[ -S $file ]]; then
      ((type=ATTR_FILE_SOCK))
    elif [[ -b $file ]]; then
      ((type=ATTR_FILE_BLK))
    fi
  elif local rex='^https?://[^ ^`"<>\{|}]+$'; [[ $file =~ $rex ]]; then
    ((type=ATTR_FILE_URL))
  fi
  [[ $type ]]
}

#------------------------------------------------------------------------------
# ble/syntax/highlight/ls_colors

## @dict _ble_syntax_highlight_lscolors_ext
## @dict _ble_syntax_highlight_lscolors_suffix
##   Those dictionaries are defined in core-syntax-def.sh

_ble_syntax_highlight_lscolors=()
_ble_syntax_highlight_lscolors_rl_colored_completion_prefix=

function ble/syntax/highlight/ls_colors/.clear {
  _ble_syntax_highlight_lscolors=()
  ble/gdict#clear _ble_syntax_highlight_lscolors_ext
  ble/gdict#clear _ble_syntax_highlight_lscolors_suffix
  _ble_syntax_highlight_lscolors_rl_colored_completion_prefix=
}

## @fn ble/syntax/highlight/ls_colors/.register-suffix suffix value
##   @param[in] suffix value
function ble/syntax/highlight/ls_colors/.register-suffix {
  local suffix=$1 value=$2
  if [[ $suffix == .readline-colored-completion-prefix ]]; then
    _ble_syntax_highlight_lscolors_rl_colored_completion_prefix=$value
  elif [[ $suffix == .* ]]; then
    ble/gdict#set _ble_syntax_highlight_lscolors_ext "$suffix" "$value"
  else
    ble/gdict#set _ble_syntax_highlight_lscolors_suffix "$suffix" "$value"
  fi
}

function ble/syntax/highlight/ls_colors/.has-suffix {
  ((${#_ble_syntax_highlight_lscolors_ext[@]})) ||
    ((${#_ble_syntax_highlight_lscolors_suffix[@]}))
}

## @fn ble/syntax/highlight/ls_colors/.match-suffix path
##   @param[in] path
##   @var[out] ret
function ble/syntax/highlight/ls_colors/.match-suffix {
  ret=
  local filename=${1##*/} suffix= g=

  local ext=$filename
  while [[ $ext == *.* ]]; do
    ext=${ext#*.}
    if ble/gdict#get _ble_syntax_highlight_lscolors_ext ".$ext" && [[ $ret ]]; then
      suffix=.$ext g=$ret
      break
    fi
  done

  local key keys
  ble/gdict#keys _ble_syntax_highlight_lscolors_suffix
  keys=("${ret[@]}")
  for key in "${keys[@]}"; do
    ((${#key}>${#suffix})) &&
      [[ $filename == *"$key" ]] &&
      ble/gdict#get _ble_syntax_highlight_lscolors_suffix "$key" &&
      [[ $ret ]] &&
      suffix=$key g=$ret
  done

  ret=$g
  [[ $ret ]]
}

function ble/syntax/highlight/ls_colors/.parse {
  ble/syntax/highlight/ls_colors/.clear

  local fields field
  ble/string#split fields : "$1"
  for field in "${fields[@]}"; do
    [[ $field == *=* ]] || continue
    if [[ $field == 'ln=target' ]]; then
      _ble_syntax_highlight_lscolors[ATTR_FILE_LINK]=target
      continue
    fi

    local lhs=${field%%=*}
    local ret; ble/color/sgrspec2g "${field#*=}"; local rhs=$ret
    case $lhs in
    ('di') _ble_syntax_highlight_lscolors[ATTR_FILE_DIR]=$rhs  ;;
    ('st') _ble_syntax_highlight_lscolors[ATTR_FILE_STICKY]=$rhs  ;;
    ('ln') _ble_syntax_highlight_lscolors[ATTR_FILE_LINK]=$rhs ;;
    ('or') _ble_syntax_highlight_lscolors[ATTR_FILE_ORPHAN]=$rhs ;;
    ('fi') _ble_syntax_highlight_lscolors[ATTR_FILE_FILE]=$rhs ;;
    ('su') _ble_syntax_highlight_lscolors[ATTR_FILE_SETUID]=$rhs ;;
    ('sg') _ble_syntax_highlight_lscolors[ATTR_FILE_SETGID]=$rhs ;;
    ('ex') _ble_syntax_highlight_lscolors[ATTR_FILE_EXEC]=$rhs ;;
    ('cd') _ble_syntax_highlight_lscolors[ATTR_FILE_CHR]=$rhs  ;;
    ('pi') _ble_syntax_highlight_lscolors[ATTR_FILE_FIFO]=$rhs ;;
    ('so') _ble_syntax_highlight_lscolors[ATTR_FILE_SOCK]=$rhs ;;
    ('bd') _ble_syntax_highlight_lscolors[ATTR_FILE_BLK]=$rhs  ;;
    (.*)   ble/syntax/highlight/ls_colors/.register-suffix "$lhs" "$rhs" ;;
    (\*?*) ble/syntax/highlight/ls_colors/.register-suffix "${lhs:1}" "$rhs" ;;
    esac
  done
}

## @fn ble/syntax/highlight/ls_colors filename
##   対応する LS_COLORS 設定が見つかった時に g を上書きし成功します。
##   それ以外の場合は g は変更せず失敗します。
##   @param[in] filename
##   @var[ref] type
##     This specifies the type of the file.  When the file is symbolic link and
##     `ln=target' is specified, this function rewrites `type` to the file type
##     of the target file.
##   @var[in,out] g
function ble/syntax/highlight/ls_colors {
  local file=$1
  if ((type==ATTR_FILE_LINK)) && [[ ${_ble_syntax_highlight_lscolors[ATTR_FILE_LINK]} == target ]]; then
    # determine type based on resolved file
    ble/syntax/highlight/filetype "$file" follow-symlink ||
      type=$ATTR_FILE_ORPHAN
    if ((type==ATTR_FILE_FILE)) && ble/syntax/highlight/ls_colors/.has-suffix; then
      ble/util/readlink "$file"
      file=$ret
    fi
  fi

  if ((type==ATTR_FILE_FILE)); then
    local ret=
    if ble/syntax/highlight/ls_colors/.match-suffix "$file"; then
      local g1=$ret
      ble/color/face2g filename_ls_colors; g=$ret
      ble/color/g#append g "$g1"
      return 0
    fi
  fi

  local g1=${_ble_syntax_highlight_lscolors[type]}
  if [[ $g1 ]]; then
    ble/color/face2g filename_ls_colors; g=$ret
    ble/color/g#append g "$g1"
    return 0
  fi

  return 1
}

function ble/syntax/highlight/getg-from-filename {
  local filename=$1 type=
  ble/syntax/highlight/filetype "$filename"
  if [[ $bleopt_filename_ls_colors ]]; then
    if ble/syntax/highlight/ls_colors "$filename"; then
      return 0
    fi
  fi

  if [[ $type ]]; then
    ble/syntax/attr2g "$type"
  else
    g=
  fi
}

function bleopt/check:filename_ls_colors {
  ble/syntax/highlight/ls_colors/.parse "$value"
}
bleopt -I filename_ls_colors

#------------------------------------------------------------------------------
# ble/progcolor

_ble_syntax_progcolor_vars=(
  node TE_i TE_nofs wtype wlen wbeg wend wattr)
_ble_syntax_progcolor_wattr_vars=(
  wattr_buff wattr_pos wattr_g)

## @fn ble/progcolor/load-word-data i:nofs
##   @var[out] TE_i TE_nofs node
##   @var[out] wtype wlen wbeg wend wattr
function ble/progcolor/load-word-data {
  # TE_i TE_nofs
  TE_i=${1%%:*} TE_nofs=${1#*:}
  [[ $1 != *:* ]] && TE_nofs=0

  # node
  ble/string#split-words node "${_ble_syntax_tree[TE_i-1]}"

  # wvars
  wtype=${node[TE_nofs]}
  wlen=${node[TE_nofs+1]}
  wattr=${node[TE_nofs+4]}
  wbeg=$((TE_i-wlen))
  wend=$TE_i
}

## @fn ble/progcolor/set-wattr value
##   @var[in] TE_i TE_nofs node
function ble/progcolor/set-wattr {
  ble/syntax/urange#update color_ "$wbeg" "$wend"
  ble/syntax/wrange#update _ble_syntax_word_ "$TE_i"
  node[TE_nofs+4]=$1
  local IFS=$_ble_term_IFS
  _ble_syntax_tree[TE_i-1]="${node[*]}"
}

## @fn ble/progcolor/eval-word [iword] [opts]
##   現在のコマンドの iword 番目の単語を評価した値を返します。
##   iword を省略した場合には現在着色中の単語が使われます。
##   単語が評価できない場合にはコマンドは失敗します。
##
##   @param[in,opt] iword
##   @param[in,opt] opts
##     ble/syntax:bash/simple-word/eval に対する opts を指定します。
##
##   @var[in] progcolor_iword
##     現在処理中の単語の番号を指定します。
##     iword を省略した時に使われます。
##   @var[in,out] progcolor_wvals
##   @var[in,out] progcolor_stats
##     単語の評価値のキャッシュです。
##   @var[out] ret
##
function ble/progcolor/eval-word {
  local iword=${1:-progcolor_iword} opts=$2
  if [[ ${progcolor_stats[iword]+set} ]]; then
    ret=${progcolor_wvals[iword]}
    return "${progcolor_stats[iword]}"
  fi

  local wtxt=${comp_words[iword]}
  local simple_flags simple_ibrace
  if ! ble/syntax:bash/simple-word/reconstruct-incomplete-word "$wtxt"; then
    # not simple word
    ret=
    progcolor_stats[iword]=2
    progcolor_wvals[iword]=
    return 2
  fi

  ble/syntax:bash/simple-word/eval "$ret" "$opts"; local ext=$?
  ((ext==148)) && return 148
  if ((ext!=0)); then
    # fail glob
    ret=
    progcolor_stats[iword]=1
    progcolor_wvals[iword]=
    return 1
  fi

  progcolor_stats[iword]=0
  progcolor_wvals[iword]=$ret
  return 0
}

## @fn ble/progcolor/load-cmdspec-opts
##   @var[out] cmdspec_opts
function ble/progcolor/load-cmdspec-opts {
  if [[ $progcolor_cmdspec_opts ]]; then
    cmdspec_opts=$progcolor_cmdspec_opts
  else
    ble/cmdspec/opts#load "${comp_words[0]}"
    progcolor_cmdspec_opts=${cmdspec_opts:-:}
  fi
}

## @fn ble/progcolor/stop-option#init cmdspec_opts
##   @var[out] rexrej rexreq stopat
function ble/progcolor/stop-option#init {
  rexrej='^--$' rexreq= stopat=
  local cmdspec_opts=$1
  if [[ $cmdspec_opts ]]; then
    # copied from ble/complete/source:option/.stops-option
    if [[ :$cmdspec_opts: == *:no-options:* ]]; then
      stopat=0
      return 1
    elif ble/opts#extract-first-optarg "$cmdspec_opts" stop-options-at && [[ $ret ]]; then
      ((stopat=ret))
      return 1
    fi

    local ret
    if ble/opts#extract-first-optarg "$cmdspec_opts" stop-options-on && [[ $ret ]]; then
      rexrej=$ret
    elif [[ :$cmdspec_opts: == *:disable-double-hyphen:* ]]; then
      rexrej=
    fi
    if ble/opts#extract-first-optarg "$cmdspec_opts" stop-options-unless && [[ $ret ]]; then
      rexreq=$ret
    elif [[ :$cmdspec_opts: == *:stop-options-postarg:* ]]; then
      rexreq='^-.+'
      ble/opts#has "$cmdspec_opts" plus-options && rexreq='^[-+].+'
    fi
  fi
}
## @fn ble/progcolor/stop-option#test value
##   @var[in] rexrej rexreq
function ble/progcolor/stop-option#test {
  [[ $rexrej && $1 =~ $rexrej || $rexreq && ! ( $1 =~ $rexreq ) ]]
}

## @fn ble/progcolor/is-option-context
##   現在の単語位置がオプションが解釈される文脈かどうかを判定します。
##
##   @var progcolor_iword
##     現在の単語の位置。
##
##   @var progcolor_optctx[0]
##     空の時には未だオプションを初期化していない事を示します。
##     現在のコマンドについて何処までオプション停止条件を検査済みかを記録します。
##
##   @var progcolor_optctx[1]
##     負の時は常にオプションが有効である事を示す。
##     0の時は常にオプションが無効である事を示す。
##     正の時はその位置以前の引数でオプションが有効である事を示す。
##
##   @var progcolor_optctx[2]
##   @var progcolor_optctx[3]
##   @var progcolor_optctx[4]
##     それぞれ抽出済みの rexrej rexreq stopat の値を記録します。
##     ble/progcolor/stop-option#init によって初期化された値のキャッシュです。
##
function ble/progcolor/is-option-context {
  # 既にオプション停止位置が計算済みの場合
  if [[ ${progcolor_optctx[1]} ]]; then
    # Note: 等号は停止を引き起こした引数 -- 自体の時 (オプションとして有効)
    ((progcolor_optctx[1]<0?1:(progcolor_iword<=progcolor_optctx[1])))
    return "$?"
  fi

  local rexrej rexreq stopat
  if [[ ! ${progcolor_optctx[0]} ]]; then
    progcolor_optctx[0]=1
    local cmdspec_opts
    ble/progcolor/load-cmdspec-opts
    ble/progcolor/stop-option#init "$cmdspec_opts"
    if [[ ! $rexrej$rexreq ]]; then
      progcolor_optctx[1]=${stopat:--1}
      ((progcolor_optctx[1]<0?1:(progcolor_iword<=progcolor_optctx[1])))
      return "$?"
    fi
    progcolor_optctx[2]=$rexrej
    progcolor_optctx[3]=$rexreq
    progcolor_optctx[4]=$stopat
  else
    rexrej=${progcolor_optctx[2]}
    rexreq=${progcolor_optctx[3]}
    stopat=${progcolor_optctx[4]}
  fi
  [[ $stopat ]] && ((progcolor_iword>stopat)) && return 1

  local iword
  for ((iword=progcolor_optctx[0];iword<progcolor_iword;iword++)); do
    ble/progcolor/eval-word "$iword" "$highlight_eval_opts"
    if ble/progcolor/stop-option#test "$ret"; then
      progcolor_optctx[1]=$iword
      return 1
    fi
  done
  progcolor_optctx[0]=$iword
  return 0
}

## @fn ble/progcolor/wattr#initialize
##   @var[out] wattr_buff
##   @var[out] wattr_pos
##   @var[out] wattr_g
function ble/progcolor/wattr#initialize {
  wattr_buff=()
  wattr_pos=$wbeg
  wattr_g=d
}
## @fn ble/progcolor/wattr#setg pos g
##   @param[in] pos
##   @param[in] g
##   @var[in,out] wattr_buff
##   @var[in,out] wattr_pos
##   @var[in,out] wattr_g
function ble/progcolor/wattr#setg {
  local pos=$1 g=$2
  local len=$((pos-wattr_pos))
  ((len>0)) && ble/array#push wattr_buff "$len:$wattr_g"
  wattr_pos=$pos
  wattr_g=$g
}
function ble/progcolor/wattr#setattr {
  local pos=$1 attr=$2 g
  ble/syntax/attr2g "$attr"
  ble/progcolor/wattr#setg "$pos" "$g"
}
## @fn ble/progcolor/wattr#finalize
##   @var[in,out] wattr_buff
##   @var[in,out] wattr_pos
##   @var[in,out] wattr_g
function ble/progcolor/wattr#finalize {
  local wattr
  if ((${#wattr_buff[@]})); then
    local len=$((wend-wattr_pos))
    ((len>0)) && ble/array#push wattr_buff \$:"$wattr_g"
    wattr_pos=$wend
    wattr_g=d
    IFS=, builtin eval 'wattr="m${wattr_buff[*]}"'
  else
    wattr=$wattr_g
  fi
  ble/progcolor/set-wattr "$wattr"
}


## @fn ble/progcolor/highlight-filename/.detect-separated-path word
##   @param[in] word
##   @var[in] wtype p0
##   @var[in] _ble_syntax_attr
##   @var[out] ret
##     有効な区切り文字の集合を返します。
function ble/progcolor/highlight-filename/.detect-separated-path {
  local word=$1
  ((wtype==CTX_ARGI||wtype==CTX_ARGEI||wtype==CTX_VALI||wtype==ATTR_VAR||wtype==CTX_RDRS)) || return 1

  local detect_opts=url:$highlight_eval_opts
  ((wtype==CTX_RDRS)) && detect_opts=$detect_opts:noglob
  [[ $word == '~'* ]] && ((_ble_syntax_attr[p0]!=ATTR_TILDE)) && detect_opts=$detect_opts:notilde
  ble/syntax:bash/simple-word/detect-separated-path "$word" :, "$detect_opts"
}

## @fn ble/progcolor/highlight-filename/.pathspec.wattr g [opts]
##   @param[in] g
##   @param[in,opt] opts
##   @var[in] wtype p0 p1
##   @var[in] path spec
function ble/progcolor/highlight-filename/.pathspec.wattr {
  local p=$p0 opts=$2

  if [[ :$opts: != *:no-path-color:* ]]; then
    local ipath npath=${#path[@]}
    for ((ipath=0;ipath<npath-1;ipath++)); do
      local epath=${path[ipath]} espec=${spec[ipath]}
      local g=d

      if ble/syntax/util/is-directory "$epath"; then
        local type
        if ble/syntax/highlight/filetype "$epath"; then
          ble/syntax/highlight/ls_colors ||
            ble/syntax/attr2g "$type"
        fi
      elif ((wtype==CTX_CMDI)); then
        # コマンド名の時はディレクトリが存在する必要 #D1419
        ble/syntax/attr2g "$ATTR_ERR"
      fi

      # コマンド名の時は下線は引かない様にする
      ((wtype==CTX_CMDI&&(g&=~_ble_color_gflags_Underline)))

      ble/progcolor/wattr#setg "$p" "$g"
      ((p=p0+${#espec}))
    done
  fi

  ble/progcolor/wattr#setg "$p" "$1"
  [[ $1 != d ]] &&
    ble/progcolor/wattr#setg "$p1" d
  return 0
}

## @fn ble/progcolor/highlight-filename/.pathspec-with-attr.wattr attr
##   @param[in] attr
##   @var[in] wtype p0 p1
##   @var[in] path spec
function ble/progcolor/highlight-filename/.pathspec-with-attr.wattr {
  local g; ble/syntax/attr2g "$1"
  ble/progcolor/highlight-filename/.pathspec.wattr "$g"
  return 0
}
## @fn ble/progcolor/highlight-filename/.pathspec-by-name.wattr value
##   @param[in] value
##   @var[in] wtype p0 p1
##   @var[in] path spec
function ble/progcolor/highlight-filename/.pathspec-by-name.wattr {
  local value=$1

  local highlight_opts=
  local type=; ble/syntax/highlight/filetype "$value"
  ((type==ATTR_FILE_URL)) && highlight_opts=no-path-color

  # check values
  if ((wtype==CTX_RDRF||wtype==CTX_RDRD2)); then
    if ((type==ATTR_FILE_DIR)); then
      # ディレクトリにリダイレクトはできない
      type=$ATTR_ERR
    elif ((_ble_syntax_TREE_WIDTH<=TE_nofs)); then
      # noclobber の時は既存ファイルを > または <> で上書きできない
      #
      # 仮定: _ble_syntax_word に於いてリダイレクトとファイルは同じ位置で終了すると想定する。
      #   この時、リダイレクトの情報の次にファイル名の情報が格納されている筈で、
      #   リダイレクトの情報は node[TE_nofs-_ble_syntax_TREE_WIDTH] に入っていると考えられる。
      #
      local redirect_ntype=${node[TE_nofs-_ble_syntax_TREE_WIDTH]:1}
      if [[ ( $redirect_ntype == *'>' || $redirect_ntype == '>'[\|\&] ) ]]; then
        if [[ -e $value || -h $value ]]; then
          if [[ -d $value || ! -w $value ]]; then
            # ディレクトリまたは書き込み権限がない
            type=$ATTR_ERR
          elif [[ ( $redirect_ntype == [\<\&]'>' || $redirect_ntype == '>' || $redirect_ntype == '>&' ) && -f $value ]]; then
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

  local g=
  if [[ $bleopt_filename_ls_colors ]]; then
    ble/syntax/highlight/ls_colors "$value"
  fi
  [[ $type && ! $g ]] && ble/syntax/attr2g "$type"

  ble/progcolor/highlight-filename/.pathspec.wattr "${g:-d}" "$highlight_opts"
  return 0
}

## @fn ble/progcolor/highlight-filename/.single.wattr p0:p1
##   @param[in] p0 p1
##     ファイル名の (コマンドライン内部における) 範囲を指定します。
##   @param[in] wtype
function ble/progcolor/highlight-filename/.single.wattr {
  local p0=${1%%:*} p1=${1#*:}
  local wtxt=${text:p0:p1-p0}

  # alias はシェル展開等を行う前に判定するべき
  if ((wtype==CTX_CMDI)) && ble/alias#active "$wtxt"; then
    # Note: [*?] 等の文字が含まれている alias 名の場合 failglob するかもしれ
    # ないが、実際は展開されるので問題ない。
    ble/progcolor/wattr#setattr "$p0" "$ATTR_CMD_ALIAS"
    return 0
  fi

  local path_opts=after-sep:$highlight_eval_opts
  # チルダ展開の文脈でない時には抑制
  [[ $wtxt == '~'* ]] && ((_ble_syntax_attr[p0]!=ATTR_TILDE)) && path_opts=$path_opts:notilde
  ((wtype==CTX_RDRS||wtype==ATTR_VAR||wtype==CTX_VALI&&wbeg<p0)) && path_opts=$path_opts:noglob

  local ret path spec ext value count
  ble/syntax:bash/simple-word/evaluate-path-spec "$wtxt" / "count:$path_opts"; ext=$? value=("${ret[@]}")
  ((ext==148)) && return 148
  if ((ext==142)); then
    if [[ $ble_textarea_render_defer_running ]]; then
      # background で timeout した時はこのファイル名の着色は諦める
      ble/progcolor/wattr#setg "$p0" d
    else
      # foreground で timeout した時は後で background で着色する為に取り敢えず抜ける
      return 148
    fi
  elif ((ext&&(wtype==CTX_CMDI||wtype==CTX_ARGI||wtype==CTX_ARGEI||wtype==CTX_RDRF||wtype==CTX_RDRS||wtype==CTX_RDRD||wtype==CTX_RDRD2||wtype==CTX_VALI))); then
    # failglob 等の理由で展開に失敗した場合
    ble/progcolor/highlight-filename/.pathspec-with-attr.wattr "$ATTR_ERR"
  elif (((wtype==CTX_RDRF||wtype==CTX_RDRD||wtype==CTX_RDRD2)&&count>=2)); then
    # 複数語に展開されたら駄目
    ble/progcolor/wattr#setattr "$p0" "$ATTR_ERR"
  elif ((wtype==CTX_CMDI)); then
    local attr=${_ble_syntax_attr[wbeg]}
    if ((attr!=ATTR_KEYWORD&&attr!=ATTR_KEYWORD_BEGIN&&attr!=ATTR_KEYWORD_END&&attr!=ATTR_KEYWORD_MID&&attr!=ATTR_DEL)); then
      local type=; ble/syntax/highlight/cmdtype "$value" "$wtxt"
      if ((type==ATTR_CMD_FILE||type==ATTR_CMD_FILE||type==ATTR_ERR)); then
        ble/progcolor/highlight-filename/.pathspec-with-attr.wattr "$type"
      elif [[ $type ]]; then
        ble/progcolor/wattr#setattr "$p0" "$type"
      fi
    fi
  elif ((wtype==CTX_RDRD||wtype==CTX_RDRD2)); then
    if local rex='^[0-9]+-?$|^-$'; [[ $value =~ $rex ]]; then
      ble/progcolor/wattr#setattr "$p0" "$ATTR_DEL"
    elif ((wtype==CTX_RDRD2)); then
      ble/progcolor/highlight-filename/.pathspec-by-name.wattr "$value"
    else
      ble/progcolor/wattr#setattr "$p0" "$ATTR_ERR"
    fi
  elif ((wtype==CTX_ARGI||wtype==CTX_ARGEI||wtype==CTX_VALI||wtype==ATTR_VAR||wtype==CTX_RDRS||wtype==CTX_RDRF)); then
    ble/progcolor/highlight-filename/.pathspec-by-name.wattr "$value"
  fi
}

function ble/progcolor/highlight-filename.wattr {
  local p0=$1 p1=$2
  if ((p0<p1)) && [[ $bleopt_highlight_filename ]]; then
    local wtxt=${text:p0:p1-p0}
    local ret; ble/progcolor/highlight-filename/.detect-separated-path "$wtxt"; local ext=$?
    ((ext==148)) && return 148
    if ((ext==0)); then
      local sep=$ret ranges i
      ble/syntax:bash/simple-word/locate-filename "$wtxt" "$sep" "url:$highlight_eval_opts"
      (($?==148)) && return 148; ranges=("${ret[@]}")
      for ((i=0;i<${#ranges[@]};i+=2)); do
        ble/progcolor/highlight-filename/.single.wattr "$((p0+ranges[i])):$((p0+ranges[i+1]))"
        (($?==148)) && return 148
      done
    elif ble/syntax:bash/simple-word/is-simple "$wtxt"; then
      ble/progcolor/highlight-filename/.single.wattr "$p0":"$p1"
      (($?==148)) && return 148
    fi
  fi
}

function ble/progcolor/@wattr {
  [[ $wtype =~ ^[0-9]+$ ]] || return 1
  [[ $wattr == - ]] || return 1
  local "${_ble_syntax_progcolor_wattr_vars[@]/%/=}" # WA #D1570 checked
  ble/progcolor/wattr#initialize

  "$@"; local ext=$?

  if ((ext==148)); then
    _ble_textarea_render_defer=1
    ble/syntax/wrange#update _ble_syntax_word_defer_ "$wend"
  else
    ble/progcolor/wattr#finalize
  fi
  return "$ext"
}

## @fn ble/progcolor/word:default/.is-option wtxt
##   @var[in] wtype
##   @var[in] progcolor_*
function ble/progcolor/word:default/.is-option {
  # Note: オプションとして許される文字に関しては_ble_complete_option_chars と同期を取る。
  ((wtype==CTX_ARGI||wtype==CTX_ARGEI||wtype==CTX_ARGVI)) &&
    ble/string#match "$1" '^(-[-_a-zA-Z0-9!#$%&:;.,^~|\?/*@]*)=?' && # 高速な判定を先に済ませる
    ble/progcolor/is-option-context &&
    ble/string#match "$1" '^(-[-_a-zA-Z0-9!#$%&:;.,^~|\?/*@]*)=?' # 再実行 for BASH_REMATCH
}

## @fn ble/progcolor/word:default
##   @var[in] node TE_i TE_nofs
##   @var[in] wtype wlen wbeg wend wattr
##   @var[in] ${_ble_syntax_progcolor_wattr_vars[@]}
function ble/progcolor/word:default/impl.wattr {
  if ((wtype==CTX_RDRH||wtype==CTX_RDRI||wtype==ATTR_FUNCDEF||wtype==ATTR_ERR)); then
    # ヒアドキュメントのキーワード指定部分は、
    # 展開・コマンド置換などに従った解析が行われるが、
    # 実行は一切起こらないので一色で塗りつぶす。
    ble/progcolor/wattr#setattr "$wbeg" "$wtype"

  else
    # @var p0 p1
    #   文字列を切り出す範囲。
    local p0=$wbeg p1=$wend wtxt=${text:wbeg:wlen}

    # 変数代入
    if ((wtype==ATTR_VAR||wtype==CTX_VALI)); then
      # 変数代入の場合は右辺だけ切り出す。
      #   Note: arr=(a=a*b a[1]=a*b) などはパス名展開の対象ではない。
      #     これは変数代入の形式として認識されているからである。
      #     以下では element-assignment を指定することで、
      #     配列要素についても変数代入の形式を抽出する様にしている。
      local ret
      ble/syntax:bash/find-rhs "$wtype" "$wbeg" "$wlen" element-assignment && p0=$ret
    elif ((wtype==CTX_ARGI||wtype==CTX_ARGEI||wtype==CTX_VALI)) && { local rex='^[_a-zA-Z][_a-zA-Z0-9]*='; [[ $wtxt =~ $rex ]]; }; then
      # 変数代入形式の通常引数
      ((p0+=${#BASH_REMATCH}))
    elif ble/progcolor/word:default/.is-option "$wtxt"; then
      # --prefix= 等のオプション引数
      local rematch=$BASH_REMATCH rematch1=${BASH_REMATCH[1]}
      local ret; ble/color/face2g argument_option
      ble/progcolor/wattr#setg "$p0" "$ret"
      ble/progcolor/wattr#setg "$((p0+${#rematch1}))" d
      ((p0+=${#rematch}))
    fi

    ble/progcolor/highlight-filename.wattr "$p0" "$p1"
    (($?==148)) && return 148
  fi

  return 0
}

function ble/progcolor/word:default {
  ble/progcolor/@wattr ble/progcolor/word:default/impl.wattr
}

## @fn ble/progcolor/default
##   @var[in] comp_words comp_cword comp_line comp_point
##   @var[in] tree_words
##   @var[in,out] color_umin color_umax
function ble/progcolor/default {
  local i "${_ble_syntax_progcolor_vars[@]/%/=}" # WA #D1570 checked
  for ((i=1;i<${#comp_words[@]};i++)); do
    local ref=${tree_words[i]}
    [[ $ref ]] || continue
    local progcolor_iword=$i
    ble/progcolor/load-word-data "$ref"
    ble/progcolor/word:default
  done
}

## @fn ble/progcolor/.compline-rewrite-command command [args...]
##   @var[in,out] comp_words comp_cword comp_line comp_point
function ble/progcolor/.compline-rewrite-command {
  local ocmd=${comp_words[0]}
  [[ $1 != "$ocmd" ]] || (($#>=2)) || return 1
  local IFS=$_ble_term_IFS
  local ins="$*"
  comp_line=$ins${comp_line:${#ocmd}}
  ((comp_point-=${#ocmd},comp_point<0&&(comp_point=0),comp_point+=${#ins}))
  comp_words=("$@" "${comp_words[@]:1}")
  ((comp_cword&&(comp_cword+=$#-1)))

  # update tree_words
  ble/array#reserve-prototype "$#"
  tree_words=("${tree_words[0]}" "${_ble_array_prototype[@]::$#-1}" "${tree_words[@]:1}")
}
## @fn ble/progcolor cmd opts
##   @var[in] comp_words comp_cword comp_line comp_point
##   @var[in] tree_words
##   @var[in,out] color_umin color_umax
function ble/progcolor {
  local cmd=$1 opts=$2

  # cache used by "eval-word"
  local -a progcolor_stats=()
  local -a progcolor_wvals=()

  # cache used by "load-cmdspec-opts"
  local progcolor_cmdspec_opts=

  # cache used by "is-option-context"
  local -a progcolor_optctx=()

  local -a alias_args=()
  local checked=" " processed=
  while :; do
    if ble/is-function ble/cmdinfo/cmd:"$cmd"/chroma; then
      ble/progcolor/.compline-rewrite-command "$cmd" "${alias_args[@]}"
      ble/cmdinfo/cmd:"$cmd"/chroma "$opts"
      processed=1
      break
    elif [[ $cmd == */?* ]] && ble/is-function ble/cmdinfo/cmd:"${cmd##*/}"/chroma; then
      ble/progcolor/.compline-rewrite-command "${cmd##*/}" "${alias_args[@]}"
      ble/cmdinfo/cmd:"${cmd##*/}"/chroma "$opts"
      processed=1
      break
    fi
    checked="$checked$cmd "

    local ret
    ble/alias#expand "$cmd"
    ble/string#split-words ret "$ret"
    [[ $checked == *" $ret "* ]] && break
    cmd=$ret
    ((${#ret[@]}>=2)) &&
      alias_args=("${ret[@]:1}" "${alias_args[@]}")
  done
  [[ $processed ]] ||
    ble/progcolor/default

  # コマンド名に対しては既定の着色を実行
  if [[ ${tree_words[0]} ]]; then
    local "${_ble_syntax_progcolor_vars[@]/%/=}" # WA #D1570 checked
    ble/progcolor/load-word-data "${tree_words[0]}"
    [[ $wattr == - ]] && ble/progcolor/word:default
  fi
}

#------------------------------------------------------------------------------
# ble/highlight/layer:syntax

# adapter に頼らず直接実装したい
function ble/highlight/layer:syntax/touch-range {
  ble/syntax/urange#update '' "$@"
}
function ble/highlight/layer:syntax/fill {
  local _ble_local_script='
    local iNAME=0 i1NAME=$2 i2NAME=$3
    for ((iNAME=i1NAME;iNAME<i2NAME;iNAME++)); do
      NAME[iNAME]=$4
    done
  '; builtin eval -- "${_ble_local_script//NAME/$1}"
}

_ble_highlight_layer_syntax_VARNAMES=(
  _ble_highlight_layer_syntax_buff
  _ble_highlight_layer_syntax_active
  _ble_highlight_layer_syntax1_table
  _ble_highlight_layer_syntax2_table
  _ble_highlight_layer_syntax3_list
  _ble_highlight_layer_syntax3_table)
function ble/highlight/layer:syntax/initialize-vars {
  # Note (#D2000): core-syntax は遅延ロードされるので layter/update/shift 対象
  # の配列は全て必要な要素数を備えている必要がある。
  local prev_iN=${#_ble_highlight_layer_plain_buff[*]}
  ble/array#reserve-prototype "$prev_iN"
  _ble_highlight_layer_syntax_buff=("${_ble_array_prototype[@]::prev_iN}")
  _ble_highlight_layer_syntax1_table=("${_ble_array_prototype[@]::prev_iN}")
  _ble_highlight_layer_syntax2_table=("${_ble_array_prototype[@]::prev_iN}")
  _ble_highlight_layer_syntax3_table=("${_ble_array_prototype[@]::prev_iN}") # errors
  _ble_highlight_layer_syntax3_list=()
}
ble/highlight/layer:syntax/initialize-vars

function ble/highlight/layer:syntax/update-attribute-table {
  ble/highlight/layer/update/shift _ble_highlight_layer_syntax1_table
  if ((_ble_syntax_attr_umin>=0)); then
    ble/highlight/layer:syntax/touch-range _ble_syntax_attr_umin _ble_syntax_attr_umax

    local i g=0
    ((_ble_syntax_attr_umin>0)) &&
      ((g=_ble_highlight_layer_syntax1_table[_ble_syntax_attr_umin-1]))

    for ((i=_ble_syntax_attr_umin;i<_ble_syntax_attr_umax;i++)); do
      if [[ ${_ble_syntax_attr[i]} ]]; then
        ble/syntax/attr2g "${_ble_syntax_attr[i]}"
      fi
      _ble_highlight_layer_syntax1_table[i]=$g
    done

    _ble_syntax_attr_umin=-1 _ble_syntax_attr_umax=-1
  fi
}

function ble/highlight/layer:syntax/word/.update-attributes/.proc {
  [[ $wtype =~ ^[0-9]+$ ]] || return 1
  [[ ${node[TE_nofs+4]} == - ]] || return 1

  if ((wtype==CTX_CMDI||wtype==CTX_ARGI||wtype==CTX_ARGVI||wtype==CTX_ARGEI)); then
    local comp_line comp_point comp_words comp_cword tree_words
    if ble/syntax:bash/extract-command-by-noderef "$TE_i:$TE_nofs" treeinfo; then
      local cmd=${comp_words[0]}
      ble/progcolor "$cmd"
      return 0
    fi
  fi

  # コマンドラインを復元できなければ単一単語の着色
  ble/progcolor/word:default
}

## @fn ble/highlight/layer:syntax/word/.update-attributes
## @var[in] _ble_syntax_word_umin,_ble_syntax_word_umax
## @var[in,out] color_umin color_umax
function ble/highlight/layer:syntax/word/.update-attributes {
  ((_ble_syntax_word_umin>=0)) || return 1

  local _ble_syntax_bash_simple_eval_timeout=$bleopt_highlight_timeout_sync
  local highlight_eval_opts=cached:single:stopcheck

  [[ $bleopt_highlight_eval_word_limit ]] &&
    highlight_eval_opts=$highlight_eval_opts:limit=$((bleopt_highlight_eval_word_limit))

  # Timeout setting for simple-word/eval
  if [[ ! $ble_textarea_render_defer_running ]]; then
    local _ble_syntax_bash_simple_eval_timeout_carry=
    highlight_eval_opts=$highlight_eval_opts:timeout-carry
  fi

  ble/syntax/tree-enumerate-in-range "$_ble_syntax_word_umin" "$_ble_syntax_word_umax" \
    ble/highlight/layer:syntax/word/.update-attributes/.proc
}

## @fn ble/highlight/layer:syntax/word/.apply-attribute wbeg wend wattr
##   @param[in] wbeg wend wattr
function ble/highlight/layer:syntax/word/.apply-attribute {
  local wbeg=$1 wend=$2 wattr=$3
  ((wbeg<color_umin&&(wbeg=color_umin),
    wend>color_umax&&(wend=color_umax),
    wbeg<wend)) || return 1

  if [[ $wattr =~ ^[0-9]+$ ]]; then
    ble/array#fill-range _ble_highlight_layer_syntax2_table "$wbeg" "$wend" "$wattr"
  elif [[ $wattr == m* ]]; then
    local ranges; ble/string#split ranges , "${wattr:1}"
    local i=$wbeg j range
    for range in "${ranges[@]}"; do
      local len=${range%%:*} sub_wattr=${range#*:}
      if [[ $len == '$' ]]; then
        j=$wend
      else
        ((j=i+len,j>wend&&(j=wend)))
      fi
      ble/highlight/layer:syntax/word/.apply-attribute "$i" "$j" "$sub_wattr"
      (((i=j)<wend)) || break
    done
  elif [[ $wattr == d ]]; then
    ble/array#fill-range _ble_highlight_layer_syntax2_table "$wbeg" "$wend" ''
  fi
}

function ble/highlight/layer:syntax/word/.proc-childnode {
  if [[ $wtype =~ ^[0-9]+$ ]]; then
    local wbeg=$wbegin wend=$TE_i
    ble/highlight/layer:syntax/word/.apply-attribute "$wbeg" "$wend" "$attr"
  fi

  ((tchild>=0)) && ble/syntax/tree-enumerate-children "$proc_children"
}

## @var[in,out] _ble_syntax_word_umin _ble_syntax_word_umax
function ble/highlight/layer:syntax/update-word-table {
  # update table2 (単語の削除に関しては後で考える)
  # (1) 単語色の計算
  local color_umin=-1 color_umax=-1 iN=${#_ble_syntax_text}
  ble/highlight/layer:syntax/word/.update-attributes

  # (2) 色配列 shift
  ble/highlight/layer/update/shift _ble_highlight_layer_syntax2_table

  # 2015-08-16 暫定 (本当は入れ子構造を考慮に入れたい)
  ble/syntax/wrange#update _ble_syntax_word_ "$_ble_syntax_vanishing_word_umin" "$_ble_syntax_vanishing_word_umax"
  ble/syntax/wrange#update color_ "$_ble_syntax_vanishing_word_umin" "$_ble_syntax_vanishing_word_umax"
  _ble_syntax_vanishing_word_umin=-1 _ble_syntax_vanishing_word_umax=-1

  # (3) 色配列に登録
  ble/highlight/layer:syntax/word/.apply-attribute 0 "$iN" d # clear word color
  local TE_i
  for ((TE_i=_ble_syntax_word_umax;TE_i>=_ble_syntax_word_umin;)); do
    if ((TE_i>0)) && [[ ${_ble_syntax_tree[TE_i-1]} ]]; then
      local -a node
      ble/string#split-words node "${_ble_syntax_tree[TE_i-1]}"

      local wlen=${node[1]}
      local wbeg=$((TE_i-wlen)) wend=$TE_i

      if [[ ${node[0]} =~ ^[0-9]+$ ]]; then
        local attr=${node[4]}
        ble/highlight/layer:syntax/word/.apply-attribute "$wbeg" "$wend" "$attr"
      fi

      local tclen=${node[2]}
      if ((tclen>=0)); then
        local tchild=$((TE_i-tclen))
        local tree= TE_nofs=0 proc_children=ble/highlight/layer:syntax/word/.proc-childnode
        ble/syntax/tree-enumerate-children "$proc_children"
      fi

      ((TE_i=wbeg))
    else
      ((TE_i--))
    fi
  done
  ((color_umin>=0)) && ble/highlight/layer:syntax/touch-range "$color_umin" "$color_umax"

  _ble_syntax_word_umin=-1 _ble_syntax_word_umax=-1
}

function ble/highlight/layer:syntax/update-error-table/set {
  local i1=$1 i2=$2 g=$3
  if ((i1<i2)); then
    ble/highlight/layer:syntax/touch-range "$i1" "$i2"
    ble/highlight/layer:syntax/fill _ble_highlight_layer_syntax3_table "$i1" "$i2" "$g"
    _ble_highlight_layer_syntax3_list[${#_ble_highlight_layer_syntax3_list[@]}]="$i1 $i2"
  fi
}
function ble/highlight/layer:syntax/update-error-table {
  ble/highlight/layer/update/shift _ble_highlight_layer_syntax3_table

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
        ble/highlight/layer:syntax/fill _ble_highlight_layer_syntax3_table "$a" "$b" ''
        ble/highlight/layer:syntax/touch-range "$a" "$b"
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
    local ret; ble/color/face2g syntax_error; local g=$ret

    # 入れ子が閉じていないエラー
    local -a stat
    ble/string#split-words stat "${_ble_syntax_stat[iN]}"
    local ctx=${stat[0]} nlen=${stat[3]} nparam=${stat[6]}
    [[ $nparam == none ]] && nparam=
    local i inest
    if ((nlen>0)) || [[ $nparam ]]; then
      # 終端点の着色
      ble/highlight/layer:syntax/update-error-table/set "$((iN-1))" "$iN" "$g"

      if ((nlen>0)); then
        ((inest=iN-nlen))
        while ((inest>=0)); do
          # 開始字句の着色
          local inest2
          for ((inest2=inest+1;inest2<iN;inest2++)); do
            [[ ${_ble_syntax_attr[inest2]} ]] && break
          done
          ble/highlight/layer:syntax/update-error-table/set "$inest" "$inest2" "$g"

          ((i=inest))
          local wtype wbegin tchild tprev
          ble/syntax/parse/nest-pop
          ((inest>=i&&(inest=i-1)))
        done
      fi
    fi

    # コマンド欠落・引数の欠落
    if ((ctx==CTX_CMDX1||ctx==CTX_CMDXC||ctx==CTX_FARGX1||ctx==CTX_SARGX1||ctx==CTX_FARGX2||ctx==CTX_CARGX1||ctx==CTX_CARGX2||ctx==CTX_COARGX)); then
      # 終端点の着色
      ble/highlight/layer:syntax/update-error-table/set "$((iN-1))" "$iN" "$g"
    fi
  fi
}

function ble/highlight/layer:syntax/update {
  local text=$1 player=$2
  local i iN=${#text}

  local umin=-1 umax=-1
  # 少なくともこの範囲は文字が変わっているので再描画する必要がある
  ((DMIN>=0)) && umin=$DMIN umax=$DMAX

  # 今回 layer:syntax が無効の時
  if [[ ! $bleopt_highlight_syntax ]]; then
    if [[ $_ble_highlight_layer_syntax_active ]]; then
      _ble_highlight_layer_syntax_active=
      PREV_UMIN=0 PREV_UMAX=${#1}
    fi
    return 0
  fi

  # 前回 layer:syntax が無効だった時
  if [[ ! $_ble_highlight_layer_syntax_active ]]; then
    # Request full update
    _ble_highlight_layer_syntax_active=1
    umin=0 umax=${#text}
  fi

  #--------------------------------------------------------

#%if !release
  if [[ $bleopt_syntax_debug ]]; then
    local debug_attr_umin=$_ble_syntax_attr_umin
    local debug_attr_uend=$_ble_syntax_attr_umax
  fi
#%end

  ble/cmdspec/initialize # load chroma
  ble/highlight/layer:syntax/update-attribute-table
  ble/highlight/layer:syntax/update-word-table
  ble/highlight/layer:syntax/update-error-table

  # shift&sgr 設定
  if ((DMIN>=0)); then
    ble/highlight/layer/update/shift _ble_highlight_layer_syntax_buff
    if ((DMAX>0)); then
      local g sgr ch ret
      ble/highlight/layer:syntax/getg "$DMAX"
      ble/color/g2sgr "$g"; sgr=$ret
      ch=${_ble_highlight_layer_plain_buff[DMAX]}
      _ble_highlight_layer_syntax_buff[DMAX]=$sgr$ch
    fi
  fi

  local i j g gprev=0
  if ((umin>0)); then
    ble/highlight/layer:syntax/getg "$((umin-1))"
    gprev=$g
  fi

  if ((umin>=0)); then
    local ret
    for ((i=umin;i<=umax;i++)); do
      local ch=${_ble_highlight_layer_plain_buff[i]}
      ble/highlight/layer:syntax/getg "$i"
      [[ $g ]] || ble/highlight/layer/update/getg "$i"
      if ((gprev!=g)); then
        ble/color/g2sgr "$g"
        ch=$ret$ch
        ((gprev=g))
      fi
      _ble_highlight_layer_syntax_buff[i]=$ch
    done
  fi

  PREV_UMIN=$umin PREV_UMAX=$umax
  PREV_BUFF=_ble_highlight_layer_syntax_buff

#%if !release
  if [[ $bleopt_syntax_debug ]]; then
    local status buff= nl=$'\n'
    _ble_syntax_attr_umin=$debug_attr_umin _ble_syntax_attr_umax=$debug_attr_uend ble/syntax/print-status -v status

    local -a DRAW_BUFF=()
    ble/syntax/print-layer-buffer.draw plain
    ble/syntax/print-layer-buffer.draw syntax
    ble/syntax/print-layer-buffer.draw disabled
    ble/syntax/print-layer-buffer.draw region
    ble/syntax/print-layer-buffer.draw overwrite
    local ret; ble/canvas/sflush.draw
    status=$status$ret
    #ble/util/assign buff 'declare -p _ble_textarea_bufferName $_ble_textarea_bufferName | cat -A'; status="$status$buff"
    ble/edit/info/show ansi "$status"
  fi
#%end

  # # 以下は単語の分割のデバグ用
  # local -a words=() word
  # for ((i=1;i<=iN;i++)); do
  #   if [[ ${_ble_syntax_tree[i-1]} ]]; then
  #     ble/string#split-words word "${_ble_syntax_tree[i-1]}"
  #     local wtxt="${text:i-word[1]:word[1]}" value
  #     if ble/syntax:bash/simple-word/is-simple "$wtxt"; then
  #       local ret; ble/syntax:bash/simple-word/eval "$wtxt" noglob; value=$ret
  #     else
  #       value="? ($wtxt)"
  #     fi
  #     ble/array#push words "[$value ${word[*]}]"
  #   fi
  # done
  # ble/edit/info/show text "${words[*]}"
}

function ble/highlight/layer:syntax/getg {
  [[ $bleopt_highlight_syntax ]] || return 1
  local i=$1
  if [[ ${_ble_highlight_layer_syntax3_table[i]} ]]; then
    g=${_ble_highlight_layer_syntax3_table[i]}
  elif [[ ${_ble_highlight_layer_syntax2_table[i]} ]]; then
    g=${_ble_highlight_layer_syntax2_table[i]}
  elif [[ ${_ble_highlight_layer_syntax1_table[i]} ]]; then
    g=${_ble_highlight_layer_syntax1_table[i]}
  fi
}

function ble/highlight/layer:syntax/textarea_render_defer.hook {
  ble/syntax/wrange#update _ble_syntax_word_ "$_ble_syntax_word_defer_umin" "$_ble_syntax_word_defer_umax"
  _ble_syntax_word_defer_umin=-1
  _ble_syntax_word_defer_umax=-1
}
blehook textarea_render_defer!=ble/highlight/layer:syntax/textarea_render_defer.hook

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
#%m main main.r/\<ATTR_/_ble_attr_/
#%m main main.r/\<CTX_/_ble_ctx_/
#%x main

function ble/syntax/import { return 0; }

blehook/invoke syntax_load
ble/function#try ble/textarea#invalidate str

return 0
