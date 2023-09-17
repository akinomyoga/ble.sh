#!/bin/bash

source src/benchmark.sh

# 然し計測していて気付いたが実はこれは実際の処理よりも引数の展開の方に
# 時間がかかっている様である。と思ったが違う…。これは arr1 の初期化に
# 時間がかかっているのだ。
arr1=({0..10000})
arr2=()

#------------------------------------------------------------------------------
# 配列コピー

#ble-measure 'arr2=("${arr1[@]}")'

# この結果を見ると bash-4.4 が特別に遅いというよりは bash-5.0 が速い

# 10k
# bash-5.0 127048.200 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-4.4  14800.000 usec/eval: arr2=("${arr1[@]}") (x10)
# bash-4.3  17900.000 usec/eval: arr2=("${arr1[@]}") (x10)
# bash-4.2 104000.000 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-4.1 106000.000 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-4.0  23500.000 usec/eval: arr2=("${arr1[@]}") (x10)
# bash-3.2  61000.000 usec/eval: arr2=("${arr1[@]}") (x2)
# bash-3.1 104000.000 usec/eval: arr2=("${arr1[@]}") (x1)

# 100k
# bash-5.0 1384414.200 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-4.4  116000.000 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-4.3 1134000.000 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-4.2 1155000.000 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-4.1 1168000.000 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-4.0 1183000.000 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-3.2 1408000.000 usec/eval: arr2=("${arr1[@]}") (x1)
# bash-3.1 1230000.000 usec/eval: arr2=("${arr1[@]}") (x1)


function ble/array#set { eval "$1=(\"\${@:2}\")"; }
#ble-measure 'ble/array#set arr2 "${arr1[@]}"'

# Bash-5.0 以外では一旦関数の引数にした方が速い

# bash-5.0  14088.700 usec/eval: ble/array#set arr2 "${arr1[@]}" (x10)
# bash-4.4  52000.000 usec/eval: ble/array#set arr2 "${arr1[@]}" (x2)
# bash-4.3  24400.000 usec/eval: ble/array#set arr2 "${arr1[@]}" (x5)
# bash-4.2  26400.000 usec/eval: ble/array#set arr2 "${arr1[@]}" (x5)
# bash-4.1  35400.000 usec/eval: ble/array#set arr2 "${arr1[@]}" (x5)
# bash-4.0  36600.000 usec/eval: ble/array#set arr2 "${arr1[@]}" (x5)
# bash-3.2  35200.000 usec/eval: ble/array#set arr2 "${arr1[@]}" (x5)
# bash-3.1  35800.000 usec/eval: ble/array#set arr2 "${arr1[@]}" (x5)


#------------------------------------------------------------------------------
# 配列追記

function ble/array#push.1 { eval "$1+=(\"\${@:2}\")"; }
function ble/array#push.2 { eval "$1=(\"\${$1[@]}\" \"\${@:2}\")"; }

#ble-measure 'arr2=({0..10000})'
# bash-5.0 4759.662 usec/eval: arr2=({0..10000}) (x50)
# bash-4.4 4678.000 usec/eval: arr2=({0..10000}) (x50)
# bash-4.3 4438.000 usec/eval: arr2=({0..10000}) (x50)
# bash-4.2 5316.000 usec/eval: arr2=({0..10000}) (x50)
# bash-4.1 6495.000 usec/eval: arr2=({0..10000}) (x20)
# bash-4.0 6595.000 usec/eval: arr2=({0..10000}) (x20)
# bash-3.2 6495.000 usec/eval: arr2=({0..10000}) (x20)
# bash-3.1 6645.000 usec/eval: arr2=({0..10000}) (x20)

#ble-measure 'arr2=({0..10000}); ble/array#push.1 arr2 {1..1000}'
# bash-5.0  6201.960 usec/eval: arr2=({0..10000}); ble/array#push.1 arr2 {1..1000} (x20)
# bash-4.4  5795.000 usec/eval: arr2=({0..10000}); ble/array#push.1 arr2 {1..1000} (x20)
# bash-4.3 11600.000 usec/eval: arr2=({0..10000}); ble/array#push.1 arr2 {1..1000} (x10)
# bash-4.2 10600.000 usec/eval: arr2=({0..10000}); ble/array#push.1 arr2 {1..1000} (x10)
# bash-4.1 13100.000 usec/eval: arr2=({0..10000}); ble/array#push.1 arr2 {1..1000} (x10)
# bash-4.0 70500.000 usec/eval: arr2=({0..10000}); ble/array#push.1 arr2 {1..1000} (x2)
# bash-3.2 69000.000 usec/eval: arr2=({0..10000}); ble/array#push.1 arr2 {1..1000} (x2)
# bash-3.1 68500.000 usec/eval: arr2=({0..10000}); ble/array#push.1 arr2 {1..1000} (x2)

