#!/bin/bash

## @var[out] str ind
function ble/keymap:vi_test/decompose-state {
  local spec=$1
  ind=${spec%%:*} str=${spec#*:}
  [[ $ind == [!0-9a-zA-Z] ]] &&
    ind=${str%%"$ind"*} ind=${#ind} str=${str::ind}${str:ind+1}
}

function ble/keymap:vi_test/start-section {
  section=$1 nsuccess=0 ntest=0
}

function ble/keymap:vi_test/check {
  local id=$1 initial=$2 kspecs=$3 final=$4
  local str ind
  ble/keymap:vi_test/decompose-state "$initial"; local i=$ind in=$str
  ble/keymap:vi_test/decompose-state "$final"; local f=$ind fin=$str
  
  local nl=$'\n' NL=$'\e[7m^J\e[m'
  _ble_edit_str.reset "$in" edit
  _ble_edit_ind=$i
  local ret
  ble-decode-kbd "$kspecs"
  ble-decode-key $ret &>/dev/null

  # check results
  [[ $_ble_edit_ind == "$f" && $_ble_edit_str == "$fin" ]]; local ext=$?
  if ((ext==0)); then
    ((ntest++,nsuccess++))
  else
    ((ntest++))
    echo "test($section/$id): keys = ($kspecs)"
    echo "  initial  = \"$i:${in//$nl/$NL}\""
    echo "  expected = \"$f:${fin//$nl/$NL}\""
    echo "  result   = \"$_ble_edit_ind:${_ble_edit_str//$nl/$NL}\""
  fi >&2

  # restore states
  case $_ble_decode_key__kmap in
  (vi_[ixo]map)
    ble-decode-key $((ble_decode_Ctrl|99)) &>/dev/null ;;
  esac

  return "$ext"
}

function ble/keymap:vi_test/show-summary {
  local title=$section
  if ((nsuccess==ntest)); then
    local tip=$'\e[32mpassed\e[m'
  else
    local tip=$'\e[31mfailed\e[m'
  fi
  echo "# $title test: result $((nsuccess))/$((ntest)) $tip"
}

#------------------------------------------------------------------------------
# tests

function ble/widget/vi-command:check-vi-mode/space {
  ble/keymap:vi_test/start-section '<space>'

  local str=$'    1234\n567890ab\n'
  ble/keymap:vi_test/check 1 "4:$str" '4 SP' "9:$str"
  ble/keymap:vi_test/check 2 "4:$str" 'd 4 SP' $'3:    \n567890ab\n'

  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/cw {
  ble/keymap:vi_test/start-section 'cw'

  # provided by cmplstofB
  ble/keymap:vi_test/check A1 '@:cp ./foo.txt   @        /tmp/' 'c w' '@:cp ./foo.txt   @/tmp/'
  ble/keymap:vi_test/check A2 '@:cp ./foo.tx@t           /tmp/' 'c w' '@:cp ./foo.tx@           /tmp/'
  ble/keymap:vi_test/check A3 '@:cp ./fo@o.txt           /tmp/' 'c w' '@:cp ./fo@.txt           /tmp/'
  ble/keymap:vi_test/check A4 '@:cp ./foo.t@xt           /tmp/' 'c w' '@:cp ./foo.t@           /tmp/'
  ble/keymap:vi_test/check A5 '@:cp ./fo@o.txt           /tmp/' 'c W' '@:cp ./fo@           /tmp/'

  ble/keymap:vi_test/check B1a '@:123@   456    789' 'c w'   '@:123@456    789'
  ble/keymap:vi_test/check B1b '@:123@   456    789' '1 c w' '@:123@456    789'
  ble/keymap:vi_test/check B1c '@:123@   456    789' '2 c w' '@:123@789'
  ble/keymap:vi_test/check B2a '@:12@3   456    789' 'c w'   '@:12@   456    789'
  ble/keymap:vi_test/check B2b '@:12@3   456    789' '1 c w' '@:12@   456    789'
  ble/keymap:vi_test/check B2c '@:12@3   456    789' '2 c w' '@:12@    789'
  ble/keymap:vi_test/check B3a '@:@123   456    789' 'c w'   '@:@   456    789'
  ble/keymap:vi_test/check B3b '@:@123   456    789' '1 c w' '@:@   456    789'
  ble/keymap:vi_test/check B3c '@:@123   456    789' '2 c w' '@:@    789'
  ble/keymap:vi_test/check B4a '@:ab@c///漢字' 'c w'   '@:ab@///漢字'
  ble/keymap:vi_test/check B4b '@:ab@c///漢字' '1 c w' '@:ab@///漢字'
  ble/keymap:vi_test/check B4c '@:ab@c///漢字' '2 c w' '@:ab@漢字'
  ble/keymap:vi_test/check B5a '@:@abc///漢字' 'c w'   '@:@///漢字'
  ble/keymap:vi_test/check B5b '@:@abc///漢字' '1 c w' '@:@///漢字'
  ble/keymap:vi_test/check B5c '@:@abc///漢字' '2 c w' '@:@漢字'

  # with empty lines
  ble/keymap:vi_test/check C1 $'@:123 456 @  \n\n789' 'c w' $'@:123 456 @\n\n789'
  ble/keymap:vi_test/check C2 $'@:123 456   \n@\n789' 'c w' $'@:123 456   \n@\n789'
  ble/keymap:vi_test/check C3 $'@:123 45@6   \n\n789' 'c w' $'@:123 45@   \n\n789'
  ble/keymap:vi_test/check C4 $'@:123 456@   \n\n789\nabc' '2 c w' $'@:123 456@\n789\nabc'
  ble/keymap:vi_test/check C5 $'@:123 45@6   \n\n789\nabc' '2 c w' $'@:123 45@\nabc'
  ble/keymap:vi_test/check C6 $'@:123 4@56   \n\n789\nabc' '2 c w' $'@:123 4@\nabc'
  ble/keymap:vi_test/check C7 $'@:123 456@   \n\n\n789\nabc' '2 c w' $'@:123 456@\n\n789\nabc'
  ble/keymap:vi_test/check C8 $'@:123 45@6   \n\n\n789\nabc' '2 c w' $'@:123 45@\nabc'
  ble/keymap:vi_test/check C9 $'@:123 4@56   \n\n\n789\nabc' '2 c w' $'@:123 4@\nabc'
  ble/keymap:vi_test/check C9 $'@:123 456   \n\n@' '2 c w' $'@:123 456   \n\n@'

  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/search {
  ble/keymap:vi_test/start-section '/ ? n N'
  ble/keymap:vi_test/check A1a '@:ech@o abc abc abc' '/ a b c RET'       '@:echo @abc abc abc'
  ble/keymap:vi_test/check A1b '@:ech@o abc abc abc' '/ a b c RET n'     '@:echo abc @abc abc'
  ble/keymap:vi_test/check A1c '@:ech@o abc abc abc' '/ a b c RET 2 n'   '@:echo abc abc @abc'
  ble/keymap:vi_test/check A1d '@:ech@o abc abc abc' '/ a b c RET 2 n N' '@:echo abc @abc abc'
  ble/keymap:vi_test/check A2a '@:echo@ abc abc abc' '/ a b c RET' '@:echo @abc abc abc'
  ble/keymap:vi_test/check A2b '@:echo @abc abc abc' '/ a b c RET' '@:echo abc @abc abc'
  ble/keymap:vi_test/check A2c '@:echo a@bc abc abc' '/ a b c RET' '@:echo abc @abc abc'
  ble/keymap:vi_test/check A3a '@:echo abc@ abc abc' '? a b c RET' '@:echo @abc abc abc'
  ble/keymap:vi_test/check A3b '@:echo abc @abc abc' '? a b c RET' '@:echo @abc abc abc'
  ble/keymap:vi_test/check A3c '@:echo abc a@bc abc' '? a b c RET' '@:echo abc @abc abc'
  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/increment {
  ble/keymap:vi_test/start-section '<C-a>, <C-x>'

  ble/keymap:vi_test/check A1a '@:@123' 'C-a' '@:12@4'
  ble/keymap:vi_test/check A1b '@:@123' 'C-x' '@:12@2'
  ble/keymap:vi_test/check A1c '@:@-123' 'C-a' '@:-12@2'
  ble/keymap:vi_test/check A1d '@:@-123' 'C-x' '@:-12@4'

  ble/keymap:vi_test/check A2a '@:@ -123 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2b '@: @-123 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2c '@: -@123 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2d '@: -1@23 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2e '@: -12@3 0' 'C-a' '@: -12@2 0'
  ble/keymap:vi_test/check A2f '@: -123@ 0' 'C-a' '@: -123 @1'

  ble/keymap:vi_test/check A3a '@:@000' 'C-a'       '@:00@1'
  ble/keymap:vi_test/check A3b '@:@000' '1 0 C-a'   '@:01@0'
  ble/keymap:vi_test/check A3c '@:@000' '1 0 0 C-a' '@:10@0'
  ble/keymap:vi_test/check A3d '@:@000' 'C-x'       '@:-00@1'
  ble/keymap:vi_test/check A3e '@:@000' '1 0 C-x'   '@:-01@0'
  ble/keymap:vi_test/check A3f '@:@000' '1 0 0 C-x' '@:-10@0'
  ble/keymap:vi_test/check A3g '@:@099' '1 0 0 C-x' '@:-00@1'
  ble/keymap:vi_test/check A3h '@:@099' '9 9 C-x' '@:00@0'

  ble/keymap:vi_test/check A4a '@:-@0' 'C-a' '@:@1'

  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/macro {
  local _ble_decode_keylog_depth=0 # to enable ble-decode/keylog for automatic ble-decode-key
  ble/keymap:vi_test/start-section 'qx..q'
  ble/keymap:vi_test/check A1 '@:@123' 'q a A SP h e l l o C-[ q @ a' '@:123 hello hell@o'
  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/surround {
  ble/keymap:vi_test/start-section 'surround'

  # ys の時は末端の空白を除く
  ble/keymap:vi_test/check A1a '@:abcd @fghi jklm nopq' 'y s e a'     '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A1b '@:abcd @fghi jklm nopq' 'y s w a'     '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A1c '@:abcd @fghi jklm nopq' 'y s a w a'   '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A1d '@:abcd @     jklm nopq' 'y s 3 l a'   '@:abcd @<>     jklm nopq'

  # vS の時は末端の空白は除かない
  ble/keymap:vi_test/check A2a '@:abcd @fghi jklm nopq' 'v 3 l S a'   '@:abcd @<fghi> jklm nopq'
  ble/keymap:vi_test/check A2b '@:abcd @fghi jklm nopq' 'v 4 l S a'   '@:abcd @<fghi >jklm nopq'
  ble/keymap:vi_test/check A2c '@:abcd @fghi jklm nopq' 'h v 5 l S a' '@:abcd@< fghi >jklm nopq'

  ble/keymap:vi_test/show-summary
}
function ble/widget/vi-command:check-vi-mode/xmap_txtobj_quote {
  ble/keymap:vi_test/start-section 'xmap text object i" a"'

  # A. xmap txtobj i"/a"、開始点と終了点が同じとき

  # A1. 様々な位置で実行した時
  ble/keymap:vi_test/check A1a '@:ab@cd " fghi " jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A1b '@:abcd @" fghi " jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A1c '@:abcd " fghi@ " jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A1d '@:abcd " fghi @" jklm " nopq " rstu " vwxyz' 'v i " S a' '@:abcd " fghi "@< jklm >" nopq " rstu " vwxyz'
  # A2. 引数が指定された時、a" が指定された時
  ble/keymap:vi_test/check A2a '@:ab@cd " fghi " jklm " nopq " rstu " vwxyz' 'v 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A2b '@:ab@cd " fghi " jklm " nopq " rstu " vwxyz' 'v a " S a'   '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A2c '@:ab@cd " fghi " jklm " nopq " rstu " vwxyz' 'v 2 a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  # A3. "" の中が空の時
  ble/keymap:vi_test/check A3a '@:ab@cd "" jklm " nopq " rstu " vwxyz' 'v i " S a'   '@:abcd @<""> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check A3b '@:ab@cd "" jklm " nopq " rstu " vwxyz' 'v 2 i " S a' '@:abcd @<""> jklm " nopq " rstu " vwxyz'

  # B. xmap txtobj i"/a"、mark より現在位置の方が後のとき
  # B1. i"
  ble/keymap:vi_test/check B1a '@:abcd@ " fghi " jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd@< " fghi " jklm >" nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B1b '@:abcd " fghi " jklm " nopq@ " rstu " vwxyz' 'v l i " S a' '@:abcd " fghi " jklm " nopq@< " rstu >" vwxyz'
  ble/keymap:vi_test/check B1c '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B1d '@:abcd " fgh@i " jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B1e '@:abcd " fghi " @jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd " fghi " jklm "@< nopq >" rstu " vwxyz'
  ble/keymap:vi_test/check B1f '@:abcd " fghi "@ jklm " nopq " rstu " vwxyz' 'v l i " S a' '@:abcd " fghi "@< jklm " nopq >" rstu " vwxyz'
  # B2. 2i"
  ble/keymap:vi_test/check B2a '@:abcd@ " fghi " jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd@< " fghi " jklm "> nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B2b '@:abcd " fghi " jklm " nopq@ " rstu " vwxyz' 'v l 2 i " S a' '@:abcd " fghi " jklm " nopq@< " rstu "> vwxyz'
  ble/keymap:vi_test/check B2c '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B2d '@:abcd " fgh@i " jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B2e '@:abcd " fghi " @jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd " fghi " jklm @<" nopq "> rstu " vwxyz'
  ble/keymap:vi_test/check B2f '@:abcd " fghi "@ jklm " nopq " rstu " vwxyz' 'v l 2 i " S a' '@:abcd " fghi "@< jklm " nopq "> rstu " vwxyz'
  # B3. a"
  ble/keymap:vi_test/check B3a '@:abcd@ " fghi " jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd@< " fghi " jklm " >nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B3b '@:abcd " fghi " jklm " nopq@ " rstu " vwxyz' 'v l a " S a' '@:abcd " fghi " jklm " nopq@< " rstu " >vwxyz'
  ble/keymap:vi_test/check B3c '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B3d '@:abcd " fgh@i " jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check B3e '@:abcd " fghi " @jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd " fghi " jklm @<" nopq " >rstu " vwxyz'
  ble/keymap:vi_test/check B3f '@:abcd " fghi "@ jklm " nopq " rstu " vwxyz' 'v l a " S a' '@:abcd " fghi "@< jklm " nopq " >rstu " vwxyz'

  # C. xmap txtobj i"/a"、mark より現在位置の方が前のとき
  ble/keymap:vi_test/check C1a '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v h i " S a' '@:ab@<cd> " fghi " jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1b '@:abcd " @fghi " jklm " nopq " rstu " vwxyz' 'v h i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1c '@:abcd " fghi@ " jklm " nopq " rstu " vwxyz' 'v h i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1d '@:abcd " fghi @" jklm " nopq " rstu " vwxyz' 'v h i " S a' '@:abcd "@< fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1e '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v h i " S a' '@:abcd "@< fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C1f '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v 5 h i " S a' '@:abcd "@< fghi " jklm> " nopq " rstu " vwxyz'

  ble/keymap:vi_test/check C2a '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:ab@<cd> " fghi " jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2b '@:abcd " @fghi " jklm " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2c '@:abcd " fghi@ " jklm " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:abcd @<" fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2d '@:abcd " fghi @" jklm " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2e '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v h 2 i " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C2f '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v 5 h 2 i " S a' '@:abcd @<" fghi " jklm> " nopq " rstu " vwxyz'

  ble/keymap:vi_test/check C3a '@:abc@d " fghi " jklm " nopq " rstu " vwxyz' 'v h a " S a' '@:ab@<cd> " fghi " jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3b '@:abcd " @fghi " jklm " nopq " rstu " vwxyz' 'v h a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3c '@:abcd " fghi@ " jklm " nopq " rstu " vwxyz' 'v h a " S a' '@:abcd @<" fghi >" jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3d '@:abcd " fghi @" jklm " nopq " rstu " vwxyz' 'v h a " S a' '@:abcd @<" fghi "> jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3e '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v h a " S a' '@:abcd @<" fghi " >jklm " nopq " rstu " vwxyz'
  ble/keymap:vi_test/check C3f '@:abcd " fghi " jkl@m " nopq " rstu " vwxyz' 'v 5 h a " S a' '@:abcd @<" fghi " jklm> " nopq " rstu " vwxyz'

  ble/keymap:vi_test/show-summary
}

function ble/widget/vi-command:check-vi-mode/op.2018-02-22 {
  ble/keymap:vi_test/start-section 'op.2018-02-22'

  # 行指向のコピー&貼り付け #D0674
  ble/keymap:vi_test/check A0 $'@:12@345\n67890\n' 'y y p' $'@:12345\n@12345\n67890\n'

  # Y 及び yy ではカーソル位置は変化しない。 #D0673
  ble/keymap:vi_test/check B1 $'@:12@345\n67890\n' 'Y' $'@:12@345\n67890\n'
  ble/keymap:vi_test/check B2 $'@:12@345\n67890\n' 'y y' $'@:12@345\n67890\n'

  # blockwise operator d の書き直し #D0673
  ble/keymap:vi_test/check C $'@:\n12@34567\n1あ2345\n12い345\n123う45\n1234え5\n' 'C-v 4 j l d' $'@:\n12@567\n1 345\n12345\n12 45\n12え5\n'

  ble/keymap:vi_test/show-summary
}

#------------------------------------------------------------------------------

function ble/widget/vi-command:check-vi-mode {
  # save
  local original_str=$_ble_edit_str
  local original_ind=$_ble_edit_ind
  local original_mark=$_ble_edit_mark
  local original_mark_active=$_ble_edit_mark_active
  _ble_edit_line_disabled=1 ble/widget/.insert-newline
  ble/util/buffer.flush >&2

  local section ntest nsuccess

  #----------------------------------------------------------------------------

  ble/widget/vi-command:check-vi-mode/space
  ble/widget/vi-command:check-vi-mode/cw
  ble/widget/vi-command:check-vi-mode/search
  ble/widget/vi-command:check-vi-mode/increment
  ble/widget/vi-command:check-vi-mode/macro
  ble/widget/vi-command:check-vi-mode/surround
  ble/widget/vi-command:check-vi-mode/xmap_txtobj_quote
  ble/widget/vi-command:check-vi-mode/op.2018-02-22

  #----------------------------------------------------------------------------

  # restore
  _ble_edit_str.reset "$original_str" edit
  _ble_edit_ind=$original_ind
  _ble_edit_mark=$original_mark
  _ble_edit_mark_active=$original_mark_active
  return 0
}

function ble/widget/vi_imap/check-vi-mode {
  ble/widget/vi_imap/normal-mode
  ble/widget/vi-command:check-vi-mode
  return 0
}

ble-bind -m vi_imap -f 'C-\ C-\' vi_imap/check-vi-mode
ble-bind -m vi_nmap -f 'C-\ C-\' vi-command:check-vi-mode
