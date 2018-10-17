#!/bin/bash

ble-bind --csi '1~' home
ble-bind --csi '2~' insert
ble-bind --csi '3~' delete
ble-bind --csi '4~' end
ble-bind --csi '5~' prior
ble-bind --csi '6~' next

ble-bind -k 'ESC [ A' up
ble-bind -k 'ESC [ B' down
ble-bind -k 'ESC [ C' right
ble-bind -k 'ESC [ D' left
ble-bind -k 'ESC [ E' begin

ble-bind --csi 'A' up
ble-bind --csi 'B' down
ble-bind --csi 'C' right
ble-bind --csi 'D' left
ble-bind --csi 'E' begin

ble-bind --csi '11~' f1
ble-bind --csi '12~' f2
ble-bind --csi '13~' f3
ble-bind --csi '14~' f4
ble-bind --csi '15~' f5
ble-bind --csi '17~' f6
ble-bind --csi '18~' f7
ble-bind --csi '19~' f8
ble-bind --csi '20~' f9
ble-bind --csi '21~' f10
ble-bind --csi '23~' f11
ble-bind --csi '24~' f12
ble-bind --csi '25~' f13
ble-bind --csi '26~' f14
ble-bind --csi '28~' f15
ble-bind --csi '29~' f16
ble-bind --csi '31~' f17
ble-bind --csi '32~' f18
ble-bind --csi '33~' f19
ble-bind --csi '34~' f20

function ble/cmap:rosaterm/modified-function-key {
  local Fp="$1" Ft="$2" key="$3"
  ble-bind -k "ESC [ $Fp $Ft"     "$key"
  ble-bind -k "ESC [ $Fp ; 1 $Ft" "$key"
  ble-bind -k "ESC [ $Fp ; 2 $Ft" "S-$key"
  ble-bind -k "ESC [ $Fp ; 3 $Ft" "A-$key"
  ble-bind -k "ESC [ $Fp ; 4 $Ft" "A-S-$key"
  ble-bind -k "ESC [ $Fp ; 5 $Ft" "C-$key"
  ble-bind -k "ESC [ $Fp ; 6 $Ft" "C-S-$key"
  ble-bind -k "ESC [ $Fp ; 7 $Ft" "C-A-$key"
  ble-bind -k "ESC [ $Fp ; 8 $Ft" "C-A-S-$key"
}

ble/cmap:rosaterm/modified-function-key   '2 3' '$' f21
ble/cmap:rosaterm/modified-function-key   '2 4' '$' f22
ble/cmap:rosaterm/modified-function-key   '2 5' '$' f23
ble/cmap:rosaterm/modified-function-key   '2 6' '$' f24

#
# for older version of rosaterm
#

ble/cmap:rosaterm/modified-function-key     '8' '^' BS
ble/cmap:rosaterm/modified-function-key     '9' '^' TAB
ble/cmap:rosaterm/modified-function-key   '1 3' '^' RET
ble/cmap:rosaterm/modified-function-key   '2 7' '^' ESC

ble/cmap:rosaterm/modified-function-key   '3 2' '^' SP
ble/cmap:rosaterm/modified-function-key   '3 3' '^' '!'
ble/cmap:rosaterm/modified-function-key   '3 4' '^' '"'
ble/cmap:rosaterm/modified-function-key   '3 5' '^' '#'
ble/cmap:rosaterm/modified-function-key   '3 6' '^' '$'
ble/cmap:rosaterm/modified-function-key   '3 7' '^' '%'
ble/cmap:rosaterm/modified-function-key   '3 8' '^' '&'
ble/cmap:rosaterm/modified-function-key   '3 9' '^' "'"
ble/cmap:rosaterm/modified-function-key   '4 0' '^' '('
ble/cmap:rosaterm/modified-function-key   '4 1' '^' ')'
ble/cmap:rosaterm/modified-function-key   '4 2' '^' '*'
ble/cmap:rosaterm/modified-function-key   '4 3' '^' '+'
ble/cmap:rosaterm/modified-function-key   '4 4' '^' ','
ble/cmap:rosaterm/modified-function-key   '4 5' '^' '-'
ble/cmap:rosaterm/modified-function-key   '4 6' '^' ','
ble/cmap:rosaterm/modified-function-key   '4 7' '^' '/'

