#!/bin/bash

function ble/cmap:xterm/CSI-CMS {
  local Fp="$1" Ft="$2" key="$3"
  ble-bind -k "ESC [ $Fp $Ft"     "$key"
  ble-bind -k "ESC [ $Fp ; 1 $Ft" "$key"
  ble-bind -k "ESC [ $Fp ; 2 $Ft" "S-$key"
  ble-bind -k "ESC [ $Fp ; 3 $Ft" "M-$key"
  ble-bind -k "ESC [ $Fp ; 4 $Ft" "M-S-$key"
  ble-bind -k "ESC [ $Fp ; 5 $Ft" "C-$key"
  ble-bind -k "ESC [ $Fp ; 6 $Ft" "C-S-$key"
  ble-bind -k "ESC [ $Fp ; 7 $Ft" "C-M-$key"
  ble-bind -k "ESC [ $Fp ; 8 $Ft" "C-M-S-$key"
}
function ble/cmap:xterm/SS3-CMS {
  local Ft="$1" key="$2"
  ble-bind -k "ESC O $Ft"     "$key"

  # 要Check: 以下のシーケンスの出所は??
  ble-bind -k "ESC O 1 $Ft" "$key"
  ble-bind -k "ESC O 2 $Ft" "S-$key"
  ble-bind -k "ESC O 3 $Ft" "M-$key"
  ble-bind -k "ESC O 4 $Ft" "M-S-$key"
  ble-bind -k "ESC O 5 $Ft" "C-$key"
  ble-bind -k "ESC O 6 $Ft" "C-S-$key"
  ble-bind -k "ESC O 7 $Ft" "C-M-$key"
  ble-bind -k "ESC O 8 $Ft" "C-M-S-$key"
}

ble-bind --csi 'A' up
ble-bind --csi 'B' down
ble-bind --csi 'C' right
ble-bind --csi 'D' left
#ble-bind --csi 'E' begin
ble-bind --csi 'F' end
ble-bind --csi 'H' home
ble-bind --csi 'P' f1
ble-bind --csi 'Q' f2
ble-bind --csi 'R' f3
ble-bind --csi 'S' f4

ble/cmap:xterm/SS3-CMS 'A' up
ble/cmap:xterm/SS3-CMS 'B' down
ble/cmap:xterm/SS3-CMS 'C' right
ble/cmap:xterm/SS3-CMS 'D' left
#ble/cmap:xterm/SS3-CMS 'E' begin
ble/cmap:xterm/SS3-CMS 'F' end
ble/cmap:xterm/SS3-CMS 'H' home
ble/cmap:xterm/SS3-CMS 'P' f1
ble/cmap:xterm/SS3-CMS 'Q' f2
ble/cmap:xterm/SS3-CMS 'R' f3
ble/cmap:xterm/SS3-CMS 'S' f4
ble/cmap:xterm/SS3-CMS 'j' kpmul
ble/cmap:xterm/SS3-CMS 'k' kpadd
ble/cmap:xterm/SS3-CMS 'l' kpsep
ble/cmap:xterm/SS3-CMS 'm' kpsub
ble/cmap:xterm/SS3-CMS 'o' kpdiv
ble/cmap:xterm/SS3-CMS 'p' kp0
ble/cmap:xterm/SS3-CMS 'q' kp1
ble/cmap:xterm/SS3-CMS 'r' kp2
ble/cmap:xterm/SS3-CMS 's' kp3
ble/cmap:xterm/SS3-CMS 't' kp4
ble/cmap:xterm/SS3-CMS 'u' kp5
ble/cmap:xterm/SS3-CMS 'v' kp6
ble/cmap:xterm/SS3-CMS 'w' kp7
ble/cmap:xterm/SS3-CMS 'x' kp8
ble/cmap:xterm/SS3-CMS 'y' kp9

ble-bind --csi '1~' home
ble-bind --csi '2~' insert
ble-bind --csi '3~' delete
ble-bind --csi '4~' end #
ble-bind --csi '4~' select # xterm
ble-bind --csi '5~' prior
ble-bind --csi '6~' next

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
ble-bind --csi '29~' print # xterm
ble-bind --csi '31~' f17
ble-bind --csi '32~' f18
ble-bind --csi '33~' f19
ble-bind --csi '34~' f20
ble/cmap:xterm/CSI-CMS '2 3' '$' f21
ble/cmap:xterm/CSI-CMS '2 4' '$' f22
ble/cmap:xterm/CSI-CMS '2 5' '$' f23
ble/cmap:xterm/CSI-CMS '2 6' '$' f24

#
# xterm "CSI 2 7 ; ... ; code ~" 形式は
# 直接 ble 内で解釈されるので登録の必要はなくなった。
# 参考の為に、以下にデータだけは残しておく。
#

# xterm27form_code2key=(
#   [9]=TAB [13]=RET
#   # [8]=BS [27]=ESC [32]=SP

#   [33]='!' [34]='"' [35]='#' [36]='$' [37]='%' [38]='&' [39]="'" [40]='('
#   [41]=')' [42]='*' [43]='+' [44]=',' [45]='-' [46]=',' [47]='/'

#   [48]=0   [49]=1   [50]=2   [51]=3   [52]=4   [53]=5   [54]=6   [55]=7
#   [56]=8   [57]=9   [58]=':' [59]=';' [60]='<' [61]='=' [62]='>' [63]='?'

#   [92]='\'

#   # [96]='`'  [97]=a    [98]=b    [99]=c
#   # [100]=d   [101]=e   [102]=f   [103]=g
#   # [104]=h   [105]=i   [106]=j   [107]=k
#   # [108]=l   [109]=m   [110]=n   [111]=o
#   # [112]=p   [113]=q   [114]=r   [115]=s
#   # [116]=t   [117]=u   [118]=v   [119]=w
#   # [120]=x   [121]=y   [122]=z   [123]='{'
#   # [124]='|' [125]='}' [126]='~'
# )
