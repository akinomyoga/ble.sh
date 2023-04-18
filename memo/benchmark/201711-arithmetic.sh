#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

#------------------------------------------------------------------------------
# 1 条件コマンドと算術式コマンドのどちらが速いのか?
#
# →算術式コマンド (()) が最も速い。
# 条件コマンドが次に速い。
# 算術式コマンド let は遅い。
#

function measure1 {
  wtype=1 atype=-1
  function greater.w0 { [[ wtype -ge 0 ]]; }
  function greater.w1 { ((wtype>=0)); }
  function greater.w2 { let 'wtype>=0'; }
  function greater.a0 { [[ atype -ge 0 ]]; }
  function greater.a1 { ((atype>=0)); }
  function greater.a2 { let 'atype>=0'; }

  ble-measure 'greater.w0' #  19.20 usec/eval
  ble-measure 'greater.w1' #  16.50 usec/eval
  ble-measure 'greater.w2' #  20.80 usec/eval
  ble-measure 'greater.a0' #  19.40 usec/eval
  ble-measure 'greater.a1' #  16.70 usec/eval
  ble-measure 'greater.a2' #  21.10 usec/eval
}

#------------------------------------------------------------------------------
# 2 条件コマンド一個で済ませた方が速いのか、算術式コマンドと条件コマンドに分割した方が速いのか。
#
# →どちらとも言えない。最初の条件が満たされない時には、分割した方が速い。
# 両方が評価される時には単体の条件コマンドの方が微妙に速い。
#

function measure2 {
  arr=(1 2 3)
  wtype=1 atype=-1
  function greater.w0 { [[ wtype -ge 0 && ${arr[wtype]} ]]; }
  function greater.w1 { ((wtype>=0)) && [[ ${arr[wtype]} ]]; }
  function greater.a0 { [[ atype -ge 0 && ${arr[atype]} ]]; }
  function greater.a1 { ((atype>=0)) && [[ ${arr[atype]} ]]; }
  
  ble-measure 'greater.w0' #  29.30 usec/eval
  ble-measure 'greater.w1' #  30.20 usec/eval
  ble-measure 'greater.a0' #  21.00 usec/eval
  ble-measure 'greater.a1' #  19.20 usec/eval
}

#------------------------------------------------------------------------------
# 3 実は代入は算術式の外でやった方が速かったりするのか?
#
# * 算術式の中でやった方が速い。
#   これは実のところ bash の構文解析&評価が、
#   算術式の中と外でどちらの方が速いのかという競争である。
#
# * 流石に直接代入する場合には変数代入の方が速い。
#

function measure3 {
  a=2 b=3 c=4
  function assign.d1 { ((x=a*2+b*3-c*4)); }
  function assign.d2 { x=$((a*2+b*3-c*4)); }
  function assign.c1 { x=0; ((x+=a*2+b*3-c*4)); }
  function assign.c2 { x=0; x=$((x+a*2+b*3-c*4)); }

  ble-measure 'assign.d1' # 22.10 usec/eval
  ble-measure 'assign.d2' # 23.20 usec/eval
  ble-measure 'assign.c1' # 28.10 usec/eval
  ble-measure 'assign.c2' # 29.40 usec/eval

  function assign.a1 { ((x=a)); }
  function assign.a2 { x=$a; }
  function assign.a3 { x=$((a)); } # a に式が含まれている可能性がある時
  ble-measure 'assign.a1' # 17.50 usec/eval
  ble-measure 'assign.a2' # 16.20 usec/eval
  ble-measure 'assign.a3' # 19.40 usec/eval
}
measure3

#------------------------------------------------------------------------------
# 4 変数代入で配列要素を読み出すのと、再帰算術式で読み出すのでどちらが速いか?
#
# →再帰算術式で読み出すのが断然速い。
# 意外と直接呼び出すのと大した違いはないようだ。
#

function measure4 {
  arr=(1 2 3)
  ref='arr[1]'
  function element.0 { ((arr[1]>=1)); }
  function element.1 { ((ref>=1)); }
  function element.2 { val=${arr[1]}; ((val>=1)); }
  ble-measure 'element.0' # 19.80 usec/eval
  ble-measure 'element.1' # 20.10 usec/eval
  ble-measure 'element.2' # 29.50 usec/eval
}
#measure4

#------------------------------------------------------------------------------
# 5 等値比較
#
# 整数値が標準形 ($value が $((value)) と同じになる) のとき、
# 意外なことに、算術式で比較した方が速い。
#
# 但し、2つの文字列の文字数比較では条件コマンドの方が微妙に速かった。
#
function measure5 {
  value=3
  function compare.1 { [[ $value == 3 ]]; }
  function compare.2 { ((value==3)); }
  ble-measure 'compare.1' # 17.40 usec/eval
  ble-measure 'compare.2' # 16.80 usec/eval

  lhs=3 rhs=3
  function compare.a1 { [[ $lhs == "$rhs" ]]; }
  function compare.a2 { ((lhs==rhs)); }
  ble-measure 'compare.a1' # 20.10 usec/eval
  ble-measure 'compare.a2' # 17.60 usec/eval

  atext=1234 btext=4321
  function compare.b1 { [[ ${#atext} == ${#btext} ]]; }
  function compare.b2 { ((${#atext}==${#btext})); }
  ble-measure 'compare.b1' # 27.60 usec/eval
  ble-measure 'compare.b2' # 27.90 usec/eval
}
#measure5

#------------------------------------------------------------------------------
# 6 条件つきの代入
#
# 条件が満たされるときは単一の算術式にまとめてしまった方が速い。
# また、もし分割するならば ((bar=c)) よりは bar=$c の方が速い。
# 条件が満たされないときは分割した方が良い。
#

function measure6 {
  value=3
  function cond-assign.a1 { c=4; ((c>value&&(bar=c))); }
  function cond-assign.a2 { c=4; ((c>value)) && ((bar=c)); }
  function cond-assign.a3 { c=4; ((c>value)) && bar=$c; }
  function cond-assign.b1 { c=3; ((c>value&&(bar=c))); }
  function cond-assign.b2 { c=3; ((c>value)) && ((bar=c)); }
  function cond-assign.b3 { c=3; ((c>value)) && bar=$c; }
  ble-measure 'cond-assign.a1' # 29.10 usec/eval
  ble-measure 'cond-assign.a2' # 32.90 usec/eval
  ble-measure 'cond-assign.a3' # 31.30 usec/eval
  ble-measure 'cond-assign.b1' # 27.70 usec/eval
  ble-measure 'cond-assign.b2' # 25.60 usec/eval
  ble-measure 'cond-assign.b3' # 25.60 usec/eval
}
#measure6
