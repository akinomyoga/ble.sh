#!/bin/bash

function .ble-bind.function-key.CSI-CAS {
  local Fp="$1" Ft="$2" key="$3"
  echo ble-bind -k "ESC [ $Fp $Ft"     "$key"
  ble-bind -k "ESC [ $Fp $Ft"     "$key"
  ble-bind -k "ESC [ $Fp ; 1 $Ft" "$key"
  ble-bind -k "ESC [ $Fp ; 2 $Ft" "S-$key"
  ble-bind -k "ESC [ $Fp ; 3 $Ft" "A-$key"
  ble-bind -k "ESC [ $Fp ; 4 $Ft" "A-S-$key"
  ble-bind -k "ESC [ $Fp ; 5 $Ft" "C-$key"
  ble-bind -k "ESC [ $Fp ; 6 $Ft" "C-S-$key"
  ble-bind -k "ESC [ $Fp ; 7 $Ft" "C-A-$key"
  ble-bind -k "ESC [ $Fp ; 8 $Ft" "C-A-S-$key"
  echo ble-bind -k "ESC [ $Fp ; 8 $Ft" "C-A-S-$key"
}

.ble-bind.function-key.CSI-CAS '1' '~' home
.ble-bind.function-key.CSI-CAS '2' '~' insert
.ble-bind.function-key.CSI-CAS '3' '~' delete
.ble-bind.function-key.CSI-CAS '4' '~' end
.ble-bind.function-key.CSI-CAS '5' '~' prior
.ble-bind.function-key.CSI-CAS '6' '~' next

ble-bind -k 'ESC [ A' up
ble-bind -k 'ESC [ B' down
ble-bind -k 'ESC [ C' right
ble-bind -k 'ESC [ D' left
ble-bind -k 'ESC [ E' begin

.ble-bind.function-key.CSI-CAS '1' 'A' up
.ble-bind.function-key.CSI-CAS '1' 'B' down
.ble-bind.function-key.CSI-CAS '1' 'C' right
.ble-bind.function-key.CSI-CAS '1' 'D' left
.ble-bind.function-key.CSI-CAS '1' 'E' begin

.ble-bind.function-key.CSI-CAS '1 1' '~' f1
.ble-bind.function-key.CSI-CAS '1 2' '~' f2
.ble-bind.function-key.CSI-CAS '1 3' '~' f3
.ble-bind.function-key.CSI-CAS '1 4' '~' f4
.ble-bind.function-key.CSI-CAS '1 5' '~' f5
.ble-bind.function-key.CSI-CAS '1 7' '~' f6
.ble-bind.function-key.CSI-CAS '1 8' '~' f7
.ble-bind.function-key.CSI-CAS '1 9' '~' f8
.ble-bind.function-key.CSI-CAS '2 0' '~' f9
.ble-bind.function-key.CSI-CAS '2 1' '~' f10
.ble-bind.function-key.CSI-CAS '2 3' '~' f11
.ble-bind.function-key.CSI-CAS '2 4' '~' f12
.ble-bind.function-key.CSI-CAS '2 5' '~' f13
.ble-bind.function-key.CSI-CAS '2 6' '~' f14
.ble-bind.function-key.CSI-CAS '2 8' '~' f15
.ble-bind.function-key.CSI-CAS '2 9' '~' f16
.ble-bind.function-key.CSI-CAS '3 1' '~' f17
.ble-bind.function-key.CSI-CAS '3 2' '~' f18
.ble-bind.function-key.CSI-CAS '3 3' '~' f19
.ble-bind.function-key.CSI-CAS '3 4' '~' f20
.ble-bind.function-key.CSI-CAS '2 3' '$' f21
.ble-bind.function-key.CSI-CAS '2 4' '$' f22
.ble-bind.function-key.CSI-CAS '2 5' '$' f23
.ble-bind.function-key.CSI-CAS '2 6' '$' f24

.ble-bind.function-key.CSI-CAS     '8' '^' BS
.ble-bind.function-key.CSI-CAS     '9' '^' TAB
.ble-bind.function-key.CSI-CAS   '1 3' '^' RET
.ble-bind.function-key.CSI-CAS   '2 7' '^' ESC

