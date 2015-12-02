#!/bin/bash
#%begin

_ble_util_array_prototype=()
function _ble_util_array_prototype.reserve {
  local n="$1"
  for ((i=${#_ble_util_array_prototype[@]};i<n;i++)); do
    _ble_util_array_prototype[i]=
  done
}

.ble-shopt-extglob-push() { shopt -s extglob;}
.ble-shopt-extglob-pop()  { shopt -u extglob;}

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

## @var[in,out] umin,umax
function ble/util/urange#update {
  local prefix="$1"
  local -i p1="$2" p2="${3:-$2}"
  ((0<=p1&&p1<p2)) || return
  (((${prefix}umin<0||${prefix}umin>p1)&&(${prefix}umin=p1),
    (${prefix}umax<0||${prefix}umax<p2)&&(${prefix}umax=p2)))
}
## @var[in,out] umin,umax
function ble/util/wrange#update {
  local prefix="$1"
  local -i p1="$2" p2="${3:-$2}"
  ((0<=p1&&p1<=p2)) || return
  (((${prefix}umin<0||${prefix}umin>p1)&&(${prefix}umin=p1),
    (${prefix}umax<0||${prefix}umax<p2)&&(${prefix}umax=p2)))
}

## @var[in,out] umin,umax
## @var[in] beg,end,end0,shift
function ble/util/urange#shift {
  local prefix="$1"
  ((${prefix}umin>=end0?(${prefix}umin+=shift):(
      ${prefix}umin>=beg&&(${prefix}umin=end)),
    ${prefix}umax>end0?(${prefix}umax+=shift):(
      ${prefix}umax>beg&&(${prefix}umax=beg)),
    ${prefix}umin>=${prefix}umax&&
      (${prefix}umin=${prefix}umax=-1)))
}
## @var[in,out] umin,umax
## @var[in] beg,end,end0,shift
function ble/util/wrange#shift {
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

## @var _ble_syntax_text
##   解析対象の文字列を保持します
## @var _ble_syntax_stat[i]
##   文字 #i を解釈しようとする直前の状態を記録する。
##   各要素は "ctx wlen wtype nlen tclen tplen" の形式をしている。
##   ctx は現在の文脈。
##   wlen は現在のシェル単語の継続している長さ。
##   nlen は現在の入れ子状態が継続している長さ。
##   tclen, tplen は tchild, tprev の負オフセット。
## @var _ble_syntax_nest[inest]
##   入れ子の情報
##   各要素は "ctx wlen wtype inest tclen tplen type" の形式をしている。
##   ctx wbegin inest wtype は入れ子を抜けた時の状態を表す。
##   type は入れ子の種類を表す文字列。
## @var _ble_syntax_tree[i-1]
##   境界 #i で終わる単語についての情報を保持する。
##   各要素は "wtype wlen tclen tplen ..." の形式をしている。
## @var _ble_syntax_attr[i]
##   文脈・属性の情報
_ble_syntax_text=
_ble_syntax_stat=()
_ble_syntax_nest=()
_ble_syntax_tree=()
_ble_syntax_attr=()

#--------------------------------------
# ble-syntax/tree-enumerate proc
# ble-syntax/tree-enumerate-children proc
# ble-syntax/tree-enumerate-in-range beg end proc

## @var[in]  iN
## @var[out] tree,i,nofs
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

    tree="${nest[6]} $olen $tclen $tplen -- ${tree[@]}"

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
## @param[in] command...
##   @var[in]     wtype,wbegin,wlen,attr,tchild
##   @var[in,out] tprev
##     列挙を中断する時は ble-syntax/tree-enumerate-break
##     を呼び出す事によって、tprev=-1 を設定します。
## @var[in] iN
## @var[in] tree,i,nofs
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

## @fn ble-syntax/tree-enumerate-in-range beg end proc
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
    .ble-text.s2c "$char" 0
    local code="$ret"
    if ((code<32)); then
      .ble-text.c2s "$((code+64))"
      graph="$_ble_term_rev^$ret$_ble_term_sgr0"
    elif ((code==127)); then
      graph="$_ble_term_rev^?$_ble_term_sgr0"
    elif ((128<=code&&code<160)); then
      .ble-text.c2s "$((code-64))"
      graph="${_ble_term_rev}M-^$ret$_ble_term_sgr0"
    else
      graph="'$char' ($code)"
    fi
  fi
}

