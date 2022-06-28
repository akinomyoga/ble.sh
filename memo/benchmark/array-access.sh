#!/usr/bin/env bash

if [[ ! ${BLE_VERSION-} ]]; then
  source ../../src/benchmark.sh
fi

function measure-array.1 {
  local N=$1
  eval "local -a a=({1..$N})"
  ble-measure "$2"
}
function measure-array {
  measure-array.1 10     "$1 10    "
  measure-array.1 100    "$1 100   "
  measure-array.1 1000   "$1 1000  "
  measure-array.1 10000  "$1 10000 "
  measure-array.1 100000 "$1 100000"
}
function sum-forward  { local s=0; for ((i=0;i<N;i++)); do ((s+=a[i])); done       ; }
function sum-backward { local s=0; for ((i=N;--i>=0;)); do ((s+=a[i])); done       ; }
function sum-random   { local s=0; for ((i=0;i<N;i++)); do ((s+=a[RANDOM%N])); done; }

measure-array sum-forward 
measure-array sum-backward
measure-array sum-random  

# bash-dev
#      38.371 usec/eval: sum-forward 10     (x5000)
#     311.913 usec/eval: sum-forward 100    (x500)
#    3046.322 usec/eval: sum-forward 1000   (x50)
#   30699.500 usec/eval: sum-forward 10000  (x5)
#  309013.300 usec/eval: sum-forward 100000 (x1)
#      33.804 usec/eval: sum-backward 10     (x5000)
#     269.811 usec/eval: sum-backward 100    (x500)
#    2645.302 usec/eval: sum-backward 1000   (x50)
#   26564.500 usec/eval: sum-backward 10000  (x5)
#  266084.300 usec/eval: sum-backward 100000 (x1)
#      45.826 usec/eval: sum-random 10     (x5000)
#     399.209 usec/eval: sum-random 100    (x500)
#    4580.182 usec/eval: sum-random 1000   (x50)
#  135904.300 usec/eval: sum-random 10000  (x1)
# 3693072.300 usec/eval: sum-random 100000 (x1)

# bash-5.0
#      38.723 usec/eval: sum-forward 10     (x5000)
#     322.861 usec/eval: sum-forward 100    (x500)
#    3188.720 usec/eval: sum-forward 1000   (x50)
#   31446.200 usec/eval: sum-forward 10000  (x5)
#  317422.600 usec/eval: sum-forward 100000 (x1)
#      34.875 usec/eval: sum-backward 10     (x5000)
#     286.639 usec/eval: sum-backward 100    (x500)
#    2826.220 usec/eval: sum-backward 1000   (x50)
#   27921.600 usec/eval: sum-backward 10000  (x5)
#  283819.600 usec/eval: sum-backward 100000 (x1)
#      46.838 usec/eval: sum-random 10     (x2000)
#     414.663 usec/eval: sum-random 100    (x500)
#    5517.050 usec/eval: sum-random 1000   (x20)
#  123421.600 usec/eval: sum-random 10000  (x1)
# 4942400.600 usec/eval: sum-random 100000 (x1)

# bash-4.4
#       41.660 usec/eval: sum-forward 10     (x5000)
#      354.000 usec/eval: sum-forward 100    (x500)
#     3416.000 usec/eval: sum-forward 1000   (x50)
#    34200.000 usec/eval: sum-forward 10000  (x5)
#   347000.000 usec/eval: sum-forward 100000 (x1)
#       37.060 usec/eval: sum-backward 10     (x5000)
#      316.000 usec/eval: sum-backward 100    (x500)
#     5095.000 usec/eval: sum-backward 1000   (x20)
#   242000.000 usec/eval: sum-backward 10000  (x1)
# 19999000.000 usec/eval: sum-backward 100000 (x1)
#       51.050 usec/eval: sum-random 10     (x2000)
#      454.000 usec/eval: sum-random 100    (x500)
#     5895.000 usec/eval: sum-random 1000   (x20)
#   172000.000 usec/eval: sum-random 10000  (x1)
#  4577000.000 usec/eval: sum-random 100000 (x1)