ble/cmap:rosaterm/modified-function-key   '4 8' '^' 0
ble/cmap:rosaterm/modified-function-key   '4 9' '^' 1
ble/cmap:rosaterm/modified-function-key   '5 0' '^' 2
ble/cmap:rosaterm/modified-function-key   '5 1' '^' 3
ble/cmap:rosaterm/modified-function-key   '5 2' '^' 4
ble/cmap:rosaterm/modified-function-key   '5 3' '^' 5
ble/cmap:rosaterm/modified-function-key   '5 4' '^' 6
ble/cmap:rosaterm/modified-function-key   '5 5' '^' 7
ble/cmap:rosaterm/modified-function-key   '5 6' '^' 8
ble/cmap:rosaterm/modified-function-key   '5 7' '^' 9
ble/cmap:rosaterm/modified-function-key   '5 8' '^' ':'
ble/cmap:rosaterm/modified-function-key   '5 9' '^' ';'
ble/cmap:rosaterm/modified-function-key   '6 0' '^' '<'
ble/cmap:rosaterm/modified-function-key   '6 1' '^' '='
ble/cmap:rosaterm/modified-function-key   '6 2' '^' '>'
ble/cmap:rosaterm/modified-function-key   '6 3' '^' '?'

ble/cmap:rosaterm/modified-function-key   '9 6' '^' '`'
ble/cmap:rosaterm/modified-function-key   '9 7' '^' a
ble/cmap:rosaterm/modified-function-key   '9 8' '^' b
ble/cmap:rosaterm/modified-function-key   '9 9' '^' c
ble/cmap:rosaterm/modified-function-key '1 0 0' '^' d
ble/cmap:rosaterm/modified-function-key '1 0 1' '^' e
ble/cmap:rosaterm/modified-function-key '1 0 2' '^' f
ble/cmap:rosaterm/modified-function-key '1 0 3' '^' g
ble/cmap:rosaterm/modified-function-key '1 0 4' '^' h
ble/cmap:rosaterm/modified-function-key '1 0 5' '^' i
ble/cmap:rosaterm/modified-function-key '1 0 6' '^' j
ble/cmap:rosaterm/modified-function-key '1 0 7' '^' k
ble/cmap:rosaterm/modified-function-key '1 0 8' '^' l
ble/cmap:rosaterm/modified-function-key '1 0 9' '^' m
ble/cmap:rosaterm/modified-function-key '1 1 0' '^' n
ble/cmap:rosaterm/modified-function-key '1 1 1' '^' o
ble/cmap:rosaterm/modified-function-key '1 1 2' '^' p
ble/cmap:rosaterm/modified-function-key '1 1 3' '^' q
ble/cmap:rosaterm/modified-function-key '1 1 4' '^' r
ble/cmap:rosaterm/modified-function-key '1 1 5' '^' s
ble/cmap:rosaterm/modified-function-key '1 1 6' '^' t
ble/cmap:rosaterm/modified-function-key '1 1 7' '^' u
ble/cmap:rosaterm/modified-function-key '1 1 8' '^' v
ble/cmap:rosaterm/modified-function-key '1 1 9' '^' w
ble/cmap:rosaterm/modified-function-key '1 2 0' '^' x
ble/cmap:rosaterm/modified-function-key '1 2 1' '^' y
ble/cmap:rosaterm/modified-function-key '1 2 2' '^' z
ble/cmap:rosaterm/modified-function-key '1 2 3' '^' '{'
ble/cmap:rosaterm/modified-function-key '1 2 4' '^' '|'
ble/cmap:rosaterm/modified-function-key '1 2 5' '^' '}'
ble/cmap:rosaterm/modified-function-key '1 2 6' '^' '~'
