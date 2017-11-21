#!/bin/bash

_ble_measure_base=0
source benchmark.sh

ble-measure :

#------------------------------------------------------------------------------
# 1 条件コマンドと算術式コマンドのどちらが速いのか?
#
# →算術式コマンド (()) が最も速い。
# 条件コマンドが次に速い。
# 算術式コマンド let は遅い。
#

function measure1 {
  wtype=1 atype=-1
  function greater.w0 () { [[ wtype -ge 0 ]]; }
  function greater.w1 () { ((wtype>=0)); }
  function greater.w2 () { let 'wtype>=0'; }
  function greater.a0 () { [[ atype -ge 0 ]]; }
  function greater.a1 () { ((atype>=0)); }
  function greater.a2 () { let 'atype>=0'; }

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
  function greater.w0 () { [[ wtype -ge 0 && ${arr[wtype]} ]]; }
  function greater.w1 () { ((wtype>=0)) && [[ ${arr[wtype]} ]]; }
  function greater.a0 () { [[ atype -ge 0 && ${arr[atype]} ]]; }
  function greater.a1 () { ((atype>=0)) && [[ ${arr[atype]} ]]; }
  
  ble-measure 'greater.w0' #  29.30 usec/eval
  ble-measure 'greater.w1' #  30.20 usec/eval
  ble-measure 'greater.a0' #  21.00 usec/eval
  ble-measure 'greater.a1' #  19.20 usec/eval
}

#------------------------------------------------------------------------------
# 3 実は代入は算術式の外でやった方が速かったりするのか?
#
# →算術式の中でやった方が速い。
#
# これは実のところ bash の構文解析&評価が、
# 算術式の中と外でどちらの方が速いのかという競争である。
#

function measure3 {
  a=2 b=3 c=4
  function assign.d1 () { ((x=a*2+b*3-c*4)); }
  function assign.d2 () { x=$((a*2+b*3-c*4)); }
  function assign.c1 () { x=0; ((x+=a*2+b*3-c*4)); }
  function assign.c2 () { x=0; x=$((x+a*2+b*3-c*4)); }

  ble-measure 'assign.d1' #  22.10 usec/eval
  ble-measure 'assign.d2' #  23.20 usec/eval
  ble-measure 'assign.c1' #  28.10 usec/eval
  ble-measure 'assign.c2' #  29.40 usec/eval
}
measure3