#ble-measure 'arr2=({0..10000}); ble/array#push.2 arr2 {1..1000}'
# bash-5.0  15342.200 usec/eval: arr2=({0..10000}); ble/array#push.2 arr2 {1..1000} (x10)
# bash-4.4  24000.000 usec/eval: arr2=({0..10000}); ble/array#push.2 arr2 {1..1000} (x5)
# bash-4.3  15700.000 usec/eval: arr2=({0..10000}); ble/array#push.2 arr2 {1..1000} (x10)
# bash-4.2 106000.000 usec/eval: arr2=({0..10000}); ble/array#push.2 arr2 {1..1000} (x1)
# bash-4.1 119000.000 usec/eval: arr2=({0..10000}); ble/array#push.2 arr2 {1..1000} (x1)
# bash-4.0 119000.000 usec/eval: arr2=({0..10000}); ble/array#push.2 arr2 {1..1000} (x1)
# bash-3.2 116000.000 usec/eval: arr2=({0..10000}); ble/array#push.2 arr2 {1..1000} (x1)
# bash-3.1 113000.000 usec/eval: arr2=({0..10000}); ble/array#push.2 arr2 {1..1000} (x1)

#ble-measure 'arr2=({0..1000}); ble/array#push.1 arr2 "${arr1[@]}"'
# bash-5.0  14919.310 usec/eval: arr2=({0..1000}); ble/array#push.1 arr2 "${arr1[@]}" (x10)
# bash-4.4  78000.000 usec/eval: arr2=({0..1000}); ble/array#push.1 arr2 "${arr1[@]}" (x2)
# bash-4.3  25800.000 usec/eval: arr2=({0..1000}); ble/array#push.1 arr2 "${arr1[@]}" (x5)
# bash-4.2  28000.000 usec/eval: arr2=({0..1000}); ble/array#push.1 arr2 "${arr1[@]}" (x5)
# bash-4.1  36400.000 usec/eval: arr2=({0..1000}); ble/array#push.1 arr2 "${arr1[@]}" (x5)
# bash-4.0 372000.000 usec/eval: arr2=({0..1000}); ble/array#push.1 arr2 "${arr1[@]}" (x1)
# bash-3.2 273000.000 usec/eval: arr2=({0..1000}); ble/array#push.1 arr2 "${arr1[@]}" (x1)
# bash-3.1 267000.000 usec/eval: arr2=({0..1000}); ble/array#push.1 arr2 "${arr1[@]}" (x1)

#ble-measure 'arr2=({0..1000}); ble/array#push.2 arr2 "${arr1[@]}"'
# bash-5.0  15667.830 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 "${arr1[@]}" (x10)
# bash-4.4 101000.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 "${arr1[@]}" (x1)
# bash-4.3  25600.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 "${arr1[@]}" (x5)
# bash-4.2  28000.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 "${arr1[@]}" (x5)
# bash-4.1  37600.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 "${arr1[@]}" (x5)
# bash-4.0  37600.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 "${arr1[@]}" (x5)
# bash-3.2  37200.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 "${arr1[@]}" (x5)
# bash-3.1  37400.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 "${arr1[@]}" (x5)

#ble-measure 'arr2=({0..1000}); ble/array#push.2 arr2 {0..10000}'
# bash-5.0 133900.200 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 {0..10000} (x1)
# bash-4.4 106000.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 {0..10000} (x1)
# bash-4.3  21800.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 {0..10000} (x5)
# bash-4.2  22600.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 {0..10000} (x5)
# bash-4.1  29400.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 {0..10000} (x5)
# bash-4.0  30400.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 {0..10000} (x5)
# bash-3.2  29800.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 {0..10000} (x5)
# bash-3.1  29200.000 usec/eval: arr2=({0..1000}); ble/array#push.2 arr2 {0..10000} (x5)

#------------------------------------------------------------------------------