## @var[in,out] word
function ble-syntax/print-status/.tree-prepend {
  local -i j="$1"
  local t="$2"
  tree[j]="$t${tree[j]}"
  ((max_tree_width<${#tree[j]}&&(max_tree_width=${#tree[j]})))
}

function ble-syntax/print-status/.dump-arrays/.append-attr-char {
  if (($?==0)); then
    attr="${attr}$1"
  else
    attr="${attr} "
  fi
}
## @var[out] resultA
## @var[in]  iN
function ble-syntax/print-status/.dump-arrays {
  local -a tree char line
  tree=()
  char=()
  line=()

  local i max_tree_width=0
  for ((i=0;i<iN;i++)); do
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

    local -a word nest stat
    word=(${_ble_syntax_tree[i]})
    local tword=
    if [[ $word ]]; then
      local nofs="$((${#word[@]}/BLE_SYNTAX_TREE_WIDTH*BLE_SYNTAX_TREE_WIDTH))"
      while (((nofs-=BLE_SYNTAX_TREE_WIDTH)>=0)); do
        local axis=$((i+1))
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

        tword=" word=${word[nofs]}:$_prev$b-$e$_child$tword"
        for ((;b<i;b++)); do
          ble-syntax/print-status/.tree-prepend b '|'
        done
        ble-syntax/print-status/.tree-prepend i '+'
      done
    fi

    nest=(${_ble_syntax_nest[i]})
    if [[ $nest ]]; then
      local nword='-'
      local nnest='-'
      ((nest[3]>=0)) && nnest="'${nest[6]}':$((i-nest[3]))-"
      ((nest[1]>=0)) && nword="${nest[2]}:$((i-nest[1]))-"
      nest=" nest=(${nest[0]} w=$nword n=$nnest t=${nest[4]}:${nest[5]})"
    fi

    stat=(${_ble_syntax_stat[i]})
    if [[ $stat ]]; then
      local sword=-
      local snest=-
      ((stat[3]>=0)) && snest="@$((i-stat[3]))"
      ((stat[1]>=0)) && sword="${stat[2]}:$((i-stat[1]))-"
      stat=" stat=(${stat[0]} w=$sword n=$snest t=${stat[4]}:${stat[5]})"
    fi

    local graph=
    ble-syntax/print-status/.graph "${_ble_syntax_text:i:1}"
    char[i]="$attr $index $graph"
    line[i]="$tword$nest$stat"
  done

  resultA='A?'$'\n'
  _ble_util_string_prototype.reserve max_tree_width
  for ((i=0;i<iN;i++)); do
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

  local _result="$resultA$_ble_term_NL$resultB"
  if [[ $1 == -v && $2 ]]; then
    eval "$2=\"\$_result\""
  else
    builtin echo "$_result"
  fi
}

#--------------------------------------

function ble-syntax/parse/generate-stat {
  _stat="$ctx $((wbegin<0?wbegin:i-wbegin)) $wtype $((inest<0?inest:i-inest)) $((tchild<0?tchild:i-tchild)) $((tprev<0?tprev:i-tprev))"
}

# 構文木の管理 (_ble_syntax_tree)

BLE_SYNTAX_TREE_WIDTH=5

function ble-syntax/parse/tree-append {
  local type="$1"
  local beg="$2" end="$i"
  local len="$((end-beg))"
  ((len==0)) && return

  # 子情報・兄情報
  local ochild=-1 oprev=-1
  ((tchild>=0&&(ochild=i-tchild)))
  ((tprev>=0&&(oprev=i-tprev)))

  [[ $type =~ ^[0-9]+$ ]] && ble-syntax/parse/touch-updated-word "$i"
  _ble_syntax_tree[i-1]="$type $len $ochild $oprev - ${_ble_syntax_tree[i-1]}"
}

function ble-syntax/parse/word-push {
  wtype="$1" wbegin="$2" tprev="$tchild" tchild=-1
}
## @fn ble-syntax/parse/word-pop
## 仮定: 1つ上の level は nest-push による level か top level のどちらかである。
##   この場合に限って ble-syntax/parse/nest-reset-tprev を用いて、tprev
##   を適切な値に復元することができる。
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

## 関数 ble-syntax/parse/nest-push newctx type
##  @param[in]     newctx 新しい ctx を指定します。
##  @param[in,opt] type   文法要素の種類を指定します。
##  @var  [in]     i      現在の位置を指定します。
##  @var  [in,out] ctx    復帰時の ctx を指定します。新しい ctx (newctx) を返します。
##  @var  [in,out] wbegin 復帰時の wbegin を指定します。新しい wbegin (-1) を返します。
##  @var  [in,out] wtype  復帰時の wtype を指定します。新しい wtype (-1) を返します。
##  @var  [in,out] inest  復帰時の inest を指定します。新しい inest (i) を返します。
function ble-syntax/parse/nest-push {
  local wlen=$((wbegin<0?wbegin:i-wbegin))
  local nlen=$((inest<0?inest:i-inest))
  local tclen=$((tchild<0?tchild:i-tchild))
  local tplen=$((tprev<0?tprev:i-tprev))
  _ble_syntax_nest[i]="$ctx $wlen $wtype $nlen $tclen $tplen ${2:-none}"
  ((ctx=$1,inest=i,wbegin=-1,wtype=-1,tprev=tchild,tchild=-1))
}
function ble-syntax/parse/nest-pop {
  ((inest<0)) && return 1

  local -a parentNest
  parentNest=(${_ble_syntax_nest[inest]})

  local ntype="${parentNest[6]}" nbeg="$inest"
  ble-syntax/parse/tree-append "n$ntype" "$nbeg" "$tchild" "$tprev"

  local wlen="${parentNest[1]}" nlen="${parentNest[3]}" tplen="${parentNest[5]}"
  ((ctx=parentNest[0]))
  ((wtype=parentNest[2]))
  ((wbegin=wlen<0?wlen:nbeg-wlen,
    inest=nlen<0?nlen:nbeg-nlen,
    tchild=i,
    tprev=tplen<0?tplen:nbeg-tplen))
}
function ble-syntax/parse/nest-type {
  local _var=type
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
    ((0<onest[3]&&onest[3]<=parent_inest)) || { ble-stackdump 'invalid nest' && return 0; }
#%end
    ((parent_inest-=onest[3]))
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
# Bash Script 文法
#
#------------------------------------------------------------------------------

# @var _BLE_SYNTAX_FCTX[]
# @var _BLE_SYNTAX_FEND[]
#   以上の二つの配列を通して文法要素は最終的に登録される。
#   (逆に言えば上の二つの配列を弄れば別の文法の解析を実行する事もできる)

# 文脈値達
CTX_UNSPECIFIED=0
CTX_ARGX=3   # (コマンド) 次に引数が来る
CTX_ARGX0=18 # (コマンド)   文法的には次に引数が来そうだがもう引数が来てはならない文脈。例えば ]] や )) の後。
CTX_CMDX=1   # (コマンド) 次にコマンドが来る。
CTX_CMDXV=13 # (コマンド)   var=val の直後。次にコマンドが来るかも知れないし、来ないかもしれない。
CTX_CMDXF=16 # (コマンド)   for の直後。直後が (( だったら CTX_CMDI に、他の時は CTX_CMDI に。
CTX_CMDX1=17 # (コマンド)   次にコマンドが少なくとも一つ来なければならない。例えば ( や && や while の直後。
CTX_CMDXC=26 # (コマンド)   次に複合コマンド('(' '{' '((' '[[' for select case if while until)が来る。
CTX_CMDI=2   # (コマンド) context,attr: in a command
CTX_ARGI=4   # (コマンド) context,attr: in an argument
CTX_VRHS=11  # (コマンド) context,attr: var=rhs
CTX_QUOT=5   # context,attr: in double quotations
CTX_EXPR=8   # context,attr: in expression
ATTR_ERR=6   # attr: error
ATTR_VAR=7   # attr: variable
ATTR_QDEL=9  # attr: delimiters for quotation
ATTR_DEF=10  # attr: default (currently not used)
ATTR_DEL=12  # attr: delimiters
ATTR_HISTX=21 # 履歴展開 (!!$ など)
ATTR_FUNCDEF=22 # 関数名 ( hoge() や function fuga など)
CTX_PARAM=14 # (パラメータ展開) context,attr: inside of parameter expansion
CTX_PWORD=15 # (パラメータ展開) context,attr: inside of parameter expansion
CTX_RDRF=19 # (リダイレクト) リダイレクト対象のファイル。
CTX_RDRD=20 # (リダイレクト) リダイレクト対象のファイルディスクリプタ。
CTX_VALX=23 # (値リスト) 次に値が来る
CTX_VALI=24 # (値リスト) 値の中
ATTR_COMMENT=25 # コメント

_BLE_SYNTAX_CSPACE=$' \t\n'

## @var _ble_syntax_bashc[]
##   特定の役割を持つ文字の集合。Bracket expression [～] に入れて使う為の物。
##   histchars に依存しているので変化があった時に更新する。
_ble_syntax_bashc=()
{
  # default values
  _ble_syntax_bashc_def=()
  _ble_syntax_bashc_def[CTX_ARGI]="$_BLE_SYNTAX_CSPACE;|&()<>\$\"\`\\'!^"
  _ble_syntax_bashc_def[CTX_QUOT]="\$\"\`\\!"       # 文字列 "～" で特別な意味を持つのは $ ` \ " のみ。+履歴展開の ! も。
  _ble_syntax_bashc_def[CTX_EXPR]="][}()\$\"\`\\'!" # ()[] は入れ子を数える為。} は ${var:ofs:len} の為。
  _ble_syntax_bashc_def[CTX_PWORD]="}\$\"\`\\!"     # パラメータ展開 ${～}

  # templates
  _ble_syntax_bashc_fmt=()
  _ble_syntax_bashc_fmt[CTX_ARGI]="$_BLE_SYNTAX_CSPACE;|&()<>\$\"\`\\'@h@q"
  _ble_syntax_bashc_fmt[CTX_QUOT]="\$\"\`\\@h"
  _ble_syntax_bashc_fmt[CTX_EXPR]="][}()\$\"\`\\'@h"
  _ble_syntax_bashc_fmt[CTX_PWORD]="}\$\"\`\\@h"

  ## @param[in] histc1 histc histc12
  ## @param[out] _ble_syntax_bashc[]
  function ble-syntax:bash/.update-_ble_syntax_bashc {
    if [[ $histc12 == '!^' ]]; then
      local key
      for key in CTX_ARGI CTX_QUOT CTX_EXPR CTX_PWORD; do
        _ble_syntax_bashc[key]="${_ble_syntax_bashc_def[key]}"
      done
    else
      local key
      for key in CTX_ARGI CTX_QUOT CTX_EXPR CTX_PWORD; do
        local a="${_ble_syntax_bashc_fmt[key]}"
        a="${a//@h/$histc1}"
        a="${a//@q/$histc2}"

        # Bracket expression として安全な順に並び替える必要がある:
        [[ $a == *']'* ]] && a="]${a//]}"
        [[ $a == *'-'* ]] && a="${a//-}-"

        _ble_syntax_bashc[key]="$a"
      done
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
    local rex_letter='[^'"${_ble_syntax_bashc[CTX_ARGI]}"']'
    _ble_syntax_rex_simple_word_element='('"$rex_letter"'|\\.|'"$rex_squot"'|'"$rex_dquot"'|'"$rex_param"'|'"$rex_param2"')'
    _ble_syntax_rex_simple_word='^'"$_ble_syntax_rex_simple_word_element"'+$'
  }
  ble-syntax:bash/.update-rex_simple_word
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

      ble-syntax/parse/nest-push "$CTX_PARAM" '${'
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
    ble-syntax/parse/nest-push "$CTX_EXPR" '(('
    ((i+=3))
    return 0
  elif [[ $tail == '$['* ]]; then
    ((_ble_syntax_attr[i]=CTX_PARAM))
    ble-syntax/parse/nest-push "$CTX_EXPR" '['
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
  fi

  return 1
}

function ble-syntax:bash/check-quotes {
  local rex

  if rex='^`([^`\]|\\(.|$))*(`?)|^'\''[^'\'']*('\''?)' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ATTR_QDEL,
      _ble_syntax_attr[i+1]=CTX_QUOT,
      i+=${#BASH_REMATCH},
      _ble_syntax_attr[i-1]=${#BASH_REMATCH[3]}||${#BASH_REMATCH[4]}?ATTR_QDEL:ATTR_ERR))
    return 0
  fi

  if ((ctx!=CTX_QUOT)); then
    if rex='^(\$?")([^'"${_ble_syntax_bashc[CTX_QUOT]}"']|\\.)*("?)' && [[ $tail =~ $rex ]]; then
      if [[ ${BASH_REMATCH[3]} ]]; then
        # 終端まで行った場合
        local rematch1="${BASH_REMATCH[1]}" # for bash-3.1 ${#arr[n]} bug
        ((_ble_syntax_attr[i]=ATTR_QDEL,
          _ble_syntax_attr[i+${#rematch1}]=CTX_QUOT,
          i+=${#BASH_REMATCH},
          _ble_syntax_attr[i-1]=ATTR_QDEL))
      else
        # 中に構造がある場合
        ble-syntax/parse/nest-push "$CTX_QUOT"
        ((_ble_syntax_attr[i]=ATTR_QDEL,
          _ble_syntax_attr[i+1]=CTX_QUOT,
          i+=${#BASH_REMATCH}))
      fi
      return 0
    elif rex='^\$'\''([^'\''\]|\\(.|$))*('\''?)' && [[ $tail =~ $rex ]]; then
      ((_ble_syntax_attr[i]=ATTR_QDEL,
        _ble_syntax_attr[i+2]=CTX_QUOT,
        i+=${#BASH_REMATCH},
        _ble_syntax_attr[i-1]=${#BASH_REMATCH[3]}?ATTR_QDEL:ATTR_ERR))
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
  if shopt -q interactive_comments &>/dev/null; then
    if ((wbegin<0||wbegin==i)) && local rex=$'^#[^\n]*' && [[ $tail =~ $rex ]]; then
      # 空白と同様に ctx は変えずに素通り (末端の改行は残す)
      ((_ble_syntax_attr[i]=ATTR_COMMENT,
        i+=${#BASH_REMATCH}))
      return 0
    fi
  fi

  return 1
}

# histchars には対応していない
#   histchars を変更した時に変更するべき所:
#   - _ble_syntax_rex_histexpand.init
#   - ble-syntax:bash/check-history-expansion
#   - _ble_syntax_bashc の中の !^ の部分
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
  [[ $- == *H* ]] || return 1

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

_BLE_SYNTAX_FCTX=()
_BLE_SYNTAX_FEND=()

_BLE_SYNTAX_FCTX[CTX_QUOT]=ble-syntax:bash/ctx-quot
function ble-syntax:bash/ctx-quot {
  # 文字列の中身
  local rex
  if rex='^([^'"${_ble_syntax_bashc[ctx]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
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

_BLE_SYNTAX_FCTX[CTX_EXPR]=ble-syntax:bash/ctx-expr
function ble-syntax:bash/ctx-expr {
  # 式の中身
  local rex

  if rex='^([^'"${_ble_syntax_bashc[ctx]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif rex='^[][()}]' && [[ $tail =~ $rex ]]; then
    if [[ ${BASH_REMATCH[0]} == ')' ]]; then
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == '((' ]]; then
        if [[ $tail == '))'* ]]; then
          ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
          ((i+=2))
          ble-syntax/parse/nest-pop
        else
          ((_ble_syntax_attr[i]=ATTR_ERR,
            i+=1))
          ble-syntax/parse/nest-pop
        fi
        return 0
      elif [[ $type == '(' ]]; then
        ((_ble_syntax_attr[i]=ctx,i+=1))
        ble-syntax/parse/nest-pop
        return 0
      else
        return 1
      fi
    elif [[ ${BASH_REMATCH[0]} == ']' ]]; then
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == '[' ]]; then
        # ((a[...]=123)) や $[...] などの場合。
        ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
        ((i++))
        ble-syntax/parse/nest-pop
        return 0
      elif [[ $type == 'a[' ]]; then
        if [[ $tail == ']='* ]]; then
          # a[...]= の場合。配列代入
          ble-syntax/parse/nest-pop
          ((_ble_syntax_attr[i]=CTX_EXPR,
            i+=2))
        else
          # a[...]... という唯のコマンドの場合。
          ((_ble_syntax_attr[i]=CTX_EXPR,i++))
          ble-syntax/parse/nest-pop
          ((ctx=CTX_CMDI,wtype=CTX_CMDI))
        fi
        return 0
      elif [[ $type == 'v[' ]]; then
        # ${v[]...} などの場合。
        ((_ble_syntax_attr[i]=CTX_EXPR,
          i++))
        ble-syntax/parse/nest-pop
        return 0
      else
        return 1
      fi
    elif [[ ${BASH_REMATCH[0]} == '}' ]]; then
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == '${' ]]; then
        ((_ble_syntax_attr[i]=_ble_syntax_attr[inest]))
        ((i++))
        ble-syntax/parse/nest-pop
        return 0
      else
        return 1
      fi
    else
      ble-syntax/parse/nest-push "$CTX_EXPR" "${BASH_REMATCH[0]}"
      ((_ble_syntax_attr[i]=ctx,
        i+=${#BASH_REMATCH}))
      return 0
    fi
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
_BLE_SYNTAX_FCTX[CTX_CMDX1]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXC]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXF]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDXV]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_ARGI]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_CMDI]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FCTX[CTX_VRHS]=ble-syntax:bash/ctx-command
_BLE_SYNTAX_FEND[CTX_CMDI]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_ARGI]=ble-syntax:bash/ctx-command/check-word-end
_BLE_SYNTAX_FEND[CTX_VRHS]=ble-syntax:bash/ctx-command/check-word-end

## 関数 ble-syntax:bash/ctx-command/check-word-end
## @var[in,out] ctx
## @var[in,out] wbegin
## @var[in,out] 他
function ble-syntax:bash/ctx-command/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  [[ ${text:i:1} == [^"$_BLE_SYNTAX_CSPACE;|&<>()"] ]] && return 1

  local wbeg="$wbegin" wlen="$((i-wbegin))" wend="$i"
  local word="${text:wbegin:wlen}"
  local wt="$wtype"

  if ((wt==CTX_CMDXC)); then
    if local rex='^(\(|\{|\(\(|\[\[|for|select|case|if|while|until)$' && [[ $word =~ $rex ]]; then
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

      i="$wbeg" ble-syntax/parse/nest-push "$CTX_VALX" '[['

      # work-around: word "[[" を nest 内部に設置し直す
      i="$wbeg" ble-syntax/parse/word-push "$CTX_CMDI" "$wbeg"
      ble-syntax/parse/word-pop

      return 0 ;;
    (['!{']|'time'|'do'|'if'|'then'|'else'|'while'|'until')
      ((ctx=CTX_CMDX1)) ;;
    ('for')
      ((ctx=CTX_CMDXF)) ;;
    ('}'|'done'|'fi'|'esac')
      ((ctx=CTX_ARGX0)) ;;
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
          #   仕方がないのでサブシェルと思って取り敢えず解析する
          ((_ble_syntax_attr[i]=CTX_ARGX0,i+=${#rematch1},
            _ble_syntax_attr[i]=ATTR_ERR,
            ctx=CTX_ARGX0))
          ble-syntax/parse/nest-push "$CTX_CMDX1" '('
          ((${#rematch2}>=2&&(_ble_syntax_attr[i+1]=CTX_CMDXC),
            i+=${#rematch2}))
          return 0
        else
          # case: /hoge */ 恐らくコマンド
          ((_ble_syntax_attr[i]=CTX_ARGX,i+=${#rematch1}))
        fi
      fi ;;
    esac
  elif ((ctx==CTX_ARGI)); then
    # case "$word" in
    # (']]')
    #   # 条件コマンド終了
    #   local type
    #   ble-syntax/parse/nest-type -v type
    #   if [[ $type == '[[' ]]; then
    #     ble-syntax/parse/touch-updated-attr "$wbeg"
    #     ((_ble_syntax_attr[wbeg]=ATTR_CMD_KEYWORD))
    #     ble-syntax/parse/nest-pop
    #     return 0
    #   else
    #     ((ctx=CTX_ARGX0))
    #   fi ;;
    # (*)
    #   ((ctx=CTX_ARGX)) ;;
    # esac
    ((ctx=CTX_ARGX))
  elif ((ctx==CTX_VRHS)); then
    ((ctx=CTX_CMDXV))
  fi

  return 0
}

function ble-syntax:bash/ctx-command {
  # コマンド・引数部分
  local rex

  local rex_delimiters="^[$_BLE_SYNTAX_CSPACE;|&<>()]"
  local rex_redirect='^((\{[a-zA-Z_][a-zA-Z_0-9]+\}|[0-9]+)?(&?>>?|<>?|[<>]&))['"$_BLE_SYNTAX_CSPACE"']*'
  if [[ ( $tail =~ $rex_delimiters || $wbegin -lt 0 && $tail =~ $rex_redirect ) && $tail != ['<>']'('* ]]; then
#%if !release
    ((ctx==CTX_ARGX||ctx==CTX_ARGX0||
         ctx==CTX_CMDX||ctx==CTX_CMDXF||
         ctx==CTX_CMDX1||ctx==CTX_CMDXC||ctx==CTX_CMDXV)) || ble-stackdump "invalid ctx=$ctx @ i=$i"
    ((wbegin<0&&wtype<0)) || ble-stackdump "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
#%end

    if rex="^[$_BLE_SYNTAX_CSPACE]+" && [[ $tail =~ $rex ]]; then
      # 空白 (ctx はそのままで素通り)
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      ((ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_CMDXV)) && [[ ${BASH_REMATCH[0]} =~ $'\n' ]] && ((ctx=CTX_CMDX))
      return 0
    elif [[ $tail =~ $rex_redirect ]]; then
      # リダイレクト (& 単体の解釈より優先する)

      # for bash-3.1 ${#arr[n]} bug ... 一旦 rematch1 に入れてから ${#rematch1} で文字数を得る。
      local rematch1="${BASH_REMATCH[1]}"
      if [[ $rematch1 == *'&' ]]; then
        ble-syntax/parse/nest-push "$CTX_RDRD" "$rematch1"
      else
        ble-syntax/parse/nest-push "$CTX_RDRF" "$rematch1"
      fi
      ((_ble_syntax_attr[i]=ATTR_DEL,
        _ble_syntax_attr[i+${#rematch1}]=CTX_ARGX,
        i+=${#BASH_REMATCH}))
      return 0

      #■リダイレクト&プロセス置換では直前の ctx を覚えて置いて後で復元する。
    elif rex='^;;&?|^;&|^(&&|\|[|&]?)|^[;&]' && [[ $tail =~ $rex ]]; then
      # 制御演算子 && || | & ; |& ;; ;;&

      # for bash-3.1 ${#arr[n]} bug
      local rematch1="${BASH_REMATCH[1]}"
      ((_ble_syntax_attr[i]=ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_CMDXV?ATTR_DEL:ATTR_ERR,
        ctx=${#rematch1}?CTX_CMDX1:CTX_CMDX,
        i+=${#BASH_REMATCH}))
      #■;& ;; ;;& の次に来るのは CTX_CMDX ではなくて CTX_CASE? 的な物では?
      #■;& ;; ;;& の場合には CTX_ARGX CTX_CMDXV に加え CTX_CMDX でも ERR ではない。
      return 0
    elif rex='^\(\(?' && [[ $tail =~ $rex ]]; then
      # サブシェル (, 算術コマンド ((
      local m="${BASH_REMATCH[0]}"
      ((_ble_syntax_attr[i]=(ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXC||ctx==CTX_CMDXF&&${#m}==2)?ATTR_DEL:ATTR_ERR))
      ((ctx=CTX_ARGX0))
      ble-syntax/parse/nest-push "$((${#m}==1?CTX_CMDX1:CTX_EXPR))" "$m"
      ((i+=${#m}))
      return 0
    elif [[ $tail == ')'* ]]; then
      local type
      ble-syntax/parse/nest-type -v type
      local attr=
      if [[ $type == '(' ]]; then
        # ( sub shell )
        # <( process substitution )
        # func ( invalid )
        ((attr=ATTR_DEL))
      elif [[ $type == '$(' ]]; then
        # $(command substitution)
        ((attr=CTX_PARAM))
      fi

      if [[ $attr ]]; then
        ((_ble_syntax_attr[i]=(ctx==CTX_CMDX||ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_CMDXV)?attr:ATTR_ERR,
          i+=1))
        ble-syntax/parse/nest-pop
        return 0
      fi
    else
      return 1
    fi
  fi

  if ble-syntax:bash/check-comment; then
    return 0
  fi

  local unexpectedWbegin=-1
  if ((wbegin<0)); then
    # case CTX_ARGX | CTX_ARGX0 | CTX_CMDXF
    #   ctx=CTX_ARGI
    # case CTX_CMDX | CTX_CMDX1 | CTX_CMDXC | CTX_CMDXV
    #   ctx=CTX_CMDI
    # case CTX_ARGI | CTX_CMDI | CTX_VRHS
    #   エラー...
    local octx="$ctx"
    ((ctx==CTX_ARGX0&&(unexpectedWbegin=i),
      ctx=(ctx==CTX_ARGX||ctx==CTX_ARGX0||ctx==CTX_CMDXF)?CTX_ARGI:CTX_CMDI,
      wtype=octx==CTX_CMDXC?octx:ctx))
    ble-syntax/parse/word-push "$wtype" "$i"
  fi

#%if !release
  ((ctx==CTX_CMDI||ctx==CTX_ARGI||ctx==CTX_VRHS)) || ble-stackdump 2
#%end

  local flagConsume=0
  if ((wbegin==i&&ctx==CTX_CMDI)) && rex='^[a-zA-Z_][a-zA-Z_0-9]*([=[]|\+=)' && [[ $tail =~ $rex ]]; then
    # for bash-3.1 ${#arr[n]} bug
    local rematch1="${BASH_REMATCH[1]}"

    ((wtype=ATTR_VAR,
      _ble_syntax_attr[i]=ATTR_VAR,
      i+=${#BASH_REMATCH},
      _ble_syntax_attr[i-${#rematch1}]=CTX_EXPR,
      ctx=CTX_VRHS))
    if [[ $rematch1 == '[' ]]; then
      # arr[
      i=$((i-1)) ble-syntax/parse/nest-push "$CTX_EXPR" 'a['
    elif [[ ${text:i} == '('* ]]; then
      # var=( var+=(
      ble-syntax/parse/word-pop # 単語キャンセル
      ((ctx=CTX_CMDXV)) # pop したら直ぐにコマンドが来て良い
      ble-syntax/parse/nest-push "$CTX_VALX" 'A('
      ((_ble_syntax_attr[i]=ATTR_DEL,i+=1))
    fi
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
# 文脈: 値リスト、条件コマンド
#
#   値リストと条件コマンドの文法は、 &<>() 等の文字に対して結構違う。
#   分離した方が良いのではないか?
#

_BLE_SYNTAX_FCTX[CTX_VALX]=ble-syntax:bash/ctx-values
_BLE_SYNTAX_FCTX[CTX_VALI]=ble-syntax:bash/ctx-values
_BLE_SYNTAX_FEND[CTX_VALI]=ble-syntax:bash/ctx-values/check-word-end

## 関数 ble-syntax:bash/ctx-values/check-word-end
function ble-syntax:bash/ctx-values/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  [[ ${text:i:1} == [^"$_BLE_SYNTAX_CSPACE;|&<>()"] ]] && return 1

  local wbeg="$wbegin" wlen="$((i-wbegin))" wend="$i"
  local word="${text:wbegin:wlen}"

  ble-syntax/parse/word-pop

  ble-assert '((ctx==CTX_VALI))' 'invalid context'
  case "$word" in
  (']]')
    # 条件コマンド終了
    local type
    ble-syntax/parse/nest-type -v type
    if [[ $type == '[[' ]]; then
      ble-syntax/parse/touch-updated-attr "$wbeg"
      ((_ble_syntax_attr[wbeg]=ATTR_CMD_KEYWORD))
      ble-syntax/parse/nest-pop
      return 0
    else
      ((ctx=CTX_VALX))
    fi ;;
  (*)
    ((ctx=CTX_VALX)) ;;
  esac

  return 0
}

function ble-syntax:bash/ctx-values {
  # コマンド・引数部分
  local rex

  local rex_delimiters="^[$_BLE_SYNTAX_CSPACE;|&<>()]"
  if [[ $tail =~ $rex_delimiters && $tail != ['<>']'('* ]]; then
#%if !release
    ((ctx==CTX_VALX)) || ble-stackdump "invalid ctx=$ctx @ i=$i"
    ((wbegin<0&&wtype<0)) || ble-stackdump "invalid word-context (wtype=$wtype wbegin=$wbegin) on non-word char."
#%end

    if rex="^[$_BLE_SYNTAX_CSPACE]+" && [[ $tail =~ $rex ]]; then
      # 空白 (ctx はそのままで素通り)
      ((_ble_syntax_attr[i]=ctx,i+=${#BASH_REMATCH}))
      return 0
    elif [[ $tail == ')'* ]]; then
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == 'A(' ]]; then
        # 配列定義の終了
        ((_ble_syntax_attr[i++]=ATTR_DEL))
        ble-syntax/parse/nest-pop
        return 0
      fi
      # そのまま単語へ(?)
    elif [[ $type == ';'* ]]; then
      ((_ble_syntax_attr[i++]=ATTR_ERR))
      return 0
    else
      local type
      ble-syntax/parse/nest-type -v type
      if [[ $type == 'A(' ]]; then
        ((_ble_syntax_attr[i++]=ATTR_ERR))
      else
        ((_ble_syntax_attr[i++]=ATTR_VALI))
      fi
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
  elif [[ $histc12 && $tail == ["$histc12"]* ]]; then
    ble-syntax:bash/check-history-expansion ||
      ((_ble_syntax_attr[i]=ctx,i++))
    return 0
  else
    local type
    ble-syntax/parse/nest-type -v type
    if [[ $type == '[[' ]]; then
      # 条件コマンドの時は $ や ) 等を許す。。
      ((_ble_syntax_attr[i]=ctx,i++))
      return 0
    fi
  fi

  return 1
}

#------------------------------------------------------------------------------
# 文脈: リダイレクト

_BLE_SYNTAX_FCTX[CTX_RDRF]=ble-syntax:bash/ctx-redirect
_BLE_SYNTAX_FCTX[CTX_RDRD]=ble-syntax:bash/ctx-redirect
_BLE_SYNTAX_FEND[CTX_RDRF]=ble-syntax:bash/ctx-redirect/check-word-end
_BLE_SYNTAX_FEND[CTX_RDRD]=ble-syntax:bash/ctx-redirect/check-word-end
function ble-syntax:bash/ctx-redirect/check-word-begin {
  if ((wbegin<0)); then
    # ※ここで ctx==CTX_RDRF か ctx==CTX_RDRD かの情報が使われるので
    #   CTX_RDRF と CTX_RDRD は異なる二つの文脈として管理している。
    ble-syntax/parse/word-push "$ctx" "$i"
    ble-syntax/parse/touch-updated-word "$i" #■これは不要では?
  fi
}
function ble-syntax:bash/ctx-redirect/check-word-end {
  # 単語の中にいない時は抜ける
  ((wbegin<0)) && return 1

  # 未だ続きがある場合は抜ける
  local tail="${text:i}"
  [[ $tail == [^"$_BLE_SYNTAX_CSPACE;|&<>()"]* || $tail == ['<>']'('* ]] && return 1

  # 単語の登録
  ble-syntax/parse/word-pop

  # pop
  ble-syntax/parse/nest-pop
#%if !release
  # ここで終端の必要のある ctx (CTX_CMDI や CTX_ARGI, CTX_VRHS など) になる事は無い。
  # 何故なら push した時は CMDX か ARGX の文脈にいたはずだから。
  ((ctx!=CTX_CMDI&&ctx!=CTX_ARGI&&ctx!=CTX_VRHS)) || ble-stackdump "invalid ctx=$ctx after nest-pop"
#%end
  return 0
}
function ble-syntax:bash/ctx-redirect {
  local rex

  local rex_delimiters="^[$_BLE_SYNTAX_CSPACE;|&<>()]"
  local rex_redirect='^((\{[a-zA-Z_][a-zA-Z_0-9]+\}|[0-9]+)?(&?>>?|<>?|[<>]&))['"$_BLE_SYNTAX_CSPACE"']*'
  if [[ ( $tail =~ $rex_delimiters || $wbegin -lt 0 && $tail =~ $rex_redirect ) && $tail != ['<>']'('* ]]; then
    ((_ble_syntax_attr[i-1]=ATTR_ERR))
    ble-syntax/parse/nest-pop
    return 1
  fi

  # 単語開始の設置
  ble-syntax:bash/ctx-redirect/check-word-begin

  if rex='^([^'"${_ble_syntax_bashc[CTX_ARGI]}"']|\\.)+' && [[ $tail =~ $rex ]]; then
    ((_ble_syntax_attr[i]=ctx,
      i+=${#BASH_REMATCH}))
    return 0
  elif ble-syntax:bash/check-process-subst; then
    return 0;
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
      ble/util/urange#update _ble_syntax_vanishing_word_ "$wbeg" "$wend"
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

# 実装中
function ble-syntax/parse/shift.impl2/.proc1 {
  while ((j>=j2)); do
    if ((j==i)); then
      ble-syntax/parse/shift.tree "$nofs"

      if (((tprev<=end0||wbegin<=end0)&&tchild>=0)); then
        # tprev<=end0 の場合、stat の中の tplen が shift 対象の可能性がある。
        ble-syntax/tree-enumerate-children ble-syntax/parse/shift.impl2/.proc1
      else
#%if !release
        [[ $ble_debug ]] && _ble_syntax_stat_shift[j+shift]=1
#%end
        ble-syntax/parse/shift.stat
        ble-syntax/parse/shift.nest
        ((j=wbegin)) # skip
      fi
      return
    else
#%if !release
      [[ $ble_debug ]] && _ble_syntax_stat_shift[j+shift]=1
#%end
      ble-syntax/parse/shift.stat
      ble-syntax/parse/shift.nest
      ((j--))
    fi
  done

  ((tprev=-1)) # 中断
}

## @var[in] i1,i2,j2,iN
## @var[in] beg,end,end0,shift
function ble-syntax/parse/shift {
  # ※shift==0 でも更新で消滅した部分を縮める必要があるので
  #   shift 実行する必要がある。

  local ble_shift_method=2
  if [[ $ble_shift_method == 1 ]]; then
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
  else
#%if !release
    [[ $ble_debug ]] && _ble_syntax_stat_shift=()
#%end

    local iN="${#_ble_syntax_text}"
    local j="$iN"
    ble-syntax/tree-enumerate ble-syntax/parse/shift.impl2/.proc1
  fi

  if ((shift!=0)); then
    # 更新範囲の shift
    ble/util/urange#shift _ble_syntax_attr_
    ble/util/wrange#shift _ble_syntax_word_
    ble/util/urange#shift _ble_syntax_vanishing_word_
  fi
}

#----------------------------------------------------------
# parse

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
  local -r beg="${2:-0}" end="${3:-${#text}}"
  local -r end0="${4:-$end}"
  ((end==beg&&end0==beg&&_ble_syntax_dbeg<0)) && return

  # 解析予定範囲の更新
  local -ir iN="${#text}" shift=end-end0
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
  ((0<=beg&&beg<=end&&end<=iN&&beg<=end0)) || ble-stackdump "X1 0 <= beg:$beg <= end:$end <= iN:$iN, beg:$beg <= end0:$end0 (shift=$shift text=$text)"
  ((0<=i1&&i1<=beg&&end<=i2&&i2<=iN)) || ble-stackdump "X2 0 <= $i1 <= $beg <= $end <= $i2 <= $iN"
#%end

  ble-syntax/vanishing-word/register _ble_syntax_tree 0 i1 j2 0 i1

  ble-syntax/parse/shift

  # 解析途中状態の復元
  local ctx wbegin wtype inest tchild tprev
  if [[ ${_ble_syntax_stat[i1]} ]]; then
    local -a stat
    stat=(${_ble_syntax_stat[i1]})
    local wlen="${stat[1]}" nlen="${stat[3]}" tclen="${stat[4]}" tplen="${stat[5]}"
    ctx="${stat[0]}"
    wbegin="$((wlen<0?wlen:i1-wlen))"
    wtype="${stat[2]}"
    inest="$((nlen<0?nlen:i1-nlen))"
    tchild="$((tclen<0?tclen:i1-tclen))"
    tprev="$((tplen<0?tplen:i1-tplen))"
  else
    # 初期値
    ctx="$CTX_CMDX" ##!< 現在の解析の文脈
    wbegin=-1       ##!< シェル単語内にいる時、シェル単語の開始位置
    wtype=-1        ##!< シェル単語内にいる時、シェル単語の種類
    inest=-1        ##!< 入れ子の時、親の開始位置
    tchild=-1
    tprev=-1
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
  ble-syntax:bash/initialize-vars

  # 解析
  _ble_syntax_text="$text"
  local i _stat
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
    _ble_syntax_stat[i]="$_stat"
    local tail="${text:i}"

    # 処理
    "${_BLE_SYNTAX_FCTX[ctx]}" || ((_ble_syntax_attr[i]=ATTR_ERR,i++))

    # nest-pop で CMDI/ARGI になる事もあるし、
    # また単語終端な文字でも FCTX が失敗する事もある (unrecognized な場合) ので、
    # (FCTX の中や直後ではなく) ここで単語終端をチェック
    [[ ${_BLE_SYNTAX_FEND[ctx]} ]] && "${_BLE_SYNTAX_FEND[ctx]}"
  done

  ble-syntax/vanishing-word/register _tail_syntax_tree -i2 i2+1 i 0 i

  ble/util/urange#update _ble_syntax_attr_ i1 i

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
  local rex_paramx='^\$([a-zA-Z_][a-zA-Z_0-9]*)?$'
  if [[ ${text:i:index-i} =~ $rex_paramx ]]; then
    ble-syntax/completion-context/add variable $((i+1))
  fi
}

## 関数 ble-syntax/completion-context/check-prefix
##   @var[in] text
##   @var[in] index
##   @var[out] context
function ble-syntax/completion-context/check-prefix {
  local rex_param='^[a-zA-Z_][a-zA-Z_0-9]*$'
  local rex_delimiters="^[$_BLE_SYNTAX_CSPACE;|&<>()]"

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
          ble-syntax/completion-context/add variable "$wbeg"
        fi
      fi
      ble-syntax/completion-context/check/parameter-expansion
    elif ((ctx==CTX_ARGI||ctx==CTX_VALI)); then
      # CTX_ARGI  → 引数の続き
      if ((wlen>=0)); then
        local source=argument
        ((ctx==CTX_VALI)) && source=file
        ble-syntax/completion-context/add "$source" "$wbeg"

        local sub="${text:wbeg:index-wbeg}"
        if [[ $sub == *[=:]* ]]; then
          sub="${sub##*[=:]}"
          ble-syntax/completion-context/add file "$((index-${#sub}))"
        fi
      fi
      ble-syntax/completion-context/check/parameter-expansion
    elif ((ctx==CTX_CMDX||ctx==CTX_CMDX1||ctx==CTX_CMDXC||ctx==CTX_CMDXV)); then
      # 直前の再開点が CMDX だった場合、
      # 現在地との間にコマンド名があればそれはコマンドである。
      # スペースや ;&| 等のコマンド以外の物がある可能性もある事に注意する。
      local word="${text:i:index-i}"
      if [[ $word =~ $_ble_syntax_rex_simple_word ]]; then
        ble-syntax/completion-context/add command "$i"
        if [[ $word =~ $rex_param ]]; then
          ble-syntax/completion-context/add variable "$i"
        fi
      fi
      ble-syntax/completion-context/check/parameter-expansion
    elif ((ctx==CTX_CMDXF)); then
      # CTX_CMDXF → (( でなければ 変数名
      if [[ ${text:i:index-1} =~ $rex_param ]]; then
        ble-syntax/completion-context/add variable "$i"
      fi
    elif ((ctx==CTX_ARGX||ctx==CTX_VALX)); then
      local source=argument
      ((ctx==CTX_VALX)) && source=file

      local sub="${text:i:index-i}"
      if [[ $sub =~ $_ble_syntax_rex_simple_word ]]; then
        ble-syntax/completion-context/add "$source" "$i"
        local rex="^([^'\"\$\\]|\\.)*="
        if [[ $sub =~ $rex ]]; then
          sub="${sub:${#BASH_REMATCH}}"
          ble-syntax/completion-context/add "$source" "$((index-${#sub}))"
        fi
      fi
      ble-syntax/completion-context/check/parameter-expansion
    elif ((ctx==CTX_RDRF||ctx==CTX_VRHS)); then
      # CTX_RDRF: redirect の filename 部分
      # CTX_VRHS: VAR=value の value 部分
      local sub="${text:i:index-i}"
      if [[ $sub =~ $_ble_syntax_rex_simple_word ]]; then
        ble-syntax/completion-context/add file "$i"
      fi
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

    if ((stat[0]==CTX_CMDX||
            stat[0]==CTX_CMDXV||
            stat[0]==CTX_CMDX1||
            stat[0]==CTX_CMDXC)); then
      ble-syntax/completion-context/add command "$index"
      ble-syntax/completion-context/add variable "$index"
    elif ((stat[0]==CTX_CMDXF)); then
      ble-syntax/completion-context/add variable "$index"
    elif ((stat[0]==CTX_ARGX)); then
      ble-syntax/completion-context/add argument "$index"
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
      ble/util/array-push comp_words "$wtxt"
    else
      comp_cword="${#comp_words[@]}"
      comp_point="${#comp_line}"
      comp_line="$wtxt $comp_line"
      ble/util/array-push comp_words ""
      ble/util/array-push comp_words "$wtxt"
    fi
  else
    comp_line="$wtxt$comp_line"
    ble/util/array-push comp_words "$wtxt"
  fi
}

function ble-syntax:bash/extract-command/.construct-proc {
  if [[ $wtype =~ ^[0-9]+$ ]]; then
    if ((wtype==CTX_CMDI)); then
      if ((pos<wbegin)); then
        echo clear words
        comp_line= comp_point= comp_cword= comp_words=()
      else
        ble-syntax:bash/extract-command/.register-word
        ble-syntax/tree-enumerate-break
        return
      fi
    elif ((wtype==CTX_ARGI)); then
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

  ble/util/array-reverse comp_words
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
  # @@
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

_ble_syntax_attr2iface=()
function _ble_syntax_attr2iface.define {
  ((_ble_syntax_attr2iface[$1]=_ble_faces__$2))
}
_ble_syntax_attr2iface.define CTX_ARGX     syntax_default
_ble_syntax_attr2iface.define CTX_ARGX0    syntax_default
_ble_syntax_attr2iface.define CTX_CMDX     syntax_default
_ble_syntax_attr2iface.define CTX_CMDXF    syntax_default
_ble_syntax_attr2iface.define CTX_CMDX1    syntax_default
_ble_syntax_attr2iface.define CTX_CMDXC    syntax_default
_ble_syntax_attr2iface.define CTX_CMDXV    syntax_default
_ble_syntax_attr2iface.define CTX_ARGI     syntax_default
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
_ble_syntax_attr2iface.define ATTR_COMMENT syntax_comment

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

function ble-syntax/attr2g {
  local iface="${_ble_syntax_attr2iface[$1]:-_ble_faces__syntax_default}"
  g="${_ble_faces[iface]}"
}

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
  [[ ! -e "$file" && ( $file == '~' || $file == '~/'* ) ]] && file="$HOME${file:1}"
  if [[ -d $file ]]; then
    ((type=ATTR_FILE_DIR))
  elif [[ -h $file ]]; then
    ((type=ATTR_FILE_LINK))
  elif [[ -x $file ]]; then
    ((type=ATTR_FILE_EXEC))
  elif [[ -f $file ]]; then
    ((type=ATTR_FILE_FILE))
  else
    type=
  fi
}

# adapter に頼らず直接実装したい
function ble-highlight-layer:syntax/touch-range {
  ble/util/urange#update '' "$@"
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
  [[ ${node[nofs]} =~ ^[0-9]+$ ]] || continue
  [[ ${node[nofs+4]} == - ]] || continue
  local wtxt="${text:wbeg:wlen}"
  ble/util/urange#update color_ "$wbeg" "$wend"
  if [[ $wtxt =~ $_ble_syntax_rex_simple_word ]]; then

    # 単語を展開
    local value
    if [[ $wtxt == '['* ]]; then
      # 先頭に [ があると配列添字と解釈されて失敗するので '' を前置する。
      eval "value=(''$wtxt)"
    else
      # 先頭が [ 以外の時は tilde expansion 等が有効になる様に '' は前置しない。
      eval "value=($wtxt)"
    fi

    local type=
    if ((wtype==CTX_CMDI)); then
      ble-syntax/highlight/cmdtype "$value" "$wtxt"
    elif ((wtype==CTX_ARGI||wtype==CTX_RDRF)); then
      ble-syntax/highlight/filetype "$value" "$wtxt"

      # エラー: ディレクトリにリダイレクトはできない
      ((wtype==CTX_RDRF&&type==ATTR_FILE_DIR&&(type=ATTR_ERR)))
    elif ((wtype==ATTR_FUNCDEF||wtype==ATTR_ERR)); then
      ((type=wtype))
    fi

    if [[ $type ]]; then
      local g
      ble-syntax/attr2g "$type"
      node[nofs+4]="$g"
    else
      node[nofs+4]='d'
    fi
    flagUpdateNode=1
  fi
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
  ble/util/wrange#update _ble_syntax_word_ _ble_syntax_vanishing_word_umin _ble_syntax_vanishing_word_umax
  ble/util/wrange#update color_ _ble_syntax_vanishing_word_umin _ble_syntax_vanishing_word_umax
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
  if [[ ${_ble_syntax_stat[iN]} ]]; then
    local g; ble-color-face2g syntax_error

    # 入れ子が閉じていないエラー
    local -a stat
    stat=(${_ble_syntax_stat[iN]})
    local ctx="${stat[0]}" nlen="${stat[3]}"
    local i inest
    if((nlen>0)); then
      # 終端点の着色
      ble-highlight-layer:syntax/update-error-table/set "$((iN-1))" "$iN" "$g"

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

    # コマンド欠落
    if ((ctx==CTX_CMDX1||ctx==CTX_CMDXC||ctx==CTX_CMDXF)); then
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
    local status buff=
    _ble_syntax_attr_umin="$debug_attr_umin" _ble_syntax_attr_umax="$debug_attr_uend" ble-syntax/print-status -v status
    ble/util/assign buff 'declare -p _ble_highlight_layer_plain_buff _ble_highlight_layer_syntax_buff | cat -A'; status="$status$buff"
    ble/util/assign buff 'declare -p _ble_highlight_layer_disabled_buff _ble_highlight_layer_region_buff _ble_highlight_layer_overwrite_mode_buff | cat -A'; status="$status$buff"
    #ble/util/assign buff 'declare -p _ble_line_text_buffName $_ble_line_text_buffName | cat -A'; status="$status$buff"
    .ble-line-info.draw "$status"
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
  #     ble/util/array-push words "[$value ${word[*]}]"
  #   fi
  # done
  # .ble-line-info.draw-text "${words[*]}"
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
attrg[CTX_CMDX]=$'\e[m'
attrg[CTX_CMDXF]=$'\e[m'
attrg[CTX_CMDX1]=$'\e[m'
attrg[CTX_CMDXC]=$'\e[m'
attrg[CTX_CMDXV]=$'\e[m'
attrg[CTX_ARGI]=$'\e[m'
attrg[CTX_CMDI]=$'\e[;91m'
attrg[CTX_VRHS]=$'\e[m'
attrg[CTX_RDRD]=$'\e[4m'
attrg[CTX_RDRF]=$'\e[4m'
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
    # .ble-text.s2c "$text" "$i"
    # .ble-text.c2w "$ret"
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
mytest 'a=1 b[x[y]]=1234 echo <( world ) > hello; ( sub shell); ((1+2*3));'
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