.ble-bind.function-key.CSI-CAS   '3 2' '^' SP
.ble-bind.function-key.CSI-CAS   '3 3' '^' '!'
.ble-bind.function-key.CSI-CAS   '3 4' '^' '"'
.ble-bind.function-key.CSI-CAS   '3 5' '^' '#'
.ble-bind.function-key.CSI-CAS   '3 6' '^' '$'
.ble-bind.function-key.CSI-CAS   '3 7' '^' '%'
.ble-bind.function-key.CSI-CAS   '3 8' '^' '&'
.ble-bind.function-key.CSI-CAS   '3 9' '^' "'"
.ble-bind.function-key.CSI-CAS   '4 0' '^' '('
.ble-bind.function-key.CSI-CAS   '4 1' '^' ')'
.ble-bind.function-key.CSI-CAS   '4 2' '^' '*'
.ble-bind.function-key.CSI-CAS   '4 3' '^' '+'
.ble-bind.function-key.CSI-CAS   '4 4' '^' ','
.ble-bind.function-key.CSI-CAS   '4 5' '^' '-'
.ble-bind.function-key.CSI-CAS   '4 6' '^' ','
.ble-bind.function-key.CSI-CAS   '4 7' '^' '/'

.ble-bind.function-key.CSI-CAS   '4 8' '^' 0
.ble-bind.function-key.CSI-CAS   '4 9' '^' 1
.ble-bind.function-key.CSI-CAS   '5 0' '^' 2
.ble-bind.function-key.CSI-CAS   '5 1' '^' 3
.ble-bind.function-key.CSI-CAS   '5 2' '^' 4
.ble-bind.function-key.CSI-CAS   '5 3' '^' 5
.ble-bind.function-key.CSI-CAS   '5 4' '^' 6
.ble-bind.function-key.CSI-CAS   '5 5' '^' 7
.ble-bind.function-key.CSI-CAS   '5 6' '^' 8
.ble-bind.function-key.CSI-CAS   '5 7' '^' 9
.ble-bind.function-key.CSI-CAS   '5 8' '^' ':'
.ble-bind.function-key.CSI-CAS   '5 9' '^' ';'
.ble-bind.function-key.CSI-CAS   '6 0' '^' '<' 
.ble-bind.function-key.CSI-CAS   '6 1' '^' '='
.ble-bind.function-key.CSI-CAS   '6 2' '^' '>'
.ble-bind.function-key.CSI-CAS   '6 3' '^' '?'

.ble-bind.function-key.CSI-CAS   '9 6' '^' '`'
.ble-bind.function-key.CSI-CAS   '9 7' '^' a
.ble-bind.function-key.CSI-CAS   '9 8' '^' b
.ble-bind.function-key.CSI-CAS   '9 9' '^' c
.ble-bind.function-key.CSI-CAS '1 0 0' '^' d
.ble-bind.function-key.CSI-CAS '1 0 1' '^' e
.ble-bind.function-key.CSI-CAS '1 0 2' '^' f
.ble-bind.function-key.CSI-CAS '1 0 3' '^' g
.ble-bind.function-key.CSI-CAS '1 0 4' '^' h
.ble-bind.function-key.CSI-CAS '1 0 5' '^' i
.ble-bind.function-key.CSI-CAS '1 0 6' '^' j
.ble-bind.function-key.CSI-CAS '1 0 7' '^' k
.ble-bind.function-key.CSI-CAS '1 0 8' '^' l
.ble-bind.function-key.CSI-CAS '1 0 9' '^' m
.ble-bind.function-key.CSI-CAS '1 1 0' '^' n
.ble-bind.function-key.CSI-CAS '1 1 1' '^' o
.ble-bind.function-key.CSI-CAS '1 1 2' '^' p
.ble-bind.function-key.CSI-CAS '1 1 3' '^' q
.ble-bind.function-key.CSI-CAS '1 1 4' '^' r
.ble-bind.function-key.CSI-CAS '1 1 5' '^' s
.ble-bind.function-key.CSI-CAS '1 1 6' '^' t
.ble-bind.function-key.CSI-CAS '1 1 7' '^' u
.ble-bind.function-key.CSI-CAS '1 1 8' '^' v
.ble-bind.function-key.CSI-CAS '1 1 9' '^' w
.ble-bind.function-key.CSI-CAS '1 2 0' '^' x
.ble-bind.function-key.CSI-CAS '1 2 1' '^' y
.ble-bind.function-key.CSI-CAS '1 2 2' '^' z
.ble-bind.function-key.CSI-CAS '1 2 3' '^' '{'
.ble-bind.function-key.CSI-CAS '1 2 4' '^' '|'
.ble-bind.function-key.CSI-CAS '1 2 5' '^' '}'
.ble-bind.function-key.CSI-CAS '1 2 6' '^' '~'
