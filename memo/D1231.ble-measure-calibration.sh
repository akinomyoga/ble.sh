# -*- mode: sh; mode: sh-bash -*-

f1() { local a; ble-measure -q 'a=1'; }
f2() { f1; }
f3() { f2; }
f4() { f3; }
f5() { f4; }
f6() { f5; }
f7() { f6; }
f8() { f7; }
f9() { f8; }
fA() { f9; }
ble-measure -q a=1; echo $nsec
f1; echo $nsec
f2; echo $nsec
f3; echo $nsec
f4; echo $nsec
f5; echo $nsec
f6; echo $nsec
f7; echo $nsec
f8; echo $nsec
f9; echo $nsec
fA; echo $nsec

# 結果を見ると f1 は短いがそれより増えると急に遅くなる。
#
#    S1   S5   D5   D1
# -- ---- ---- ---- ----
# NF -    -    -    -123
# f1 44   33   -72  35  
# f2 852  883  19   82  
# f3 877  907  77   97  
# f4 875  944  122  167 
# f5 953  991  207  232 
# f6 1035 1040 254  271 
# f7 1170 1102 297  337 
# f8 1222 1196 354  395 
# f9 1310 1222 395  466 
# fA 1357 1314 482  536 
#
# S1, S5 ... サブシェルで source した時。
#   S1 は _ble_measure_count=1 で
#   S5 は _ble_measure_count=5 である。
# D5 ... 直接 source した時。
#   _ble_measure_count=5 で計測した。
#
# 分かる事は、サブシェルで評価している時は入れ子の数が1回だと速いが、
# 関数が一段でも入ると急に遅くなってしまう。
# 直接実行している時には線形に増えている気がする。

#------------------------------------------------------------------------------
# 上記で調べた関数入れ子の傾きはコマンドが違っても同じだろうか。

echo a=1 b=2

g1() { local a b; ble-measure -q 'a=1 b=2'; }
g2() { g1; }
g3() { g2; }
g4() { g3; }
g5() { g4; }
g6() { g5; }
g7() { g6; }
g8() { g7; }
g9() { g8; }
gA() { g9; }
ble-measure -q a=1 b=2; echo $nsec
g1; echo $nsec
g2; echo $nsec
g3; echo $nsec
g4; echo $nsec
g5; echo $nsec
g6; echo $nsec
g7; echo $nsec
g8; echo $nsec
g9; echo $nsec
gA; echo $nsec

#    SC   SP
#    ---- ----
# g0 220  281
# g1 790  429
# g2 790  459
# g3 892  517
# g4 941  583
# g5 1078 660
# g6 1077 684
# g7 1160 688
# g8 1221 745
# g9 1290 936
# gA 1397 868
#
# SC: 'a=1; b=2'
# SP: 'a=1 b=2'
# どうも関数の中身によって異なる様だ…。
# でもグラフに書いてみると (g0 を除けば) 傾きは同じ様だ。
